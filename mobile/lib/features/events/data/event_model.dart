class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.venueCity,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.bannerImageUrl,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.price,
    this.organizerId,
    this.organizerUserId,
  });

  final String id;
  final String title;
  final String? description;
  final String locationName;
  final String? venueCity;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? bannerImageUrl;
  final double? latitude;
  final double? longitude;
  final String status;
  final double price;
  final int? organizerId;
  final String? organizerUserId;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json["id"] as String,
      title: json["title"] as String,
      description: json["description"] as String?,
      locationName: json["location_name"] as String,
      venueCity: json["venue_city"] as String?,
      startAtUtc: DateTime.parse(json["start_at_utc"] as String),
      endAtUtc: DateTime.parse(json["end_at_utc"] as String),
      bannerImageUrl: json["banner_image_url"] as String?,
      latitude: (json["latitude"] as num?)?.toDouble(),
      longitude: (json["longitude"] as num?)?.toDouble(),
      status: (json["status"] as String?) ?? "published",
      price: (json["price"] as num?)?.toDouble() ?? 0.0,
      organizerId: json["organizer_id"] as int?,
      organizerUserId: json["organizer_user_id"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "location_name": locationName,
      "venue_city": venueCity,
      "start_at_utc": startAtUtc.toIso8601String(),
      "end_at_utc": endAtUtc.toIso8601String(),
      "banner_image_url": bannerImageUrl,
      "latitude": latitude,
      "longitude": longitude,
      "status": status,
      "price": price,
      "organizer_id": organizerId,
      "organizer_user_id": organizerUserId,
    };
  }
}

class EventCategoryModel {
  const EventCategoryModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.price,
  });

  final String id;
  final String eventId;
  final String name;
  final double price;

  factory EventCategoryModel.fromJson(Map<String, dynamic> json) {
    return EventCategoryModel(
      id: json["id"] as String,
      eventId: json["event_id"] as String,
      name: json["name"] as String,
      price: (json["price"] as num?)?.toDouble() ?? 0,
    );
  }
}

class RegistrationModel {
  const RegistrationModel({
    required this.registrationId,
    required this.userId,
    required this.userName,
    required this.status,
    required this.event,
  });

  final String registrationId;
  final String userId;
  final String userName;
  final String status;
  final EventModel? event;

  factory RegistrationModel.fromJson(Map<String, dynamic> json) {
    final eventJson = json["event"] as Map<String, dynamic>?;
    return RegistrationModel(
      registrationId: json["registration_id"] as String,
      userId: json["user_id"] as String,
      userName: (json["user_name"] as String?) ?? "",
      status: (json["status"] as String?) ?? "pending",
      event: eventJson == null ? null : EventModel.fromJson(eventJson),
    );
  }
}
