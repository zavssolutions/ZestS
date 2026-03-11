import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/notification_service.dart";
import "../../../core/permission_service.dart";
import "../../profile/data/profile_providers.dart";
import "../data/auth_repository.dart";
import "../data/auth_token_store.dart";

class AuthState {
  const AuthState({
    this.loading = false,
    this.error,
    this.verificationId,
  });

  final bool loading;
  final String? error;
  final String? verificationId;

  AuthState copyWith({bool? loading, String? error, String? verificationId}) {
    return AuthState(
      loading: loading ?? this.loading,
      error: error,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref)
      : _repo = _ref.read(authRepositoryProvider),
        super(const AuthState());

  final Ref _ref;
  final AuthRepository _repo;

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.signInWithGoogle();
      _ref.read(authTokenStoreProvider).token = result.token;
      await _ref.read(profileRepositoryProvider).fetchProfile();
      await _ref.read(notificationServiceProvider).registerDeviceToken();
      if (result.isNewUser) {
        await PermissionService().requestOptionalPermissions();
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e, st) {
      debugPrint("Google Sign-in Error: $e");
      debugPrintStack(stackTrace: st);
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.sendOtp(
        phone: phone,
        onCodeSent: (id) => state = state.copyWith(verificationId: id),
      );
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }




  Future<bool> verifyOtp(String otp) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(error: "Please request OTP first.");
      return false;
    }

    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.verifyOtp(
        verificationId: verificationId,
        otp: otp,
      );
      _ref.read(authTokenStoreProvider).token = result.token;
      await _ref.read(profileRepositoryProvider).fetchProfile();
      await _ref.read(notificationServiceProvider).registerDeviceToken();
      if (result.isNewUser) {
        await PermissionService().requestOptionalPermissions();
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    _ref.read(authTokenStoreProvider).token = null;
    await _ref.read(profileRepositoryProvider).clearCache();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
