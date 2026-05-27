import 'package:flutter/material.dart';

class ReviewSection extends StatelessWidget {
  final String? review;
  final VoidCallback onEditPressed;

  const ReviewSection({
    super.key,
    required this.review,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'My Review',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (review == null || review!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add review'),
            ),
          )
        else
          InkWell(
            onTap: onEditPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(review!),
            ),
          ),
      ],
    );
  }
}
