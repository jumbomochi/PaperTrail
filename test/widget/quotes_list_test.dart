import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/widgets/quotes_list.dart';

void main() {
  final t = DateTime(2026, 5, 1);

  testWidgets('shows header with count and Add quote button when empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: const [],
            onAddPressed: () {},
            onQuoteTapped: (_) {},
            onQuoteLongPressed: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Quotes (0)'), findsOneWidget);
    expect(find.text('Add quote'), findsOneWidget);
  });

  testWidgets('renders each quote with page when set',
      (WidgetTester tester) async {
    final quotes = [
      Quote(id: 'q1', bookId: 'b', text: 'Alpha', page: 1, createdAt: t),
      Quote(id: 'q2', bookId: 'b', text: 'Beta', page: null, createdAt: t),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: quotes,
            onAddPressed: () {},
            onQuoteTapped: (_) {},
            onQuoteLongPressed: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Quotes (2)'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('p.1'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('forwards taps and long-presses', (WidgetTester tester) async {
    final quotes = [
      Quote(id: 'q1', bookId: 'b', text: 'Alpha', page: 1, createdAt: t),
    ];
    Quote? tapped;
    Quote? longPressed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuotesList(
            quotes: quotes,
            onAddPressed: () {},
            onQuoteTapped: (q) => tapped = q,
            onQuoteLongPressed: (q) => longPressed = q,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    expect(tapped, equals(quotes.first));

    await tester.longPress(find.text('Alpha'));
    expect(longPressed, equals(quotes.first));
  });
}
