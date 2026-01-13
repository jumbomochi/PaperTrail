import 'package:paper_trail/core/database/database_helper.dart';
import 'package:paper_trail/features/books/models/book.dart';

class BookRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Book>> getAllBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'is_wishlist = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> getWishlistBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'is_wishlist = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> getBooksByOwner(String ownerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'owner_id = ? AND is_wishlist = ?',
      whereArgs: [ownerId, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> getBooksByCategory(String categoryId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'category_id = ? AND is_wishlist = ?',
      whereArgs: [categoryId, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<Book?> getBookById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<Book?> getBookByIsbn(String isbn) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<List<Book>> searchBooks(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final maps = await db.query(
      'books',
      where:
          '(title LIKE ? OR author LIKE ? OR isbn LIKE ?) AND is_wishlist = ?',
      whereArgs: [searchQuery, searchQuery, searchQuery, 0],
      orderBy: 'title ASC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<void> insertBook(Book book) async {
    final db = await _dbHelper.database;
    await db.insert('books', book.toMap());
  }

  Future<void> updateBook(Book book) async {
    final db = await _dbHelper.database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(String id) async {
    final db = await _dbHelper.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getBookCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM books WHERE is_wishlist = 0',
    );
    return result.first['count'] as int;
  }

  Future<int> getWishlistCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM books WHERE is_wishlist = 1',
    );
    return result.first['count'] as int;
  }
}
