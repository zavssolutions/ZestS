import "package:flutter/material.dart";

ThemeData buildAppTheme() {
  const seed = Color(0xFF00A6C7);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    scaffoldBackgroundColor: const Color(0xFFF7FBFF),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
