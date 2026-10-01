import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app's light/dark/system appearance and persists the choice.
///
/// This only picks which ThemeData is active. Individual screens get their
/// colours from `AppColors` (lib/theme/app_colors.dart), which has a light and
/// a dark value for every role (text, card, border, ...). Keep the dark
/// values below in step with that file.
class ThemeProvider with ChangeNotifier {
  static const _prefsKey = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  static const _green = Color(0xFF00C853);
  static const _greenSoft = Color(0xFFDCFCE7);

  /// Light theme — matches the app's existing look (white backgrounds, dark
  /// slate text, green accent) so turning this on changes nothing visually
  /// for screens still using hardcoded colors.
  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.light,
      primary: _green,
      secondary: _greenSoft,
    ),
    primaryColor: _green,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1E293B),
      elevation: 0,
    ),
    cardColor: const Color(0xFFF8FAFC),
    dividerColor: const Color(0xFFF1F5F9),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1E293B)),
      bodyMedium: TextStyle(color: Color(0xFF1E293B)),
    ),
  );

  static const _bgDark = Color(0xFF0F172A);
  static const _surfaceDark = Color(0xFF1B2538);
  static const _textDark = Color(0xFFF1F5F9);
  static const _mutedDark = Color(0xFF94A3B8);

  /// Dark theme: slate background, slightly lighter surfaces for sheets and
  /// dialogs, same green accent. Material pieces that a screen does not
  /// colour itself (dialogs, pickers, snackbars, dropdown menus) use these.
  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: _bgDark,
    canvasColor: _surfaceDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
      primary: _green,
      secondary: _greenSoft,
    ).copyWith(
      surface: _surfaceDark,
      onSurface: _textDark,
      surfaceTint: Colors.transparent,
    ),
    primaryColor: _green,
    appBarTheme: const AppBarTheme(
      backgroundColor: _bgDark,
      foregroundColor: _textDark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: const Color(0xFF243147),
    dividerColor: const Color(0xFF334155),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _textDark),
      bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _surfaceDark,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surfaceDark,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: _surfaceDark,
      surfaceTintColor: Colors.transparent,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: _surfaceDark,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF334155),
      contentTextStyle: TextStyle(color: _textDark),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _bgDark,
      selectedItemColor: _green,
      unselectedItemColor: _mutedDark,
    ),
  );

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (e) {
      debugPrint('Could not load theme setting: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('Could not save theme setting: $e');
    }
  }
}