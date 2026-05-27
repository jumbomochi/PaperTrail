import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/models/book_search_result.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/utils/book_search.dart';

void main() {
  final t = DateTime(2026, 5, 1);

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
