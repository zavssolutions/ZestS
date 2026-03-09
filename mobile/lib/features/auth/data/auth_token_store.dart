import "package:flutter_riverpod/flutter_riverpod.dart";

class AuthTokenStore {
  String? token;
}

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return AuthTokenStore();
});
