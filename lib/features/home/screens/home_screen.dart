import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/features/books/screens/add_book_screen.dart';
import 'package:paper_trail/features/scanner/screens/scanner_screen.dart';
import 'package:paper_trail/core/theme/app_theme.dart';
import 'package:paper_trail/core/providers/theme_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookCountAsync = ref.watch(bookCountProvider);
    final wishlistCountAsync = ref.watch(wishlistCountProvider);
    final familyCountAsync = ref.watch(familyMemberCountProvider);
    final categoryCountAsync = ref.watch(categoryCountProvider);

    final currentTheme = ref.watch(themeProvider);
    final isDark = currentTheme == AppThemeMode.dark ||
        (currentTheme == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PaperTrail'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Text(
              'Your Library',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track and organize your book collection',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan Book',
                    onTap: () => _scanAndAddBook(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.edit,
                    label: 'Add Manually',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddBookScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Stats section
            Text(
              'Collection Stats',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  icon: Icons.menu_book,
                  label: 'Books',
                  value: bookCountAsync.when(
                    data: (count) => count.toString(),
                    loading: () => '-',
                    error: (_, __) => '0',
                  ),
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatCard(
                  icon: Icons.bookmark,
                  label: 'Wishlist',
                  value: wishlistCountAsync.when(
                    data: (count) => count.toString(),
                    loading: () => '-',
                    error: (_, __) => '0',
                  ),
                  color: Colors.orange,
                ),
                _StatCard(
                  icon: Icons.people,
                  label: 'Family',
                  value: familyCountAsync.when(
                    data: (count) => count.toString(),
                    loading: () => '-',
                    error: (_, __) => '0',
                  ),
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.category,
                  label: 'Categories',
                  value: categoryCountAsync.when(
                    data: (count) => count.toString(),
                    loading: () => '-',
                    error: (_, __) => '0',
                  ),
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Tips section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Tips',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _TipItem(
                      icon: Icons.qr_code,
                      text: 'Scan book barcodes to auto-fill details',
                    ),
                    _TipItem(
                      icon: Icons.people,
                      text: 'Add family members to track ownership',
                    ),
                    _TipItem(
                      icon: Icons.category,
                      text: 'Create categories to organize your shelves',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndAddBook(BuildContext context) async {
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (isbn != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddBookScreen()),
      ).then((_) {
        // The AddBookScreen will handle the ISBN lookup
      });
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}
