import 'package:flutter/widgets.dart';

enum MotionQualityLevel {
  full,

  /// GPU 가 약한 단말용 — blur·shimmer 트랙을 무시한다.
  reduced,
}

/// 하위 `Motion` 의 품질 등급. 플레이어가 기기 모델 등으로 스스로 정해 최상위에 둔다.
/// 패키지는 자동 감지하지 않으며, 없으면 [MotionQualityLevel.full].
class MotionQuality extends InheritedWidget {
  const MotionQuality({super.key, required this.level, required super.child});

  final MotionQualityLevel level;

  static MotionQualityLevel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionQuality>()?.level ??
      MotionQualityLevel.full;

  @override
  bool updateShouldNotify(MotionQuality oldWidget) => oldWidget.level != level;
}
