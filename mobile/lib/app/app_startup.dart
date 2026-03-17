import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "../firebase_options.dart";
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
  final remoteConfig = await ref.watch(remoteConfigProvider.future);
  if (await remoteConfig.isForceUpdateRequired()) {
    return StartupDestination.forceUpdate;
  }

  final currentUser = FirebaseAuth.instance.currentUser;

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
    await ref.read(notificationServiceProvider).registerDeviceToken();
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
  return StartupDestination.home;
});

final appStartupProvider = Provider<void>((ref) {
  ref.watch(startupDestinationProvider);
});

