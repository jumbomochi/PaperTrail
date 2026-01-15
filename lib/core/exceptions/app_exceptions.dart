/// Base exception for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException: $message${code != null ? ' ($code)' : ''}';
}

/// Exception for network-related errors
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
    this.statusCode,
  });

  factory NetworkException.noConnection() => const NetworkException(
        'No internet connection. Please check your network settings.',
        code: 'NO_CONNECTION',
      );

  factory NetworkException.timeout() => const NetworkException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );

  factory NetworkException.serverError(int statusCode) => NetworkException(
        'Server error occurred. Please try again later.',
        code: 'SERVER_ERROR',
        statusCode: statusCode,
      );

  factory NetworkException.fromStatusCode(int statusCode) {
    if (statusCode >= 500) {
      return NetworkException.serverError(statusCode);
    }
    if (statusCode == 404) {
      return const NetworkException(
        'Resource not found.',
        code: 'NOT_FOUND',
        statusCode: 404,
      );
    }
    if (statusCode == 429) {
      return const NetworkException(
        'Too many requests. Please try again later.',
        code: 'RATE_LIMITED',
        statusCode: 429,
      );
    }
    return NetworkException(
      'Request failed with status $statusCode.',
      code: 'HTTP_ERROR',
      statusCode: statusCode,
    );
  }

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Exception for database operations
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code,
    super.originalError,
  });

  factory DatabaseException.insertFailed(String entity) => DatabaseException(
        'Failed to save $entity. Please try again.',
        code: 'INSERT_FAILED',
      );

  factory DatabaseException.updateFailed(String entity) => DatabaseException(
        'Failed to update $entity. Please try again.',
        code: 'UPDATE_FAILED',
      );

  factory DatabaseException.deleteFailed(String entity) => DatabaseException(
        'Failed to delete $entity. Please try again.',
        code: 'DELETE_FAILED',
      );

  factory DatabaseException.queryFailed() => const DatabaseException(
        'Failed to load data. Please try again.',
        code: 'QUERY_FAILED',
      );

  factory DatabaseException.notFound(String entity) => DatabaseException(
        '$entity not found.',
        code: 'NOT_FOUND',
      );

  @override
  String toString() => 'DatabaseException: $message';
}

/// Exception for validation errors
class ValidationException extends AppException {
  final String field;

  const ValidationException(
    super.message, {
    required this.field,
    super.code,
  });

  factory ValidationException.required(String field) => ValidationException(
        '$field is required.',
        field: field,
        code: 'REQUIRED',
      );

  factory ValidationException.invalidFormat(String field, String format) =>
      ValidationException(
        '$field has an invalid format. Expected: $format',
        field: field,
        code: 'INVALID_FORMAT',
      );

  factory ValidationException.tooLong(String field, int maxLength) =>
      ValidationException(
        '$field is too long. Maximum length is $maxLength characters.',
        field: field,
        code: 'TOO_LONG',
      );

  factory ValidationException.invalidIsbn() => const ValidationException(
        'Invalid ISBN format.',
        field: 'isbn',
        code: 'INVALID_ISBN',
      );

  @override
  String toString() => 'ValidationException [$field]: $message';
}

/// Exception for image operations
class ImageException extends AppException {
  const ImageException(
    super.message, {
    super.code,
    super.originalError,
  });

  factory ImageException.captureFailed() => const ImageException(
        'Failed to capture image. Please try again.',
        code: 'CAPTURE_FAILED',
      );

  factory ImageException.pickFailed() => const ImageException(
        'Failed to select image. Please try again.',
        code: 'PICK_FAILED',
      );

  factory ImageException.saveFailed() => const ImageException(
        'Failed to save image. Please check storage permissions.',
        code: 'SAVE_FAILED',
      );

  factory ImageException.deleteFailed() => const ImageException(
        'Failed to delete image.',
        code: 'DELETE_FAILED',
      );

  factory ImageException.invalidFile() => const ImageException(
        'Invalid image file.',
        code: 'INVALID_FILE',
      );

  @override
  String toString() => 'ImageException: $message';
}

/// Exception for book lookup operations
class BookLookupException extends AppException {
  const BookLookupException(
    super.message, {
    super.code,
    super.originalError,
  });

  factory BookLookupException.notFound(String isbn) => BookLookupException(
        'No book found with ISBN: $isbn',
        code: 'NOT_FOUND',
      );

  factory BookLookupException.invalidResponse() => const BookLookupException(
        'Invalid response from book service.',
        code: 'INVALID_RESPONSE',
      );

  @override
  String toString() => 'BookLookupException: $message';
}
