import 'package:flutter/material.dart';

// Couleurs constantes
const Color primaryColor = Color(0xFF1DA1F2);
const Color secondaryColor = Color(0xFF14171A);
const Color accentColor = Color(0xFF657786);
const Color backgroundColor = Color(0xFFF5F8FA);
const Color darkBackgroundColor = Color(0xFF15202B);
final Color cardShadowColor = Colors.black.withOpacity(0.1);

// Espacements constants
const double spacingXS = 4.0;
const double spacingS = 8.0;
const double spacingM = 16.0;
const double spacingL = 24.0;
const double spacingXL = 32.0;

// Styles de texte
final TextStyle headlineStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  letterSpacing: -0.5,
  color: primaryColor,
);

final TextStyle titleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
);

final TextStyle bodyStyle = TextStyle(
  fontSize: 16,
  letterSpacing: 0.1,
  height: 1.4,
);

final TextStyle captionStyle = TextStyle(
  fontSize: 14,
  color: accentColor,
  letterSpacing: 0.2,
);

class AppThemes {
  static final ThemeData lightTheme = ThemeData.light().copyWith(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 8,
      shadowColor: cardShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    textTheme: TextTheme(
      headlineMedium: headlineStyle.copyWith(color: Colors.black),
      titleMedium: titleStyle.copyWith(color: Colors.black),
      bodyMedium: bodyStyle.copyWith(color: Colors.black),
      bodySmall: captionStyle.copyWith(color: accentColor),
    ),
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackgroundColor,
      foregroundColor: primaryColor,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: secondaryColor,
      elevation: 8,
      shadowColor: cardShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    textTheme: TextTheme(
      headlineMedium: headlineStyle.copyWith(color: Colors.white),
      titleMedium: titleStyle.copyWith(color: Colors.white),
      bodyMedium: bodyStyle.copyWith(color: Colors.white),
      bodySmall: captionStyle.copyWith(color: accentColor),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: secondaryColor,
      onSurface: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}