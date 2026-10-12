import 'dart:math' as math;

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:keyframe_motion/src/widget/color_matrix.dart';
import 'package:keyframe_motion/src/widget/motion.dart' show featherStops;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const all = Timeline(
  durationMs: 1000,
  repeat: MotionRepeat.loop,
  tracks: [
    Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(1000, 1)]),
    Track(MotionProp.clipRight, [Keyframe(0, 1), Keyframe(1000, 0)]),
    Track(MotionProp.tint, [
      Keyframe(0, 0),
      Keyframe(500, 1),
      Keyframe(1000, 0),
    ], color: Color(0xFFFF2D2D)),
    Track(MotionProp.blur, [
      Keyframe(0, 0),
      Keyframe(500, 8),
      Keyframe(1000, 0),
    ]),
    Track(MotionProp.shimmer, [
      Keyframe(0, 0),
      Keyframe(1000, 1),
    ], color: Color(0xCCFFFFFF)),
  ],
);

Widget host(
  Widget child, {
  MotionQualityLevel quality = MotionQualityLevel.full,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MotionQuality(
    level: quality,
    child: Center(child: child),
  ),
);

class _Clock extends StatefulWidget {
  const _Clock({required this.builder});
  final Widget Function(MotionController) builder;
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> with SingleTickerProviderStateMixin {
  late final controller = MotionController(vsync: this);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}

void main() {
  group('색·이동·clip·feather', extraTests);
  testWidgets('효과가 모두 있어도 재생 중 child 는 한 번만 빌드되고 트리 모양이 유지된다', (tester) async {
    var builds = 0;
    late MotionController clock;
    await tester.pumpWidget(
      host(
        _Clock(
          builder: (c) {
            clock = c;
            return Motion(
              timeline: all,
              controller: c,
              child: Builder(
                builder: (_) {
                  builds++;
                  return const SizedBox(width: 100, height: 50);
                },
              ),
            );
          },
        ),
      ),
    );
    for (final t in <double>[0, 250, 500, 999]) {
      clock.seek(t);
      await tester.pump();
      // 값이 0 인 프레임(t=0 의 tint·blur)에도 래퍼가 빠지지 않는다
      expect(find.byType(ShaderMask), findsOneWidget, reason: 't=$t');
      expect(find.byType(ImageFiltered), findsOneWidget, reason: 't=$t');
      expect(find.byType(ColorFiltered), findsOneWidget, reason: 't=$t');
      expect(find.byType(ClipRect), findsOneWidget, reason: 't=$t');
    }
    expect(builds, 1);
  });

  testWidgets('reduced 는 blur·shimmer 를 빼고 tint·clip 은 유지한다', (tester) async {
    await tester.pumpWidget(
      host(
        const Motion(timeline: all, child: SizedBox(width: 100, height: 50)),
        quality: MotionQualityLevel.reduced,
      ),
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.byType(ClipRect), findsOneWidget);
  });

  testWidgets('MotionQuality 가 없으면 full', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Motion(timeline: all, child: SizedBox()),
      ),
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  testWidgets('clip 은 요소 비율만큼 자르고, 범위 밖 값과 합 > 1 에도 크래시가 없다', (tester) async {
    Future<Rect?> clipFor(double l, double r) async {
      await tester.pumpWidget(
        host(
          Motion(
            key: ValueKey('$l/$r'),
            timeline: Timeline(
              durationMs: 10,
              tracks: [
                Track(MotionProp.clipLeft, [Keyframe(0, l)]),
                Track(MotionProp.clipRight, [Keyframe(0, r)]),
              ],
            ),
            autoplay: false,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      );
      final clip = tester.widget<ClipRect>(find.byType(ClipRect));
      return clip.clipper!.getClip(const Size(200, 100));
    }

    expect(await clipFor(0.25, 0.5), const Rect.fromLTRB(50, 0, 100, 100));
    expect(await clipFor(-1, 2), const Rect.fromLTRB(0, 0, 0, 100));
    expect((await clipFor(0.7, 0.7))!.width, 0);
  });

  testWidgets('tint 색이 없으면 검정으로 어둡게 한다', (tester) async {
    await tester.pumpWidget(
      host(
        const Motion(
          timeline: Timeline(
            durationMs: 10,
            tracks: [
              Track(MotionProp.tint, [Keyframe(0, 0.5)]),
            ],
          ),
          autoplay: false,
          child: SizedBox(),
        ),
      ),
    );
    final f = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(
      f.colorFilter,
      ColorFilter.matrix(
        motionColorMatrix(tint: const Color(0xFF000000), tintStrength: 0.5),
      ),
    );
  });
}

Timeline single(
  MotionProp p,
  double v, {
  FractionalOffset origin = FractionalOffset.center,
}) => Timeline(
  durationMs: 10,
  origin: origin,
  tracks: [
    Track(p, [Keyframe(0, v)]),
  ],
);

Widget frozen(Timeline tl, {Key? key, double w = 100, double h = 50}) => Motion(
  key: key,
  timeline: tl,
  autoplay: false,
  child: SizedBox(key: const Key('box'), width: w, height: h),
);

void extraTests() {
  testWidgets('translateXRel·YRel 은 요소 크기 비율만큼, px 이동과 더해진다', (tester) async {
    await tester.pumpWidget(
      host(
        frozen(
          const Timeline(
            durationMs: 10,
            tracks: [
              Track(MotionProp.translateXRel, [Keyframe(0, -1)]),
              Track(MotionProp.translateYRel, [Keyframe(0, 0.5)]),
              Track(MotionProp.translateX, [Keyframe(0, 7)]),
            ],
          ),
        ),
      ),
    );
    final base = tester.getCenter(find.byType(Motion));
    final box = tester.renderObject<RenderBox>(find.byKey(const Key('box')));
    final topLeft = box.localToGlobal(Offset.zero);
    // 이동 전 왼쪽 위 = 중심 - (50, 25). x: -100 + 7, y: +25
    expect(topLeft, base - const Offset(50, 25) + const Offset(-93, 25));
  });

  testWidgets('clipCircle: origin 중심, 1 이면 가장 먼 꼭짓점까지(+1px), 0 이면 빈 원', (
    tester,
  ) async {
    Future<Rect> circle(double v, FractionalOffset o) async {
      await tester.pumpWidget(
        host(
          frozen(
            single(MotionProp.clipCircle, v, origin: o),
            key: ValueKey('$v$o'),
          ),
        ),
      );
      final clip = tester.widget<ClipOval>(find.byType(ClipOval));
      return clip.clipper!.getClip(const Size(100, 50));
    }

    final far = math.sqrt(50 * 50 + 25 * 25);
    expect(
      await circle(1, FractionalOffset.center),
      Rect.fromCircle(center: const Offset(50, 25), radius: far + 1),
    );
    final corner = await circle(0.5, FractionalOffset.topLeft);
    expect(corner.center, Offset.zero);
    expect(
      corner.width / 2,
      closeTo((math.sqrt(100 * 100 + 50 * 50) + 1) * 0.5, 1e-9),
    );
    expect((await circle(0, FractionalOffset.center)).width, 0);
    expect((await circle(-3, FractionalOffset.center)).width, 0); // 음수에도 크래시 없음
  });

  testWidgets('색 속성은 ColorFiltered 하나로 합쳐지고 reduced 에서도 유지된다', (tester) async {
    const tl = Timeline(
      durationMs: 10,
      tracks: [
        Track(MotionProp.saturate, [Keyframe(0, 0)]),
        Track(MotionProp.brightness, [Keyframe(0, 1.2)]),
        Track(MotionProp.tint, [Keyframe(0, 0.3)]),
      ],
    );
    await tester.pumpWidget(
      host(frozen(tl), quality: MotionQualityLevel.reduced),
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets(
    'feather: full 에서는 축마다 ShaderMask, 그 축은 ClipRect 가 자르지 않는다. reduced 는 일반 clip',
    (tester) async {
      const tl = Timeline(
        durationMs: 10,
        tracks: [
          Track(MotionProp.clipRight, [Keyframe(0, 0.5)]),
          Track(MotionProp.clipTop, [Keyframe(0, 0.2)]),
          Track(MotionProp.feather, [Keyframe(0, 0.3)]),
        ],
      );
      await tester.pumpWidget(host(frozen(tl, key: const Key('full'))));
      expect(find.byType(ShaderMask), findsNWidgets(2));
      expect(find.byType(ClipRect), findsNothing);

      await tester.pumpWidget(
        host(
          frozen(tl, key: const Key('reduced')),
          quality: MotionQualityLevel.reduced,
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
      final clip = tester.widget<ClipRect>(find.byType(ClipRect));
      expect(
        clip.clipper!.getClip(const Size(100, 50)),
        const Rect.fromLTRB(0, 10, 50, 50),
      );
    },
  );

  test('feather 알파: clip 0 이면 전부 보이고 1 이면 전부 숨는다. 경계가 겹쳐도 단조', () {
    double alphaAt((List<double>, List<double>) s, double x) {
      final (p, a) = s;
      if (x <= p.first) return a.first;
      for (var i = 1; i < p.length; i++) {
        if (x <= p[i]) {
          return a[i - 1] +
              (a[i] - a[i - 1]) * (x - p[i - 1]) / (p[i] - p[i - 1]);
        }
      }
      return a.last;
    }

    for (final f in [0.0, 0.1, 0.3, 1.0]) {
      final open = featherStops(0, 0, f),
          shut = featherStops(0, 1, f),
          shutL = featherStops(1, 0, f);
      for (var x = 0.0; x <= 1.0; x += 0.05) {
        expect(alphaAt(open, x), closeTo(1, 1e-9), reason: 'open f=$f x=$x');
        expect(alphaAt(shut, x), closeTo(0, 1e-9), reason: 'shut f=$f x=$x');
        expect(alphaAt(shutL, x), closeTo(0, 1e-9), reason: 'shutL f=$f x=$x');
      }
      final (p, _) = featherStops(0.6, 0.6, f); // 겹침
      for (var i = 1; i < p.length; i++) {
        expect(p[i], greaterThanOrEqualTo(p[i - 1]));
      }
    }
    // 오른쪽 경계 가운데(clipRight 0.5, f 0.3)는 알파 0.5 근처
    expect(
      alphaAt(featherStops(0, 0.5, 0.3), 0.5 * 1.3 - 0.15),
      closeTo(0.5, 1e-9),
    );
  });
}
