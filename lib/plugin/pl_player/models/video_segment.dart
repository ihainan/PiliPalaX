import 'package:flutter/material.dart';
import '../../../common/widgets/audio_video_progress_bar.dart';

/// 视频区段类型
class VideoSegmentType {
  static const String sponsor = 'sponsor'; // 广告
  static const String selfpromo = 'selfpromo'; // 自我推广
  static const String intro = 'intro'; // 开场动画
  static const String outro = 'outro'; // 结束动画
}

/// 视频区段信息
class VideoSegment {
  final String category;
  final List<double> segment;

  VideoSegment({
    required this.category,
    required this.segment,
  });

  factory VideoSegment.fromJson(Map<String, dynamic> json) {
    return VideoSegment(
      category: json['category'] as String,
      segment: [
        (json['segment'][0] as num).toDouble(),
        (json['segment'][1] as num).toDouble(),
      ],
    );
  }

  ProgressBarRegion toProgressBarRegion() {
    Color color;
    String type;
    switch (category) {
      case VideoSegmentType.sponsor:
        color = Colors.red.withOpacity(0.3);
        type = '赞助';
        break;
      case VideoSegmentType.selfpromo:
        color = Colors.orange.withOpacity(0.3);
        type = '自我推广';
        break;
      case VideoSegmentType.intro:
        color = Colors.blue.withOpacity(0.3);
        type = '片头';
        break;
      case VideoSegmentType.outro:
        color = Colors.purple.withOpacity(0.3);
        type = '片尾';
        break;
      default:
        color = Colors.grey.withOpacity(0.3);
        type = '其他';
    }
    return ProgressBarRegion(
      start: Duration(milliseconds: (segment[0] * 1000).round()),
      end: Duration(milliseconds: (segment[1] * 1000).round()),
      color: color,
      type: type,
    );
  }
}
