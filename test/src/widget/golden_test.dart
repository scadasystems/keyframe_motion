@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 웹 데모와 같은 타임라인(fixture)으로 효과별 중간 프레임을 고정한다. macOS 로컬 전용.
final Map<String, List<Timeline>> demo = {
  for (final d
      in jsonDecode(
            File('test/fixtures/demo_timelines.json').readAsStringSync(),
          )
          as List)
    d['id'] as String: [
      for (final e in d['elements']) Timeline.fromJson(e['timeline']),
    ],
};

/// 방향이 보이도록 왼쪽에 주황 띠가 있는 카드 (480×270 씬 중앙, 220×120)
Widget card(int i) => DecoratedBox(
  decoration: BoxDecoration(
    color: i == 0 ? const Color(0xFFFFFFFF) : const Color(0xFFDC2626),
    borderRadius: BorderRadius.circular(10),
  ),
  child: const Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: 0.3,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFF59E0B),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
        ),
      ),
    ),
  ),
);

class _Scene extends StatefulWidget {
  const _Scene({
    required this.timelines,
    required this.t,
    required this.quality,
  });
  final List<Timeline> timelines;
  final double t;
  final MotionQualityLevel quality;
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final clock = MotionController(vsync: this)..seek(widget.t);
  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MotionQuality(
    level: widget.quality,
    child: ColoredBox(
      color: const Color(0xFF0D1015),
      child: Stack(
        children: [
          for (final (i, tl) in widget.timelines.indexed)
            Positioned(
              left: 130,
              top: 75,
              width: 220,
              height: 120,
              child: Motion(timeline: tl, controller: clock, child: card(i)),
            ),
        ],
      ),
    ),
  );
}

void main() {
  final cases = <(String, double, MotionQualityLevel)>[
    ('flipIn', 300, MotionQualityLevel.full),
    ('doorOpen', 400, MotionQualityLevel.full),
    ('jelly', 200, MotionQualityLevel.full),
    ('swing', 0, MotionQualityLevel.full),
    ('wipeIn', 400, MotionQualityLevel.full),
    ('splitOpen', 350, MotionQualityLevel.full),
    ('priceSwap', 1700, MotionQualityLevel.full),
    ('saleFlash', 250, MotionQualityLevel.full),
    ('blurIn', 300, MotionQualityLevel.full),
    ('blurIn', 300, MotionQualityLevel.reduced),
    ('shimmer', 500, MotionQualityLevel.full),
    ('shimmer', 500, MotionQualityLevel.reduced),
    // 색 행렬·상대 이동·원형 clip·feather
    ('soldOut', 1200, MotionQualityLevel.full),
    ('flash', 200, MotionQualityLevel.full),
    ('hueCycle', 2000, MotionQualityLevel.full),
    ('grayTint', 800, MotionQualityLevel.full),
    ('slideInRel', 300, MotionQualityLevel.full),
    ('irisIn', 450, MotionQualityLevel.full),
    ('irisCorner', 450, MotionQualityLevel.full),
    ('featherWipe', 700, MotionQualityLevel.full),
    ('featherWipe', 700, MotionQualityLevel.reduced),
    ('featherBox', 500, MotionQualityLevel.full),
  ];

  for (final (id, t, quality) in cases) {
    testWidgets('$id @${t.toInt()}ms ${quality.name}', (tester) async {
      tester.view.physicalSize = const Size(480, 270);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _Scene(timelines: demo[id]!, t: t, quality: quality),
        ),
      );
      await expectLater(
        find.byType(_Scene),
        matchesGoldenFile('goldens/${id}_${t.toInt()}_${quality.name}.png'),
      );
    });
  }
}
