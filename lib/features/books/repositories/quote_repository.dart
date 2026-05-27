import 'package:paper_trail/core/database/database_helper.dart';
import 'package:paper_trail/features/books/models/quote.dart';

class QuoteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Quote>> getAllQuotes() async {
    final db = await _dbHelper.database;
    final maps = await db.query('quotes');
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<List<Quote>> getQuotesForBook(String bookId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'quotes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'CASE WHEN page IS NULL THEN 1 ELSE 0 END, page ASC, created_at ASC',
    );
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<Map<String, int>> getQuoteCountsByBook() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT book_id, COUNT(*) AS count FROM quotes GROUP BY book_id',
    );
    return {
      for (final row in rows) row['book_id'] as String: row['count'] as int,
    };
  }

  Future<void> insertQuote(Quote quote) async {
    final db = await _dbHelper.database;
    await db.insert('quotes', quote.toMap());
  }

  Future<void> updateQuote(Quote quote) async {
    final db = await _dbHelper.database;
    await db.update(
      'quotes',
      quote.toMap(),
      where: 'id = ?',
      whereArgs: [quote.id],
    );
  }

  Future<void> deleteQuote(String id) async {
    final db = await _dbHelper.database;
    await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }
}
