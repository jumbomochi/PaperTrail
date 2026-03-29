import 'dart:convert';
import 'package:paper_trail/core/database/database_helper.dart';

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
}
