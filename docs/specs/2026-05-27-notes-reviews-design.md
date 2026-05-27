# Notes & Reviews Feature Design

## Overview

Add per-book written reviews and quotes (highlights) to PaperTrail, plus a search bar on the book list that searches across title, author, review text, and quote text. Small visual indicators on book cards show which books have a review or quotes.

## Scope

**In scope:**
- One free-form review per book.
- Multiple quotes per book, each with optional page number.
- Inline UI on book detail screen.
- Search bar on book list with match snippets.
- Review/quote indicators on book list cards.
- Long-press quote → copy / share (reuses `share_plus`).
- Backup format v2 (includes reviews and quotes) with backward-compatible v1 import.

**Out of scope:**
- Star ratings.
- Reading notes / marginalia (separate freeform notes per book).
- A global "All Quotes" feed or wall.
- Markdown / rich-text formatting.
- Sharing quote cards as images.
- Full-text search index (SQL `LIKE` is sufficient at expected collection size).

## Data Model

### Schema changes (DB v2 → v3)

```sql
ALTER TABLE books ADD COLUMN review TEXT;
ALTER TABLE books ADD COLUMN review_updated_at INTEGER;  -- epoch ms

CREATE TABLE quotes (
  id           TEXT PRIMARY KEY,        -- uuid v4
  book_id      TEXT NOT NULL,
  text         TEXT NOT NULL,
  page         INTEGER,                 -- nullable
  created_at   INTEGER NOT NULL,        -- epoch ms
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);
CREATE INDEX idx_quotes_book_id ON quotes(book_id);
-- No index on quotes.text: a plain B-tree does not accelerate
-- LIKE '%keyword%' (leading wildcard bypasses the index), and
-- the spec accepts full-scan search at expected collection size.
```

Migration runs in `database_helper.dart`'s `_onUpgrade` from v2 → v3. No data backfill — new columns/table start empty.

### Rationale

- **Review on the book row**, not a separate table: there's exactly one per book.
- **`review_updated_at`** is added now so a future "edited X ago" hint costs no migration later. No UI surface for it in this feature.
- **Quote `id` as TEXT/uuid** matches the existing book id convention so quotes survive export/import by stable identity.
- **`ON DELETE CASCADE`** matches how category/family links behave when a book is deleted.

## UI

### Book detail screen — inline sections

Appended below today's content on `book_detail_screen.dart`:

```
--- My Review ---
"Brilliant pacing. The middle sags…"     ← tap to edit
[Add review]                              ← shown only when review is null

--- Quotes (3) ---
"All happy families…"                p.1
"The child is father of the man…"    p.42
"…"                                  p.83
[+ Add quote]
```

- **Review tap** → full-screen modal route with a multiline `TextField`. Save closes the modal and persists. Cancel discards.
- **Quote tap** → same modal in edit mode (text + optional page). Save / Cancel / Delete.
- **+ Add quote** → modal in create mode.
- **Long-press a quote** → action sheet: Copy, Share (via `share_plus`), Delete.
- **Quote sort order**: `page ASC NULLS LAST, created_at ASC`.

### Book list screen — search bar + indicators

Add a search row pinned above the existing list. Indicators are small icons right-aligned on each card.

```
[ 🔍  Search books, reviews, quotes… ]

[cover] Pride and Prejudice          ★ 📑3
        Jane Austen
[cover] War and Peace                ★
        Leo Tolstoy
```

- **Indicators**: filled star (`Icons.star`) when `review IS NOT NULL`; document icon (`Icons.format_quote`) plus count when quote count > 0. Subtle, small, grouped at the right edge.
- **Empty query** → existing list behavior (sort/filter/category chips all still apply).
- **Non-empty query** → switches the list into "search results" mode. Active category filter still applies (results are restricted to the current category); sort order is replaced by search relevance / match-field order.

### Search results mode

Each result card shows a snippet beneath the title/author when the match was on review or quote text:

```
[cover] Anna Karenina                ★ 📑5
        Leo Tolstoy
        ↳ "…happy families are all alike…" — quote, p.1
```

- One snippet per book.
- Snippet preference order when multiple fields match: title > author > review > quote.
- For title/author matches, no snippet is rendered (the title already makes the match obvious).
- Snippet is ~60 chars centered on the match with `…` padding; matched substring rendered with `FontWeight.bold`.

## Search Behavior

### Queries

Two SQL `LIKE` queries (case-insensitive via `LOWER()`), merged in Dart and deduped by `book_id`:

```sql
-- Books matching title/author/review:
SELECT b.*,
       CASE
         WHEN LOWER(b.title)  LIKE :q THEN 'title'
         WHEN LOWER(b.author) LIKE :q THEN 'author'
         WHEN LOWER(b.review) LIKE :q THEN 'review'
       END AS match_field,
       b.review AS match_text
  FROM books b
 WHERE LOWER(b.title)  LIKE :q
    OR LOWER(b.author) LIKE :q
    OR LOWER(b.review) LIKE :q;

-- Books matching via quotes:
SELECT q.book_id, q.text AS match_text, q.page
  FROM quotes q
 WHERE LOWER(q.text) LIKE :q
 GROUP BY q.book_id;   -- one quote row per book; first match wins
```

`:q` is bound as `'%' + query.toLowerCase() + '%'`. Rows from the first query carry their `match_field` literal; rows from the second query are treated as `match_field = 'quote'` in the Dart merge.

### Provider

New `bookSearchProvider` (Riverpod, family by query string) returns `List<BookSearchResult>`, where:

```dart
class BookSearchResult {
  final Book book;
  final MatchSnippet? snippet; // null for title/author matches
}

class MatchSnippet {
  final String prefix;   // text before match
  final String matched;  // bolded portion
  final String suffix;   // text after match
  final String source;   // 'review' | 'quote'
  final int? page;       // when source == 'quote'
}
```

The book list screen swaps between the existing `bookNotifierProvider` (empty query) and `bookSearchProvider` (non-empty query).

### Snippet generation

Pure Dart helper, unit-testable:

1. Locate the (case-insensitive) match index in `match_text`.
2. Compute a 60-char window centered on the match, clamped to text bounds.
3. Add `…` prefix/suffix when the window is truncated.
4. Return `MatchSnippet(prefix, matched, suffix, source, page)`.

### Debounce

Search field debounces at 200 ms before triggering a query.

## Backup Format

### Version 2 schema (additive)

```json
{
  "version": 2,
  "exported_at": "2026-05-27T…",
  "books": [
    {
      "id": "…",
      "title": "…",
      "author": "…",
      "review": "Brilliant pacing…",
      "review_updated_at": 1716800000000
    }
  ],
  "categories": [ … ],
  "family": [ … ],
  "quotes": [
    { "id": "…", "book_id": "…", "text": "…", "page": 42, "created_at": 1716800000000 }
  ]
}
```

### Import behavior

- **v1 file**: reviews and quotes absent. Existing fields import as before; `review` stays null and no quotes are inserted. No warning.
- **v2 file**: books upsert as today; quotes upsert by `id` (insert-or-replace, matching the existing book upsert pattern).
- **Orphan guard**: if a quote's `book_id` is not present after the books pass, skip the quote and log via `LoggerService` (Sentry will capture).

### Export behavior

Always emits v2. Quotes are queried separately and serialized as a top-level array (not nested inside each book) so the format mirrors the table layout and stays diff-friendly.

## Code Organization

Files affected:

- `lib/core/database/database_helper.dart` — schema bump to v3, migration.
- `lib/core/services/backup_service.dart` — extend export to v2, extend import to read v1 and v2.
- `lib/features/books/models/book.dart` — add `review`, `reviewUpdatedAt`.
- `lib/features/books/models/quote.dart` — new model.
- `lib/features/books/providers/book_providers.dart` — add quote provider(s), `bookSearchProvider`, indicator query (review presence + quote count per book).
- `lib/features/books/screens/book_detail_screen.dart` — add inline review and quotes sections.
- `lib/features/books/screens/book_list_screen.dart` — add search bar; render snippets in results mode.
- `lib/features/books/widgets/book_card.dart` — add indicator icons.
- `lib/features/books/widgets/review_editor.dart` — new modal route.
- `lib/features/books/widgets/quote_editor.dart` — new modal route.
- `lib/features/books/utils/snippet.dart` — new pure helper.

## Testing

- **Unit**: snippet generator (truncation, padding, multi-match, no-match, edge of string); `bookSearchProvider` merge/dedupe and field-precedence; backup v1 → v2 round-trip parity (v2 export → v2 import yields equal data); v1 import on the v2 codepath leaves reviews/quotes empty.
- **Widget**: review section renders, opens editor, persists on save; quotes list adds/edits/deletes a quote; book list shows star and quote-count indicators only when applicable; search bar debounces (no query before 200 ms), switches between list and results modes, renders snippets with bolded match.
- **Migration**: applies v2 → v3 upgrade against a seeded v2 DB; verifies new column/table exist and old book rows are preserved.
- **No new integration tests**: existing `BackupService` tests gain the v1 → v2 cases.
