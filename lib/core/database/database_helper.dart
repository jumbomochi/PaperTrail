import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('paper_trail.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Family members table
    await db.execute('''
      CREATE TABLE family_members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Books table
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        isbn TEXT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        publisher TEXT,
        published_date TEXT,
        description TEXT,
        cover_image_path TEXT,
        thumbnail_url TEXT,
        page_count INTEGER,
        owner_id TEXT,
        category_id TEXT,
        is_wishlist INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        review TEXT,
        review_updated_at INTEGER,  -- epoch ms, null until first review
        FOREIGN KEY (owner_id) REFERENCES family_members (id) ON DELETE SET NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for common queries
    await db.execute('CREATE INDEX idx_books_owner ON books (owner_id)');
    await db.execute('CREATE INDEX idx_books_category ON books (category_id)');
    await db.execute('CREATE INDEX idx_books_wishlist ON books (is_wishlist)');
    await db.execute('CREATE INDEX idx_books_isbn ON books (isbn)');

    // Quotes table
    await db.execute('''
      CREATE TABLE quotes (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        text TEXT NOT NULL,
        page INTEGER,
        created_at INTEGER NOT NULL,  -- epoch ms
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_quotes_book_id ON quotes (book_id)');

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultCategories = [
      {'id': 'cat_fiction', 'name': 'Fiction', 'icon': 'icon_fiction', 'created_at': now},
      {'id': 'cat_nonfiction', 'name': 'Non-Fiction', 'icon': 'icon_non_fiction', 'created_at': now},
      {'id': 'cat_science', 'name': 'Science', 'icon': 'icon_science', 'created_at': now},
      {'id': 'cat_history', 'name': 'History', 'icon': 'icon_history', 'created_at': now},
      {'id': 'cat_biography', 'name': 'Biography', 'icon': 'icon_biography', 'created_at': now},
      {'id': 'cat_children', 'name': 'Children', 'icon': 'icon_children', 'created_at': now},
      {'id': 'cat_cooking', 'name': 'Cooking', 'icon': 'icon_cooking', 'created_at': now},
      {'id': 'cat_art', 'name': 'Art', 'icon': 'icon_art', 'created_at': now},
    ];

    for (final category in defaultCategories) {
      await db.insert('categories', category);
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate emoji icons to asset keys
      const emojiToAsset = {
        '📚': 'icon_fiction',
        '📖': 'icon_non_fiction',
        '🔬': 'icon_science',
        '🏛️': 'icon_history',
        '👤': 'icon_biography',
        '🧒': 'icon_children',
        '🍳': 'icon_cooking',
        '🎨': 'icon_art',
      };
      for (final entry in emojiToAsset.entries) {
        await db.update(
          'categories',
          {'icon': entry.value},
          where: 'icon = ?',
          whereArgs: [entry.key],
        );
      }
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE books ADD COLUMN review TEXT');
      // epoch ms, null until first review
      await db.execute('ALTER TABLE books ADD COLUMN review_updated_at INTEGER');
      await db.execute('''
        CREATE TABLE quotes (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          text TEXT NOT NULL,
          page INTEGER,
          created_at INTEGER NOT NULL,  -- epoch ms
          FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_quotes_book_id ON quotes (book_id)');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
