class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    this.shareUrl,
  });

  final String id;
  final String? title;
  final String imageUrl;
  final String? linkUrl;
  final String? shareUrl;

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json["id"] as String,
      title: json["title"] as String?,
      imageUrl: json["image_url"] as String,
      linkUrl: json["link_url"] as String?,
      shareUrl: json["share_url"] as String?,
    );
  }
}
