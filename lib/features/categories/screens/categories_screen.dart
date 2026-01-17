import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paper_trail/features/categories/models/category.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/shared/widgets/empty_state.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const List<String> _availableIcons = [
    '📚',
    '📖',
    '📕',
    '📗',
    '📘',
    '📙',
    '🎭',
    '🔬',
    '🎨',
    '💼',
    '🎵',
    '🏠',
    '🌍',
    '💡',
    '🔧',
    '🎮',
    '📱',
    '💻',
    '🍳',
    '✈️',
    '🏃',
    '💰',
    '❤️',
    '🧠',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.category,
              title: 'No categories yet',
              subtitle: 'Create categories to organize your books',
              buttonText: 'Add Category',
              onButtonPressed: () => _showAddCategoryDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(
                category: category,
                onEdit: () => _showEditCategoryDialog(context, ref, category),
                onDelete: () => _showDeleteDialog(context, ref, category),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories_fab',
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    _showCategoryDialog(
      context: context,
      title: 'Add Category',
      onSave: (name, icon) {
        final category = Category(
          id: const Uuid().v4(),
          name: name,
          icon: icon,
          createdAt: DateTime.now(),
        );
        ref.read(categoryNotifierProvider.notifier).addCategory(category);
      },
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    _showCategoryDialog(
      context: context,
      title: 'Edit Category',
      initialName: category.name,
      initialIcon: category.icon,
      onSave: (name, icon) {
        final updatedCategory = category.copyWith(name: name, icon: icon);
        ref
            .read(categoryNotifierProvider.notifier)
            .updateCategory(updatedCategory);
      },
    );
  }

  void _showCategoryDialog({
    required BuildContext context,
    required String title,
    String? initialName,
    String? initialIcon,
    required void Function(String name, String icon) onSave,
  }) {
    final nameController = TextEditingController(text: initialName);
    String selectedIcon = initialIcon ?? _availableIcons.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g., Fiction, Science, History',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Icon'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      onSave(name, selectedIcon);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? Books in this category will be uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(categoryNotifierProvider.notifier)
                  .deleteCategory(category.id);
              ref.invalidate(booksProvider);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(category.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
