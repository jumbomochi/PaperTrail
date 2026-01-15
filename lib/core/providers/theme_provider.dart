import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum representing the available theme modes
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Provider for managing the app's theme mode
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system);

  void setThemeMode(AppThemeMode mode) {
    state = mode;
  }

  void toggleTheme() {
    if (state == AppThemeMode.light) {
      state = AppThemeMode.dark;
    } else if (state == AppThemeMode.dark) {
      state = AppThemeMode.light;
    } else {
      // If system, toggle to light
      state = AppThemeMode.light;
    }
  }

  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Helper to get the current ThemeMode for MaterialApp
final themeModeProvider = Provider<ThemeMode>((ref) {
  final themeNotifier = ref.watch(themeProvider.notifier);
  return themeNotifier.themeMode;
});
