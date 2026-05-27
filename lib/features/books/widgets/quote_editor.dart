import 'package:flutter/material.dart';

class QuoteEditorResult {
  final bool isDelete;
  final String? text;
  final int? page;

  const QuoteEditorResult.save({required this.text, required this.page})
      : isDelete = false;
  const QuoteEditorResult.delete()
      : isDelete = true,
        text = null,
        page = null;
}

Future<QuoteEditorResult?> openQuoteEditor(
  BuildContext context, {
  required String bookTitle,
  String? initialText,
  int? initialPage,
}) {
  return Navigator.of(context).push<QuoteEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuoteEditor(
        bookTitle: bookTitle,
        initialText: initialText,
        initialPage: initialPage,
      ),
    ),
  );
}

class QuoteEditor extends StatefulWidget {
  final String bookTitle;
  final String? initialText;
  final int? initialPage;

  const QuoteEditor({
    super.key,
    required this.bookTitle,
    this.initialText,
    this.initialPage,
  });

  @override
  State<QuoteEditor> createState() => _QuoteEditorState();
}

class _QuoteEditorState extends State<QuoteEditor> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.initialText ?? '');
  late final TextEditingController _pageController = TextEditingController(
    text: widget.initialPage?.toString() ?? '',
  );

  bool get _isEditing => widget.initialText != null;

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final pageStr = _pageController.text.trim();
    final page = pageStr.isEmpty ? null : int.tryParse(pageStr);
    Navigator.of(context).pop(
      QuoteEditorResult.save(text: text, page: page),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quote?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      Navigator.of(context).pop(const QuoteEditorResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit quote' : 'Add quote'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
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
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Quote',
                hintText: 'Type or paste the quote here…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Page (optional)',
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
