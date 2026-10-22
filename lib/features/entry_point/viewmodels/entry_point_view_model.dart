import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart';
import '../data/navigation_repository.dart';
import '../models/menu_item_model.dart';

class EntryPointViewModel extends ChangeNotifier {
  final NavigationRepository _repository;

  bool _isSideBarOpen = false;
  late MenuItemModel _selectedBottomNav;
  late MenuItemModel _selectedSideMenu;
  SMIBool? isMenuOpenInput;

  late final List<MenuItemModel> _sidebarMenus;
  late final List<MenuItemModel> _sidebarMenus2;
  late final List<MenuItemModel> _bottomNavItems;

  EntryPointViewModel({NavigationRepository? repository})
      : _repository = repository ?? LocalNavigationRepository() {
    _sidebarMenus = _repository.getSidebarMenus();
    _sidebarMenus2 = _repository.getSidebarMenus2();
    _bottomNavItems = _repository.getBottomNavItems();
    _selectedBottomNav = _bottomNavItems.first;
    _selectedSideMenu = _sidebarMenus.first;
  }

  bool get isSideBarOpen => _isSideBarOpen;
  MenuItemModel get selectedBottomNav => _selectedBottomNav;
  MenuItemModel get selectedSideMenu => _selectedSideMenu;

  List<MenuItemModel> get sidebarMenus => _sidebarMenus;
  List<MenuItemModel> get sidebarMenus2 => _sidebarMenus2;
  List<MenuItemModel> get bottomNavItems => _bottomNavItems;

  void toggleSidebar() {
    _isSideBarOpen = !_isSideBarOpen;
    if (isMenuOpenInput != null) {
      isMenuOpenInput!.value = !isMenuOpenInput!.value;
    }
    notifyListeners();
  }

  void setSidebarOpen(bool isOpen) {
    _isSideBarOpen = isOpen;
    notifyListeners();
  }

  void updateSelectedBottomNav(MenuItemModel menu) {
    if (_selectedBottomNav != menu) {
      _selectedBottomNav = menu;
      notifyListeners();
    }
  }

  void updateSelectedSideMenu(MenuItemModel menu) {
    if (_selectedSideMenu != menu) {
      _selectedSideMenu = menu;
      notifyListeners();
    }
  }
}
