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
  static const control = 30.0;
  static const controlCompact = 26.0;
  static const iconButton = 26.0;
}

abstract final class DashMotion {
  static const duration = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;
  static const hover = Duration(milliseconds: 120);
  static const screen = Duration(milliseconds: 200);
  static const chart = Duration(milliseconds: 400);
  static const stagger = Duration(milliseconds: 30);
}

/// v2 palette: dark gray/navy, white text, restrained glow.
/// [accent] is runtime-changeable (persisted per-vault); never reference it
/// from a const context.
abstract final class DashColors {
  static const bg0 = Color(0xFF08090D);
  static const bg1 = Color(0xFF0D0F15);
  static final glassFill = Colors.white.withValues(alpha: 0.03);
  static final glassBorder = Colors.white.withValues(alpha: 0.06);
  static final hover = Colors.white.withValues(alpha: 0.05);
  static final active = Colors.white.withValues(alpha: 0.09);

  /// Curated accent choices (name → color); default cyan.
  static const accents = <String, Color>{
    'cyan': Color(0xFF22D3EE),
    'violet': Color(0xFF818CF8),
    'green': Color(0xFF34D399),
    'amber': Color(0xFFFBBF24),
    'red': Color(0xFFF87171),
    'white': Color(0xFFE6EDF3),
  };
  static Color accent = accents['cyan']!;
  static Color get accentDim => accent.withValues(alpha: 0.14);

  static const accent2 = Color(0xFF818CF8);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const text0 = Color(0xFFF4F6F8);
  static const text1 = Color(0xFF848D9C);
  static const text2 = Color(0xFF454D5C);

  // Legacy aliases kept for call-site compatibility.
  static const bg = bg0;
  static const surface = bg1;
  static const border = Color(0x0FFFFFFF);
  static const accentSecondary = accent2;
  static const textPrimary = text0;
  static const textSecondary = text1;
  static const textFaint = text2;
}

abstract final class DashType {
  static const _family = 'Inter';
  static const _display = 'Rajdhani';
  static const _mono = 'SF Mono';

  static const display = TextStyle(
    fontFamily: _display,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: DashColors.text0,
  );

  static const title = TextStyle(
    fontFamily: _display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: DashColors.text0,
  );

  static const heading = TextStyle(
    fontFamily: _display,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: DashColors.text0,
  );

  static const hudLabel = TextStyle(
    fontFamily: _display,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.5,
    color: DashColors.text1,
  );

  static const clock = TextStyle(
    fontFamily: _display,
    fontSize: 52,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: DashColors.text0,
  );

  static const clockSmall = TextStyle(
    fontFamily: _display,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: DashColors.text0,
  );

  static const ticker = TextStyle(
    fontFamily: _mono,
    fontSize: 10.5,
    height: 1.7,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w400,
    color: DashColors.text1,
  );

  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: DashColors.text0,
  );

  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DashColors.text1,
  );

  static const small = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: DashColors.text1,
  );

  static const mono = TextStyle(
    fontFamily: _mono,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: DashColors.text0,
  );

  // Editor scale (body 14 base): dimmed markers rendered separately.
  static const editorH1 =
      TextStyle(fontFamily: _family, fontSize: 22, fontWeight: FontWeight.w700, height: 1.35, color: DashColors.text0);
  static const editorH2 =
      TextStyle(fontFamily: _family, fontSize: 18, fontWeight: FontWeight.w600, height: 1.35, color: DashColors.text0);
  static const editorH3 =
      TextStyle(fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, color: DashColors.text0);
  static const codeFamily = _mono;
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
      isDense: true,
      fillColor: DashColors.bg1,
      hintStyle: DashType.body.copyWith(fontSize: 13, height: 1.2, color: DashColors.text2),
      contentPadding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 7),
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
        borderSide: BorderSide(color: DashColors.accent),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.10),
      ),
      radius: Radius.zero,
      thickness: const WidgetStatePropertyAll(6),
      trackVisibility: const WidgetStatePropertyAll(false),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: DashColors.accent,
      selectionColor: DashColors.accent.withValues(alpha: 0.15),
      selectionHandleColor: DashColors.accent,
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
