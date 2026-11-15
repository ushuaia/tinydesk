import 'package:flutter/material.dart';

const seedColor = Color(0xFF4F46E5);

ThemeData buildTheme(Brightness brightness) => ThemeData(
      colorSchemeSeed: seedColor,
      brightness: brightness,
      useMaterial3: true,
    );
