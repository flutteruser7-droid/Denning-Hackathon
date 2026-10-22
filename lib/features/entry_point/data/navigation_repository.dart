import '../../../core/models/rive_asset_model.dart';
import '../models/menu_item_model.dart';

abstract class NavigationRepository {
  List<MenuItemModel> getSidebarMenus();
  List<MenuItemModel> getSidebarMenus2();
  List<MenuItemModel> getBottomNavItems();
}

class LocalNavigationRepository implements NavigationRepository {
  final List<MenuItemModel> _sidebarMenus = [
    MenuItemModel(
      title: "Home",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "HOME",
        stateMachineName: "HOME_interactivity",
      ),
    ),
    MenuItemModel(
      title: "Chat with AI",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "CHAT",
        stateMachineName: "CHAT_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Search",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "SEARCH",
        stateMachineName: "SEARCH_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Favorites",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "LIKE/STAR",
        stateMachineName: "STAR_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Help",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "CHAT",
        stateMachineName: "CHAT_Interactivity",
      ),
    ),
  ];

  final List<MenuItemModel> _sidebarMenus2 = [
    MenuItemModel(
      title: "History",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "TIMER",
        stateMachineName: "TIMER_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Notifications",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "BELL",
        stateMachineName: "BELL_Interactivity",
      ),
    ),
  ];

  final List<MenuItemModel> _bottomNavItems = [
    MenuItemModel(
      title: "Chat",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "CHAT",
        stateMachineName: "CHAT_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Search",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "SEARCH",
        stateMachineName: "SEARCH_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Timer",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "TIMER",
        stateMachineName: "TIMER_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Notification",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "BELL",
        stateMachineName: "BELL_Interactivity",
      ),
    ),
    MenuItemModel(
      title: "Profile",
      rive: RiveAssetModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "USER",
        stateMachineName: "USER_Interactivity",
      ),
    ),
  ];

  @override
  List<MenuItemModel> getSidebarMenus() => _sidebarMenus;

  @override
  List<MenuItemModel> getSidebarMenus2() => _sidebarMenus2;

  @override
  List<MenuItemModel> getBottomNavItems() => _bottomNavItems;
}
