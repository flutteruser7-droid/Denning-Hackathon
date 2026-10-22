import 'package:flutter/material.dart' show Color;

class Course {
  final String title;
  final String description;
  final String iconSrc;
  final Color color;

  Course({
    required this.title,
    this.description = 'Build and animate an iOS app from scratch',
    this.iconSrc = "assets/icons/ios.svg",
    this.color = const Color(0xFF7553F6),
  });
}
