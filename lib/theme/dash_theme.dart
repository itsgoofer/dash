import 'package:flutter/material.dart';

/// 8pt spacing grid.
abstract final class DashSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 16.0;
  static const x4 = 24.0;
  static const x5 = 32.0;
  static const x6 = 48.0;
}

/// Single radius token — everywhere. No pills, no capsules.
abstract final class DashRadius {
  static const value = 4.0;
  static BorderRadius get br => BorderRadius.circular(value);
}

/// Shared control heights so same-row controls (buttons, inputs, dropdowns) align.
abstract final class DashSize {
  static const control = 32.0;
  static const controlCompact = 28.0;
  static const iconButton = 28.0;
}

abstract final class DashMotion {
  static const duration = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;
  static const hover = Duration(milliseconds: 120);
  static const screen = Duration(milliseconds: 200);
  static const chart = Duration(milliseconds: 400);
  static const stagger = Duration(milliseconds: 30);
}

abstract final class DashColors {
  static const bg0 = Color(0xFF0A0E14);
  static const bg1 = Color(0xFF0F141C);
  static final glassFill = Colors.white.withValues(alpha: 0.04);
  static final glassBorder = Colors.white.withValues(alpha: 0.07);
  static final hover = Colors.white.withValues(alpha: 0.05);
  static final active = Colors.white.withValues(alpha: 0.09);
  static const accent = Color(0xFF22D3EE);
  static final accentDim = accent.withValues(alpha: 0.15);
  static const accent2 = Color(0xFF818CF8);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const text0 = Color(0xFFE6EDF3);
  static const text1 = Color(0xFF8B98A9);
  static const text2 = Color(0xFF4B5666);

  // Legacy aliases kept for call-site compatibility.
  static const bg = bg0;
  static const surface = bg1;
  static const border = Color(0x12FFFFFF);
  static const accentSecondary = accent2;
  static const textPrimary = text0;
  static const textSecondary = text1;
  static const textFaint = text2;
}

abstract final class DashType {
  static const _family = 'Inter';
  static const _mono = 'SF Mono';

  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: DashColors.text0,
  );

  static const title = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DashColors.text0,
  );

  static const heading = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DashColors.text0,
  );

  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: DashColors.text0,
  );

  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: DashColors.text1,
  );

  static const small = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: DashColors.text1,
  );

  static const mono = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: DashColors.text0,
  );
}

ThemeData buildDashTheme() {
  final colorScheme = ColorScheme.dark(
    surface: DashColors.bg0,
    primary: DashColors.accent,
    secondary: DashColors.accent2,
    error: DashColors.danger,
    onSurface: DashColors.text0,
    onPrimary: DashColors.bg0,
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: DashRadius.br);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DashColors.bg0,
    colorScheme: colorScheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: DashColors.hover,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: DashType.display,
      titleLarge: DashType.title,
      titleMedium: DashType.heading,
      bodyLarge: DashType.body,
      labelLarge: DashType.label,
      bodySmall: DashType.small,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DashColors.accent,
        foregroundColor: DashColors.bg0,
        disabledBackgroundColor: DashColors.active,
        minimumSize: Size(0, DashSize.control),
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3),
        textStyle: DashType.label,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DashColors.text0,
        side: BorderSide(color: DashColors.glassBorder),
        minimumSize: Size(0, DashSize.control),
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3),
        textStyle: DashType.label,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DashColors.text1,
        minimumSize: Size(0, DashSize.control),
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3),
        textStyle: DashType.label,
        shape: buttonShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DashColors.bg1,
      hintStyle: DashType.body.copyWith(color: DashColors.text2),
      contentPadding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: DashSpace.x2),
      border: OutlineInputBorder(
        borderRadius: DashRadius.br,
        borderSide: BorderSide(color: DashColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: DashRadius.br,
        borderSide: BorderSide(color: DashColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: DashRadius.br,
        borderSide: const BorderSide(color: DashColors.accent),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.12),
      ),
      radius: Radius.zero,
      thickness: const WidgetStatePropertyAll(6),
      trackVisibility: const WidgetStatePropertyAll(false),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: DashColors.accent,
      inactiveTrackColor: DashColors.glassBorder,
      thumbColor: Colors.white,
      overlayColor: DashColors.accent.withValues(alpha: 0.15),
      trackHeight: 4,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: DashColors.bg1,
        borderRadius: DashRadius.br,
        border: Border.all(color: DashColors.glassBorder),
      ),
      textStyle: DashType.small.copyWith(color: DashColors.text0),
    ),
    dividerColor: DashColors.glassBorder,
  );
}
