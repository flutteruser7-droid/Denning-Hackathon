import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/home/data/course_repository.dart';
import 'package:rive_animation/features/home/models/course_model.dart';
import 'package:rive_animation/features/home/viewmodels/home_view_model.dart';

class MockCourseRepository implements CourseRepository {
  @override
  List<Course> getCourses() {
    return [
      Course(title: "Test Course 1"),
      Course(title: "Test Course 2"),
    ];
  }

  @override
  List<Course> getRecentCourses() {
    return [
      Course(title: "Test Recent 1"),
    ];
  }
}

void main() {
  group('HomeViewModel Tests', () {
    test('Initializes and loads courses from repository', () {
      final repo = MockCourseRepository();
      final viewModel = HomeViewModel(repository: repo);

      expect(viewModel.courses.length, 2);
      expect(viewModel.courses.first.title, "Test Course 1");
      expect(viewModel.recentCourses.length, 1);
      expect(viewModel.recentCourses.first.title, "Test Recent 1");
      expect(viewModel.isLoading, isFalse);
    });

    test('loadCourses notifies listeners and updates state', () {
      final repo = MockCourseRepository();
      final viewModel = HomeViewModel(repository: repo);

      bool notified = false;
      viewModel.addListener(() {
        notified = true;
      });

      viewModel.loadCourses();

      expect(notified, isTrue);
      expect(viewModel.courses.isNotEmpty, isTrue);
    });
  });
}
