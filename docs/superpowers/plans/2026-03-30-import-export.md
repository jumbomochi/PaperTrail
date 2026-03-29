# Import/Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON-based data export/import with a Settings page, and reorder the Add Book form to emphasize ISBN entry.

**Architecture:** A `BackupService` handles serialization/deserialization of all three tables (books, categories, family_members) to/from JSON. A new Settings screen hosts export/import buttons. Export uses `share_plus` to invoke the iOS share sheet; import uses `file_picker` to select a `.json` file, validates it, shows a confirmation dialog, then upserts into the DB.

**Tech Stack:** Flutter, sqflite, share_plus, file_picker, flutter_riverpod

---

## File Structure

| File | Responsibility |
|---|---|
| **Create:** `lib/core/services/backup_service.dart` | Export DB to JSON string, parse/validate JSON for import, upsert records into DB |
| **Create:** `lib/features/settings/screens/settings_screen.dart` | Settings UI with export/import buttons, confirmation dialogs, progress/error feedback |
| **Modify:** `lib/features/home/screens/home_screen.dart` | Add gear icon to app bar linking to Settings |
| **Modify:** `lib/features/books/screens/add_book_screen.dart` | Reorder form to lead with ISBN field and scan button |
| **Modify:** `pubspec.yaml` | Add `share_plus` and `file_picker` dependencies |

---

### Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add share_plus and file_picker to pubspec.yaml**

Add under the `# Utilities` section in `pubspec.yaml`:

```yaml
  # Backup
  share_plus: ^10.0.0
  file_picker: ^8.0.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully, no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add share_plus and file_picker dependencies for import/export"
```

---

### Task 2: Create BackupService — export

**Files:**
- Create: `lib/core/services/backup_service.dart`

- [ ] **Step 1: Create backup_service.dart with export method**

```dart
import 'dart:convert';
import 'package:paper_trail/core/database/database_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final db = await _dbHelper.database;

    final books = await db.query('books');
    final categories = await db.query('categories');
    final familyMembers = await db.query('family_members');

    // Exclude cover_image_path from books (local paths are not portable)
    final exportBooks = books.map((book) {
      final map = Map<String, dynamic>.from(book);
      map.remove('cover_image_path');
      return map;
    }).toList();

    final backup = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'books': exportBooks,
      'categories': categories,
      'family_members': familyMembers,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/core/services/backup_service.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/backup_service.dart
git commit -m "feat: add BackupService with JSON export"
```

---

### Task 3: Add import to BackupService

**Files:**
- Modify: `lib/core/services/backup_service.dart`

- [ ] **Step 1: Add validation and import methods**

Add these methods to the `BackupService` class:

```dart
  /// Parses and validates a backup JSON string.
  /// Returns the parsed map or throws a FormatException.
  Map<String, dynamic> parseAndValidate(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('Invalid JSON format');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format');
    }

    if (decoded['version'] == null) {
      throw const FormatException('Missing version field');
    }
    if (decoded['books'] is! List) {
      throw const FormatException('Missing or invalid books data');
    }
    if (decoded['categories'] is! List) {
      throw const FormatException('Missing or invalid categories data');
    }
    if (decoded['family_members'] is! List) {
      throw const FormatException('Missing or invalid family members data');
    }

    return decoded;
  }

  /// Returns counts of items in the backup for confirmation display.
  ({int books, int categories, int familyMembers}) getCounts(
    Map<String, dynamic> backup,
  ) {
    return (
      books: (backup['books'] as List).length,
      categories: (backup['categories'] as List).length,
      familyMembers: (backup['family_members'] as List).length,
    );
  }

  /// Imports validated backup data into the database via upsert.
  Future<void> importFromBackup(Map<String, dynamic> backup) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Import family members first (books reference them)
      for (final member in backup['family_members'] as List) {
        final map = Map<String, dynamic>.from(member as Map);
        await txn.insert(
          'family_members',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Import categories (books reference them)
      for (final category in backup['categories'] as List) {
        final map = Map<String, dynamic>.from(category as Map);
        await txn.insert(
          'categories',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Import books last
      for (final book in backup['books'] as List) {
        final map = Map<String, dynamic>.from(book as Map);
        // Ensure cover_image_path is null (not included in export)
        map['cover_image_path'] = null;
        await txn.insert(
          'books',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
```

Also add the sqflite import at the top of the file:

```dart
import 'package:sqflite/sqflite.dart';
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/core/services/backup_service.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/backup_service.dart
git commit -m "feat: add import with validation and upsert to BackupService"
```

---

### Task 4: Create Settings screen

**Files:**
- Create: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Create settings_screen.dart**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:paper_trail/core/services/backup_service.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _backupService = BackupService();
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Export Library'),
                  subtitle: const Text('Save your collection as a JSON file'),
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExporting ? null : _exportLibrary,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Library'),
                  subtitle: const Text('Restore from a backup file'),
                  trailing: _isImporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isImporting ? null : _importLibrary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'PaperTrail v1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLibrary() async {
    setState(() => _isExporting = true);

    try {
      final json = await _backupService.exportToJson();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'papertrail_backup_$date.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importLibrary() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      final backup = _backupService.parseAndValidate(jsonString);
      final counts = _backupService.getCounts(backup);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Library'),
          content: Text(
            'This will import:\n\n'
            '${counts.books} books\n'
            '${counts.categories} categories\n'
            '${counts.familyMembers} family members\n\n'
            'Existing items with matching IDs will be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isImporting = true);

      await _backupService.importFromBackup(backup);

      // Refresh all providers
      ref.invalidate(bookNotifierProvider);
      ref.invalidate(booksProvider);
      ref.invalidate(bookCountProvider);
      ref.invalidate(wishlistCountProvider);
      ref.invalidate(wishlistBooksProvider);
      ref.invalidate(categoryNotifierProvider);
      ref.invalidate(categoryCountProvider);
      ref.invalidate(familyNotifierProvider);
      ref.invalidate(familyMemberCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${counts.books} books, '
              '${counts.categories} categories, '
              '${counts.familyMembers} family members',
            ),
          ),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup file: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/features/settings/screens/settings_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/screens/settings_screen.dart
git commit -m "feat: add Settings screen with export/import UI"
```

---

### Task 5: Add gear icon to Home screen

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add import for SettingsScreen**

Add to the imports at the top of `home_screen.dart`:

```dart
import 'package:paper_trail/features/settings/screens/settings_screen.dart';
```

- [ ] **Step 2: Add gear icon to app bar actions**

In the `appBar: AppBar(...)` section, add a gear icon after the existing theme toggle button. Find this block:

```dart
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
        ],
```

Replace with:

```dart
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/features/home/screens/home_screen.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/screens/home_screen.dart
git commit -m "feat: add settings gear icon to home screen app bar"
```

---

### Task 6: Reorder Add Book form to emphasize ISBN

**Files:**
- Modify: `lib/features/books/screens/add_book_screen.dart`

- [ ] **Step 1: Move ISBN field above cover image section**

In `add_book_screen.dart`, find the form body inside the `ListView` children (starting around line 104). Currently the order is:

1. Cover image section
2. "Add Photo" button
3. Title field
4. Author field
5. ISBN field
6. ...rest

Restructure the `children` list of the `ListView` to this order:

```dart
                children: [
                  // ISBN section — primary entry method
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter an ISBN or scan a barcode for best results',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _isbnController,
                            decoration: InputDecoration(
                              labelText: 'ISBN',
                              prefixIcon: const Icon(Icons.qr_code),
                              helperText: 'Enter ISBN-10 or ISBN-13',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _lookupByIsbn,
                                tooltip: 'Lookup ISBN',
                              ),
                            ),
                            validator: Validators.validateIsbn,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _scanBarcode,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan Barcode'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cover image section
                  Center(
```

Then remove the old standalone ISBN `TextFormField` and the `SizedBox(height: 16)` before it (the one that was between Author and ISBN fields around line 154-168).

Also remove the barcode scanner icon from the app bar `actions` since the scan button is now in the form body:

```dart
        actions: [
          // Remove the entire if (!_isEditing) IconButton block for qr_code_scanner
        ],
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/features/books/screens/add_book_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/screens/add_book_screen.dart
git commit -m "feat: reorder Add Book form to emphasize ISBN entry"
```

---

### Task 7: Integration test on simulator

- [ ] **Step 1: Run flutter analyze on entire project**

Run: `flutter analyze`
Expected: No errors (only pre-existing info-level warnings).

- [ ] **Step 2: Build and launch on simulator**

Run: `flutter run -d 77DED4FE-AC6F-49AD-B279-F3F227110403`

Verify:
- Home screen shows gear icon in app bar
- Tapping gear opens Settings screen
- Export creates a JSON file and opens share sheet
- Add Book screen shows ISBN section at top with scan button
- Import flow: pick a previously exported file, see confirmation dialog, import succeeds, data appears

- [ ] **Step 3: Commit any fixes**

If any issues found, fix and commit.
