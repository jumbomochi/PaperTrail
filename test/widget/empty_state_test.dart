import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('displays icon and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.book), findsOneWidget);
      expect(find.text('No Books Found'), findsOneWidget);
    });

    testWidgets('displays subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              subtitle: 'Start by adding your first book',
            ),
          ),
        ),
      );

      expect(find.text('No Books Found'), findsOneWidget);
      expect(find.text('Start by adding your first book'), findsOneWidget);
    });

    testWidgets('does not display subtitle when null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              subtitle: null,
            ),
          ),
        ),
      );

      expect(find.text('No Books Found'), findsOneWidget);
      // Only one text widget should be present (the title)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.length, equals(1));
    });

    testWidgets('displays button when buttonText and onButtonPressed provided',
        (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              buttonText: 'Add Book',
              onButtonPressed: () => buttonPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Book'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(buttonPressed, isTrue);
    });

    testWidgets('does not display button when buttonText is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              onButtonPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('does not display button when onButtonPressed is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              buttonText: 'Add Book',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('button has add icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
              buttonText: 'Add Book',
              onButtonPressed: () {},
            ),
          ),
        ),
      );

      // Find the add icon within the ElevatedButton
      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      // The button should contain an add icon
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
    });

    testWidgets('content is centered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books Found',
            ),
          ),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('displays with different icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.favorite,
              title: 'No Favorites',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('No Favorites'), findsOneWidget);
    });
  });
}
