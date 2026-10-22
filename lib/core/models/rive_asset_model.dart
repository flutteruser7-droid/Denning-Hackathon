import 'package:rive/rive.dart';

class RiveAssetModel {
  final String src;
  final String artboard;
  final String stateMachineName;
  SMIBool? status;

  RiveAssetModel({
    required this.src,
    required this.artboard,
    required this.stateMachineName,
    this.status,
  });

  set setStatus(SMIBool state) {
    status = state;
  }
}

typedef RiveModel = RiveAssetModel;
