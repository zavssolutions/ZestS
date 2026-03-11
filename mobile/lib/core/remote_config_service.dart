import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:package_info_plus/package_info_plus.dart";

class RemoteConfigService {
  RemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  static Future<RemoteConfigService> create() async {
    final instance = FirebaseRemoteConfig.instance;
    await instance.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await instance.setDefaults(const {
      "phone_auth_enabled": false,
      "google_auth_enabled": true,
      "minimum_version_android": "1.0.0",
      "minimum_version_ios": "1.0.0",
      "force_update_enabled": false,
    });
    try {
      await instance.fetchAndActivate();
    } catch (_) {
      // If fetch fails (no network, Firebase not configured, etc.),
      // the safe defaults set above will be used automatically.
    }
    return RemoteConfigService(instance);
  }

  bool get phoneAuthEnabled => _remoteConfig.getBool("phone_auth_enabled");

  bool get googleAuthEnabled => _remoteConfig.getBool("google_auth_enabled");

  Future<bool> isForceUpdateRequired() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final minVersion = _remoteConfig.getString("minimum_version_android");
    final forceEnabled = _remoteConfig.getBool("force_update_enabled");
    return forceEnabled && _compareVersion(current, minVersion) < 0;
  }

  int _compareVersion(String current, String minVersion) {
    final c = current.split(".").map(int.tryParse).map((e) => e ?? 0).toList();
    final m = minVersion.split(".").map(int.tryParse).map((e) => e ?? 0).toList();
    final len = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv != mv) {
        return cv.compareTo(mv);
      }
    }
    return 0;
  }
}
