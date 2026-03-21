class TipOfDayModel {
  const TipOfDayModel({
    required this.serialNo,
    required this.date,
    required this.content,
    required this.isUrl,
  });

  final int serialNo;
  final String date;
  final String content;
  final bool isUrl;

  factory TipOfDayModel.fromJson(Map<String, dynamic> json) {
    return TipOfDayModel(
      serialNo: (json["serial_no"] as int?) ?? 0,
      date: (json["date"] as String?) ?? "",
      content: (json["content"] as String?) ?? "",
      isUrl: (json["is_url"] as bool?) ?? false,
    );
  }
}

