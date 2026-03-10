import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/foundation.dart";

import "../core/constants.dart";
import "../core/remote_config_service.dart";
import "../core/notification_service.dart";
import "../core/storage.dart";
import "../features/auth/data/auth_token_store.dart";
import "../features/profile/data/profile_providers.dart";
import "../features/profile/data/profile_model.dart";

enum StartupDestination { home, onboarding, login, forceUpdate, profileCompletion }

final remoteConfigProvider = FutureProvider<RemoteConfigService>((ref) async {
  return RemoteConfigService.create();
});

final startupDestinationProvider = FutureProvider<StartupDestination>((ref) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed (likely missing google-services.json). Error: $e");
  }

  try {
    final remoteConfig = await ref.watch(remoteConfigProvider.future);
    if (await remoteConfig.isForceUpdateRequired()) {
      return StartupDestination.forceUpdate;
    }
  } catch (e) {
    debugPrint("Remote Config not initialized: $e");
  }

  User? currentUser;
  try {
    currentUser = FirebaseAuth.instance.currentUser;
  } catch (e) {
    debugPrint("Firebase Auth not initialized: $e");
  }

  if (currentUser != null) {
    final idToken = await currentUser.getIdToken(true);
    ref.read(authTokenStoreProvider).token = idToken;
    ProfileModel? profile;
    try {
      profile = await ref.read(profileRepositoryProvider).fetchProfile();
    } catch (_) {
      // Fallback to cached profile if API is not reachable during startup.
      profile = await ref.read(profileRepositoryProvider).readCachedProfile();
    }
    try {
      await ref.read(notificationServiceProvider).registerDeviceToken();
    } catch (e) {
      debugPrint("Notifications not initialized: $e");
    }
    if (profile == null || !profile.hasCompletedProfile) {
      return StartupDestination.profileCompletion;
    }
    return StartupDestination.home;
  }

  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final isFirstOpen = prefs.getBool(kFirstOpenKey) ?? true;

  if (isFirstOpen) {
    return StartupDestination.onboarding;
  }
  return StartupDestination.login;
});

final appStartupProvider = Provider<void>((ref) {
  ref.watch(startupDestinationProvider);
});

