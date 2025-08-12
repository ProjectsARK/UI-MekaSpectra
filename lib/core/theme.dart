import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.buttonBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50), // Rounded-pill
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppPaddings.buttonVertical,
          horizontal: AppPaddings.buttonHorizontal,
        ),
      ),
    ),
  );
}
