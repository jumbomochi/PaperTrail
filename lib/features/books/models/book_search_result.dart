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
