import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/models/book_search_result.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/utils/snippet.dart';

enum BookSearchSort { dateAdded, title, author }

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
