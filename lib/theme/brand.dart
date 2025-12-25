import 'package:flutter/material.dart';

class Brand {
  static const black   = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161823);
  static const red     = Color(0xFFFE2C55);
  static const cyan    = Color(0xFF25F4EE);

  static const gradient = LinearGradient(
    colors: [red, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
