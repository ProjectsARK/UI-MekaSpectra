import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: AppTextSizes.title,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
      labelLarge: TextStyle(
        fontSize: AppTextSizes.button,
        color: AppColors.primary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, // warna solid tombol
        foregroundColor: Colors.white, // warna teks & ikon
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // sudut membulat
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
  );
}
