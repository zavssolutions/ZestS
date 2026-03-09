import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/constants.dart";
import "../../../core/storage.dart";
import "profile_model.dart";

class ProfileRepository {
  ProfileRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  Future<ProfileModel> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>("/users/me");
    final data = response.data ?? {};
    final profile = ProfileModel.fromJson(data);

    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(kProfileCacheKey, jsonEncode(profile.toJson()));
    return profile;
  }

  Future<ProfileModel?> readCachedProfile() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final raw = prefs.getString(kProfileCacheKey);
    if (raw == null) {
      return null;
    }
    return ProfileModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearCache() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.remove(kProfileCacheKey);
  }
}
