import 'package:flutter/material.dart';
import 'package:paper_trail/features/books/models/quote.dart';

class QuotesList extends StatelessWidget {
  final List<Quote> quotes;
  final VoidCallback onAddPressed;
  final ValueChanged<Quote> onQuoteTapped;
  final ValueChanged<Quote> onQuoteLongPressed;

  const QuotesList({
    super.key,
    required this.quotes,
    required this.onAddPressed,
    required this.onQuoteTapped,
    required this.onQuoteLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quotes (${quotes.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add quote'),
              ),
            ],
          ),
        ),
        for (final q in quotes)
          InkWell(
            onTap: () => onQuoteTapped(q),
            onLongPress: () => onQuoteLongPressed(q),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.text,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (q.page != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'p.${q.page}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
