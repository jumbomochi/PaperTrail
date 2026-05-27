import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/quote.dart';

void main() {
  final testTime = DateTime(2026, 5, 1, 12);

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
