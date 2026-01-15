import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:paper_trail/core/exceptions/app_exceptions.dart';
import 'package:paper_trail/core/services/logger_service.dart';

class BookInfo {
  final String? isbn;
  final String title;
  final String author;
  final String? publisher;
  final String? publishedDate;
  final String? description;
  final String? thumbnailUrl;
  final int? pageCount;

  BookInfo({
    this.isbn,
    required this.title,
    required this.author,
    this.publisher,
    this.publishedDate,
    this.description,
    this.thumbnailUrl,
    this.pageCount,
  });
}

/// Result wrapper for book lookup operations
class BookLookupResult {
  final BookInfo? book;
  final String? errorMessage;
  final bool isNotFound;

  const BookLookupResult._({
    this.book,
    this.errorMessage,
    this.isNotFound = false,
  });

  factory BookLookupResult.success(BookInfo book) =>
      BookLookupResult._(book: book);

  factory BookLookupResult.notFound() =>
      const BookLookupResult._(isNotFound: true);

  factory BookLookupResult.error(String message) =>
      BookLookupResult._(errorMessage: message);

  bool get isSuccess => book != null;
  bool get isError => errorMessage != null;
}

class BookApiService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  static const String _tag = 'BookApiService';

  final http.Client _client;

  BookApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Look up a book by ISBN with detailed result
  Future<BookLookupResult> lookupByIsbnWithResult(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');

    if (cleanIsbn.isEmpty) {
      return BookLookupResult.error('Invalid ISBN provided');
    }

    logger.debug('Looking up ISBN: $cleanIsbn', tag: _tag);

    try {
      final url = Uri.parse('$_baseUrl?q=isbn:$cleanIsbn');
      final response = await _client.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw NetworkException.timeout(),
          );

      if (response.statusCode != 200) {
        logger.warning(
          'API returned non-200 status',
          tag: _tag,
          data: {'statusCode': response.statusCode, 'isbn': cleanIsbn},
        );
        return BookLookupResult.error(
          'Unable to search books. Please try again.',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final totalItems = data['totalItems'] as int? ?? 0;

      if (totalItems == 0) {
        logger.info('No book found for ISBN: $cleanIsbn', tag: _tag);
        return BookLookupResult.notFound();
      }

      final items = data['items'] as List<dynamic>;
      final volumeInfo = items[0]['volumeInfo'] as Map<String, dynamic>;
      final book = _parseVolumeInfo(volumeInfo, cleanIsbn);

      if (book == null) {
        logger.warning(
          'Failed to parse book info',
          tag: _tag,
          data: {'isbn': cleanIsbn},
        );
        return BookLookupResult.error('Unable to read book information.');
      }

      logger.info(
        'Found book: ${book.title}',
        tag: _tag,
        data: {'isbn': cleanIsbn, 'title': book.title},
      );
      return BookLookupResult.success(book);
    } on SocketException catch (e) {
      logger.error(
        'Network error during ISBN lookup',
        tag: _tag,
        error: e,
        data: {'isbn': cleanIsbn},
      );
      return BookLookupResult.error(
        'No internet connection. Please check your network.',
      );
    } on NetworkException catch (e) {
      logger.error(
        'Network exception during ISBN lookup',
        tag: _tag,
        error: e,
        data: {'isbn': cleanIsbn},
      );
      return BookLookupResult.error(e.message);
    } on FormatException catch (e) {
      logger.error(
        'Invalid response format',
        tag: _tag,
        error: e,
        data: {'isbn': cleanIsbn},
      );
      return BookLookupResult.error('Invalid response from book service.');
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error during ISBN lookup',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
        data: {'isbn': cleanIsbn},
      );
      return BookLookupResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Legacy method for backwards compatibility - returns null on any error
  Future<BookInfo?> lookupByIsbn(String isbn) async {
    final result = await lookupByIsbnWithResult(isbn);
    return result.book;
  }

  /// Search books by query with detailed results
  Future<(List<BookInfo>, String?)> searchBooksWithResult(String query) async {
    if (query.trim().isEmpty) {
      return (const <BookInfo>[], 'Please enter a search term.');
    }

    logger.debug('Searching books: "$query"', tag: _tag);

    try {
      final url = Uri.parse(
        '$_baseUrl?q=${Uri.encodeComponent(query)}&maxResults=20',
      );
      final response = await _client.get(url).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw NetworkException.timeout(),
          );

      if (response.statusCode != 200) {
        logger.warning(
          'Search API returned non-200 status',
          tag: _tag,
          data: {'statusCode': response.statusCode, 'query': query},
        );
        return (
          const <BookInfo>[],
          'Unable to search books. Please try again.',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final totalItems = data['totalItems'] as int? ?? 0;

      if (totalItems == 0) {
        logger.info('No results for query: "$query"', tag: _tag);
        return (const <BookInfo>[], null);
      }

      final items = data['items'] as List<dynamic>;
      final books = <BookInfo>[];

      for (final item in items) {
        final volumeInfo = item['volumeInfo'] as Map<String, dynamic>;
        final book = _parseVolumeInfo(volumeInfo, null);
        if (book != null) {
          books.add(book);
        }
      }

      logger.info(
        'Search returned ${books.length} results',
        tag: _tag,
        data: {'query': query, 'count': books.length},
      );
      return (books, null);
    } on SocketException catch (e) {
      logger.error(
        'Network error during search',
        tag: _tag,
        error: e,
        data: {'query': query},
      );
      return (
        const <BookInfo>[],
        'No internet connection. Please check your network.',
      );
    } on NetworkException catch (e) {
      logger.error(
        'Network exception during search',
        tag: _tag,
        error: e,
        data: {'query': query},
      );
      return (const <BookInfo>[], e.message);
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error during search',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
        data: {'query': query},
      );
      return (
        const <BookInfo>[],
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Legacy method for backwards compatibility
  Future<List<BookInfo>> searchBooks(String query) async {
    final (books, _) = await searchBooksWithResult(query);
    return books;
  }

  BookInfo? _parseVolumeInfo(Map<String, dynamic> volumeInfo, String? isbn) {
    final title = volumeInfo['title'] as String?;
    final authors = volumeInfo['authors'] as List<dynamic>?;

    if (title == null) {
      return null;
    }

    final author = authors?.isNotEmpty == true
        ? authors!.join(', ')
        : 'Unknown Author';

    String? thumbnailUrl;
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    if (imageLinks != null) {
      thumbnailUrl = (imageLinks['thumbnail'] as String?)?.replaceFirst(
        'http:',
        'https:',
      );
    }

    // Try to extract ISBN from identifiers if not provided
    String? foundIsbn = isbn;
    if (foundIsbn == null) {
      final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
      if (identifiers != null) {
        for (final id in identifiers) {
          final type = id['type'] as String?;
          if (type == 'ISBN_13' || type == 'ISBN_10') {
            foundIsbn = id['identifier'] as String?;
            break;
          }
        }
      }
    }

    return BookInfo(
      isbn: foundIsbn,
      title: title,
      author: author,
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      description: volumeInfo['description'] as String?,
      thumbnailUrl: thumbnailUrl,
      pageCount: volumeInfo['pageCount'] as int?,
    );
  }
}
