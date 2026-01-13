import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/repositories/book_repository.dart';

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

  BookNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = const AsyncValue.loading();
    try {
      final books = await _repository.getAllBooks();
      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBook(Book book) async {
    await _repository.insertBook(book);
    await loadBooks();
    _ref.invalidate(bookCountProvider);
    _ref.invalidate(wishlistCountProvider);
  }

  Future<void> updateBook(Book book) async {
    await _repository.updateBook(book);
    await loadBooks();
  }

  Future<void> deleteBook(String id) async {
    await _repository.deleteBook(id);
    await loadBooks();
    _ref.invalidate(bookCountProvider);
    _ref.invalidate(wishlistCountProvider);
  }

  Future<void> toggleWishlist(Book book) async {
    final updatedBook = book.copyWith(
      isWishlist: !book.isWishlist,
      updatedAt: DateTime.now(),
    );
    await _repository.updateBook(updatedBook);
    await loadBooks();
    _ref.invalidate(wishlistBooksProvider);
    _ref.invalidate(bookCountProvider);
    _ref.invalidate(wishlistCountProvider);
  }
}

final bookNotifierProvider =
    StateNotifierProvider<BookNotifier, AsyncValue<List<Book>>>((ref) {
      final repository = ref.watch(bookRepositoryProvider);
      return BookNotifier(repository, ref);
    });
