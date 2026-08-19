import 'package:flutter/material.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  const seed = Color(0xFF0F766E);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
