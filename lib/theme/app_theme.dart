import 'package:flutter/material.dart';

/// פלטת הצבעים של הסטודיו - בורדו עמוק, זהב וורוד פודרה
class StudioColors {
  static const burgundy = Color(0xFF4A1525);
  static const gold = Color(0xFFD4AF37);
  static const rose = Color(0xFFD8A7B1);
  static const cream = Color(0xFFFAF7F2);
  static const ink = Color(0xFF2B1B1F);
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: StudioColors.cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: StudioColors.burgundy,
    brightness: Brightness.light,
    primary: StudioColors.burgundy,
    secondary: StudioColors.rose,
    tertiary: StudioColors.gold,
    surface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: StudioColors.burgundy,
    foregroundColor: StudioColors.cream,
    centerTitle: true,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: StudioColors.cream,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 1.5,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: StudioColors.burgundy,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: StudioColors.burgundy,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: StudioColors.burgundy,
      side: const BorderSide(color: StudioColors.burgundy),
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: StudioColors.rose.withOpacity(0.6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: StudioColors.rose.withOpacity(0.6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: StudioColors.burgundy, width: 2),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  chipTheme: ChipThemeData(
    selectedColor: StudioColors.burgundy,
    backgroundColor: StudioColors.rose.withOpacity(0.25),
    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return StudioColors.burgundy;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return StudioColors.burgundy;
      }),
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontWeight: FontWeight.bold, color: StudioColors.ink),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, color: StudioColors.ink),
    bodyMedium: TextStyle(color: StudioColors.ink),
  ),
);
