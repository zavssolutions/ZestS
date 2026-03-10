import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "api_client.dart";

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;

  Future<void> registerDeviceToken() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token == null) {
      return;
    }
    final platform = Platform.isIOS ? "ios" : "android";
    await _ref.read(dioProvider).post(
      "/notifications/device-token",
      data: {"token": token, "platform": platform},
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});
