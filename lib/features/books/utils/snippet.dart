class TextSnippet {
  final String prefix;
  final String matched;
  final String suffix;

  const TextSnippet({
    required this.prefix,
    required this.matched,
    required this.suffix,
  });
}

TextSnippet? buildSnippet({
  required String text,
  required String query,
  int maxLength = 60,
}) {
  if (query.isEmpty || text.isEmpty) return null;

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final matchStart = lowerText.indexOf(lowerQuery);
  if (matchStart < 0) return null;
  final matchEnd = matchStart + query.length;

  if (text.length <= maxLength) {
    return TextSnippet(
      prefix: text.substring(0, matchStart),
      matched: text.substring(matchStart, matchEnd),
      suffix: text.substring(matchEnd),
    );
  }

  final effectiveMax =
      query.length > maxLength ? query.length : maxLength;
  final remaining = effectiveMax - query.length;
  final halfBefore = remaining ~/ 2;
  final halfAfter = remaining - halfBefore;

  var windowStart = matchStart - halfBefore;
  var windowEnd = matchEnd + halfAfter;

  if (windowStart < 0) {
    windowEnd += -windowStart;
    windowStart = 0;
  }
  if (windowEnd > text.length) {
    windowStart -= (windowEnd - text.length);
    windowEnd = text.length;
  }
  if (windowStart < 0) windowStart = 0;

  final prefixSrc = text.substring(windowStart, matchStart);
  final suffixSrc = text.substring(matchEnd, windowEnd);

  final leadingEllipsis = windowStart > 0 ? '…' : '';
  final trailingEllipsis = windowEnd < text.length ? '…' : '';

  return TextSnippet(
    prefix: '$leadingEllipsis$prefixSrc',
    matched: text.substring(matchStart, matchEnd),
    suffix: '$suffixSrc$trailingEllipsis',
  );
}
