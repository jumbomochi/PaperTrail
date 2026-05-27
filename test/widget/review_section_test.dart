import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/widgets/review_section.dart';

void main() {
  testWidgets('shows Add review button when review is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(review: null, onEditPressed: () {}),
        ),
      ),
    );
    expect(find.text('Add review'), findsOneWidget);
  });

  testWidgets('renders review text when present', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(
            review: 'Brilliant pacing',
            onEditPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Brilliant pacing'), findsOneWidget);
    expect(find.text('Add review'), findsNothing);
  });

  testWidgets('triggers onEditPressed on tap', (WidgetTester tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewSection(
            review: 'Some review',
            onEditPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Some review'));
    await tester.pumpAndSettle();
    expect(taps, equals(1));
  });
}
