import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/books/widgets/book_card.dart';
import 'package:paper_trail/features/books/screens/book_detail_screen.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/features/categories/models/category.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';
import 'package:paper_trail/features/family/models/family_member.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

enum SortOption {
  dateAdded,
  title,
  author,
}

class BookListScreen extends ConsumerStatefulWidget {
  const BookListScreen({super.key});

  @override
  ConsumerState<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends ConsumerState<BookListScreen> {
  String _searchQuery = '';
  String? _selectedOwnerId;
  String? _selectedCategoryId;
  SortOption _selectedSort = SortOption.dateAdded;
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
    final categoryAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (SortOption option) {
              setState(() => _selectedSort = option);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortOption.dateAdded,
                child: Row(
                  children: [
                    if (_selectedSort == SortOption.dateAdded)
                      const Icon(Icons.check, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Date Added'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.title,
                child: Row(
                  children: [
                    if (_selectedSort == SortOption.title)
                      const Icon(Icons.check, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Title (A-Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.author,
                child: Row(
                  children: [
                    if (_selectedSort == SortOption.author)
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
          if (_selectedOwnerId != null || _selectedCategoryId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedOwnerId != null)
                    familyAsync.when(
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
                          label: Text('Owner: ${member.name}'),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedOwnerId = null);
                          },
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  if (_selectedCategoryId != null)
                    categoryAsync.when(
                      data: (categories) {
                        final category = categories.firstWhere(
                          (c) => c.id == _selectedCategoryId,
                          orElse: () => Category(
                            id: '',
                            name: 'Unknown',
                            icon: '',
                            createdAt: DateTime.now(),
                          ),
                        );
                        return Chip(
                          label: Text('${category.icon} ${category.name}'),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedCategoryId = null);
                          },
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                ],
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

    if (_selectedCategoryId != null) {
      filtered =
          filtered.where((b) => b.categoryId == _selectedCategoryId).toList();
    }

    // Apply sorting
    switch (_selectedSort) {
      case SortOption.title:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortOption.author:
        filtered.sort((a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
      case SortOption.dateAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    final categoryAsync = ref.read(categoryNotifierProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              children: [
                // Clear all filters
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedOwnerId != null ||
                          _selectedCategoryId != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedOwnerId = null;
                              _selectedCategoryId = null;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Category filter section
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                categoryAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No categories added yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: const Text('All Categories'),
                          selected: _selectedCategoryId == null,
                          onTap: () {
                            setState(() => _selectedCategoryId = null);
                            Navigator.pop(context);
                          },
                        ),
                        ...categories.map((category) {
                          return ListTile(
                            leading: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(category.name),
                            selected: _selectedCategoryId == category.id,
                            onTap: () {
                              setState(() => _selectedCategoryId = category.id);
                              Navigator.pop(context);
                            },
                          );
                        }),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Text('Error loading categories'),
                ),
                const Divider(height: 1),

                // Owner filter section
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Owner',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                familyAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No family members added yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.people_outline),
                          title: const Text('All Owners'),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error loading family'),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
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
