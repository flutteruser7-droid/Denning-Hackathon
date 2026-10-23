import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/core/services/preferences_service.dart';
import 'package:rive_animation/features/auth/models/user_model.dart';
import 'package:rive_animation/features/admin/viewmodels/admin_dashboard_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Authentication & Model Tests', () {
    test('UserModel correctly detects admin from role or isAdmin flag', () {
      final adminUser = UserModel.fromMap({
        'uid': 'sRCk4fO9emQgPOJwHt5g8Ea1gEP2',
        'email': 'admin@gmail.com',
        'name': 'Admin',
      }, 'sRCk4fO9emQgPOJwHt5g8Ea1gEP2', true);

      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.role, equals('admin'));
      expect(adminUser.email, equals('admin@gmail.com'));
      expect(adminUser.uid, equals('sRCk4fO9emQgPOJwHt5g8Ea1gEP2'));

      final regularUser = UserModel.fromMap({
        'uid': 'user123',
        'email': 'student@gmail.com',
        'name': 'Student',
        'isAdmin': false,
      });

      expect(regularUser.isAdmin, isFalse);
      expect(regularUser.role, equals('user'));
    });

    test('PreferencesService correctly saves and reads isAdmin flag', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService();

      expect(await prefs.isAdmin(), isFalse);

      await prefs.setIsAdmin(true);
      expect(await prefs.isAdmin(), isTrue);

      await prefs.clearAuthPreferences();
      expect(await prefs.isAdmin(), isFalse);
    });

    test('AdminDashboardViewModel initializes and filters users by query', () {
      final vm = AdminDashboardViewModel();
      expect(vm.isLoading, isTrue);
      expect(vm.searchQuery, isEmpty);

      vm.setSearchQuery('test');
      expect(vm.searchQuery, equals('test'));
    });
  });
}
