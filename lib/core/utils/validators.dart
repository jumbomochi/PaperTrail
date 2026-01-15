import 'package:paper_trail/core/exceptions/app_exceptions.dart';

/// Collection of input validators for the app
class Validators {
  Validators._();

  /// Maximum lengths for various text fields
  static const int maxTitleLength = 500;
  static const int maxAuthorLength = 300;
  static const int maxDescriptionLength = 5000;
  static const int maxPublisherLength = 200;
  static const int maxNameLength = 100;

  /// Validates and sanitizes a book title
  static String? validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Title is required';
    }
    if (title.length > maxTitleLength) {
      return 'Title must be less than $maxTitleLength characters';
    }
    return null;
  }

  /// Validates and sanitizes an author name
  static String? validateAuthor(String? author) {
    if (author == null || author.trim().isEmpty) {
      return 'Author is required';
    }
    if (author.length > maxAuthorLength) {
      return 'Author must be less than $maxAuthorLength characters';
    }
    return null;
  }

  /// Validates an optional description
  static String? validateDescription(String? description) {
    if (description != null && description.length > maxDescriptionLength) {
      return 'Description must be less than $maxDescriptionLength characters';
    }
    return null;
  }

  /// Validates an optional publisher name
  static String? validatePublisher(String? publisher) {
    if (publisher != null && publisher.length > maxPublisherLength) {
      return 'Publisher must be less than $maxPublisherLength characters';
    }
    return null;
  }

  /// Validates a family member or category name
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    if (name.length > maxNameLength) {
      return 'Name must be less than $maxNameLength characters';
    }
    return null;
  }

  /// Validates an ISBN-10 or ISBN-13
  /// Returns null if valid, error message if invalid
  static String? validateIsbn(String? isbn) {
    if (isbn == null || isbn.trim().isEmpty) {
      return null; // ISBN is optional
    }

    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();

    if (cleanIsbn.length == 10) {
      if (!_isValidIsbn10(cleanIsbn)) {
        return 'Invalid ISBN-10 checksum';
      }
    } else if (cleanIsbn.length == 13) {
      if (!_isValidIsbn13(cleanIsbn)) {
        return 'Invalid ISBN-13 checksum';
      }
    } else {
      return 'ISBN must be 10 or 13 digits';
    }

    return null;
  }

  /// Validates ISBN-10 checksum
  static bool _isValidIsbn10(String isbn) {
    if (isbn.length != 10) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (10 - i);
    }

    // Handle check digit (can be 'X' for 10)
    final checkChar = isbn[9];
    final checkDigit = checkChar == 'X' ? 10 : int.tryParse(checkChar);
    if (checkDigit == null) return false;

    sum += checkDigit;
    return sum % 11 == 0;
  }

  /// Validates ISBN-13 checksum
  static bool _isValidIsbn13(String isbn) {
    if (isbn.length != 13) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (i.isEven ? 1 : 3);
    }

    final checkDigit = int.tryParse(isbn[12]);
    if (checkDigit == null) return false;

    final calculatedCheck = (10 - (sum % 10)) % 10;
    return checkDigit == calculatedCheck;
  }

  /// Cleans and normalizes an ISBN
  static String cleanIsbn(String isbn) {
    return isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
  }

  /// Validates a URL
  static String? validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null; // URL is optional
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || !['http', 'https'].contains(uri.scheme)) {
        return 'URL must start with http:// or https://';
      }
      if (uri.host.isEmpty) {
        return 'Invalid URL';
      }
      return null;
    } catch (e) {
      return 'Invalid URL format';
    }
  }

  /// Validates a page count
  static String? validatePageCount(String? pageCount) {
    if (pageCount == null || pageCount.trim().isEmpty) {
      return null; // Optional field
    }

    final count = int.tryParse(pageCount);
    if (count == null) {
      return 'Page count must be a number';
    }
    if (count < 1) {
      return 'Page count must be at least 1';
    }
    if (count > 50000) {
      return 'Page count seems too high';
    }
    return null;
  }

  /// Sanitizes text input by trimming and removing control characters
  static String sanitizeText(String text) {
    // Remove control characters except newlines and tabs
    final sanitized = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    return sanitized.trim();
  }

  /// Validates and throws exception if invalid
  static void requireValidIsbn(String isbn) {
    final error = validateIsbn(isbn);
    if (error != null) {
      throw ValidationException.invalidIsbn();
    }
  }

  /// Validates that a string is not empty
  static void requireNonEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationException.required(fieldName);
    }
  }
}

/// Extension to add validation methods to String
extension StringValidation on String {
  bool get isValidIsbn10 => Validators._isValidIsbn10(
        replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase(),
      );

  bool get isValidIsbn13 => Validators._isValidIsbn13(
        replaceAll(RegExp(r'[^0-9]'), ''),
      );

  bool get isValidIsbn {
    final clean = replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
    return clean.length == 10
        ? Validators._isValidIsbn10(clean)
        : clean.length == 13
            ? Validators._isValidIsbn13(clean)
            : false;
  }

  String get sanitized => Validators.sanitizeText(this);

  String get cleanedIsbn => Validators.cleanIsbn(this);
}
