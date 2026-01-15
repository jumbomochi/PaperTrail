import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/repositories/book_repository.dart';
import 'package:paper_trail/core/services/logger_service.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final booksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
});

final wishlistBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getWishlistBooks();
});

final bookByIdProvider = FutureProvider.family<Book?, String>((ref, id) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBookById(id);
});

final booksByOwnerProvider = FutureProvider.family<List<Book>, String>((
  ref,
  ownerId,
) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBooksByOwner(ownerId);
});

final booksByCategoryProvider = FutureProvider.family<List<Book>, String>((
  ref,
  categoryId,
) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBooksByCategory(categoryId);
});

final bookSearchProvider = FutureProvider.family<List<Book>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(bookRepositoryProvider);
  return repository.searchBooks(query);
});

final bookCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBookCount();
});

final wishlistCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getWishlistCount();
});

class BookNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  final BookRepository _repository;
  final Ref _ref;
  static const String _tag = 'BookNotifier';

  BookNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = const AsyncValue.loading();
    try {
      final books = await _repository.getAllBooks();
      state = AsyncValue.data(books);
      logger.debug('Loaded ${books.length} books', tag: _tag);
    } catch (e, st) {
      logger.error('Failed to load books', tag: _tag, error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBook(Book book) async {
    // Optimistic update: Add to current state immediately
    final previousState = state;
    state.whenData((books) {
      // Insert at the beginning (newest first)
      if (!book.isWishlist) {
        state = AsyncValue.data([book, ...books]);
      }
    });

    try {
      await _repository.insertBook(book);
      logger.info('Added book: ${book.title}', tag: _tag);
      _invalidateCountProviders();
      if (book.isWishlist) {
        _ref.invalidate(wishlistBooksProvider);
      }
    } catch (e, st) {
      // Rollback on error
      logger.error('Failed to add book', tag: _tag, error: e, stackTrace: st);
      state = previousState;
      rethrow;
    }
  }

  Future<void> updateBook(Book book) async {
    // Optimistic update: Replace the book in current state
    final previousState = state;
    state.whenData((books) {
      final index = books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        final updatedBooks = List<Book>.from(books);
        updatedBooks[index] = book;
        state = AsyncValue.data(updatedBooks);
      }
    });

    try {
      await _repository.updateBook(book);
      logger.info('Updated book: ${book.title}', tag: _tag);
      // Invalidate related providers
      _ref.invalidate(bookByIdProvider(book.id));
      if (book.ownerId != null) {
        _ref.invalidate(booksByOwnerProvider(book.ownerId!));
      }
      if (book.categoryId != null) {
        _ref.invalidate(booksByCategoryProvider(book.categoryId!));
      }
    } catch (e, st) {
      // Rollback on error
      logger.error('Failed to update book', tag: _tag, error: e, stackTrace: st);
      state = previousState;
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    // Optimistic update: Remove from current state
    final previousState = state;
    Book? deletedBook;
    state.whenData((books) {
      final index = books.indexWhere((b) => b.id == id);
      if (index != -1) {
        deletedBook = books[index];
        final updatedBooks = List<Book>.from(books)..removeAt(index);
        state = AsyncValue.data(updatedBooks);
      }
    });

    try {
      await _repository.deleteBook(id);
      logger.info('Deleted book: $id', tag: _tag);
      _invalidateCountProviders();
      _ref.invalidate(wishlistBooksProvider);
    } catch (e, st) {
      // Rollback on error
      logger.error('Failed to delete book', tag: _tag, error: e, stackTrace: st);
      state = previousState;
      rethrow;
    }
  }

  Future<void> toggleWishlist(Book book) async {
    final updatedBook = book.copyWith(
      isWishlist: !book.isWishlist,
      updatedAt: DateTime.now(),
    );

    // Optimistic update
    final previousState = state;
    state.whenData((books) {
      // If moving to wishlist, remove from collection view
      // If moving from wishlist, add to collection view
      if (updatedBook.isWishlist) {
        // Remove from collection (moving to wishlist)
        final updatedBooks = books.where((b) => b.id != book.id).toList();
        state = AsyncValue.data(updatedBooks);
      } else {
        // Add back to collection (moving from wishlist)
        state = AsyncValue.data([updatedBook, ...books]);
      }
    });

    try {
      await _repository.updateBook(updatedBook);
      logger.info(
        'Toggled wishlist for: ${book.title} (now ${updatedBook.isWishlist ? "wishlist" : "collection"})',
        tag: _tag,
      );
      _ref.invalidate(wishlistBooksProvider);
      _invalidateCountProviders();
    } catch (e, st) {
      // Rollback on error
      logger.error('Failed to toggle wishlist', tag: _tag, error: e, stackTrace: st);
      state = previousState;
      rethrow;
    }
  }

  /// Refresh books from database
  Future<void> refresh() async {
    await loadBooks();
    _invalidateAllProviders();
  }

  void _invalidateCountProviders() {
    _ref.invalidate(bookCountProvider);
    _ref.invalidate(wishlistCountProvider);
  }

  void _invalidateAllProviders() {
    _invalidateCountProviders();
    _ref.invalidate(booksProvider);
    _ref.invalidate(wishlistBooksProvider);
  }
}

final bookNotifierProvider =
    StateNotifierProvider<BookNotifier, AsyncValue<List<Book>>>((ref) {
      final repository = ref.watch(bookRepositoryProvider);
      return BookNotifier(repository, ref);
    });
