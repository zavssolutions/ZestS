import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/api_client.dart";
import "profile_model.dart";
import "profile_repository.dart";
import "../../auth/data/auth_token_store.dart";

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider), ref);
});

final cachedProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.readCachedProfile();
});

final kidsProvider = FutureProvider<List<ProfileModel>>((ref) async {
  return ref.watch(profileRepositoryProvider).fetchKids();
});

final userPointsProvider = FutureProvider<int>((ref) async {
  final token = ref.watch(authTokenStoreProvider).token;
  if (token == null || token.isEmpty) return 0;
  
  final profile = ref.watch(cachedProfileProvider).valueOrNull;
  if (profile == null) return 0;
  
  return ref.watch(profileRepositoryProvider).fetchUserPoints();
});
