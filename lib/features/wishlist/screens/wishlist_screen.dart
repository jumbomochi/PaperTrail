import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/books/widgets/book_card.dart';
import 'package:paper_trail/features/books/screens/book_detail_screen.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

enum WishlistSortOption {
  dateAdded,
  title,
  author,
}

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  WishlistSortOption _selectedSort = WishlistSortOption.dateAdded;

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          PopupMenuButton<WishlistSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (WishlistSortOption option) {
              setState(() => _selectedSort = option);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: WishlistSortOption.dateAdded,
                child: Row(
                  children: [
                    if (_selectedSort == WishlistSortOption.dateAdded)
                      const Icon(Icons.check, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Date Added'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: WishlistSortOption.title,
                child: Row(
                  children: [
                    if (_selectedSort == WishlistSortOption.title)
                      const Icon(Icons.check, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Title (A-Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: WishlistSortOption.author,
                child: Row(
                  children: [
                    if (_selectedSort == WishlistSortOption.author)
                      const Icon(Icons.check, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Author (A-Z)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
          final sortedBooks = _sortBooks(books);
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
              itemCount: sortedBooks.length,
              itemBuilder: (context, index) {
                final book = sortedBooks[index];
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

  List<Book> _sortBooks(List<Book> books) {
    final sorted = List<Book>.from(books);
    switch (_selectedSort) {
      case WishlistSortOption.title:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case WishlistSortOption.author:
        sorted.sort(
            (a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
      case WishlistSortOption.dateAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  void _navigateToAddBook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBookScreen()),
    );
  }
}
