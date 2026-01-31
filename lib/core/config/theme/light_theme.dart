import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';

final ThemeData lightTheme = ThemeData(
  scaffoldBackgroundColor: kPrimaryColor,
  fontFamily: AppFonts.URBANIST,
  fontFamilyFallback: const [
    'SF Pro Text',
    'Helvetica',
    'Roboto',
    'Arial',
    'Noto Sans',
    'sans-serif',
  ],
  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: kPrimaryColor,
    iconTheme: IconThemeData(color: kTertiaryColor),
    titleTextStyle: TextStyle(
      color: kTertiaryColor,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      fontFamily: AppFonts.URBANIST,
      fontFamilyFallback: const [
        'SF Pro Text',
        'Helvetica',
        'Roboto',
        'Arial',
        'Noto Sans',
        'sans-serif',
      ],
    ),
  ),
  splashColor: kSecondaryColor.withValues(alpha: 0.08),
  highlightColor: kSecondaryColor.withValues(alpha: 0.08),
  colorScheme: ColorScheme.light(
    primary: kSecondaryColor,
    onPrimary: kWhiteColor,
    secondary: kSecondaryColor,
    onSecondary: kWhiteColor,
    surface: kPrimaryColor,
    onSurface: kTertiaryColor,
    error: kRedColor,
    onError: kWhiteColor,
  ),
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: kTertiaryColor,
        displayColor: kTertiaryColor,
      ),
  useMaterial3: false,
  textSelectionTheme: TextSelectionThemeData(cursorColor: kTertiaryColor),
);
