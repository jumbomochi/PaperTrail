import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/models/quote.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/books/providers/quote_providers.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/features/books/widgets/quote_editor.dart';
import 'package:paper_trail/features/books/widgets/quotes_list.dart';
import 'package:paper_trail/features/books/widgets/review_editor.dart';
import 'package:paper_trail/features/books/widgets/review_section.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final familyAsync = ref.watch(familyNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final quotesAsync = ref.watch(quotesForBookProvider(bookId));

    return bookAsync.when(
      data: (book) {
        if (book == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Book Not Found')),
            body: const Center(child: Text('This book no longer exists.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Book Details'),
            actions: [
              IconButton(
                icon: Icon(
                  book.isWishlist ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () {
                  ref.read(bookNotifierProvider.notifier).toggleWishlist(book);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddBookScreen(editBook: book),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteDialog(context, ref),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: _buildCoverImage(
                    book.coverImagePath,
                    book.thumbnailUrl,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Author
                      Text(
                        'by ${book.author}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      // Tags row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (book.isbn != null)
                            Chip(
                              avatar: const Icon(Icons.qr_code, size: 18),
                              label: Text(book.isbn!),
                            ),
                          if (book.pageCount != null)
                            Chip(
                              avatar: const Icon(Icons.menu_book, size: 18),
                              label: Text('${book.pageCount} pages'),
                            ),
                          if (book.isWishlist)
                            const Chip(
                              avatar: Icon(Icons.bookmark, size: 18),
                              label: Text('Wishlist'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Owner section
                      if (book.ownerId != null)
                        familyAsync.when(
                          data: (members) {
                            final owner = members
                                .where((m) => m.id == book.ownerId)
                                .firstOrNull;
                            if (owner == null) return const SizedBox.shrink();
                            return _buildInfoSection(
                              context,
                              'Owner',
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: owner.color,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(owner.name),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      // Category section
                      if (book.categoryId != null)
                        categoriesAsync.when(
                          data: (categories) {
                            final category = categories
                                .where((c) => c.id == book.categoryId)
                                .firstOrNull;
                            if (category == null)
                              return const SizedBox.shrink();
                            return _buildInfoSection(
                              context,
                              'Category',
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/icons/categories/${category.icon}.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(category.name),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      // Publisher
                      if (book.publisher != null)
                        _buildInfoSection(
                          context,
                          'Publisher',
                          Text(book.publisher!),
                        ),
                      // Published date
                      if (book.publishedDate != null)
                        _buildInfoSection(
                          context,
                          'Published',
                          Text(book.publishedDate!),
                        ),
                      // Description
                      if (book.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                ReviewSection(
                  review: book.review,
                  onEditPressed: () async {
                    final newText = await openReviewEditor(
                      context,
                      bookTitle: book.title,
                      initial: book.review,
                    );
                    if (newText == null) return;
                    final now = DateTime.now();
                    final next = book.copyWith(
                      review: newText.isEmpty ? null : newText,
                      reviewUpdatedAt: now,
                      updatedAt: now,
                    );
                    await ref.read(bookNotifierProvider.notifier).updateBook(next);
                  },
                ),
                quotesAsync.when(
                  data: (quotes) => QuotesList(
                    quotes: quotes,
                    onAddPressed: () async {
                      final result = await openQuoteEditor(
                        context,
                        bookTitle: book.title,
                      );
                      if (result == null || result.isDelete) return;
                      final quote = Quote(
                        id: const Uuid().v4(),
                        bookId: book.id,
                        text: result.text!,
                        page: result.page,
                        createdAt: DateTime.now(),
                      );
                      await ref.read(quoteNotifierProvider.notifier).addQuote(quote);
                    },
                    onQuoteTapped: (q) async {
                      final result = await openQuoteEditor(
                        context,
                        bookTitle: book.title,
                        initialText: q.text,
                        initialPage: q.page,
                      );
                      if (result == null) return;
                      if (result.isDelete) {
                        await ref.read(quoteNotifierProvider.notifier).deleteQuote(
                              id: q.id,
                              bookId: q.bookId,
                            );
                      } else {
                        await ref.read(quoteNotifierProvider.notifier).updateQuote(
                              q.copyWith(text: result.text!, page: result.page),
                            );
                      }
                    },
                    onQuoteLongPressed: (q) => _showQuoteActions(context, ref, book, q),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load quotes: $e'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildCoverImage(String? localPath, String? thumbnailUrl) {
    if (localPath != null) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(Icons.menu_book, size: 80, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text(
          'Are you sure you want to delete this book? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(bookNotifierProvider.notifier).deleteBook(bookId);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to list
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

Future<void> _showQuoteActions(
  BuildContext context,
  WidgetRef ref,
  Book book,
  Quote quote,
) async {
  // Capture box before async gap for sharePositionOrigin on iPad.
  final box = context.findRenderObject() as RenderBox?;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () => Navigator.of(ctx).pop('copy'),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () => Navigator.of(ctx).pop('share'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete'),
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;
  final shareText = quote.page != null
      ? '"${quote.text}" — ${book.title}, p.${quote.page}'
      : '"${quote.text}" — ${book.title}';
  switch (action) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: shareText));
      break;
    case 'share':
      await Share.share(
        shareText,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
      break;
    case 'delete':
      await ref.read(quoteNotifierProvider.notifier).deleteQuote(
            id: quote.id,
            bookId: quote.bookId,
          );
      break;
  }
}
