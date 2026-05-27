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

    test('treats missing quotes array on v2 as optional (no throw)', () {
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

    test('throws when quotes is present but not a list', () {
      final json = jsonEncode({
        'version': 2,
        'exported_at': '2026-05-01T00:00:00.000Z',
        'books': [],
        'categories': [],
        'family_members': [],
        'quotes': 'not-a-list',
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
