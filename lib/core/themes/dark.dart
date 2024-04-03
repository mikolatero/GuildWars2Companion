import 'package:flutter/material.dart';

ThemeData darkTheme = ThemeData(
  primaryColor: Color(0xFFAA0404),
  cardColor: Color(0xFF262626),
  scaffoldBackgroundColor: Color(0xFF111111),
  textSelectionTheme: TextSelectionThemeData(cursorColor: Color(0xFFAA0404)),
  textTheme: TextTheme(
    displayLarge: TextStyle(
        fontSize: 22.0, color: Colors.white, fontWeight: FontWeight.normal),
    displayMedium: TextStyle(
      fontSize: 18.0,
      color: Colors.white,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontSize: 16.0,
      color: Colors.white,
      fontWeight: FontWeight.normal,
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    elevation: 0,
    foregroundColor: Colors.black,
  ),
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red)
      .copyWith(secondary: Color(0xFFEEEEEE), brightness: Brightness.dark),
);
