import 'dart:convert';
import 'package:paper_trail/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final db = await _dbHelper.database;

    final books = await db.query('books');
    final categories = await db.query('categories');
    final familyMembers = await db.query('family_members');

    // Exclude cover_image_path from books (local paths are not portable)
    final exportBooks = books.map((book) {
      final map = Map<String, dynamic>.from(book);
      map.remove('cover_image_path');
      return map;
    }).toList();

    final backup = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'books': exportBooks,
      'categories': categories,
      'family_members': familyMembers,
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

    return decoded;
  }

  ({int books, int categories, int familyMembers}) getCounts(
    Map<String, dynamic> backup,
  ) {
    return (
      books: (backup['books'] as List).length,
      categories: (backup['categories'] as List).length,
      familyMembers: (backup['family_members'] as List).length,
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

      for (final book in backup['books'] as List) {
        final map = Map<String, dynamic>.from(book as Map);
        map['cover_image_path'] = null;
        await txn.insert(
          'books',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
