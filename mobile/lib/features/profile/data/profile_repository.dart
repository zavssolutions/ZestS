import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

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

  Future<ProfileModel> updateProfile({
    required String firstName,
    required String lastName,
    DateTime? dob,
    String? role,
    String? schoolName,
    String? clubName,
    String? specialization,
    int? experienceYears,
    String? orgName,
    String? websiteUrl,
    String? skillLevel,
    int? yearsSkating,
    String? preferredTracks,
  }) async {
    final payload = <String, dynamic>{
      "first_name": firstName,
      "last_name": lastName,
      "favorite_sport": "skating",
    };
    if (dob != null) payload["dob"] = DateFormat("yyyy-MM-dd").format(dob);
    if (role != null) payload["role"] = role;
    if (schoolName != null) payload["school_name"] = schoolName;
    if (clubName != null) payload["club_name"] = clubName;
    if (specialization != null) payload["specialization"] = specialization;
    if (experienceYears != null) payload["experience_years"] = experienceYears;
    if (orgName != null) payload["org_name"] = orgName;
    if (websiteUrl != null) payload["website_url"] = websiteUrl;
    if (skillLevel != null) payload["skill_level"] = skillLevel;
    if (yearsSkating != null) payload["years_skating"] = yearsSkating;
    if (preferredTracks != null) payload["preferred_tracks"] = preferredTracks;

    final response = await _dio.put<Map<String, dynamic>>("/users/me", data: payload);
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

  Future<List<ProfileModel>> fetchKids() async {
    final response = await _dio.get<List<dynamic>>("/users/me/kids");
    final data = response.data ?? [];
    return compute(_parseProfiles, data);
  }

  static List<ProfileModel> _parseProfiles(List<dynamic> data) {
    return data
        .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ProfileModel> addKid({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
  }) async {
    final payload = <String, dynamic>{
      "first_name": firstName,
      "last_name": lastName,
      "dob": DateFormat("yyyy-MM-dd").format(dob),
      "gender": gender,
    };
    final response = await _dio.post<Map<String, dynamic>>("/users/me/kids", data: payload);
    final data = response.data ?? {};
    return ProfileModel.fromJson(data);
  }

  Future<int> fetchUserPoints() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>("/users/me/points");
      final data = response.data ?? {};
      return (data["total_points"] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
