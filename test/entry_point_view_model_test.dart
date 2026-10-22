import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/entry_point/data/navigation_repository.dart';
import 'package:rive_animation/features/entry_point/viewmodels/entry_point_view_model.dart';

void main() {
  group('EntryPointViewModel Tests', () {
    test('Initializes with default menu selections including Chat with AI', () {
      final repo = LocalNavigationRepository();
      final viewModel = EntryPointViewModel(repository: repo);

      expect(viewModel.isSideBarOpen, isFalse);
      expect(viewModel.sidebarMenus.length, 5);
      expect(viewModel.sidebarMenus[0].title, "Home");
      expect(viewModel.sidebarMenus[1].title, "Chat with AI");
      expect(viewModel.sidebarMenus2.length, 2);
      expect(viewModel.bottomNavItems.length, 5);
      expect(viewModel.selectedBottomNav.title, "Chat");
      expect(viewModel.selectedSideMenu.title, "Home");
    });

    test('Toggles sidebar and updates state', () {
      final viewModel = EntryPointViewModel();

      expect(viewModel.isSideBarOpen, isFalse);
      viewModel.toggleSidebar();
      expect(viewModel.isSideBarOpen, isTrue);
      viewModel.toggleSidebar();
      expect(viewModel.isSideBarOpen, isFalse);
    });

    test('Updates selected bottom and side menus', () {
      final viewModel = EntryPointViewModel();

      final searchBottom = viewModel.bottomNavItems[1];
      viewModel.updateSelectedBottomNav(searchBottom);
      expect(viewModel.selectedBottomNav.title, "Search");

      final chatSide = viewModel.sidebarMenus[1];
      viewModel.updateSelectedSideMenu(chatSide);
      expect(viewModel.selectedSideMenu.title, "Chat with AI");
    });
  });
}
