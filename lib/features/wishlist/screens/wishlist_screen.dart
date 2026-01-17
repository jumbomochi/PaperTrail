import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/books/widgets/book_card.dart';
import 'package:paper_trail/features/books/screens/book_detail_screen.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistBooksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlistAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_border,
              title: 'Your wishlist is empty',
              subtitle: 'Add books you want to buy to your wishlist',
              buttonText: 'Add to Wishlist',
              onButtonPressed: () => _navigateToAddBook(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(wishlistBooksProvider);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(bookId: book.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'wishlist_fab',
        onPressed: () => _navigateToAddBook(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddBook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBookScreen()),
    );
  }
}
