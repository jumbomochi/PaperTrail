import 'dart:convert';
import 'package:http/http.dart' as http;

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

class BookApiService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  Future<BookInfo?> lookupByIsbn(String isbn) async {
    try {
      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
      final url = Uri.parse('$_baseUrl?q=isbn:$cleanIsbn');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final totalItems = data['totalItems'] as int? ?? 0;

      if (totalItems == 0) {
        return null;
      }

      final items = data['items'] as List<dynamic>;
      final volumeInfo = items[0]['volumeInfo'] as Map<String, dynamic>;

      return _parseVolumeInfo(volumeInfo, cleanIsbn);
    } catch (e) {
      return null;
    }
  }

  Future<List<BookInfo>> searchBooks(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?q=${Uri.encodeComponent(query)}&maxResults=20',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final totalItems = data['totalItems'] as int? ?? 0;

      if (totalItems == 0) {
        return [];
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

      return books;
    } catch (e) {
      return [];
    }
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
