import 'dart:math' as math;

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpringCurve', () {
    const under = SpringCurve(stiffness: 260, damping: 11);
    final critical = SpringCurve(stiffness: 100, damping: 2 * math.sqrt(100));
    const over = SpringCurve(stiffness: 100, damping: 60);

    test('끝점은 정확히 0 과 1, 끝 직전은 1 에 가깝다', () {
      for (final c in [under, critical, over]) {
        expect(c.transform(0), 0);
        expect(c.transform(1), 1);
        expect(c.transform(0.999), closeTo(1, 2e-3), reason: '$c');
      }
    });

    test('저감쇠는 1 을 넘었다가 돌아온다 (pop 의 튀는 느낌)', () {
      final peak = [
        for (var i = 0; i <= 100; i++) under.transform(i / 100),
      ].reduce(math.max);
      expect(peak, greaterThan(1.1));
    });

    test('같은 파라미터의 SpringSimulation 궤적과 같다', () {
      final sim = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 260, damping: 11),
        0,
        1,
        0,
      );
      final settle = under.settleSeconds;
      for (var i = 1; i < 20; i++) {
        final u = i / 20;
        expect(under.transform(u), closeTo(sim.x(u * settle), 1e-12));
      }
    });

    test('세 감쇠 유형 모두 settle 시간이 유한하고 10초 이내', () {
      for (final c in [under, critical, over]) {
        expect(c.settleSeconds, inExclusiveRange(0, 10.002), reason: '$c');
      }
      // 감쇠가 극히 약하면 10초 상한에 걸린다
      expect(
        const SpringCurve(stiffness: 100, damping: 0.01).settleSeconds,
        closeTo(10.001, 1e-9),
      );
    });

    test('동등성은 파라미터로 판단한다', () {
      expect(
        const SpringCurve(stiffness: 1, damping: 2),
        const SpringCurve(stiffness: 1, damping: 2),
      );
      expect(
        const SpringCurve(stiffness: 1, damping: 2),
        isNot(const SpringCurve(stiffness: 1, damping: 2, mass: 2)),
      );
    });
  });

  test('step 은 구간 끝 전까지 0, 끝에서 1', () {
    final step = motionCurves['step']!;
    expect(step.transform(0), 0);
    expect(step.transform(0.999), 0);
    expect(step.transform(1), 1);

    const blink = Timeline(
      durationMs: 1000,
      tracks: [
        Track(MotionProp.opacity, [
          Keyframe(0, 1),
          Keyframe(600, 0, curve: Threshold(1)),
          Keyframe(1000, 1, curve: Threshold(1)),
        ]),
      ],
    );
    final out = newMotionValues();
    evaluate(blink, 599, out);
    expect(out[MotionProp.opacity.index], 1);
    evaluate(blink, 600, out);
    expect(out[MotionProp.opacity.index], 0);
    evaluate(blink, 999, out);
    expect(out[MotionProp.opacity.index], 0);
  });
}
