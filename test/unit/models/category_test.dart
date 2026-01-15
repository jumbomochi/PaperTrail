import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/categories/models/category.dart';

void main() {
  group('Category', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    Category createTestCategory({
      String id = 'category-id',
      String name = 'Fiction',
      String icon = '\ud83d\udcda',
    }) {
      return Category(
        id: id,
        name: name,
        icon: icon,
        createdAt: testDate,
      );
    }

    group('toMap', () {
      test('should convert category to map with all fields', () {
        final category = createTestCategory();
        final map = category.toMap();

        expect(map['id'], equals('category-id'));
        expect(map['name'], equals('Fiction'));
        expect(map['icon'], equals('\ud83d\udcda'));
        expect(map['created_at'], equals(testDate.toIso8601String()));
      });

      test('should handle different emoji icons', () {
        final scienceCategory = createTestCategory(icon: '\ud83d\udd2c');
        final fantasyCategory = createTestCategory(icon: '\ud83e\uddd9');

        expect(scienceCategory.toMap()['icon'], equals('\ud83d\udd2c'));
        expect(fantasyCategory.toMap()['icon'], equals('\ud83e\uddd9'));
      });
    });

    group('fromMap', () {
      test('should create category from map', () {
        final map = {
          'id': 'category-id',
          'name': 'Fiction',
          'icon': '\ud83d\udcda',
          'created_at': testDate.toIso8601String(),
        };

        final category = Category.fromMap(map);

        expect(category.id, equals('category-id'));
        expect(category.name, equals('Fiction'));
        expect(category.icon, equals('\ud83d\udcda'));
        expect(category.createdAt, equals(testDate));
      });

      test('should handle various icon strings', () {
        final map = {
          'id': 'category-id',
          'name': 'History',
          'icon': '\ud83c\udfdb\ufe0f',
          'created_at': testDate.toIso8601String(),
        };

        final category = Category.fromMap(map);

        expect(category.icon, equals('\ud83c\udfdb\ufe0f'));
      });
    });

    group('copyWith', () {
      test('should create copy with updated name', () {
        final category = createTestCategory();
        final updated = category.copyWith(name: 'Non-Fiction');

        expect(updated.name, equals('Non-Fiction'));
        expect(updated.id, equals(category.id));
        expect(updated.icon, equals(category.icon));
      });

      test('should create copy with updated icon', () {
        final category = createTestCategory(icon: '\ud83d\udcda');
        final updated = category.copyWith(icon: '\ud83d\udd2c');

        expect(updated.icon, equals('\ud83d\udd2c'));
        expect(updated.name, equals(category.name));
      });

      test('should preserve all fields when no arguments provided', () {
        final category = createTestCategory();
        final copy = category.copyWith();

        expect(copy.id, equals(category.id));
        expect(copy.name, equals(category.name));
        expect(copy.icon, equals(category.icon));
        expect(copy.createdAt, equals(category.createdAt));
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final category1 = createTestCategory(id: 'same-id', name: 'Name 1');
        final category2 = createTestCategory(id: 'same-id', name: 'Name 2');

        expect(category1, equals(category2));
      });

      test('should not be equal when ids differ', () {
        final category1 = createTestCategory(id: 'id-1');
        final category2 = createTestCategory(id: 'id-2');

        expect(category1, isNot(equals(category2)));
      });

      test('should have same hashCode when ids match', () {
        final category1 = createTestCategory(id: 'same-id');
        final category2 = createTestCategory(id: 'same-id', name: 'Different');

        expect(category1.hashCode, equals(category2.hashCode));
      });
    });

    group('roundtrip', () {
      test('should survive toMap/fromMap roundtrip', () {
        final original = createTestCategory();
        final map = original.toMap();
        final restored = Category.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.icon, equals(original.icon));
        expect(restored.createdAt, equals(original.createdAt));
      });

      test('should preserve emoji icons through roundtrip', () {
        final original = createTestCategory(icon: '\ud83d\udc7e');
        final map = original.toMap();
        final restored = Category.fromMap(map);

        expect(restored.icon, equals('\ud83d\udc7e'));
      });
    });
  });
}
