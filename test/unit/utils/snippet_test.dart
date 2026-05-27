import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trail/features/books/utils/snippet.dart';

void main() {
  group('buildSnippet', () {
    test('returns null when query is not found', () {
      expect(buildSnippet(text: 'hello world', query: 'zzz'), isNull);
    });

    test('returns null when query is empty', () {
      expect(buildSnippet(text: 'hello world', query: ''), isNull);
    });

    test('returns null when text is empty', () {
      expect(buildSnippet(text: '', query: 'foo'), isNull);
    });

    test('matches case-insensitively and preserves source casing', () {
      final s = buildSnippet(text: 'Hello World', query: 'WORLD');
      expect(s, isNotNull);
      expect(s!.matched, equals('World'));
    });

    test('no truncation when text is shorter than window', () {
      final s = buildSnippet(text: 'A short bit', query: 'short');
      expect(s, isNotNull);
      expect(s!.prefix, equals('A '));
      expect(s.matched, equals('short'));
      expect(s.suffix, equals(' bit'));
    });

    test('truncates with ellipsis on both sides when match is in the middle', () {
      final long = 'a' * 200 + 'NEEDLE' + 'b' * 200;
      final s = buildSnippet(text: long, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.prefix.startsWith('…'), isTrue);
      expect(s.suffix.endsWith('…'), isTrue);
      expect(s.matched, equals('NEEDLE'));
      final total = s.prefix.length + s.matched.length + s.suffix.length;
      expect(total, lessThanOrEqualTo(62));
    });

    test('no leading ellipsis when match is near the start', () {
      final text = 'NEEDLE at the start of a longer string ' + 'x' * 100;
      final s = buildSnippet(text: text, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.prefix.startsWith('…'), isFalse);
      expect(s.suffix.endsWith('…'), isTrue);
    });

    test('no trailing ellipsis when match is near the end', () {
      final text = 'x' * 100 + ' at the end NEEDLE';
      final s = buildSnippet(text: text, query: 'needle', maxLength: 60);
      expect(s, isNotNull);
      expect(s!.suffix.endsWith('…'), isFalse);
      expect(s.prefix.startsWith('…'), isTrue);
    });

    test('picks the first match when query appears multiple times', () {
      final s = buildSnippet(text: 'foo BAR foo BAR', query: 'bar');
      expect(s, isNotNull);
      expect(s!.matched, equals('BAR'));
      expect(s.prefix, equals('foo '));
    });
  });
}
