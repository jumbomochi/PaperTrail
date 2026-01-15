import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/family/models/family_member.dart';

void main() {
  group('FamilyMember', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    const testColor = Colors.blue;

    FamilyMember createTestMember({
      String id = 'member-id',
      String name = 'Test Member',
      Color color = testColor,
    }) {
      return FamilyMember(
        id: id,
        name: name,
        color: color,
        createdAt: testDate,
      );
    }

    group('toMap', () {
      test('should convert family member to map with all fields', () {
        final member = createTestMember();
        final map = member.toMap();

        expect(map['id'], equals('member-id'));
        expect(map['name'], equals('Test Member'));
        expect(map['color'], equals(testColor.toARGB32()));
        expect(map['created_at'], equals(testDate.toIso8601String()));
      });

      test('should convert different colors correctly', () {
        final redMember = createTestMember(color: Colors.red);
        final greenMember = createTestMember(color: Colors.green);

        expect(redMember.toMap()['color'], equals(Colors.red.toARGB32()));
        expect(greenMember.toMap()['color'], equals(Colors.green.toARGB32()));
      });
    });

    group('fromMap', () {
      test('should create family member from map', () {
        final map = {
          'id': 'member-id',
          'name': 'Test Member',
          'color': testColor.toARGB32(),
          'created_at': testDate.toIso8601String(),
        };

        final member = FamilyMember.fromMap(map);

        expect(member.id, equals('member-id'));
        expect(member.name, equals('Test Member'));
        expect(member.color.value, equals(testColor.value));
        expect(member.createdAt, equals(testDate));
      });

      test('should handle different color values', () {
        final map = {
          'id': 'member-id',
          'name': 'Red Member',
          'color': Colors.red.toARGB32(),
          'created_at': testDate.toIso8601String(),
        };

        final member = FamilyMember.fromMap(map);

        expect(member.color.value, equals(Colors.red.value));
      });
    });

    group('copyWith', () {
      test('should create copy with updated name', () {
        final member = createTestMember();
        final updated = member.copyWith(name: 'New Name');

        expect(updated.name, equals('New Name'));
        expect(updated.id, equals(member.id));
        expect(updated.color, equals(member.color));
      });

      test('should create copy with updated color', () {
        final member = createTestMember(color: Colors.blue);
        final updated = member.copyWith(color: Colors.orange);

        expect(updated.color, equals(Colors.orange));
        expect(updated.name, equals(member.name));
      });

      test('should preserve all fields when no arguments provided', () {
        final member = createTestMember();
        final copy = member.copyWith();

        expect(copy.id, equals(member.id));
        expect(copy.name, equals(member.name));
        expect(copy.color, equals(member.color));
        expect(copy.createdAt, equals(member.createdAt));
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final member1 = createTestMember(id: 'same-id', name: 'Name 1');
        final member2 = createTestMember(id: 'same-id', name: 'Name 2');

        expect(member1, equals(member2));
      });

      test('should not be equal when ids differ', () {
        final member1 = createTestMember(id: 'id-1');
        final member2 = createTestMember(id: 'id-2');

        expect(member1, isNot(equals(member2)));
      });

      test('should have same hashCode when ids match', () {
        final member1 = createTestMember(id: 'same-id');
        final member2 = createTestMember(id: 'same-id', name: 'Different');

        expect(member1.hashCode, equals(member2.hashCode));
      });
    });

    group('roundtrip', () {
      test('should survive toMap/fromMap roundtrip', () {
        final original = createTestMember();
        final map = original.toMap();
        final restored = FamilyMember.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.color.value, equals(original.color.value));
        expect(restored.createdAt, equals(original.createdAt));
      });

      test('should preserve custom colors through roundtrip', () {
        const customColor = Color(0xFFABCDEF);
        final original = createTestMember(color: customColor);
        final map = original.toMap();
        final restored = FamilyMember.fromMap(map);

        expect(restored.color.value, equals(customColor.value));
      });
    });
  });
}
