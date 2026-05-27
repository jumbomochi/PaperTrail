import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/core/services/logger_service.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/repositories/quote_repository.dart';

const _tag = 'QuoteProviders';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

/// All quotes for a given book, sorted page-asc with nulls last.
final quotesForBookProvider =
    FutureProvider.family<List<Quote>, String>((ref, bookId) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuotesForBook(bookId);
});

/// All quotes across the library (used by client-side search).
final allQuotesProvider = FutureProvider<List<Quote>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getAllQuotes();
});

/// Map of bookId → quote count, used by book card indicators.
final quoteCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuoteCountsByBook();
});

class QuoteNotifier extends StateNotifier<AsyncValue<void>> {
  final QuoteRepository _repository;
  final Ref _ref;

  QuoteNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> addQuote(Quote quote) async {
    try {
      await _repository.insertQuote(quote);
      logger.info('Added quote for ${quote.bookId}', tag: _tag);
      _invalidate(quote.bookId);
    } catch (e, st) {
      logger.error('Failed to add quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateQuote(Quote quote) async {
    try {
      await _repository.updateQuote(quote);
      logger.info('Updated quote ${quote.id}', tag: _tag);
      _invalidate(quote.bookId);
    } catch (e, st) {
      logger.error('Failed to update quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteQuote({required String id, required String bookId}) async {
    try {
      await _repository.deleteQuote(id);
      logger.info('Deleted quote $id', tag: _tag);
      _invalidate(bookId);
    } catch (e, st) {
      logger.error('Failed to delete quote',
          tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  void _invalidate(String bookId) {
    _ref.invalidate(quotesForBookProvider(bookId));
    _ref.invalidate(allQuotesProvider);
    _ref.invalidate(quoteCountsProvider);
  }
}

final quoteNotifierProvider =
    StateNotifierProvider<QuoteNotifier, AsyncValue<void>>((ref) {
  return QuoteNotifier(ref.watch(quoteRepositoryProvider), ref);
});
