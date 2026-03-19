import "package:dio/dio.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../../../core/api_client.dart";

class AuthBackendException implements Exception {
  const AuthBackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthLoginResult {
  const AuthLoginResult({required this.token, required this.isNewUser});

  final String token;
  final bool isNewUser;
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      "email",
    ],
  );

  Future<void> _resetLocalAuthState() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<AuthLoginResult> signInWithGoogle() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await _resetLocalAuthState();
    }

    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception("Sign-in cancelled by user");
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken(true);
    if (idToken == null) {
      throw Exception("Unable to get Firebase ID token");
    }
    try {
      return await _exchangeToken(idToken);
    } catch (_) {
      await _resetLocalAuthState();
      rethrow;
    }
  }

  Future<AuthLoginResult> signInWithEmail(String email, String password) async {
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
    UserCredential userCredential;
    if (methods.contains("password")) {
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        final msg = e.message ?? "";
        if (e.code == "invalid-credential" && (msg.contains("Recaptcha") || msg.contains("reCAPTCHA") || msg.contains("token"))) {
          throw Exception(
            "Sign-in blocked by reCAPTCHA/Play Integrity. Add the app signing fingerprint(s) in Firebase (Android app settings; SHA-1 is required, SHA-256 may be available depending on console/Play setup), ensure Google Play services are up to date (use a Google Play emulator image), or temporarily disable Email/Password reCAPTCHA enforcement in Firebase Auth settings.",
          );
        }
        if (e.code == "wrong-password" || e.code == "invalid-credential") {
          throw Exception("Incorrect email or password.");
        }
        if (e.code == "too-many-requests") {
          throw Exception("Too many failed attempts. Please try again later.");
        }
        rethrow;
      }
    } else if (methods.isEmpty) {
      try {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == "operation-not-allowed") {
          throw Exception("Email/Password sign-in is disabled. Enable it in Firebase Authentication settings.");
        }
        rethrow;
      }
    } else {
      throw Exception("This email is registered with a different provider. Use Google Sign-in for this account.");
    }

    final idToken = await userCredential.user?.getIdToken(true);
    if (idToken == null) {
      throw Exception("Unable to get Firebase ID token");
    }
    try {
      return await _exchangeToken(idToken);
    } catch (_) {
      await _resetLocalAuthState();
      rethrow;
    }
  }

  Future<String> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      codeAutoRetrievalTimeout: (_) {},
      verificationCompleted: (_) {},
      verificationFailed: (e) => throw Exception(e.message ?? "Phone verification failed"),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
    );
    return "sent";
  }

  Future<AuthLoginResult> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken(true);
    if (idToken == null) {
      throw Exception("Unable to get Firebase ID token");
    }
    try {
      return await _exchangeToken(idToken);
    } catch (_) {
      await _resetLocalAuthState();
      rethrow;
    }
  }

  Future<AuthLoginResult> _exchangeToken(String token) async {
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        "/auth/token",
        data: {"id_token": token},
        options: Options(
          validateStatus: (_) => true,
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 1),
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout) {
        throw const AuthBackendException(
          "Backend took too long to respond. If this is a fresh Render deploy/cold start, wait 1–2 minutes and try again.",
        );
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        throw const AuthBackendException(
          "Unable to reach backend. Check the API base URL and verify the Render service is running.",
        );
      }
      rethrow;
    }

    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      final data = response.data ?? const <String, dynamic>{};
      final detail = data["detail"]?.toString();
      if (statusCode == 401) {
        throw AuthBackendException(
          detail ?? "Backend rejected the Firebase token (401).",
          statusCode: statusCode,
        );
      }
      throw AuthBackendException(
        detail ?? "Backend token exchange failed (${statusCode ?? "unknown"}).",
        statusCode: statusCode,
      );
    }

    final data = response.data ?? {};
    return AuthLoginResult(
      token: data["access_token"] as String? ?? token,
      isNewUser: data["is_new_user"] as bool? ?? false,
    );
  }

  Future<void> signOut() async {
    await _resetLocalAuthState();
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
