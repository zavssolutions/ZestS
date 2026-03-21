import "package:flutter_riverpod/flutter_riverpod.dart";

import "../core/constants.dart";
import "../core/remote_config_service.dart";
import "../core/storage.dart";
import "../features/auth/data/auth_token_store.dart";
import "../features/profile/data/profile_providers.dart";
import "package:firebase_auth/firebase_auth.dart";

enum StartupDestination { home, onboarding, login, forceUpdate, profileCompletion }

final remoteConfigProvider = FutureProvider<RemoteConfigService>((ref) async {
  return RemoteConfigService.create();
});

final firebaseIdTokenProvider = StreamProvider<String?>((ref) async* {
  await for (final user in FirebaseAuth.instance.idTokenChanges()) {
    if (user == null) {
      yield null;
      continue;
    }
    try {
      yield await user.getIdToken(false);
    } catch (_) {
      yield null;
    }
  }
});

final startupDestinationProvider = FutureProvider<StartupDestination>((ref) async {
  final remoteConfig = await ref.watch(remoteConfigProvider.future);
  if (await remoteConfig.isForceUpdateRequired()) {
    return StartupDestination.forceUpdate;
  }

  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final isFirstOpen = prefs.getBool(kFirstOpenKey) ?? true;

  if (isFirstOpen) {
    return StartupDestination.onboarding;
  }
  
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      final profile = await ref.read(profileRepositoryProvider).fetchProfile();
      if (profile.hasCompletedProfile) {
        return StartupDestination.home;
      } else {
        return StartupDestination.profileCompletion;
      }
    } catch (_) {
      return StartupDestination.profileCompletion;
    }
  }

  return StartupDestination.home;
});

final appStartupProvider = Provider<void>((ref) {
  ref.watch(startupDestinationProvider);
  ref.listen(firebaseIdTokenProvider, (previous, next) {
    final token = next.valueOrNull;
    ref.read(authTokenStoreProvider).token = token;
  });
});

