import "package:permission_handler/permission_handler.dart";

class PermissionService {
  Future<void> requestOptionalPermissions() async {
    await [
      Permission.notification,
      Permission.locationWhenInUse,
      Permission.photos,
    ].request();
  }
}
