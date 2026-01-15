import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/book.dart';

void main() {
  group('Book', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    Book createTestBook({
      String id = 'test-id',
      String? isbn = '978-0-13-468599-1',
      String title = 'Test Book',
      String author = 'Test Author',
      bool isWishlist = false,
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
      );
    }

    group('toMap', () {
      test('should convert book to map with all fields', () {
        final book = createTestBook();
        final map = book.toMap();

        expect(map['id'], equals('test-id'));
        expect(map['isbn'], equals('978-0-13-468599-1'));
        expect(map['title'], equals('Test Book'));
        expect(map['author'], equals('Test Author'));
        expect(map['publisher'], equals('Test Publisher'));
        expect(map['published_date'], equals('2024'));
        expect(map['description'], equals('A test book description'));
        expect(map['cover_image_path'], equals('/path/to/cover.jpg'));
        expect(map['thumbnail_url'], equals('https://example.com/thumb.jpg'));
        expect(map['page_count'], equals(300));
        expect(map['owner_id'], equals('owner-1'));
        expect(map['category_id'], equals('category-1'));
        expect(map['is_wishlist'], equals(0));
        expect(map['created_at'], equals(testDate.toIso8601String()));
        expect(map['updated_at'], equals(testDate.toIso8601String()));
      });

      test('should convert isWishlist true to 1', () {
        final book = createTestBook(isWishlist: true);
        final map = book.toMap();

        expect(map['is_wishlist'], equals(1));
      });

      test('should handle null optional fields', () {
        final book = Book(
          id: 'test-id',
          title: 'Minimal Book',
          author: 'Author',
          createdAt: testDate,
          updatedAt: testDate,
        );
        final map = book.toMap();

        expect(map['isbn'], isNull);
        expect(map['publisher'], isNull);
        expect(map['description'], isNull);
        expect(map['cover_image_path'], isNull);
        expect(map['thumbnail_url'], isNull);
        expect(map['page_count'], isNull);
        expect(map['owner_id'], isNull);
        expect(map['category_id'], isNull);
      });
    });

    group('fromMap', () {
      test('should create book from map with all fields', () {
        final map = {
          'id': 'test-id',
          'isbn': '978-0-13-468599-1',
          'title': 'Test Book',
          'author': 'Test Author',
          'publisher': 'Test Publisher',
          'published_date': '2024',
          'description': 'A test book description',
          'cover_image_path': '/path/to/cover.jpg',
          'thumbnail_url': 'https://example.com/thumb.jpg',
          'page_count': 300,
          'owner_id': 'owner-1',
          'category_id': 'category-1',
          'is_wishlist': 0,
          'created_at': testDate.toIso8601String(),
          'updated_at': testDate.toIso8601String(),
        };

        final book = Book.fromMap(map);

        expect(book.id, equals('test-id'));
        expect(book.isbn, equals('978-0-13-468599-1'));
        expect(book.title, equals('Test Book'));
        expect(book.author, equals('Test Author'));
        expect(book.publisher, equals('Test Publisher'));
        expect(book.publishedDate, equals('2024'));
        expect(book.description, equals('A test book description'));
        expect(book.coverImagePath, equals('/path/to/cover.jpg'));
        expect(book.thumbnailUrl, equals('https://example.com/thumb.jpg'));
        expect(book.pageCount, equals(300));
        expect(book.ownerId, equals('owner-1'));
        expect(book.categoryId, equals('category-1'));
        expect(book.isWishlist, isFalse);
        expect(book.createdAt, equals(testDate));
        expect(book.updatedAt, equals(testDate));
      });

      test('should parse isWishlist correctly when 1', () {
        final map = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'is_wishlist': 1,
          'created_at': testDate.toIso8601String(),
          'updated_at': testDate.toIso8601String(),
        };

        final book = Book.fromMap(map);

        expect(book.isWishlist, isTrue);
      });

      test('should handle null is_wishlist as false', () {
        final map = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'is_wishlist': null,
          'created_at': testDate.toIso8601String(),
          'updated_at': testDate.toIso8601String(),
        };

        final book = Book.fromMap(map);

        expect(book.isWishlist, isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with updated title', () {
        final book = createTestBook();
        final updated = book.copyWith(title: 'New Title');

        expect(updated.title, equals('New Title'));
        expect(updated.id, equals(book.id));
        expect(updated.author, equals(book.author));
      });

      test('should create copy with updated isWishlist', () {
        final book = createTestBook(isWishlist: false);
        final updated = book.copyWith(isWishlist: true);

        expect(updated.isWishlist, isTrue);
        expect(updated.title, equals(book.title));
      });

      test('should preserve all fields when no arguments provided', () {
        final book = createTestBook();
        final copy = book.copyWith();

        expect(copy.id, equals(book.id));
        expect(copy.isbn, equals(book.isbn));
        expect(copy.title, equals(book.title));
        expect(copy.author, equals(book.author));
        expect(copy.publisher, equals(book.publisher));
        expect(copy.isWishlist, equals(book.isWishlist));
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final book1 = createTestBook(id: 'same-id');
        final book2 = createTestBook(id: 'same-id', title: 'Different Title');

        expect(book1, equals(book2));
      });

      test('should not be equal when ids differ', () {
        final book1 = createTestBook(id: 'id-1');
        final book2 = createTestBook(id: 'id-2');

        expect(book1, isNot(equals(book2)));
      });

      test('should have same hashCode when ids match', () {
        final book1 = createTestBook(id: 'same-id');
        final book2 = createTestBook(id: 'same-id', title: 'Different Title');

        expect(book1.hashCode, equals(book2.hashCode));
      });
    });

    group('roundtrip', () {
      test('should survive toMap/fromMap roundtrip', () {
        final original = createTestBook();
        final map = original.toMap();
        final restored = Book.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.isbn, equals(original.isbn));
        expect(restored.title, equals(original.title));
        expect(restored.author, equals(original.author));
        expect(restored.isWishlist, equals(original.isWishlist));
        expect(restored.createdAt, equals(original.createdAt));
      });
    });
  });
}
