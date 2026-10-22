import '../../../core/models/rive_asset_model.dart';

class MenuItemModel {
  final String title;
  final RiveAssetModel rive;

  MenuItemModel({required this.title, required this.rive});
}

// Alias for backward compatibility
typedef Menu = MenuItemModel;
