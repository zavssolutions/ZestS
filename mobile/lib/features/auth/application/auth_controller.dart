import "package:flutter/foundation.dart";
import "package:dio/dio.dart";
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

  String _toUserMessage(Object error) {
    if (error is AuthBackendException) {
      if (error.statusCode == 401) {
        return "Backend rejected the sign-in token (401). Set FIREBASE_SERVICE_ACCOUNT_JSON on the backend and redeploy.";
      }
      return error.message;
    }
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == 401) {
        return "Backend rejected the sign-in token (401). Set FIREBASE_SERVICE_ACCOUNT_JSON on the backend and redeploy.";
      }
      return error.message ?? error.toString();
    }
    return error.toString();
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.signInWithGoogle();
      _ref.read(authTokenStoreProvider).token = result.token;
      await _ref.read(profileRepositoryProvider).fetchProfile();
      _ref.invalidate(cachedProfileProvider);
      _ref.invalidate(kidsProvider);
      await _ref.read(notificationServiceProvider).registerDeviceToken();
      if (result.isNewUser) {
        await PermissionService().requestOptionalPermissions();
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e, st) {
      if (e.toString().contains("cancelled by user")) {
        state = state.copyWith(loading: false);
        return false;
      }
      debugPrint("Google Sign-in Error: $e");
      debugPrintStack(stackTrace: st);
      state = state.copyWith(loading: false, error: _toUserMessage(e));
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.signInWithEmail(email, password);
      _ref.read(authTokenStoreProvider).token = result.token;
      await _ref.read(profileRepositoryProvider).fetchProfile();
      _ref.invalidate(cachedProfileProvider);
      _ref.invalidate(kidsProvider);
      await _ref.read(notificationServiceProvider).registerDeviceToken();
      if (result.isNewUser) {
        await PermissionService().requestOptionalPermissions();
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _toUserMessage(e));
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
      state = state.copyWith(loading: false, error: _toUserMessage(e));
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
      _ref.invalidate(cachedProfileProvider);
      _ref.invalidate(kidsProvider);
      await _ref.read(notificationServiceProvider).registerDeviceToken();
      if (result.isNewUser) {
        await PermissionService().requestOptionalPermissions();
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _toUserMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    _ref.read(authTokenStoreProvider).token = null;
    await _ref.read(profileRepositoryProvider).clearCache();
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.sendPasswordReset(email);
      state = state.copyWith(loading: false, error: "Password reset email sent.");
    } catch (e) {
      state = state.copyWith(loading: false, error: _toUserMessage(e));
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
