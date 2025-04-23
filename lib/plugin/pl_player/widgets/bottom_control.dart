import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:nil/nil.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/models/video/skip_segment.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'dart:math';

import '../../../common/widgets/audio_video_progress_bar.dart';

// 广告段标记组件
class AdSegmentIndicator extends StatelessWidget {
  final List<SkipSegment> segments;
  final Duration total;
  final double barHeight;

  const AdSegmentIndicator({
    Key? key,
    required this.segments,
    required this.total,
    this.barHeight = 3.5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 考虑到 ProgressBar 可能有左右边距，这里需要调整实际可用宽度
          // ProgressBar 组件的时间标签占用了两侧空间
          final timeLabelWidth = 50.0; // 估计的时间标签宽度
          final availableWidth = constraints.maxWidth - (timeLabelWidth * 2);
          final leftPadding = timeLabelWidth;

          final sponsorSegments = segments
              .where((segment) => segment.category == 'sponsor')
              .toList();

          return Stack(
            children: sponsorSegments.map((segment) {
              final totalDuration = segment.videoDuration > 0
                  ? segment.videoDuration
                  : total.inSeconds;

              final startRatio = segment.segment[0] / totalDuration;
              final endRatio = segment.segment[1] / totalDuration;

              // 根据可用宽度计算实际位置
              final left = leftPadding + (availableWidth * startRatio);
              final segmentWidth = availableWidth * (endRatio - startRatio);

              return Positioned(
                left: left,
                top: (constraints.maxHeight - barHeight) / 2,
                width: segmentWidth,
                height: barHeight,
                child: Container(
                  color: Colors.red.withOpacity(0.7),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class BottomControl extends StatefulWidget implements PreferredSizeWidget {
  final PlPlayerController? controller;
  final List<Widget>? buildBottomControl;
  const BottomControl({
    this.controller,
    this.buildBottomControl,
    super.key,
  });

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);

  @override
  State<BottomControl> createState() => _BottomControlState();
}

class _BottomControlState extends State<BottomControl> {
  final RxList<SkipSegment> skipSegments = <SkipSegment>[].obs;
  // 记录上一次的位置
  double? lastPosition;
  // 标记是否正在拖动
  bool isDragging = false;
  // 标记是否是用户手动跳转
  bool isManualSeek = false;

  @override
  void initState() {
    super.initState();
    debugPrint('BottomControl 初始化');
    debugPrint('controller: ${widget.controller}');
    debugPrint('currentBvid: ${widget.controller?.currentBvid}');

    // 监听视频源变化
    widget.controller?.addVideoSourceChangeListener(_onVideoSourceChanged);
    // 监听播放进度
    widget.controller?.addPositionListener(_onPositionChanged);
    // 初始化时获取一次广告段信息
    if (widget.controller?.currentBvid != null) {
      debugPrint('初始化时获取广告段信息');
      fetchSkipSegments(widget.controller!.currentBvid!);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeVideoSourceChangeListener(_onVideoSourceChanged);
    widget.controller?.removePositionListener(_onPositionChanged);
    super.dispose();
  }

  // 判断是否在广告段内
  bool _isInAdSegment(double position, SkipSegment segment) {
    final timeTolerance = 0.5;
    return position >= (segment.segment[0] - timeTolerance) &&
        position < (segment.segment[1] + timeTolerance);
  }

  // 判断是否从广告外进入广告内
  bool _isEnteringAdSegment(
      double currentPosition, double lastPosition, SkipSegment segment) {
    return !_isInAdSegment(lastPosition, segment) &&
        _isInAdSegment(currentPosition, segment);
  }

  void _onPositionChanged(Duration position) {
    // 如果正在拖动，不执行跳转
    if (isDragging) {
      lastPosition = position.inSeconds.toDouble();
      return;
    }

    final currentPosition = position.inSeconds.toDouble();
    final sponsorSegments =
        skipSegments.where((segment) => segment.category == 'sponsor').toList();

    // 如果没有上一次的位置记录，记录当前位置并返回
    if (lastPosition == null) {
      lastPosition = currentPosition;
      return;
    }

    // 如果是用户手动跳转，且当前位置在广告段内，不执行跳转
    if (isManualSeek) {
      bool isInAdSegment = false;
      for (final segment in sponsorSegments) {
        if (_isInAdSegment(currentPosition, segment)) {
          isInAdSegment = true;
          break;
        }
      }
      if (isInAdSegment) {
        lastPosition = currentPosition;
        return;
      }
      isManualSeek = false;
    }

    for (int i = 0; i < sponsorSegments.length; i++) {
      final segment = sponsorSegments[i];

      // 如果是从广告外进入广告内，且是正向播放
      if (_isEnteringAdSegment(currentPosition, lastPosition!, segment) &&
          currentPosition > lastPosition!) {
        debugPrint(
            '检测到进入广告段！当前位置: ${currentPosition}s, 广告段: ${segment.segment[0]}s - ${segment.segment[1]}s');

        final targetPosition = Duration(seconds: segment.segment[1].toInt());
        Future.microtask(() async {
          try {
            await widget.controller?.seekTo(targetPosition, type: 'skip');
            SmartDialog.showToast(
              '已跳过广告区段 (${segment.segment[0].toInt()}s - ${segment.segment[1].toInt()}s)',
              displayTime: const Duration(seconds: 2),
            );
          } catch (e) {
            debugPrint('跳转失败: $e');
          }
        });
        break;
      }
    }

    // 更新上一次的位置
    lastPosition = currentPosition;
  }

  void _onVideoSourceChanged() {
    // 当视频源改变时，重新获取广告段信息
    debugPrint('视频源发生变化');
    if (widget.controller?.currentBvid != null) {
      debugPrint('获取新视频的广告段信息，bvid: ${widget.controller!.currentBvid}');
      fetchSkipSegments(widget.controller!.currentBvid!);
    }
  }

  Future<void> fetchSkipSegments(String bvid) async {
    try {
      debugPrint('正在获取广告段信息，bvid: $bvid');
      final response = await http.get(
        Uri.parse('https://bsbsb.top/api/skipSegments?videoID=$bvid'),
      );
      debugPrint('API 响应状态码: ${response.statusCode}');
      debugPrint('API 响应内容: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonList = json.decode(response.body);
          debugPrint('解析到 JSON 数组，长度: ${jsonList.length}');

          // 打印第一个片段的内容（如果存在）
          if (jsonList.isNotEmpty) {
            debugPrint('第一个片段内容: ${json.encode(jsonList.first)}');
            debugPrint('segment 类型: ${jsonList.first['segment'].runtimeType}');
            debugPrint('segment 值: ${jsonList.first['segment']}');
          }

          final segments = SkipSegment.fromJsonList(response.body);
          debugPrint('成功解析所有片段，总数: ${segments.length}');
          debugPrint(
              '其中 sponsor 类型的片段数: ${segments.where((segment) => segment.category == 'sponsor').length}');
          skipSegments.value = segments;
        } catch (e, stackTrace) {
          debugPrint('解析响应内容时出错: $e');
          debugPrint('错误堆栈: $stackTrace');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('获取广告段出错: $e');
      debugPrint('错误堆栈: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    Color colorTheme = Theme.of(context).colorScheme.primary;
    final _ = widget.controller!;
    //阅读器限制
    Timer? accessibilityDebounce;
    double lastAnnouncedValue = -1;
    return Obx(() {
      final int value = _.sliderPositionSeconds.value;
      final int durationSec = _.durationSeconds.value;
      final int buffer = _.bufferedSeconds.value;

      if (value > durationSec || durationSec <= 0) {
        return nil;
      }
      bool isEquivalentFullScreen = _.isFullScreen.value ||
          !_.horizontalScreen &&
              MediaQuery.of(context).orientation == Orientation.landscape;
      return Container(
        color: Colors.transparent,
        height: 70 + (isEquivalentFullScreen ? Get.height * 0.08 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  bottom: 3 + (isEquivalentFullScreen ? Get.height * 0.01 : 0)),
              child: Semantics(
                  // label: '${(value / max * 100).round()}%',
                  value: '${(value / durationSec * 100).round()}%',
                  // enabled: false,
                  child: Stack(
                    children: [
                      // 广告段标记
                      Obx(() {
                        if (skipSegments.isEmpty) {
                          return const SizedBox();
                        }
                        return AdSegmentIndicator(
                          segments: skipSegments,
                          total: Duration(seconds: durationSec),
                        );
                      }),
                      // 原有的进度条，设置半透明
                      ProgressBar(
                        progress: Duration(seconds: value),
                        buffered: Duration(seconds: buffer),
                        total: Duration(seconds: durationSec),
                        progressBarColor: colorTheme.withOpacity(0.5),
                        baseBarColor: Colors.white.withOpacity(0.08),
                        bufferedBarColor: colorTheme.withOpacity(0.2),
                        timeLabelLocation: TimeLabelLocation.sides,
                        timeLabelTextStyle:
                            const TextStyle(color: Colors.white),
                        thumbColor: colorTheme,
                        barHeight: 3.5,
                        thumbRadius: 7,
                        onDragStart: (duration) {
                          isDragging = true;
                          feedBack();
                          _.onChangedSliderStart();
                        },
                        onDragUpdate: (duration) {
                          double newProgress =
                              duration.timeStamp.inSeconds / durationSec;
                          if ((newProgress - lastAnnouncedValue).abs() > 0.02) {
                            accessibilityDebounce?.cancel();
                            accessibilityDebounce =
                                Timer(const Duration(milliseconds: 200), () {
                              SemanticsService.announce(
                                  "${(newProgress * 100).round()}%",
                                  TextDirection.ltr);
                              lastAnnouncedValue = newProgress;
                            });
                          }
                          _.onUpdatedSliderProgress(duration.timeStamp);
                        },
                        onSeek: (duration) {
                          isDragging = false;
                          isManualSeek = true;
                          _.onChangedSliderEnd();
                          _.onChangedSlider(duration.inSeconds.toDouble());
                          _.seekTo(Duration(seconds: duration.inSeconds),
                              type: 'slider');
                          SemanticsService.announce(
                              "${(duration.inSeconds / durationSec * 100).round()}%",
                              TextDirection.ltr);
                        },
                      ),
                    ],
                  )),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [...widget.buildBottomControl!],
            ),
            const SizedBox(height: 6),
            if (isEquivalentFullScreen)
              SizedBox(height: max(Get.height * 0.08 - 15, 0)),
          ],
        ),
      );
    });
  }
}
