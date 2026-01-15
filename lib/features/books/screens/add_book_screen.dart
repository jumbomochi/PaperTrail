import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paper_trail/features/books/models/book.dart';
import 'package:paper_trail/features/books/providers/book_providers.dart';
import 'package:paper_trail/features/family/providers/family_providers.dart';
import 'package:paper_trail/features/categories/providers/category_providers.dart';
import 'package:paper_trail/core/services/image_service.dart';
import 'package:paper_trail/core/services/book_api_service.dart';
import 'package:paper_trail/core/utils/validators.dart';
import 'package:paper_trail/features/scanner/screens/scanner_screen.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  final Book? editBook;

  const AddBookScreen({super.key, this.editBook});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publishedDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageCountController = TextEditingController();

  final _imageService = ImageService();
  final _bookApiService = BookApiService();

  String? _coverImagePath;
  String? _thumbnailUrl;
  String? _selectedOwnerId;
  String? _selectedCategoryId;
  bool _isWishlist = false;
  bool _isLoading = false;

  bool get _isEditing => widget.editBook != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final book = widget.editBook!;
      _titleController.text = book.title;
      _authorController.text = book.author;
      _isbnController.text = book.isbn ?? '';
      _publisherController.text = book.publisher ?? '';
      _publishedDateController.text = book.publishedDate ?? '';
      _descriptionController.text = book.description ?? '';
      _pageCountController.text = book.pageCount?.toString() ?? '';
      _coverImagePath = book.coverImagePath;
      _thumbnailUrl = book.thumbnailUrl;
      _selectedOwnerId = book.ownerId;
      _selectedCategoryId = book.categoryId;
      _isWishlist = book.isWishlist;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _publishedDateController.dispose();
    _descriptionController.dispose();
    _pageCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(familyNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Book' : 'Add Book'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scanBarcode,
              tooltip: 'Scan Barcode',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cover image section
                  Center(
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        width: 150,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _buildCoverPreview(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _coverImagePath != null || _thumbnailUrl != null
                            ? 'Change Photo'
                            : 'Add Photo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Form fields
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      prefixIcon: Icon(Icons.book),
                    ),
                    maxLength: Validators.maxTitleLength,
                    validator: Validators.validateTitle,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    maxLength: Validators.maxAuthorLength,
                    validator: Validators.validateAuthor,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Publisher',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _publishedDateController,
                    decoration: const InputDecoration(
                      labelText: 'Published Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pageCountController,
                    decoration: const InputDecoration(
                      labelText: 'Page Count',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Owner dropdown
                  familyAsync.when(
                    data: (members) {
                      if (members.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String>(
                        value: _selectedOwnerId,
                        decoration: const InputDecoration(
                          labelText: 'Owner',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No owner'),
                          ),
                          ...members.map((member) {
                            return DropdownMenuItem(
                              value: member.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: member.color,
                                    radius: 10,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(member.name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedOwnerId = value);
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  // Category dropdown
                  categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No category'),
                          ),
                          ...categories.map((category) {
                            return DropdownMenuItem(
                              value: category.id,
                              child: Row(
                                children: [
                                  Text(category.icon),
                                  const SizedBox(width: 8),
                                  Text(category.name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: Validators.maxDescriptionLength,
                    validator: Validators.validateDescription,
                  ),
                  const SizedBox(height: 16),
                  // Wishlist toggle
                  SwitchListTile(
                    title: const Text('Add to Wishlist'),
                    subtitle: const Text('Mark as a book you want to buy'),
                    value: _isWishlist,
                    onChanged: (value) {
                      setState(() => _isWishlist = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  // Save button
                  ElevatedButton(
                    onPressed: _saveBook,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _isEditing ? 'Save Changes' : 'Add Book',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverPreview() {
    if (_coverImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(_coverImagePath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      );
    } else if (_thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text('Add Cover', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final path = await _imageService.captureImage();
                  if (path != null) {
                    setState(() {
                      _coverImagePath = path;
                      _thumbnailUrl = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final path = await _imageService.pickImageFromGallery();
                  if (path != null) {
                    setState(() {
                      _coverImagePath = path;
                      _thumbnailUrl = null;
                    });
                  }
                },
              ),
              if (_coverImagePath != null || _thumbnailUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _coverImagePath = null;
                      _thumbnailUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (result != null && mounted) {
      setState(() => _isbnController.text = result);
      await _lookupByIsbn();
    }
  }

  Future<void> _lookupByIsbn() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ISBN')),
      );
      return;
    }

    // Validate ISBN format first
    final validationError = Validators.validateIsbn(isbn);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _bookApiService.lookupByIsbnWithResult(isbn);

      if (!mounted) return;

      if (result.isSuccess) {
        final bookInfo = result.book!;
        setState(() {
          _titleController.text = bookInfo.title;
          _authorController.text = bookInfo.author;
          if (bookInfo.publisher != null) {
            _publisherController.text = bookInfo.publisher!;
          }
          if (bookInfo.publishedDate != null) {
            _publishedDateController.text = bookInfo.publishedDate!;
          }
          if (bookInfo.description != null) {
            _descriptionController.text = bookInfo.description!;
          }
          if (bookInfo.pageCount != null) {
            _pageCountController.text = bookInfo.pageCount.toString();
          }
          if (bookInfo.thumbnailUrl != null) {
            _thumbnailUrl = bookInfo.thumbnailUrl;
            _coverImagePath = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found: ${bookInfo.title}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.isNotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book not found. Please enter details manually.'),
          ),
        );
      } else if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final book = Book(
      id: _isEditing ? widget.editBook!.id : const Uuid().v4(),
      isbn: _isbnController.text.isEmpty ? null : _isbnController.text.trim(),
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      publisher: _publisherController.text.isEmpty
          ? null
          : _publisherController.text.trim(),
      publishedDate: _publishedDateController.text.isEmpty
          ? null
          : _publishedDateController.text.trim(),
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text.trim(),
      coverImagePath: _coverImagePath,
      thumbnailUrl: _thumbnailUrl,
      pageCount: _pageCountController.text.isEmpty
          ? null
          : int.tryParse(_pageCountController.text),
      ownerId: _selectedOwnerId,
      categoryId: _selectedCategoryId,
      isWishlist: _isWishlist,
      createdAt: _isEditing ? widget.editBook!.createdAt : now,
      updatedAt: now,
    );

    if (_isEditing) {
      await ref.read(bookNotifierProvider.notifier).updateBook(book);
    } else {
      await ref.read(bookNotifierProvider.notifier).addBook(book);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
