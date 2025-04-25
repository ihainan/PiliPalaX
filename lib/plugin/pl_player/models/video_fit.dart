import 'package:flutter/material.dart';

/// 视频适配模式
enum VideoFit {
  contain,
  cover,
  fill,
  fitHeight,
  fitWidth,
  none,
  scaleDown,
}

extension VideoFitExtension on VideoFit {
  String get description {
    switch (this) {
      case VideoFit.contain:
        return '适应';
      case VideoFit.cover:
        return '填充';
      case VideoFit.fill:
        return '拉伸';
      case VideoFit.fitHeight:
        return '适应高度';
      case VideoFit.fitWidth:
        return '适应宽度';
      case VideoFit.none:
        return '原始';
      case VideoFit.scaleDown:
        return '缩小适应';
    }
  }
}
