import 'dart:convert';

class SkipSegment {
  final String cid;
  final String category;
  final String actionType;
  final List<double> segment;
  final String uuid;
  final int videoDuration;
  final int locked;
  final int votes;
  final String description;

  SkipSegment({
    required this.cid,
    required this.category,
    required this.actionType,
    required this.segment,
    required this.uuid,
    required this.videoDuration,
    required this.locked,
    required this.votes,
    required this.description,
  });

  factory SkipSegment.fromJson(Map<String, dynamic> json) {
    return SkipSegment(
      cid: json['cid']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      segment: (json['segment'] as List<dynamic>?)?.map((e) {
            if (e is int) {
              return e.toDouble();
            } else if (e is double) {
              return e;
            } else if (e is String) {
              return double.tryParse(e) ?? 0.0;
            } else {
              return 0.0;
            }
          }).toList() ??
          [],
      uuid: json['UUID']?.toString() ?? '',
      videoDuration: (json['videoDuration'] is int)
          ? json['videoDuration'] as int
          : int.tryParse(json['videoDuration']?.toString() ?? '0') ?? 0,
      locked: (json['locked'] is int)
          ? json['locked'] as int
          : int.tryParse(json['locked']?.toString() ?? '0') ?? 0,
      votes: (json['votes'] is int)
          ? json['votes'] as int
          : int.tryParse(json['votes']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }

  static List<SkipSegment> fromJsonList(String jsonStr) {
    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList.map((json) => SkipSegment.fromJson(json)).toList();
  }
}
