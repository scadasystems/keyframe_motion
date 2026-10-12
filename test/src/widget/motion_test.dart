import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fadeUp = Timeline(
  durationMs: 600,
  delayMs: 100,
  repeat: MotionRepeat.pingpong,
  tracks: [
    Track(MotionProp.opacity, [
      Keyframe(0, 0),
      Keyframe(300, 1, curve: Curves.easeOut),
    ]),
    Track(MotionProp.translateY, [
      Keyframe(0, 24),
      Keyframe(600, 0, curve: Curves.easeInOut),
    ]),
  ],
);

Widget host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

double opacityOf(WidgetTester tester, [int i = 0]) =>
    tester.widgetList<Opacity>(find.byType(Opacity)).elementAt(i).opacity;

Matrix4 matrixOf(WidgetTester tester, [int i = 0]) =>
    tester.widgetList<Transform>(find.byType(Transform)).elementAt(i).transform;

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
  group('builder', builderTests);
  testWidgets('seek(t) 결과가 0 부터 t 까지 재생한 결과와 같다 (delay·pingpong 포함)', (
    tester,
  ) async {
    late MotionController clock;
    await tester.pumpWidget(
      host(
        _Clock(
          builder: (c) {
            clock = c;
            return Motion(
              timeline: fadeUp,
              controller: c,
              child: const SizedBox(width: 10, height: 10),
            );
          },
        ),
      ),
    );

    for (final t in [0, 50, 250, 700, 1000, 1450]) {
      clock.seek(0);
      clock.play();
      await tester.pump();
      await tester.pump(Duration(milliseconds: t));
      final playedOpacity = opacityOf(tester),
          playedMatrix = matrixOf(tester).clone();
      clock.pause();

      clock.seek(t.toDouble());
      await tester.pump();
      expect(opacityOf(tester), closeTo(playedOpacity, 1e-9), reason: 't=$t');
      expect(matrixOf(tester).storage, playedMatrix.storage, reason: 't=$t');
    }
  });

  testWidgets('재생 중 child 는 한 번만 빌드된다', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      host(
        Motion(
          timeline: fadeUp,
          child: Builder(
            builder: (_) {
              builds++;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(builds, 1);
    expect(opacityOf(tester), greaterThan(0));
  });

  testWidgets('공유 controller 하나로 위젯 30개가 같은 값을 낸다', (tester) async {
    late MotionController clock;
    await tester.pumpWidget(
      host(
        _Clock(
          builder: (c) {
            clock = c;
            return Column(
              children: [
                for (var i = 0; i < 30; i++)
                  Motion(
                    timeline: fadeUp,
                    controller: c,
                    child: const SizedBox(width: 4, height: 4),
                  ),
              ],
            );
          },
        ),
      ),
    );
    clock.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    final first = opacityOf(tester);
    expect(first, inExclusiveRange(0, 1));
    for (var i = 1; i < 30; i++) {
      expect(opacityOf(tester, i), first);
    }
  });

  testWidgets('controller 가 없으면 autoplay 로 스스로 재생하고, false 면 멈춰 있다', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Motion(timeline: fadeUp, child: SizedBox())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final expected = newMotionValues();
    evaluate(fadeUp, 250, expected);
    expect(
      opacityOf(tester),
      closeTo(expected[MotionProp.opacity.index], 1e-9),
    );
    expect(opacityOf(tester), greaterThan(0));

    await tester.pumpWidget(
      host(
        const Motion(
          key: ValueKey('b'),
          timeline: fadeUp,
          autoplay: false,
          child: SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), 0);
  });

  testWidgets('dispose 하면 Ticker 가 해제된다', (tester) async {
    await tester.pumpWidget(
      host(const Motion(timeline: fadeUp, child: SizedBox())),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(host(const SizedBox()));
    // 활성 Ticker 가 남아 있으면 테스트 종료 시 프레임워크가 실패시킨다.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('disableAnimations 이면 마지막 키프레임 값을 바로 보여 준다', (tester) async {
    await tester.pumpWidget(
      host(
        const Motion(timeline: fadeUp, child: SizedBox()),
        disableAnimations: true,
      ),
    );
    expect(opacityOf(tester), 1);
    expect(matrixOf(tester).getTranslation().y, 0);
  });

  testWidgets('timeline 이 null 이면 child 를 모션 없이 그린다', (tester) async {
    await tester.pumpWidget(
      host(const Motion(timeline: null, child: SizedBox())),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(Transform), findsNothing);
    expect(tester.hasRunningAnimations, isTrue); // 내부 클록은 돌지만 그릴 것이 없다
  });

  testWidgets('타임라인에 없는 속성의 래퍼는 넣지 않는다', (tester) async {
    const rotateOnly = Timeline(
      durationMs: 100,
      tracks: [
        Track(MotionProp.rotate, [Keyframe(0, 0), Keyframe(100, 90)]),
      ],
    );
    await tester.pumpWidget(
      host(const Motion(timeline: rotateOnly, child: SizedBox())),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(Transform), findsOneWidget);
  });

  testWidgets('reverse 는 0 에 닿으면 멈춘다', (tester) async {
    late MotionController clock;
    await tester.pumpWidget(
      host(
        _Clock(
          builder: (c) {
            clock = c;
            return Motion(
              timeline: fadeUp,
              controller: c,
              child: const SizedBox(),
            );
          },
        ),
      ),
    );
    clock
      ..seek(200)
      ..play();
    await tester.pump();
    clock.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.timeMs, 0);
    expect(clock.isPlaying, isFalse);
  });
}

const priceDrop = Timeline(
  durationMs: 1000,
  tracks: [
    Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(1000, 1)]),
  ],
  channels: [
    Channel('price', [Keyframe(0, 4900), Keyframe(1000, 3900)]),
  ],
);

void builderTests() {
  testWidgets('Motion.builder 는 seek 시점의 채널 값을 넘기고, 다른 속성 트랙도 적용한다', (
    tester,
  ) async {
    final seen = <double?>[];
    double? missing = 0;
    late MotionController clock;
    await tester.pumpWidget(
      host(
        _Clock(
          builder: (c) {
            clock = c;
            return Motion.builder(
              timeline: priceDrop,
              controller: c,
              builder: (context, v) {
                seen.add(v['price']);
                missing = v['nope'];
                return const SizedBox();
              },
            );
          },
        ),
      ),
    );
    clock.seek(250);
    await tester.pump();
    expect(seen.last, 4650);
    expect(opacityOf(tester), 0.25);
    expect(missing, isNull);
  });

  testWidgets(
    'Motion.builder: timeline null 이면 빈 값, disableAnimations 면 마지막 값',
    (tester) async {
      double? got = -1;
      Widget b(BuildContext _, MotionChannels v) {
        got = v['price'];
        return const SizedBox();
      }

      await tester.pumpWidget(host(Motion.builder(timeline: null, builder: b)));
      expect(got, isNull);
      await tester.pumpWidget(
        host(
          Motion.builder(
            key: const Key('end'),
            timeline: priceDrop,
            builder: b,
          ),
          disableAnimations: true,
        ),
      );
      expect(got, 3900);
    },
  );
}
