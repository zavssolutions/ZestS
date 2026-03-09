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
    );
  }
}
