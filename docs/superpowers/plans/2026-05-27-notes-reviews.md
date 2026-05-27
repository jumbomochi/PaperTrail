# Notes & Reviews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-book reviews and quotes (with optional page numbers) to PaperTrail, surface them on the book detail screen, show small indicators on book cards, and extend the existing book list search to match review and quote text with inline snippets. Backup format bumps to v2 with backward-compatible v1 import.

**Architecture:** New `quotes` SQLite table with FK + cascade to `books`; review fields added directly to `books` (one per book). Riverpod providers expose per-book quotes and an aggregate `Map<bookId, count>` for indicators. Search remains client-side (matches the existing pattern in `book_list_screen.dart`): we load all books + all quotes once, then filter and decorate with `MatchSnippet` objects. Editors are full-screen modal routes returning the saved value.

**Tech Stack:** Flutter 3.x, Dart 3.10, `sqflite`, `flutter_riverpod`, `uuid`, `share_plus`, `flutter_test`.

**Spec:** `docs/specs/2026-05-27-notes-reviews-design.md`

---

## Important context for the implementer

- **Database version**: `database_helper.dart` is currently `version: 2`. Bump to `3` and add a new branch to `_upgradeDB` using `if (oldVersion < 3)`. Also add the new column/table to `_createDB` so fresh installs get them.
- **Book ID convention**: `const Uuid().v4()` (see `add_book_screen.dart:519`). Use the same for quotes.
- **Search currently lives client-side**: `book_list_screen.dart` does its own `_filterBooks` against the in-memory book list — that is the surface we extend. There is an unused `bookSearchProvider` in `book_providers.dart` that searches title/author/isbn server-side; leave it alone (don't touch / don't extend / don't rename).
- **Backup JSON keys** follow existing snake_case: `family_members` (not `family`), `categories`, `books`. The spec's example used `family` as a placeholder — match the existing `family_members` key.
- **Share on iOS** requires `sharePositionOrigin` (see commit 2033a7f). Reuse the same pattern when sharing a quote.
- **`updated_at` on books**: when a review changes, also update `books.updated_at` so existing logic continues to see the row as modified.

---

## Task 1: Bump DB to v3 — add review columns and quotes table

**Files:**
- Modify: `lib/core/database/database_helper.dart`

- [ ] **Step 1: Read the existing file** to confirm the current layout (`version: 2`, `_createDB`, `_upgradeDB`).

- [ ] **Step 2: Change the version constant**

Find:
```dart
return await openDatabase(
  path,
  version: 2,
  onCreate: _createDB,
  onUpgrade: _upgradeDB,
);
```

Replace with:
```dart
return await openDatabase(
  path,
  version: 3,
  onCreate: _createDB,
  onUpgrade: _upgradeDB,
);
```

- [ ] **Step 3: Add review columns to the books table in `_createDB`**

In the `CREATE TABLE books (...)` block in `_createDB`, add the two new columns just before the closing `)` and the foreign-key clauses (after `updated_at TEXT NOT NULL,`):

```dart
await db.execute('''
  CREATE TABLE books (
    id TEXT PRIMARY KEY,
    isbn TEXT,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    publisher TEXT,
    published_date TEXT,
    description TEXT,
    cover_image_path TEXT,
    thumbnail_url TEXT,
    page_count INTEGER,
    owner_id TEXT,
    category_id TEXT,
    is_wishlist INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    review TEXT,
    review_updated_at INTEGER,
    FOREIGN KEY (owner_id) REFERENCES family_members (id) ON DELETE SET NULL,
    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
  )
''');
```

- [ ] **Step 4: Add the quotes table to `_createDB`**

After the existing book indexes (`CREATE INDEX idx_books_isbn ON books (isbn)`) and before the `await _seedDefaultCategories(db);` line, add:

```dart
// Quotes table
await db.execute('''
  CREATE TABLE quotes (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    text TEXT NOT NULL,
    page INTEGER,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
  )
''');
await db.execute('CREATE INDEX idx_quotes_book_id ON quotes (book_id)');
await db.execute('CREATE INDEX idx_quotes_text ON quotes (text)');
```

- [ ] **Step 5: Add the v2 → v3 migration branch to `_upgradeDB`**

Append this block inside `_upgradeDB`, after the existing `if (oldVersion < 2)` block:

```dart
if (oldVersion < 3) {
  await db.execute('ALTER TABLE books ADD COLUMN review TEXT');
  await db.execute('ALTER TABLE books ADD COLUMN review_updated_at INTEGER');
  await db.execute('''
    CREATE TABLE quotes (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      text TEXT NOT NULL,
      page INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_quotes_book_id ON quotes (book_id)');
  await db.execute('CREATE INDEX idx_quotes_text ON quotes (text)');
}
```

- [ ] **Step 6: Verify build still compiles**

Run:
```bash
flutter analyze lib/core/database/database_helper.dart
```
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/database/database_helper.dart
git commit -m "feat: bump DB to v3 — add review columns and quotes table"
```

---

## Task 2: Extend `Book` model with `review` and `reviewUpdatedAt`

**Files:**
- Modify: `lib/features/books/models/book.dart`
- Test: `test/unit/models/book_test.dart`

- [ ] **Step 1: Write failing tests for the new fields**

Open `test/unit/models/book_test.dart`. Find the `createTestBook` helper and add two new optional parameters (and pass them through to the `Book` constructor). At the top of the helper:

```dart
Book createTestBook({
  String id = 'test-id',
  String? isbn = '978-0-13-468599-1',
  String title = 'Test Book',
  String author = 'Test Author',
  bool isWishlist = false,
  String? review,
  DateTime? reviewUpdatedAt,
}) {
  return Book(
    id: id,
    isbn: isbn,
    title: title,
    author: author,
    publisher: 'Test Publisher',
    publishedDate: '2024',
    description: 'A test book description',
    coverImagePath: '/path/to/cover.jpg',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    pageCount: 300,
    ownerId: 'owner-1',
    categoryId: 'category-1',
    isWishlist: isWishlist,
    createdAt: testDate,
    updatedAt: testDate,
    review: review,
    reviewUpdatedAt: reviewUpdatedAt,
  );
}
```

Then add a new `group` at the end of the file's existing top-level `group('Book', ...)`:

```dart
group('review fields', () {
  test('review and reviewUpdatedAt default to null', () {
    final book = createTestBook();
    expect(book.review, isNull);
    expect(book.reviewUpdatedAt, isNull);
  });

  test('toMap serializes review and review_updated_at', () {
    final reviewTime = DateTime.utc(2026, 5, 1, 12);
    final book = createTestBook(
      review: 'Brilliant pacing',
      reviewUpdatedAt: reviewTime,
    );
    final map = book.toMap();
    expect(map['review'], equals('Brilliant pacing'));
    expect(map['review_updated_at'], equals(reviewTime.millisecondsSinceEpoch));
  });

  test('toMap emits nulls when review is unset', () {
    final book = createTestBook();
    final map = book.toMap();
    expect(map['review'], isNull);
    expect(map['review_updated_at'], isNull);
  });

  test('fromMap parses review and review_updated_at', () {
    final reviewTime = DateTime.utc(2026, 5, 1, 12);
    final book = createTestBook(
      review: 'Great book',
      reviewUpdatedAt: reviewTime,
    );
    final roundTripped = Book.fromMap(book.toMap());
    expect(roundTripped.review, equals('Great book'));
    expect(roundTripped.reviewUpdatedAt, equals(reviewTime));
  });

  test('copyWith updates review and reviewUpdatedAt', () {
    final book = createTestBook();
    final later = DateTime.utc(2026, 5, 2);
    final updated = book.copyWith(review: 'New thoughts', reviewUpdatedAt: later);
    expect(updated.review, equals('New thoughts'));
    expect(updated.reviewUpdatedAt, equals(later));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
flutter test test/unit/models/book_test.dart
```
Expected: compile error (`review` named parameter undefined on `Book`).

- [ ] **Step 3: Add the fields to the `Book` model**

In `lib/features/books/models/book.dart`:

1. Add two new final fields after `updatedAt`:
   ```dart
   final String? review;
   final DateTime? reviewUpdatedAt;
   ```

2. Add them to the constructor:
   ```dart
   Book({
     required this.id,
     this.isbn,
     required this.title,
     required this.author,
     this.publisher,
     this.publishedDate,
     this.description,
     this.coverImagePath,
     this.thumbnailUrl,
     this.pageCount,
     this.ownerId,
     this.categoryId,
     this.isWishlist = false,
     required this.createdAt,
     required this.updatedAt,
     this.review,
     this.reviewUpdatedAt,
   });
   ```

3. Extend `toMap`:
   ```dart
   Map<String, dynamic> toMap() {
     return {
       'id': id,
       'isbn': isbn,
       'title': title,
       'author': author,
       'publisher': publisher,
       'published_date': publishedDate,
       'description': description,
       'cover_image_path': coverImagePath,
       'thumbnail_url': thumbnailUrl,
       'page_count': pageCount,
       'owner_id': ownerId,
       'category_id': categoryId,
       'is_wishlist': isWishlist ? 1 : 0,
       'created_at': createdAt.toIso8601String(),
       'updated_at': updatedAt.toIso8601String(),
       'review': review,
       'review_updated_at': reviewUpdatedAt?.millisecondsSinceEpoch,
     };
   }
   ```

4. Extend `fromMap`:
   ```dart
   factory Book.fromMap(Map<String, dynamic> map) {
     return Book(
       id: map['id'] as String,
       isbn: map['isbn'] as String?,
       title: map['title'] as String,
       author: map['author'] as String,
       publisher: map['publisher'] as String?,
       publishedDate: map['published_date'] as String?,
       description: map['description'] as String?,
       coverImagePath: map['cover_image_path'] as String?,
       thumbnailUrl: map['thumbnail_url'] as String?,
       pageCount: map['page_count'] as int?,
       ownerId: map['owner_id'] as String?,
       categoryId: map['category_id'] as String?,
       isWishlist: (map['is_wishlist'] as int?) == 1,
       createdAt: DateTime.parse(map['created_at'] as String),
       updatedAt: DateTime.parse(map['updated_at'] as String),
       review: map['review'] as String?,
       reviewUpdatedAt: map['review_updated_at'] == null
           ? null
           : DateTime.fromMillisecondsSinceEpoch(map['review_updated_at'] as int),
     );
   }
   ```

5. Extend `copyWith`:
   ```dart
   Book copyWith({
     String? id,
     String? isbn,
     String? title,
     String? author,
     String? publisher,
     String? publishedDate,
     String? description,
     String? coverImagePath,
     String? thumbnailUrl,
     int? pageCount,
     String? ownerId,
     String? categoryId,
     bool? isWishlist,
     DateTime? createdAt,
     DateTime? updatedAt,
     String? review,
     DateTime? reviewUpdatedAt,
   }) {
     return Book(
       id: id ?? this.id,
       isbn: isbn ?? this.isbn,
       title: title ?? this.title,
       author: author ?? this.author,
       publisher: publisher ?? this.publisher,
       publishedDate: publishedDate ?? this.publishedDate,
       description: description ?? this.description,
       coverImagePath: coverImagePath ?? this.coverImagePath,
       thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
       pageCount: pageCount ?? this.pageCount,
       ownerId: ownerId ?? this.ownerId,
       categoryId: categoryId ?? this.categoryId,
       isWishlist: isWishlist ?? this.isWishlist,
       createdAt: createdAt ?? this.createdAt,
       updatedAt: updatedAt ?? this.updatedAt,
       review: review ?? this.review,
       reviewUpdatedAt: reviewUpdatedAt ?? this.reviewUpdatedAt,
     );
   }
   ```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
flutter test test/unit/models/book_test.dart
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/books/models/book.dart test/unit/models/book_test.dart
git commit -m "feat: add review and reviewUpdatedAt fields to Book"
```

---

## Task 3: Create `Quote` model

**Files:**
- Create: `lib/features/books/models/quote.dart`
- Create: `test/unit/models/quote_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/models/quote_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/quote.dart';

void main() {
  final testTime = DateTime.utc(2026, 5, 1, 12);

  group('Quote', () {
    test('toMap serializes all fields', () {
      final quote = Quote(
        id: 'q-1',
        bookId: 'b-1',
        text: 'All happy families are alike',
        page: 1,
        createdAt: testTime,
      );
      final map = quote.toMap();
      expect(map['id'], equals('q-1'));
      expect(map['book_id'], equals('b-1'));
      expect(map['text'], equals('All happy families are alike'));
      expect(map['page'], equals(1));
      expect(map['created_at'], equals(testTime.millisecondsSinceEpoch));
    });

    test('toMap allows null page', () {
      final quote = Quote(
        id: 'q-1',
        bookId: 'b-1',
        text: 'no page',
        page: null,
        createdAt: testTime,
      );
      expect(quote.toMap()['page'], isNull);
    });

    test('fromMap round-trips', () {
      final original = Quote(
        id: 'q-1',
        bookId: 'b-1',
        text: 'A quote',
        page: 42,
        createdAt: testTime,
      );
      final reconstructed = Quote.fromMap(original.toMap());
      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.bookId, equals(original.bookId));
      expect(reconstructed.text, equals(original.text));
      expect(reconstructed.page, equals(original.page));
      expect(reconstructed.createdAt, equals(original.createdAt));
    });

    test('equality is by id', () {
      final a = Quote(id: 'q-1', bookId: 'b-1', text: 'A', createdAt: testTime);
      final b = Quote(id: 'q-1', bookId: 'b-2', text: 'B', createdAt: testTime);
      expect(a, equals(b));
    });

    test('copyWith replaces only provided fields', () {
      final original = Quote(
        id: 'q-1', bookId: 'b-1', text: 'A', page: 1, createdAt: testTime,
      );
      final updated = original.copyWith(text: 'B', page: 99);
      expect(updated.id, equals('q-1'));
      expect(updated.bookId, equals('b-1'));
      expect(updated.text, equals('B'));
      expect(updated.page, equals(99));
      expect(updated.createdAt, equals(testTime));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/unit/models/quote_test.dart
```
Expected: compile error (`quote.dart` not found).

- [ ] **Step 3: Create the model**

Create `lib/features/books/models/quote.dart`:

```dart
class Quote {
  final String id;
  final String bookId;
  final String text;
  final int? page;
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.bookId,
    required this.text,
    this.page,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'text': text,
      'page': page,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      text: map['text'] as String,
      page: map['page'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Quote copyWith({
    String? id,
    String? bookId,
    String? text,
    int? page,
    DateTime? createdAt,
  }) {
    return Quote(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      text: text ?? this.text,
      page: page ?? this.page,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
flutter test test/unit/models/quote_test.dart
```
Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/books/models/quote.dart test/unit/models/quote_test.dart
git commit -m "feat: add Quote model"
```

---

## Task 4: Create `QuoteRepository`

**Files:**
- Create: `lib/features/books/repositories/quote_repository.dart`

(No unit test file yet — repository depends on a live SQLite database. It is exercised through widget/integration tests added in later tasks.)

- [ ] **Step 1: Create the repository**

Create `lib/features/books/repositories/quote_repository.dart`:

```dart
import 'package:paper_trail/core/database/database_helper.dart';
import 'package:paper_trail/features/books/models/quote.dart';

class QuoteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Quote>> getAllQuotes() async {
    final db = await _dbHelper.database;
    final maps = await db.query('quotes');
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<List<Quote>> getQuotesForBook(String bookId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'quotes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'CASE WHEN page IS NULL THEN 1 ELSE 0 END, page ASC, created_at ASC',
    );
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<Map<String, int>> getQuoteCountsByBook() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT book_id, COUNT(*) AS count FROM quotes GROUP BY book_id',
    );
    return {
      for (final row in rows) row['book_id'] as String: row['count'] as int,
    };
  }

  Future<void> insertQuote(Quote quote) async {
    final db = await _dbHelper.database;
    await db.insert('quotes', quote.toMap());
  }

  Future<void> updateQuote(Quote quote) async {
    final db = await _dbHelper.database;
    await db.update(
      'quotes',
      quote.toMap(),
      where: 'id = ?',
      whereArgs: [quote.id],
    );
  }

  Future<void> deleteQuote(String id) async {
    final db = await _dbHelper.database;
    await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }
}
```

- [ ] **Step 2: Verify compile**

Run:
```bash
flutter analyze lib/features/books/repositories/quote_repository.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/repositories/quote_repository.dart
git commit -m "feat: add QuoteRepository with CRUD and aggregate count"
```

---

## Task 5: Quote Riverpod providers

**Files:**
- Create: `lib/features/books/providers/quote_providers.dart`

- [ ] **Step 1: Create the providers**

Create `lib/features/books/providers/quote_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/core/services/logger_service.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/repositories/quote_repository.dart';

const _tag = 'QuoteProviders';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

/// All quotes for a given book, sorted page-asc with nulls last.
final quotesForBookProvider =
    FutureProvider.family<List<Quote>, String>((ref, bookId) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuotesForBook(bookId);
});

/// All quotes across the library (used by client-side search).
final allQuotesProvider = FutureProvider<List<Quote>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getAllQuotes();
});

/// Map of bookId → quote count, used by book card indicators.
final quoteCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuoteCountsByBook();
});

class QuoteNotifier extends StateNotifier<AsyncValue<void>> {
  final QuoteRepository _repository;
  final Ref _ref;

  QuoteNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> addQuote(Quote quote) async {
    try {
      await _repository.insertQuote(quote);
      logger.info('Added quote for ${quote.bookId}', tag: _tag);
      _invalidate(quote.bookId);
    } catch (e, st) {
      logger.error('Failed to add quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateQuote(Quote quote) async {
    try {
      await _repository.updateQuote(quote);
      logger.info('Updated quote ${quote.id}', tag: _tag);
      _invalidate(quote.bookId);
    } catch (e, st) {
      logger.error('Failed to update quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteQuote({required String id, required String bookId}) async {
    try {
      await _repository.deleteQuote(id);
      logger.info('Deleted quote $id', tag: _tag);
      _invalidate(bookId);
    } catch (e, st) {
      logger.error('Failed to delete quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  void _invalidate(String bookId) {
    _ref.invalidate(quotesForBookProvider(bookId));
    _ref.invalidate(allQuotesProvider);
    _ref.invalidate(quoteCountsProvider);
  }
}

final quoteNotifierProvider =
    StateNotifierProvider<QuoteNotifier, AsyncValue<void>>((ref) {
  return QuoteNotifier(ref.watch(quoteRepositoryProvider), ref);
});
```

- [ ] **Step 2: Verify compile**

Run:
```bash
flutter analyze lib/features/books/providers/quote_providers.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/providers/quote_providers.dart
git commit -m "feat: add quote Riverpod providers"
```

---

## Task 6: Snippet generator utility

**Files:**
- Create: `lib/features/books/utils/snippet.dart`
- Create: `test/unit/utils/snippet_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/unit/utils/snippet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/utils/snippet.dart';

void main() {
  group('buildSnippet', () {
    test('returns null when query is not found', () {
      expect(buildSnippet(text: 'hello world', query: 'zzz'), isNull);
    });

    test('returns null when query is empty', () {
      expect(buildSnippet(text: 'hello world', query: ''), isNull);
    });

    test('returns null when text is empty', () {
      expect(buildSnippet(text: '', query: 'foo'), isNull);
    });

    test('matches case-insensitively and preserves source casing', () {
      final s = buildSnippet(text: 'Hello World', query: 'WORLD');
      expect(s, isNotNull);
      expect(s!.matched, equals('World'));
    });

    test('no truncation when text is shorter than window', () {
      final s = buildSnippet(text: 'A short bit', query: 'short');
      expect(s, isNotNull);
      expect(s!.prefix, equals('A '));
      expect(s.matched, equals('short'));
      expect(s.suffix, equals(' bit'));
    });

    test('truncates with ellipsis on both sides when match is in the middle', () {
      final long = 'a' * 200 + 'NEEDLE' + 'b' * 200;
      final s = buildSnippet(text: long, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.prefix.startsWith('…'), isTrue);
      expect(s.suffix.endsWith('…'), isTrue);
      expect(s.matched, equals('NEEDLE'));
      final total = s.prefix.length + s.matched.length + s.suffix.length;
      // 60 char window + two single-char ellipses
      expect(total, lessThanOrEqualTo(62));
    });

    test('no leading ellipsis when match is near the start', () {
      final text = 'NEEDLE at the start of a longer string ' + 'x' * 100;
      final s = buildSnippet(text: text, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.prefix.startsWith('…'), isFalse);
      expect(s.suffix.endsWith('…'), isTrue);
    });

    test('no trailing ellipsis when match is near the end', () {
      final text = 'x' * 100 + ' at the end NEEDLE';
      final s = buildSnippet(text: text, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.suffix.endsWith('…'), isFalse);
      expect(s.prefix.startsWith('…'), isTrue);
    });

    test('picks the first match when query appears multiple times', () {
      final s = buildSnippet(text: 'foo BAR foo BAR', query: 'bar');
      expect(s, isNotNull);
      expect(s!.matched, equals('BAR'));
      expect(s.prefix, equals('foo '));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:
```bash
flutter test test/unit/utils/snippet_test.dart
```
Expected: compile error (`snippet.dart` not found).

- [ ] **Step 3: Implement the helper**

Create `lib/features/books/utils/snippet.dart`:

```dart
class TextSnippet {
  final String prefix;
  final String matched;
  final String suffix;

  const TextSnippet({
    required this.prefix,
    required this.matched,
    required this.suffix,
  });
}

/// Build a snippet around the first case-insensitive occurrence of [query]
/// in [text], padded with `…` on truncated sides.
///
/// Returns null if [query] is empty or not found in [text].
/// [maxLength] is the maximum number of characters from [text] to include
/// (does not count the ellipsis characters themselves).
TextSnippet? buildSnippet({
  required String text,
  required String query,
  int maxLength = 60,
}) {
  if (query.isEmpty || text.isEmpty) return null;

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final matchStart = lowerText.indexOf(lowerQuery);
  if (matchStart < 0) return null;
  final matchEnd = matchStart + query.length;

  if (text.length <= maxLength) {
    return TextSnippet(
      prefix: text.substring(0, matchStart),
      matched: text.substring(matchStart, matchEnd),
      suffix: text.substring(matchEnd),
    );
  }

  // Center a window of [maxLength] around the match.
  final remaining = maxLength - query.length;
  final halfBefore = remaining ~/ 2;
  final halfAfter = remaining - halfBefore;

  var windowStart = matchStart - halfBefore;
  var windowEnd = matchEnd + halfAfter;

  if (windowStart < 0) {
    windowEnd += -windowStart;
    windowStart = 0;
  }
  if (windowEnd > text.length) {
    windowStart -= (windowEnd - text.length);
    windowEnd = text.length;
  }
  if (windowStart < 0) windowStart = 0;

  final prefixSrc = text.substring(windowStart, matchStart);
  final suffixSrc = text.substring(matchEnd, windowEnd);

  final leadingEllipsis = windowStart > 0 ? '…' : '';
  final trailingEllipsis = windowEnd < text.length ? '…' : '';

  return TextSnippet(
    prefix: '$leadingEllipsis$prefixSrc',
    matched: text.substring(matchStart, matchEnd),
    suffix: '$suffixSrc$trailingEllipsis',
  );
}
```

- [ ] **Step 4: Run test to verify pass**

Run:
```bash
flutter test test/unit/utils/snippet_test.dart
```
Expected: all 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/books/utils/snippet.dart test/unit/utils/snippet_test.dart
git commit -m "feat: add snippet generator utility"
```

---

## Task 7: `BookSearchResult` + `MatchSnippet` models

**Files:**
- Create: `lib/features/books/models/book_search_result.dart`

- [ ] **Step 1: Create the models**

Create `lib/features/books/models/book_search_result.dart`:

```dart
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/utils/snippet.dart';

enum MatchSource { title, author, isbn, review, quote }

class MatchSnippet {
  final TextSnippet snippet;
  final MatchSource source;
  final int? page; // only set when source == MatchSource.quote

  const MatchSnippet({
    required this.snippet,
    required this.source,
    this.page,
  });
}

class BookSearchResult {
  final Book book;

  /// Null when no search query is active, or when the match was on
  /// title/author/isbn (no snippet is rendered for those).
  final MatchSnippet? snippet;

  const BookSearchResult({required this.book, this.snippet});
}
```

- [ ] **Step 2: Verify compile**

Run:
```bash
flutter analyze lib/features/books/models/book_search_result.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/models/book_search_result.dart
git commit -m "feat: add BookSearchResult and MatchSnippet types"
```

---

## Task 8: Review editor modal route

**Files:**
- Create: `lib/features/books/widgets/review_editor.dart`

This widget is a full-screen modal route. The caller passes the existing review text (nullable) and awaits a string result (nullable: null means "cancel", empty string means "save empty / delete review").

- [ ] **Step 1: Create the widget**

Create `lib/features/books/widgets/review_editor.dart`:

```dart
import 'package:flutter/material.dart';

/// Opens the review editor as a full-screen route.
///
/// Returns the new review text on save, or null if cancelled.
/// A non-null empty string indicates the user cleared the review.
Future<String?> openReviewEditor(
  BuildContext context, {
  required String bookTitle,
  String? initial,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReviewEditor(bookTitle: bookTitle, initial: initial),
    ),
  );
}

class ReviewEditor extends StatefulWidget {
  final String bookTitle;
  final String? initial;

  const ReviewEditor({super.key, required this.bookTitle, this.initial});

  @override
  State<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<ReviewEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add review' : 'Edit review'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compile**

Run:
```bash
flutter analyze lib/features/books/widgets/review_editor.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/widgets/review_editor.dart
git commit -m "feat: add review editor modal route"
```

---

## Task 9: Quote editor modal route

**Files:**
- Create: `lib/features/books/widgets/quote_editor.dart`

The quote editor handles three modes: create, edit, delete (delete only available in edit mode). It returns a `QuoteEditorResult`:
- `null` → cancelled (no change)
- `QuoteEditorResult.save(text, page)` → user saved
- `QuoteEditorResult.delete()` → user deleted (edit mode only)

- [ ] **Step 1: Create the widget**

Create `lib/features/books/widgets/quote_editor.dart`:

```dart
import 'package:flutter/material.dart';

class QuoteEditorResult {
  final bool isDelete;
  final String? text;
  final int? page;

  const QuoteEditorResult.save({required this.text, required this.page})
      : isDelete = false;
  const QuoteEditorResult.delete()
      : isDelete = true,
        text = null,
        page = null;
}

Future<QuoteEditorResult?> openQuoteEditor(
  BuildContext context, {
  required String bookTitle,
  String? initialText,
  int? initialPage,
}) {
  return Navigator.of(context).push<QuoteEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuoteEditor(
        bookTitle: bookTitle,
        initialText: initialText,
        initialPage: initialPage,
      ),
    ),
  );
}

class QuoteEditor extends StatefulWidget {
  final String bookTitle;
  final String? initialText;
  final int? initialPage;

  const QuoteEditor({
    super.key,
    required this.bookTitle,
    this.initialText,
    this.initialPage,
  });

  @override
  State<QuoteEditor> createState() => _QuoteEditorState();
}

class _QuoteEditorState extends State<QuoteEditor> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.initialText ?? '');
  late final TextEditingController _pageController = TextEditingController(
    text: widget.initialPage?.toString() ?? '',
  );

  bool get _isEditing => widget.initialText != null;

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final pageStr = _pageController.text.trim();
    final page = pageStr.isEmpty ? null : int.tryParse(pageStr);
    Navigator.of(context).pop(
      QuoteEditorResult.save(text: text, page: page),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quote?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      Navigator.of(context).pop(const QuoteEditorResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit quote' : 'Add quote'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Quote',
                hintText: 'Type or paste the quote here…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Page (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compile**

Run:
```bash
flutter analyze lib/features/books/widgets/quote_editor.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/widgets/quote_editor.dart
git commit -m "feat: add quote editor modal route"
```

---

## Task 10: Review section widget + book detail integration

**Files:**
- Create: `lib/features/books/widgets/review_section.dart`
- Create: `test/widget/review_section_test.dart`
- Modify: `lib/features/books/screens/book_detail_screen.dart`

- [ ] **Step 1: Write a failing widget test**

Create `test/widget/review_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/widgets/review_section.dart';

void main() {
  testWidgets('shows Add review button when review is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(review: null, onEditPressed: () {}),
        ),
      ),
    );
    expect(find.text('Add review'), findsOneWidget);
  });

  testWidgets('renders review text when present', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(
            review: 'Brilliant pacing',
            onEditPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Brilliant pacing'), findsOneWidget);
    expect(find.text('Add review'), findsNothing);
  });

  testWidgets('triggers onEditPressed on tap', (WidgetTester tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(
            review: 'Some review',
            onEditPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Some review'));
    await tester.pumpAndSettle();
    expect(taps, equals(1));
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:
```bash
flutter test test/widget/review_section_test.dart
```
Expected: compile error (`review_section.dart` not found).

- [ ] **Step 3: Create the widget**

Create `lib/features/books/widgets/review_section.dart`:

```dart
import 'package:flutter/material.dart';

class ReviewSection extends StatelessWidget {
  final String? review;
  final VoidCallback onEditPressed;

  const ReviewSection({
    super.key,
    required this.review,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'My Review',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (review == null || review!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add review'),
            ),
          )
        else
          InkWell(
            onTap: onEditPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(review!),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run:
```bash
flutter test test/widget/review_section_test.dart
```
Expected: all 3 tests pass.

- [ ] **Step 5: Wire ReviewSection into BookDetailScreen**

Open `lib/features/books/screens/book_detail_screen.dart` and:

1. Add imports at the top:
   ```dart
   import 'package:paper_trail/features/books/widgets/review_editor.dart';
   import 'package:paper_trail/features/books/widgets/review_section.dart';
   ```

2. Inside the existing scaffold body — append the `ReviewSection` to the existing column near the bottom of the book detail content (look for where the existing notes/family/category sections end; add this just before the final closing of the scroll/column):

   ```dart
   ReviewSection(
     review: book.review,
     onEditPressed: () async {
       final newText = await openReviewEditor(
         context,
         bookTitle: book.title,
         initial: book.review,
       );
       if (newText == null) return;
       final next = book.copyWith(
         review: newText.isEmpty ? null : newText,
         reviewUpdatedAt: DateTime.now(),
         updatedAt: DateTime.now(),
       );
       await ref.read(bookNotifierProvider.notifier).updateBook(next);
     },
   ),
   ```

   Note: `ref` is available because the screen extends `ConsumerWidget`. The `book` variable is the unwrapped result of `bookAsync.when(data: (book) {...})`.

3. If the file isn't already importing `bookNotifierProvider`, add:
   ```dart
   import 'package:paper_trail/features/books/providers/book_providers.dart';
   ```

   (It's already imported via `book_providers.dart` — confirm before adding.)

- [ ] **Step 6: Verify analyze**

Run:
```bash
flutter analyze lib/features/books/screens/book_detail_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/books/widgets/review_section.dart \
        test/widget/review_section_test.dart \
        lib/features/books/screens/book_detail_screen.dart
git commit -m "feat: add review section to book detail with full-screen editor"
```

---

## Task 11: Quotes list widget + book detail integration (incl. long-press actions)

**Files:**
- Create: `lib/features/books/widgets/quotes_list.dart`
- Create: `test/widget/quotes_list_test.dart`
- Modify: `lib/features/books/screens/book_detail_screen.dart`

The quotes list widget is **presentational only** — it takes a list of quotes and emits callbacks. The detail screen owns the `share_plus` / clipboard / provider plumbing.

- [ ] **Step 1: Write a failing widget test**

Create `test/widget/quotes_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/widgets/quotes_list.dart';

void main() {
  final t = DateTime.utc(2026, 5, 1);

  testWidgets('shows header with count and Add quote button when empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: const [],
            onAddPressed: () {},
            onQuoteTapped: (_) {},
            onQuoteLongPressed: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Quotes (0)'), findsOneWidget);
    expect(find.text('Add quote'), findsOneWidget);
  });

  testWidgets('renders each quote with page when set',
      (WidgetTester tester) async {
    final quotes = [
      Quote(id: 'q1', bookId: 'b', text: 'Alpha', page: 1, createdAt: t),
      Quote(id: 'q2', bookId: 'b', text: 'Beta', page: null, createdAt: t),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: quotes,
            onAddPressed: () {},
            onQuoteTapped: (_) {},
            onQuoteLongPressed: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Quotes (2)'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('p.1'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('forwards taps and long-presses', (WidgetTester tester) async {
    final quotes = [
      Quote(id: 'q1', bookId: 'b', text: 'Alpha', page: 1, createdAt: t),
    ];
    Quote? tapped;
    Quote? longPressed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: quotes,
            onAddPressed: () {},
            onQuoteTapped: (q) => tapped = q,
            onQuoteLongPressed: (q) => longPressed = q,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    expect(tapped, equals(quotes.first));

    await tester.longPress(find.text('Alpha'));
    expect(longPressed, equals(quotes.first));
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:
```bash
flutter test test/widget/quotes_list_test.dart
```
Expected: compile error.

- [ ] **Step 3: Create the widget**

Create `lib/features/books/widgets/quotes_list.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:paper_trail/features/books/models/quote.dart';

class QuotesList extends StatelessWidget {
  final List<Quote> quotes;
  final VoidCallback onAddPressed;
  final ValueChanged<Quote> onQuoteTapped;
  final ValueChanged<Quote> onQuoteLongPressed;

  const QuotesList({
    super.key,
    required this.quotes,
    required this.onAddPressed,
    required this.onQuoteTapped,
    required this.onQuoteLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quotes (${quotes.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add quote'),
              ),
            ],
          ),
        ),
        for (final q in quotes)
          InkWell(
            onTap: () => onQuoteTapped(q),
            onLongPress: () => onQuoteLongPressed(q),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.text,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (q.page != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'p.${q.page}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run:
```bash
flutter test test/widget/quotes_list_test.dart
```
Expected: all 3 tests pass.

- [ ] **Step 5: Wire QuotesList into BookDetailScreen**

Open `lib/features/books/screens/book_detail_screen.dart` and:

1. Add imports:
   ```dart
   import 'package:flutter/services.dart';
   import 'package:share_plus/share_plus.dart';
   import 'package:uuid/uuid.dart';
   import 'package:paper_trail/features/books/models/quote.dart';
   import 'package:paper_trail/features/books/providers/quote_providers.dart';
   import 'package:paper_trail/features/books/widgets/quote_editor.dart';
   import 'package:paper_trail/features/books/widgets/quotes_list.dart';
   ```

2. Watch the quotes provider near where `bookAsync` is watched:
   ```dart
   final quotesAsync = ref.watch(quotesForBookProvider(bookId));
   ```

3. Below the `ReviewSection` added in Task 10, render:

   ```dart
   quotesAsync.when(
     data: (quotes) => QuotesList(
       quotes: quotes,
       onAddPressed: () async {
         final result = await openQuoteEditor(
           context,
           bookTitle: book.title,
         );
         if (result == null || result.isDelete) return;
         final quote = Quote(
           id: const Uuid().v4(),
           bookId: book.id,
           text: result.text!,
           page: result.page,
           createdAt: DateTime.now(),
         );
         await ref.read(quoteNotifierProvider.notifier).addQuote(quote);
       },
       onQuoteTapped: (q) async {
         final result = await openQuoteEditor(
           context,
           bookTitle: book.title,
           initialText: q.text,
           initialPage: q.page,
         );
         if (result == null) return;
         if (result.isDelete) {
           await ref.read(quoteNotifierProvider.notifier).deleteQuote(
                 id: q.id,
                 bookId: q.bookId,
               );
         } else {
           await ref.read(quoteNotifierProvider.notifier).updateQuote(
                 q.copyWith(text: result.text!, page: result.page),
               );
         }
       },
       onQuoteLongPressed: (q) =>
           _showQuoteActions(context, ref, book, q),
     ),
     loading: () => const Padding(
       padding: EdgeInsets.all(16),
       child: Center(child: CircularProgressIndicator()),
     ),
     error: (e, _) => Padding(
       padding: const EdgeInsets.all(16),
       child: Text('Failed to load quotes: $e'),
     ),
   ),
   ```

4. Add this helper method as a top-level function at the bottom of the file (NOT inside the class, since `BookDetailScreen` is a `ConsumerWidget`):

   ```dart
   Future<void> _showQuoteActions(
     BuildContext context,
     WidgetRef ref,
     Book book,
     Quote quote,
   ) async {
     final action = await showModalBottomSheet<String>(
       context: context,
       builder: (ctx) => SafeArea(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             ListTile(
               leading: const Icon(Icons.copy),
               title: const Text('Copy'),
               onTap: () => Navigator.of(ctx).pop('copy'),
             ),
             ListTile(
               leading: const Icon(Icons.share),
               title: const Text('Share'),
               onTap: () => Navigator.of(ctx).pop('share'),
             ),
             ListTile(
               leading: const Icon(Icons.delete_outline),
               title: const Text('Delete'),
               onTap: () => Navigator.of(ctx).pop('delete'),
             ),
           ],
         ),
       ),
     );
     if (action == null) return;
     final shareText = quote.page != null
         ? '"${quote.text}" — ${book.title}, p.${quote.page}'
         : '"${quote.text}" — ${book.title}';
     switch (action) {
       case 'copy':
         await Clipboard.setData(ClipboardData(text: shareText));
         break;
       case 'share':
         final box = context.findRenderObject() as RenderBox?;
         await Share.share(
           shareText,
           sharePositionOrigin:
               box != null ? box.localToGlobal(Offset.zero) & box.size : null,
         );
         break;
       case 'delete':
         await ref.read(quoteNotifierProvider.notifier).deleteQuote(
               id: quote.id,
               bookId: quote.bookId,
             );
         break;
     }
   }
   ```

   The `Book` and `Quote` types must already be imported at the top of the file (Book is, Quote was added above).

- [ ] **Step 6: Run all widget tests**

Run:
```bash
flutter test test/widget/
```
Expected: all tests pass.

- [ ] **Step 7: Verify analyze**

Run:
```bash
flutter analyze lib/features/books/screens/book_detail_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/books/widgets/quotes_list.dart \
        test/widget/quotes_list_test.dart \
        lib/features/books/screens/book_detail_screen.dart
git commit -m "feat: add quotes list to book detail with editor and share actions"
```

---

## Task 12: Book card indicators (review star + quote count badge)

**Files:**
- Modify: `lib/features/books/widgets/book_card.dart`
- Modify: `test/widget/book_card_test.dart`

- [ ] **Step 1: Add failing test cases**

Open `test/widget/book_card_test.dart`. Inside the existing `group('BookCard', ...)`, add:

```dart
testWidgets('shows star when book has a review',
    (WidgetTester tester) async {
  final book = createTestBook().copyWith(review: 'Great');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: BookCard(book: book, quoteCount: 0),
        ),
      ),
    ),
  );
  expect(find.byIcon(Icons.star), findsOneWidget);
});

testWidgets('shows quote count badge when quoteCount > 0',
    (WidgetTester tester) async {
  final book = createTestBook();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: BookCard(book: book, quoteCount: 3),
        ),
      ),
    ),
  );
  expect(find.byIcon(Icons.format_quote), findsOneWidget);
  expect(find.text('3'), findsOneWidget);
});

testWidgets('shows no indicators when no review and zero quotes',
    (WidgetTester tester) async {
  final book = createTestBook();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: BookCard(book: book, quoteCount: 0),
        ),
      ),
    ),
  );
  expect(find.byIcon(Icons.star), findsNothing);
  expect(find.byIcon(Icons.format_quote), findsNothing);
});
```

Update the `createTestBook` helper in this file: the `Book` constructor still defaults `review` and `reviewUpdatedAt` to null, so no change is required to existing call sites. But `copyWith(review: 'Great')` requires Task 2 to have shipped — confirm by running the test first.

- [ ] **Step 2: Run tests to confirm failure**

Run:
```bash
flutter test test/widget/book_card_test.dart
```
Expected: compile error — `quoteCount` named parameter not defined.

- [ ] **Step 3: Update BookCard to accept and render indicators**

Open `lib/features/books/widgets/book_card.dart`:

1. Add `quoteCount` parameter:
   ```dart
   class BookCard extends StatelessWidget {
     final Book book;
     final VoidCallback? onTap;
     final String? ownerName;
     final Color? ownerColor;
     final int quoteCount;

     const BookCard({
       super.key,
       required this.book,
       this.onTap,
       this.ownerName,
       this.ownerColor,
       this.quoteCount = 0,
     });
     // ...
   }
   ```

2. Add an `_buildIndicators` helper method:
   ```dart
   Widget _buildIndicators() {
     final hasReview = (book.review ?? '').isNotEmpty;
     if (!hasReview && quoteCount == 0) {
       return const SizedBox.shrink();
     }
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         if (hasReview)
           Icon(Icons.star, size: 14, color: Colors.amber.shade700),
         if (quoteCount > 0) ...[
           if (hasReview) const SizedBox(width: 4),
           Icon(Icons.format_quote, size: 14, color: Colors.grey.shade600),
           const SizedBox(width: 2),
           Text(
             '$quoteCount',
             style: TextStyle(
               fontSize: 11,
               color: Colors.grey.shade700,
             ),
           ),
         ],
       ],
     );
   }
   ```

3. Modify the title row in the body padding section so it lays out title on the left and indicators on the right. Replace the title `Text` block with:

   ```dart
   Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Expanded(
         child: Text(
           book.title,
           style: const TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 13,
           ),
           maxLines: 2,
           overflow: TextOverflow.ellipsis,
         ),
       ),
       const SizedBox(width: 4),
       _buildIndicators(),
     ],
   ),
   ```

- [ ] **Step 4: Run test to verify pass**

Run:
```bash
flutter test test/widget/book_card_test.dart
```
Expected: all tests pass (existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add lib/features/books/widgets/book_card.dart test/widget/book_card_test.dart
git commit -m "feat: add review/quote indicators to BookCard"
```

---

## Task 13: Pure search helper + unit tests

**Files:**
- Create: `lib/features/books/utils/book_search.dart`
- Create: `test/unit/utils/book_search_test.dart`

Extract the search/filter logic from the list screen into a pure top-level function so it can be unit-tested directly. The list screen will call this in Task 14.

- [ ] **Step 1: Write failing tests**

Create `test/unit/utils/book_search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/models/book_search_result.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/utils/book_search.dart';

void main() {
  final t = DateTime.utc(2026, 5, 1);

  Book book({
    required String id,
    String title = 'Title',
    String author = 'Author',
    String? isbn,
    String? review,
    bool wishlist = false,
    String? ownerId,
    String? categoryId,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      review: review,
      ownerId: ownerId,
      categoryId: categoryId,
      isWishlist: wishlist,
      createdAt: t,
      updatedAt: t,
    );
  }

  group('searchAndFilterBooks — no query', () {
    test('excludes wishlist books', () {
      final books = [
        book(id: 'b1'),
        book(id: 'b2', wishlist: true),
      ];
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: const [],
        query: '',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.map((r) => r.book.id), equals(['b1']));
    });

    test('sorts by title ascending case-insensitively', () {
      final books = [
        book(id: 'b1', title: 'banana'),
        book(id: 'b2', title: 'Apple'),
      ];
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: const [],
        query: '',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.title,
      );
      expect(results.map((r) => r.book.id), equals(['b2', 'b1']));
    });

    test('applies owner and category filters', () {
      final books = [
        book(id: 'b1', ownerId: 'o1', categoryId: 'c1'),
        book(id: 'b2', ownerId: 'o2', categoryId: 'c1'),
        book(id: 'b3', ownerId: 'o1', categoryId: 'c2'),
      ];
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: const [],
        query: '',
        ownerId: 'o1',
        categoryId: 'c1',
        sort: BookSearchSort.dateAdded,
      );
      expect(results.map((r) => r.book.id), equals(['b1']));
    });

    test('returns BookSearchResult with null snippet', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1')],
        allQuotes: const [],
        query: '',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.snippet, isNull);
    });
  });

  group('searchAndFilterBooks — with query', () {
    test('title match returns no snippet (precedence: title > author > ...)', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', title: 'Pride and Prejudice', review: 'prejudice')],
        allQuotes: const [],
        query: 'prejudice',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.book.id, equals('b1'));
      expect(results.single.snippet, isNull);
    });

    test('author match returns no snippet', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', author: 'Jane Austen', review: 'Austen rules')],
        allQuotes: const [],
        query: 'austen',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.snippet, isNull);
    });

    test('isbn match returns no snippet', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', isbn: '9780141439518')],
        allQuotes: const [],
        query: '014143',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.snippet, isNull);
    });

    test('review match returns review snippet', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', review: 'Brilliant pacing throughout')],
        allQuotes: const [],
        query: 'brilliant',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.snippet, isNotNull);
      expect(results.single.snippet!.source, equals(MatchSource.review));
      expect(results.single.snippet!.snippet.matched, equals('Brilliant'));
    });

    test('quote match returns quote snippet with page', () {
      final quotes = [
        Quote(id: 'q1', bookId: 'b1', text: 'All happy families are alike', page: 1, createdAt: t),
      ];
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', title: 'AK', author: 'LT')],
        allQuotes: quotes,
        query: 'happy',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.single.snippet, isNotNull);
      expect(results.single.snippet!.source, equals(MatchSource.quote));
      expect(results.single.snippet!.page, equals(1));
      expect(results.single.snippet!.snippet.matched, equals('happy'));
    });

    test('no match yields no result', () {
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', title: 'X', author: 'Y', review: 'Z')],
        allQuotes: const [],
        query: 'zzz',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results, isEmpty);
    });

    test('owner/category filters still apply during search', () {
      final books = [
        book(id: 'b1', title: 'Match', ownerId: 'o1'),
        book(id: 'b2', title: 'Match', ownerId: 'o2'),
      ];
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: const [],
        query: 'match',
        ownerId: 'o1',
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.map((r) => r.book.id), equals(['b1']));
    });

    test('wishlist books are excluded from search', () {
      final books = [
        book(id: 'b1', title: 'Hit'),
        book(id: 'b2', title: 'Hit', wishlist: true),
      ];
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: const [],
        query: 'hit',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results.map((r) => r.book.id), equals(['b1']));
    });

    test('returns at most one result per book even with multiple matching quotes', () {
      final quotes = [
        Quote(id: 'q1', bookId: 'b1', text: 'foo bar', page: 1, createdAt: t),
        Quote(id: 'q2', bookId: 'b1', text: 'foo baz', page: 2, createdAt: t),
      ];
      final results = searchAndFilterBooks(
        books: [book(id: 'b1', title: 'T', author: 'A')],
        allQuotes: quotes,
        query: 'foo',
        ownerId: null,
        categoryId: null,
        sort: BookSearchSort.dateAdded,
      );
      expect(results, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/unit/utils/book_search_test.dart
```
Expected: compile error — `book_search.dart` not found.

- [ ] **Step 3: Implement the pure helper**

Create `lib/features/books/utils/book_search.dart`:

```dart
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/models/book_search_result.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/utils/snippet.dart';

enum BookSearchSort { dateAdded, title, author }

/// Filters [books] by owner/category/wishlist, optionally narrows them by
/// [query] (matching title, author, isbn, review, or any quote), sorts the
/// result when [query] is empty, and returns [BookSearchResult]s carrying
/// any review/quote match snippet.
List<BookSearchResult> searchAndFilterBooks({
  required List<Book> books,
  required List<Quote> allQuotes,
  required String query,
  required String? ownerId,
  required String? categoryId,
  required BookSearchSort sort,
}) {
  var filtered = books.where((b) => !b.isWishlist).toList();
  if (ownerId != null) {
    filtered = filtered.where((b) => b.ownerId == ownerId).toList();
  }
  if (categoryId != null) {
    filtered = filtered.where((b) => b.categoryId == categoryId).toList();
  }

  final trimmed = query.trim();

  if (trimmed.isEmpty) {
    switch (sort) {
      case BookSearchSort.title:
        filtered.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case BookSearchSort.author:
        filtered.sort((a, b) =>
            a.author.toLowerCase().compareTo(b.author.toLowerCase()));
      case BookSearchSort.dateAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return [for (final b in filtered) BookSearchResult(book: b)];
  }

  final lowerQuery = trimmed.toLowerCase();
  final bookIds = {for (final b in filtered) b.id};
  final quotesByBook = <String, List<Quote>>{};
  for (final q in allQuotes) {
    if (!bookIds.contains(q.bookId)) continue;
    quotesByBook.putIfAbsent(q.bookId, () => []).add(q);
  }

  final results = <BookSearchResult>[];
  for (final book in filtered) {
    if (book.title.toLowerCase().contains(lowerQuery) ||
        book.author.toLowerCase().contains(lowerQuery) ||
        (book.isbn?.toLowerCase().contains(lowerQuery) ?? false)) {
      results.add(BookSearchResult(book: book));
      continue;
    }
    final review = book.review ?? '';
    final reviewSnippet = buildSnippet(text: review, query: trimmed);
    if (reviewSnippet != null) {
      results.add(BookSearchResult(
        book: book,
        snippet: MatchSnippet(
          snippet: reviewSnippet,
          source: MatchSource.review,
        ),
      ));
      continue;
    }
    final quotes = quotesByBook[book.id] ?? const <Quote>[];
    for (final q in quotes) {
      final s = buildSnippet(text: q.text, query: trimmed);
      if (s != null) {
        results.add(BookSearchResult(
          book: book,
          snippet: MatchSnippet(
            snippet: s,
            source: MatchSource.quote,
            page: q.page,
          ),
        ));
        break;
      }
    }
  }
  return results;
}
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/unit/utils/book_search_test.dart
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/books/utils/book_search.dart \
        test/unit/utils/book_search_test.dart
git commit -m "feat: add pure book search/filter helper with unit tests"
```

---

## Task 14: Wire search helper + debounce into book list screen

**Files:**
- Modify: `lib/features/books/screens/book_list_screen.dart`

The list screen now:

- Watches `quoteCountsProvider` and `allQuotesProvider` in addition to `bookNotifierProvider`.
- Passes `quoteCount` into each `BookCard`.
- Calls `searchAndFilterBooks` (from Task 13) and renders snippets below cards.
- Debounces the search field at 200 ms.

- [ ] **Step 1: Add imports**

At the top of `lib/features/books/screens/book_list_screen.dart`:

```dart
import 'dart:async';

import 'package:paper_trail/features/books/models/book_search_result.dart';
import 'package:paper_trail/features/books/providers/quote_providers.dart';
import 'package:paper_trail/features/books/utils/book_search.dart';
```

- [ ] **Step 2: Add debounce state**

Inside `_BookListScreenState`, add:

```dart
Timer? _searchDebounce;
```

In `dispose`, cancel it:

```dart
@override
void dispose() {
  _searchController.dispose();
  _searchDebounce?.cancel();
  super.dispose();
}
```

Change the `onChanged` callback on the search `TextField` to:

```dart
onChanged: (value) {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    setState(() => _searchQuery = value);
  });
},
```

And the `clear` button's `onPressed` should clear the debounce too:

```dart
onPressed: () {
  _searchDebounce?.cancel();
  _searchController.clear();
  setState(() => _searchQuery = '');
},
```

- [ ] **Step 3: Watch the new providers in `build`**

After the existing watches at the top of `build`:

```dart
final quoteCountsAsync = ref.watch(quoteCountsProvider);
final allQuotesAsync = ref.watch(allQuotesProvider);

final Map<String, int> quoteCounts =
    quoteCountsAsync.maybeWhen(data: (m) => m, orElse: () => const {});
final allQuotes =
    allQuotesAsync.maybeWhen(data: (l) => l, orElse: () => const []);
```

- [ ] **Step 4: Map the screen's local SortOption to BookSearchSort**

Inside `_BookListScreenState`, add a small helper:

```dart
BookSearchSort get _bookSearchSort {
  switch (_selectedSort) {
    case SortOption.title:
      return BookSearchSort.title;
    case SortOption.author:
      return BookSearchSort.author;
    case SortOption.dateAdded:
      return BookSearchSort.dateAdded;
  }
}
```

- [ ] **Step 5: Replace `_filterBooks` with a call to `searchAndFilterBooks`**

Delete the existing `_filterBooks` method. Replace the `booksAsync.when` data block to use the pure helper:

```dart
Expanded(
  child: booksAsync.when(
    data: (books) {
      final results = searchAndFilterBooks(
        books: books,
        allQuotes: allQuotes,
        query: _searchQuery,
        ownerId: _selectedOwnerId,
        categoryId: _selectedCategoryId,
        sort: _bookSearchSort,
      );
      if (results.isEmpty) {
        return EmptyState(
          icon: Icons.library_books,
          title: books.isEmpty ? 'No books yet' : 'No matching books',
          subtitle: books.isEmpty
              ? 'Start by adding your first book'
              : 'Try a different search or filter',
          buttonText: books.isEmpty ? 'Add Book' : null,
          onButtonPressed:
              books.isEmpty ? () => _navigateToAddBook(context) : null,
        );
      }
      return familyAsync.when(
        data: (members) =>
            _buildBookGrid(results, members, quoteCounts),
        loading: () => _buildBookGrid(results, [], quoteCounts),
        error: (_, __) => _buildBookGrid(results, [], quoteCounts),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(child: Text('Error: $error')),
  ),
),
```

- [ ] **Step 6: Replace `_buildBookGrid` to take `BookSearchResult` and render snippets**

Replace `_buildBookGrid` with:

```dart
Widget _buildBookGrid(
  List<BookSearchResult> results,
  List<FamilyMember> members,
  Map<String, int> quoteCounts,
) {
  return RefreshIndicator(
    onRefresh: () async {
      ref.read(bookNotifierProvider.notifier).loadBooks();
      ref.invalidate(quoteCountsProvider);
      ref.invalidate(allQuotesProvider);
    },
    child: GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.60,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final book = result.book;
        final owner = members.where((m) => m.id == book.ownerId).firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BookCard(
                book: book,
                ownerName: owner?.name,
                ownerColor: owner?.color,
                quoteCount: quoteCounts[book.id] ?? 0,
                onTap: () => _navigateToBookDetail(context, book),
              ),
            ),
            if (result.snippet != null) _buildSnippetRow(result.snippet!),
          ],
        );
      },
    ),
  );
}

Widget _buildSnippetRow(MatchSnippet match) {
  final label = match.source == MatchSource.quote
      ? (match.page != null
          ? '— quote, p.${match.page}'
          : '— quote')
      : '— review';
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        children: [
          TextSpan(text: match.snippet.prefix),
          TextSpan(
            text: match.snippet.matched,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: match.snippet.suffix),
          TextSpan(
            text: ' $label',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );
}
```

The `childAspectRatio: 0.60` (down from `0.65`) gives a tiny bit of room for the snippet row. Adjust later if it visibly squishes the cover.

- [ ] **Step 7: Run analyzer + tests**

Run:
```bash
flutter analyze lib/features/books/screens/book_list_screen.dart
flutter test test/
```
Expected: analyzer clean; all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/books/screens/book_list_screen.dart
git commit -m "feat: extend book list search to review/quote text with snippets"
```

---

## Task 15: Backup service v2 export (include review + quotes)

**Files:**
- Modify: `lib/core/services/backup_service.dart`
- Create: `test/unit/services/backup_service_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/unit/services/backup_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/core/services/backup_service.dart';

void main() {
  group('BackupService.parseAndValidate', () {
    final service = BackupService();

    test('accepts v1 backup', () {
      final json = jsonEncode({
        'version': 1,
        'exported_at': '2026-01-01T00:00:00.000Z',
        'books': [],
        'categories': [],
        'family_members': [],
      });
      final result = service.parseAndValidate(json);
      expect(result['version'], equals(1));
    });

    test('accepts v2 backup with quotes', () {
      final json = jsonEncode({
        'version': 2,
        'exported_at': '2026-05-01T00:00:00.000Z',
        'books': [],
        'categories': [],
        'family_members': [],
        'quotes': [],
      });
      final result = service.parseAndValidate(json);
      expect(result['version'], equals(2));
      expect(result['quotes'], isA<List>());
    });

    test('treats missing quotes array on v2 as empty', () {
      // The parser should not throw; importer will treat as empty.
      final json = jsonEncode({
        'version': 2,
        'exported_at': '2026-05-01T00:00:00.000Z',
        'books': [],
        'categories': [],
        'family_members': [],
      });
      final result = service.parseAndValidate(json);
      expect(result['version'], equals(2));
    });

    test('throws on non-object input', () {
      expect(
        () => service.parseAndValidate('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on missing version', () {
      final json = jsonEncode({
        'books': [],
        'categories': [],
        'family_members': [],
      });
      expect(
        () => service.parseAndValidate(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BackupService.getCounts', () {
    final service = BackupService();

    test('includes quote count from v2', () {
      final backup = {
        'books': [
          {'id': 'b1'}
        ],
        'categories': [],
        'family_members': [],
        'quotes': [
          {'id': 'q1'},
          {'id': 'q2'},
        ],
      };
      final counts = service.getCounts(backup);
      expect(counts.books, equals(1));
      expect(counts.quotes, equals(2));
    });

    test('treats missing quotes as zero (v1 compatibility)', () {
      final backup = {
        'books': [],
        'categories': [],
        'family_members': [],
      };
      final counts = service.getCounts(backup);
      expect(counts.quotes, equals(0));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/unit/services/backup_service_test.dart
```
Expected: failures — `quotes` field on counts record doesn't exist; v2 missing-quotes case may not currently be handled by `parseAndValidate`.

- [ ] **Step 3: Update BackupService**

In `lib/core/services/backup_service.dart`, replace `exportToJson`, `parseAndValidate`, `getCounts`, and `importFromBackup`:

```dart
import 'dart:convert';
import 'package:paper_trail/core/database/database_helper.dart';
import 'package:paper_trail/core/services/logger_service.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static const int _currentVersion = 2;
  static const String _tag = 'BackupService';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final db = await _dbHelper.database;

    final books = await db.query('books');
    final categories = await db.query('categories');
    final familyMembers = await db.query('family_members');
    final quotes = await db.query('quotes');

    final exportBooks = books.map((book) {
      final map = Map<String, dynamic>.from(book);
      map.remove('cover_image_path'); // local paths are not portable
      return map;
    }).toList();

    final backup = {
      'version': _currentVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'books': exportBooks,
      'categories': categories,
      'family_members': familyMembers,
      'quotes': quotes,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Map<String, dynamic> parseAndValidate(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('Invalid JSON format');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format');
    }

    if (decoded['version'] == null) {
      throw const FormatException('Missing version field');
    }
    if (decoded['books'] is! List) {
      throw const FormatException('Missing or invalid books data');
    }
    if (decoded['categories'] is! List) {
      throw const FormatException('Missing or invalid categories data');
    }
    if (decoded['family_members'] is! List) {
      throw const FormatException('Missing or invalid family members data');
    }
    // quotes is optional (absent on v1, may be absent on hand-edited v2)
    if (decoded['quotes'] != null && decoded['quotes'] is! List) {
      throw const FormatException('Invalid quotes data');
    }

    return decoded;
  }

  ({int books, int categories, int familyMembers, int quotes}) getCounts(
    Map<String, dynamic> backup,
  ) {
    return (
      books: (backup['books'] as List).length,
      categories: (backup['categories'] as List).length,
      familyMembers: (backup['family_members'] as List).length,
      quotes: ((backup['quotes'] as List?) ?? const []).length,
    );
  }

  Future<void> importFromBackup(Map<String, dynamic> backup) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final member in backup['family_members'] as List) {
        final map = Map<String, dynamic>.from(member as Map);
        await txn.insert(
          'family_members',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final category in backup['categories'] as List) {
        final map = Map<String, dynamic>.from(category as Map);
        await txn.insert(
          'categories',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Collect imported book ids so we can guard against orphan quotes.
      final importedBookIds = <String>{};
      for (final book in backup['books'] as List) {
        final map = Map<String, dynamic>.from(book as Map);
        map['cover_image_path'] = null;
        // v1 files lack `review` / `review_updated_at` — leave them absent
        // and sqflite will store NULL.
        await txn.insert(
          'books',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        importedBookIds.add(map['id'] as String);
      }

      final quotes = (backup['quotes'] as List?) ?? const [];
      for (final quote in quotes) {
        final map = Map<String, dynamic>.from(quote as Map);
        final bookId = map['book_id'] as String?;
        if (bookId == null || !importedBookIds.contains(bookId)) {
          // Orphan — also check the existing DB in case the book was
          // imported earlier or already exists.
          final existing = await txn.query(
            'books',
            where: 'id = ?',
            whereArgs: [bookId],
            limit: 1,
          );
          if (existing.isEmpty) {
            logger.warning(
              'Skipping orphan quote ${map['id']} (book_id=$bookId)',
              tag: _tag,
            );
            continue;
          }
        }
        await txn.insert(
          'quotes',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
flutter test test/unit/services/backup_service_test.dart
```
Expected: all tests pass.

- [ ] **Step 5: Run the full test suite**

Run:
```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/backup_service.dart \
        test/unit/services/backup_service_test.dart
git commit -m "feat: bump backup format to v2 with reviews and quotes"
```

---

## Task 16: Manual smoke test on simulator

This is a non-code task — the engineer must launch the app and walk through the feature on an iOS simulator (or physical device).

**No file changes. No commit.**

- [ ] **Step 1: Launch the app**

Run:
```bash
flutter run
```
Wait for the app to launch on the iOS simulator (or selected device).

- [ ] **Step 2: Verify migration on existing data**

If you have a previous build's database, you should NOT see fresh-install state. Existing books, categories, family should still be present. Tap a book — confirm the detail screen still renders today's fields.

- [ ] **Step 3: Add a review**

a. Open any book.
b. Scroll to "My Review" — should show "Add review" button.
c. Tap it. Full-screen editor opens.
d. Type a review. Tap Save.
e. Returning to detail — review text is visible inline.
f. Tap the review — editor reopens with the existing text.
g. Edit, save. Detail updates.

- [ ] **Step 4: Add quotes**

a. Same book — scroll to Quotes (0).
b. Tap Add quote. Type a quote with text "All happy families…" and page 1. Save.
c. Tap Add quote again. Add "The child is father of the man" with page 42. Save.
d. Confirm both render in order (p.1, then p.42).
e. Tap the first quote — editor opens in edit mode with delete icon. Cancel out.
f. Long-press the first quote — bottom sheet shows Copy / Share / Delete.
g. Tap Copy — paste anywhere (e.g., a note) to confirm.
h. Long-press again, tap Share — share sheet opens, no crash on iOS.
i. Long-press again, tap Delete — quote vanishes.

- [ ] **Step 5: Confirm book card indicators**

a. Go back to the book list.
b. The book you just edited should show a star (review present) and `📑 N` (where N = remaining quote count).
c. Books without reviews/quotes show no indicators.

- [ ] **Step 6: Confirm search**

a. In the search bar, type a word that appears in your review (e.g., "brilliant").
b. The list filters to the matching book; below the card a snippet renders with the matched word bolded and " — review" appended.
c. Clear the bar. Type a word from a quote (e.g., "happy"). Snippet shows quote text, page label.
d. Type the book's title — book appears, no snippet (title match).

- [ ] **Step 7: Test backup round-trip**

a. Settings → Export Library. Save the file.
b. Open the file in Files (or AirDrop to your Mac) and confirm `"version": 2`, the `quotes` top-level array, and `review` fields on books.
c. Delete the book with the quotes (long-press or via detail screen).
d. Settings → Import Library → pick the exported file.
e. Book reappears; its review and quotes reappear; indicators on the list update.

- [ ] **Step 8: (Optional) Verify v1 backwards compatibility**

If you have an existing pre-v2 backup file (or hand-craft one by removing the `quotes` array and bumping the version down to 1 in an exported file), importing it should succeed silently and not crash.

- [ ] **Step 9: Stop**

Halt `flutter run` (Ctrl-C in the terminal). Implementation complete.

---

## Final notes

- **Do not push to remote** unless the user explicitly asks.
- After all tasks pass, run `flutter analyze` and `flutter test` once more to confirm a clean baseline.
- The unused `bookSearchProvider` in `book_providers.dart` was intentionally left alone — it predates this feature and the list screen never consumed it. A follow-up cleanup PR can remove it.

### Known gap from spec

The spec called for a unit migration test that applies the v2 → v3 schema upgrade against a seeded v2 database. This is **not** included in the plan because the project has no existing sqflite test harness (would require adding `sqflite_common_ffi` as a dev dependency and bootstrapping FFI in tests) — adding it is meaningful infra work that doesn't fit a bite-sized task. The migration is verified via the smoke test (Task 16 Step 2: existing data is still present after the upgrade). Add the FFI-based migration test as a follow-up if you want stronger regression coverage.
