import 'package:flutter/material.dart';

const kGreen = Color(0xFF2d7a3a);
const kLightGreen = Color(0xFFe8f5ea);
const kBg = Color(0xFFf5f0e8);
const kRed = Color(0xFFc0392b);

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
  scaffoldBackgroundColor: kBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: kGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFcccccc), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFcccccc), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kGreen, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
  useMaterial3: true,
);
