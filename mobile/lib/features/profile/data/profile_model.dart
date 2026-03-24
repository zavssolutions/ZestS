class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.favoriteSport,
    required this.profilePictureUrl,
    required this.parentId,
    required this.hasCompletedProfile,
    required this.dob,
    this.skateType,
    this.ageGroup,
  });

  final String id;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? favoriteSport;
  final String? profilePictureUrl;
  final String? parentId;
  final bool hasCompletedProfile;
  final String? dob;
  final String? skateType;
  final String? ageGroup;

  String get displayName {
    final name = "${firstName ?? ""} ${lastName ?? ""}".trim();
    return name.isEmpty ? "ZestS User" : name;
  }

  bool get isSubProfile => parentId != null;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json["id"] as String,
      role: (json["role"] as String?) ?? "parent",
      firstName: json["first_name"] as String?,
      lastName: json["last_name"] as String?,
      favoriteSport: json["favorite_sport"] as String?,
      profilePictureUrl: json["profile_picture_url"] as String?,
      parentId: json["parent_id"] as String?,
      hasCompletedProfile: (json["has_completed_profile"] as bool?) ?? false,
      dob: json["dob"] as String?,
      skateType: json["skate_type"] as String?,
      ageGroup: json["age_group"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "role": role,
      "first_name": firstName,
      "last_name": lastName,
      "favorite_sport": favoriteSport,
      "profile_picture_url": profilePictureUrl,
      "parent_id": parentId,
      "has_completed_profile": hasCompletedProfile,
      "dob": dob,
      "skate_type": skateType,
      "age_group": ageGroup,
    };
  }
}
