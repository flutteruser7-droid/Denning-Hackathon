import 'package:flutter/material.dart';
import '../models/course_model.dart';

abstract class CourseRepository {
  List<Course> getCourses();
  List<Course> getRecentCourses();
}

class LocalCourseRepository implements CourseRepository {
  final List<Course> _courses = [
    Course(
      title: "Animations in SwiftUI",
    ),
    Course(
      title: "Animations in Flutter",
      iconSrc: "assets/icons/code.svg",
      color: const Color(0xFF80A4FF),
    ),
  ];

  final List<Course> _recentCourses = [
    Course(title: "State Machine"),
    Course(
      title: "Animated Menu",
      color: const Color(0xFF9CC5FF),
      iconSrc: "assets/icons/code.svg",
    ),
    Course(title: "Flutter with Rive"),
    Course(
      title: "Animated Menu",
      color: const Color(0xFF9CC5FF),
      iconSrc: "assets/icons/code.svg",
    ),
  ];

  @override
  List<Course> getCourses() => List.unmodifiable(_courses);

  @override
  List<Course> getRecentCourses() => List.unmodifiable(_recentCourses);
}
