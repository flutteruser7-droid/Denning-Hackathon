import 'package:flutter/foundation.dart';
import '../data/course_repository.dart';
import '../models/course_model.dart';

class HomeViewModel extends ChangeNotifier {
  final CourseRepository _repository;

  List<Course> _courses = [];
  List<Course> _recentCourses = [];
  bool _isLoading = false;

  HomeViewModel({CourseRepository? repository})
      : _repository = repository ?? LocalCourseRepository() {
    loadCourses();
  }

  List<Course> get courses => _courses;
  List<Course> get recentCourses => _recentCourses;
  bool get isLoading => _isLoading;

  void loadCourses() {
    _isLoading = true;
    notifyListeners();

    _courses = _repository.getCourses();
    _recentCourses = _repository.getRecentCourses();
    _isLoading = false;
    notifyListeners();
  }
}
