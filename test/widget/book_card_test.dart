import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/widgets/book_card.dart';

void main() {
  final testDate = DateTime(2024, 1, 15);

  Book createTestBook({
    String id = 'test-id',
    String title = 'Test Book Title',
    String author = 'Test Author',
    String? coverImagePath,
    String? thumbnailUrl,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      coverImagePath: coverImagePath,
      thumbnailUrl: thumbnailUrl,
      createdAt: testDate,
      updatedAt: testDate,
    );
  }

  group('BookCard', () {
    testWidgets('displays book title and author', (WidgetTester tester) async {
      final book = createTestBook(
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      expect(find.text('The Great Gatsby'), findsOneWidget);
      expect(find.text('F. Scott Fitzgerald'), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped',
        (WidgetTester tester) async {
      final book = createTestBook();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(
                book: book,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BookCard));
      expect(tapped, isTrue);
    });

    testWidgets('displays placeholder when no cover image or thumbnail',
        (WidgetTester tester) async {
      final book = createTestBook(
        coverImagePath: null,
        thumbnailUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      // Should show the menu_book icon as placeholder
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('displays owner chip when ownerName is provided',
        (WidgetTester tester) async {
      final book = createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(
                book: book,
                ownerName: 'John',
                ownerColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('does not display owner chip when ownerName is null',
        (WidgetTester tester) async {
      final book = createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(
                book: book,
                ownerName: null,
              ),
            ),
          ),
        ),
      );

      // Should not find any extra text beyond title and author
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(textWidgets.length, equals(2)); // Only title and author
    });

    testWidgets('truncates long title with ellipsis',
        (WidgetTester tester) async {
      final book = createTestBook(
        title:
            'This Is A Very Long Book Title That Should Be Truncated With Ellipsis',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      final titleText = tester.widget<Text>(
        find.text(
            'This Is A Very Long Book Title That Should Be Truncated With Ellipsis'),
      );
      expect(titleText.overflow, equals(TextOverflow.ellipsis));
      expect(titleText.maxLines, equals(2));
    });

    testWidgets('truncates long author name with ellipsis',
        (WidgetTester tester) async {
      final book = createTestBook(
        author: 'A Very Long Author Name That Should Be Truncated',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      final authorText = tester.widget<Text>(
        find.text('A Very Long Author Name That Should Be Truncated'),
      );
      expect(authorText.overflow, equals(TextOverflow.ellipsis));
      expect(authorText.maxLines, equals(1));
    });

    testWidgets('uses Card widget with proper clipping',
        (WidgetTester tester) async {
      final book = createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, equals(Clip.antiAlias));
    });

    testWidgets('uses InkWell for tap effects', (WidgetTester tester) async {
      final book = createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('title has bold font weight', (WidgetTester tester) async {
      final book = createTestBook(title: 'Bold Title');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      final titleText = tester.widget<Text>(find.text('Bold Title'));
      expect(titleText.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('owner chip has correct color styling',
        (WidgetTester tester) async {
      final book = createTestBook();
      const ownerColor = Colors.red;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: BookCard(
                book: book,
                ownerName: 'Jane',
                ownerColor: ownerColor,
              ),
            ),
          ),
        ),
      );

      final ownerText = tester.widget<Text>(find.text('Jane'));
      expect(ownerText.style?.color, equals(ownerColor));
    });
  });
}
