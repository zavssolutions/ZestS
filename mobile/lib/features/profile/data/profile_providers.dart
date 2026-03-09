import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";
import "profile_model.dart";
import "profile_repository.dart";

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider), ref);
});

final cachedProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  return ref.watch(profileRepositoryProvider).readCachedProfile();
});
