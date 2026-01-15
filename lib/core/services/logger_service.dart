import 'dart:developer' as developer;

/// Log levels for categorizing log messages
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Simple logging service for the app
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  static LoggerService get instance => _instance;

  LoggerService._internal();

  /// Minimum log level to output (can be changed for release builds)
  LogLevel minLevel = LogLevel.debug;

  /// Whether logging is enabled
  bool enabled = true;

  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  void warning(String message,
      {String? tag, Map<String, dynamic>? data, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, data: data, error: error);
  }

  void error(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled || level.index < minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';

    final buffer = StringBuffer();
    buffer.writeln('$timestamp $levelStr $tagStr$message');

    if (data != null && data.isNotEmpty) {
      buffer.writeln('  Data: $data');
    }

    if (error != null) {
      buffer.writeln('  Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('  Stack trace:');
      buffer.writeln(stackTrace.toString());
    }

    final output = buffer.toString().trimRight();

    // Use dart:developer log for better DevTools integration
    developer.log(
      output,
      name: 'PaperTrail',
      level: _logLevelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _logLevelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

/// Global logger instance for convenience
final logger = LoggerService.instance;
