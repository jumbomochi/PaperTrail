import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:paper_trail/core/services/book_api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late BookApiService service;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    service = BookApiService(client: mockClient);
  });

  group('BookApiService', () {
    group('lookupByIsbn', () {
      test('should return BookInfo when book is found', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Clean Code',
                'authors': ['Robert C. Martin'],
                'publisher': 'Prentice Hall',
                'publishedDate': '2008',
                'description': 'A handbook of agile software craftsmanship',
                'pageCount': 464,
                'imageLinks': {
                  'thumbnail': 'http://example.com/thumb.jpg',
                },
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result, isNotNull);
        expect(result!.title, equals('Clean Code'));
        expect(result.author, equals('Robert C. Martin'));
        expect(result.publisher, equals('Prentice Hall'));
        expect(result.publishedDate, equals('2008'));
        expect(result.pageCount, equals(464));
        expect(result.isbn, equals('9780132350884'));
      });

      test('should clean ISBN before lookup', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Test Book',
                'authors': ['Author'],
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        await service.lookupByIsbn('978-0-13-235088-4');

        verify(() => mockClient.get(
              Uri.parse(
                  'https://www.googleapis.com/books/v1/volumes?q=isbn:9780132350884'),
            )).called(1);
      });

      test('should return null when no books found', () async {
        final responseBody = jsonEncode({
          'totalItems': 0,
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final result = await service.lookupByIsbn('0000000000000');

        expect(result, isNull);
      });

      test('should return null on non-200 response', () async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response('Not found', 404),
        );

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result, isNull);
      });

      test('should return null on network error', () async {
        when(() => mockClient.get(any())).thenThrow(Exception('Network error'));

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result, isNull);
      });

      test('should convert http to https for thumbnail URLs', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Test Book',
                'authors': ['Author'],
                'imageLinks': {
                  'thumbnail': 'http://books.google.com/thumb.jpg',
                },
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result!.thumbnailUrl, startsWith('https:'));
      });

      test('should handle missing authors', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Anonymous Book',
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result!.author, equals('Unknown Author'));
      });

      test('should join multiple authors with comma', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Collaborative Book',
                'authors': ['Alice', 'Bob', 'Charlie'],
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final result = await service.lookupByIsbn('978-0132350884');

        expect(result!.author, equals('Alice, Bob, Charlie'));
      });
    });

    group('searchBooks', () {
      test('should return list of books for valid query', () async {
        final responseBody = jsonEncode({
          'totalItems': 2,
          'items': [
            {
              'volumeInfo': {
                'title': 'Flutter in Action',
                'authors': ['Eric Windmill'],
              },
            },
            {
              'volumeInfo': {
                'title': 'Flutter Recipes',
                'authors': ['Fu Cheng'],
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final results = await service.searchBooks('Flutter');

        expect(results.length, equals(2));
        expect(results[0].title, equals('Flutter in Action'));
        expect(results[1].title, equals('Flutter Recipes'));
      });

      test('should return empty list when no results', () async {
        final responseBody = jsonEncode({
          'totalItems': 0,
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final results = await service.searchBooks('xyznonexistent');

        expect(results, isEmpty);
      });

      test('should return empty list on error', () async {
        when(() => mockClient.get(any())).thenThrow(Exception('Network error'));

        final results = await service.searchBooks('Flutter');

        expect(results, isEmpty);
      });

      test('should URL encode search query', () async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode({'totalItems': 0}), 200),
        );

        await service.searchBooks('clean code & architecture');

        verify(() => mockClient.get(
              Uri.parse(
                'https://www.googleapis.com/books/v1/volumes?q=clean%20code%20%26%20architecture&maxResults=20',
              ),
            )).called(1);
      });

      test('should extract ISBN from industry identifiers', () async {
        final responseBody = jsonEncode({
          'totalItems': 1,
          'items': [
            {
              'volumeInfo': {
                'title': 'Test Book',
                'authors': ['Author'],
                'industryIdentifiers': [
                  {'type': 'ISBN_13', 'identifier': '9781234567890'},
                  {'type': 'ISBN_10', 'identifier': '1234567890'},
                ],
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final results = await service.searchBooks('test');

        expect(results.first.isbn, equals('9781234567890'));
      });

      test('should skip items without title', () async {
        final responseBody = jsonEncode({
          'totalItems': 2,
          'items': [
            {
              'volumeInfo': {
                'authors': ['Author'],
              },
            },
            {
              'volumeInfo': {
                'title': 'Valid Book',
                'authors': ['Valid Author'],
              },
            },
          ],
        });

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, 200),
        );

        final results = await service.searchBooks('test');

        expect(results.length, equals(1));
        expect(results.first.title, equals('Valid Book'));
      });
    });
  });
}
