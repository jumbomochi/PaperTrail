import 'package:flutter/material.dart';

/// Opens the review editor as a full-screen route.
///
/// Returns the new review text on save, or null if cancelled.
/// A non-null empty string indicates the user cleared the review.
Future<String?> openReviewEditor(
  BuildContext context, {
  required String bookTitle,
  String? initial,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReviewEditor(bookTitle: bookTitle, initial: initial),
    ),
  );
}

class ReviewEditor extends StatefulWidget {
  final String bookTitle;
  final String? initial;

  const ReviewEditor({super.key, required this.bookTitle, this.initial});

  @override
  State<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<ReviewEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add review' : 'Edit review'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
