import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/app.dart';

void main() {
  group('PaperTrailApp', () {
    testWidgets('smoke test - app builds without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PaperTrailApp(),
        ),
      );

      // Verify the app builds and shows the title
      expect(find.text('PaperTrail'), findsOneWidget);
    });

    testWidgets('shows bottom navigation bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PaperTrailApp(),
        ),
      );

      // Verify bottom navigation items exist
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.library_books), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.category), findsOneWidget);
    });
  });
}
