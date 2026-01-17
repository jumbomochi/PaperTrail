import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/books/widgets/book_card.dart';
import 'package:paper_trail/features/books/screens/book_detail_screen.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';
import 'package:paper_trail/features/family/models/family_member.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

class BookListScreen extends ConsumerStatefulWidget {
  const BookListScreen({super.key});

  @override
  ConsumerState<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends ConsumerState<BookListScreen> {
  String _searchQuery = '';
  String? _selectedOwnerId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookNotifierProvider);
    final familyAsync = ref.watch(familyNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search books...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          if (_selectedOwnerId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: familyAsync.when(
                data: (members) {
                  final member = members.firstWhere(
                    (m) => m.id == _selectedOwnerId,
                    orElse: () => FamilyMember(
                      id: '',
                      name: 'Unknown',
                      color: Colors.grey,
                      createdAt: DateTime.now(),
                    ),
                  );
                  return Chip(
                    label: Text('Filtered by: ${member.name}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() => _selectedOwnerId = null);
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                final filteredBooks = _filterBooks(books);
                if (filteredBooks.isEmpty) {
                  return EmptyState(
                    icon: Icons.library_books,
                    title: books.isEmpty ? 'No books yet' : 'No matching books',
                    subtitle: books.isEmpty
                        ? 'Start by adding your first book'
                        : 'Try a different search or filter',
                    buttonText: books.isEmpty ? 'Add Book' : null,
                    onButtonPressed: books.isEmpty
                        ? () => _navigateToAddBook(context)
                        : null,
                  );
                }
                return familyAsync.when(
                  data: (members) {
                    return _buildBookGrid(filteredBooks, members);
                  },
                  loading: () => _buildBookGrid(filteredBooks, []),
                  error: (_, __) => _buildBookGrid(filteredBooks, []),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'book_list_fab',
        onPressed: () => _navigateToAddBook(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Book> _filterBooks(List<Book> books) {
    var filtered = books.where((b) => !b.isWishlist).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((book) {
        return book.title.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            (book.isbn?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedOwnerId != null) {
      filtered = filtered.where((b) => b.ownerId == _selectedOwnerId).toList();
    }

    return filtered;
  }

  Widget _buildBookGrid(List<Book> books, List<FamilyMember> members) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(bookNotifierProvider.notifier).loadBooks();
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
          final owner = members.where((m) => m.id == book.ownerId).firstOrNull;
          return BookCard(
            book: book,
            ownerName: owner?.name,
            ownerColor: owner?.color,
            onTap: () => _navigateToBookDetail(context, book),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final familyAsync = ref.read(familyNotifierProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return familyAsync.when(
          data: (members) {
            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No family members added yet.\nAdd family members to filter books by owner.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Filter by Owner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('All Books'),
                  selected: _selectedOwnerId == null,
                  onTap: () {
                    setState(() => _selectedOwnerId = null);
                    Navigator.pop(context);
                  },
                ),
                ...members.map((member) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: member.color,
                      radius: 16,
                    ),
                    title: Text(member.name),
                    selected: _selectedOwnerId == member.id,
                    onTap: () {
                      setState(() => _selectedOwnerId = member.id);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading family')),
        );
      },
    );
  }

  void _navigateToAddBook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBookScreen()),
    );
  }

  void _navigateToBookDetail(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    );
  }
}
