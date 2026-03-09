import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../core/constants.dart";
import "../core/remote_config_service.dart";
import "../core/storage.dart";
import "../features/auth/data/auth_token_store.dart";
import "../features/profile/data/profile_providers.dart";

enum StartupDestination { home, onboarding, login, forceUpdate }

final remoteConfigProvider = FutureProvider<RemoteConfigService>((ref) async {
  return RemoteConfigService.create();
});

final startupDestinationProvider = FutureProvider<StartupDestination>((ref) async {
  await Firebase.initializeApp();

  final remoteConfig = await ref.watch(remoteConfigProvider.future);
  if (await remoteConfig.isForceUpdateRequired()) {
    return StartupDestination.forceUpdate;
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final idToken = await currentUser.getIdToken(true);
    ref.read(authTokenStoreProvider).token = idToken;
    try {
      await ref.read(profileRepositoryProvider).fetchProfile();
    } catch (_) {
      // Fallback to cached profile if API is not reachable during startup.
      await ref.read(profileRepositoryProvider).readCachedProfile();
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

