import "package:dio/dio.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../../../core/api_client.dart";

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

  Future<AuthLoginResult> signInWithGoogle() async {
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
    return _exchangeToken(idToken);
  }

  Future<AuthLoginResult> signInWithEmail(String email, String password) async {
    UserCredential userCredential;
    try {
      userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final idToken = await userCredential.user?.getIdToken(true);
    if (idToken == null) {
      throw Exception("Unable to get Firebase ID token");
    }
    return _exchangeToken(idToken);
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
    return _exchangeToken(idToken);
  }

  Future<AuthLoginResult> _exchangeToken(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      "/auth/token",
      data: {"id_token": token},
    );
    final data = response.data ?? {};
    return AuthLoginResult(
      token: data["access_token"] as String? ?? token,
      isNewUser: data["is_new_user"] as bool? ?? false,
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
