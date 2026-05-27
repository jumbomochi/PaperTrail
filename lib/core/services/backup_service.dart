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

      final importedBookIds = <String>{};
      for (final book in backup['books'] as List) {
        final map = Map<String, dynamic>.from(book as Map);
        map['cover_image_path'] = null;
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
