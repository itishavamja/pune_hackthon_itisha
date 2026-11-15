import 'package:flutter/material.dart';

/// Dukaan360 brand colours.
class Brand {
  static const primary = Color(0xFF0E9F8E); // growth teal
  static const primaryDark = Color(0xFF0B6E66);
  static const navy = Color(0xFF0B1F3A);
  static const navySoft = Color(0xFF16305A);
  static const amber = Color(0xFFF5A524);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF2FA36B);
  static const info = Color(0xFF3B82F6);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, Color(0xFF0B4F59), primaryDark],
  );
  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryDark, primary, Color(0xFF22C3A6)],
  );
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => cs.onSurface.withValues(alpha: 0.62);
  Color get cardColor => dark ? const Color(0xFF121C2E) : Colors.white;
  Color get hairline => dark ? const Color(0x1FFFFFFF) : const Color(0x140B1F3A);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    brightness: b,
    primary: dark ? const Color(0xFF3CD3BD) : Brand.primary,
    surface: dark ? const Color(0xFF0A1220) : const Color(0xFFF3F6FA),
    onSurface: dark ? const Color(0xFFF2F5FA) : Brand.navy,
    error: Brand.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? const Color(0xFF0F1A2D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF16233A) : const Color(0xFFEEF2F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF101B2E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.navy,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: dark ? const Color(0x1FFFFFFF) : const Color(0x140B1F3A),
  );
}
