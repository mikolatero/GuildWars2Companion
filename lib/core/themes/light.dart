import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Color(0xFFAA0404),
  cardColor: Colors.white,
  scaffoldBackgroundColor: Color(0xFFEEEEEE),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Color(0xFFAA0404)
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 22.0,
      color: Colors.white,
      fontWeight: FontWeight.normal
    ),
    displayMedium: TextStyle(
      fontSize: 18.0,
      color: Colors.black,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontSize: 16.0,
      color: Colors.black,
      fontWeight: FontWeight.normal,
    ),
  ), colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red).copyWith(secondary: Colors.red)
);