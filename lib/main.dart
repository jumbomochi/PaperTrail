import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:paper_trail/app.dart';
import 'package:paper_trail/core/services/logger_service.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () {
      if (kReleaseMode) {
        logger.minLevel = LogLevel.warning;
      }

      runApp(const ProviderScope(child: PaperTrailApp()));
    },
  );
}
