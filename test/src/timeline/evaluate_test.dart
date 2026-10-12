import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

double at(Timeline tl, double t, MotionProp p) {
  final out = newMotionValues();
  evaluate(tl, t, out);
  return out[p.index];
}

void main() {
  const fade = Timeline(
    durationMs: 600,
    tracks: [
      Track(MotionProp.opacity, [
        Keyframe(0, 0),
        Keyframe(300, 1, curve: Curves.easeOut),
      ]),
      Track(MotionProp.translateY, [Keyframe(0, 24), Keyframe(600, 0)]),
    ],
  );

  group('키프레임 보간', () {
    test('첫 키 이전·마지막 키 이후는 끝값을 유지한다', () {
      expect(at(fade, -50, MotionProp.opacity), 0);
      expect(at(fade, 300, MotionProp.opacity), 1);
      expect(at(fade, 9999, MotionProp.translateY), 0);
    });

    test('구간 안에서는 해당 키프레임의 곡선을 적용한다', () {
      expect(
        at(fade, 150, MotionProp.opacity),
        closeTo(Curves.easeOut.transform(0.5), 1e-12),
      );
      expect(at(fade, 300, MotionProp.translateY), closeTo(12, 1e-12));
    });

    test('같은 t 의 키프레임 두 개는 그 시점에 뒤쪽 값으로 바로 바뀐다', () {
      const jump = Timeline(
        durationMs: 100,
        tracks: [
          Track(MotionProp.opacity, [
            Keyframe(0, 0),
            Keyframe(50, 0),
            Keyframe(50, 1),
            Keyframe(100, 1),
          ]),
        ],
      );
      expect(at(jump, 49.9, MotionProp.opacity), 0);
      expect(at(jump, 50, MotionProp.opacity), 1);
    });

    test('트랙이 없는 속성은 효과 없는 기본값이다', () {
      expect(at(fade, 100, MotionProp.scale), 1);
      expect(at(fade, 100, MotionProp.scaleX), 1);
      expect(at(fade, 100, MotionProp.rotate), 0);
      expect(at(fade, 100, MotionProp.blur), 0);
    });
  });

  group('localTime', () {
    const base = Timeline(durationMs: 1000, delayMs: 100, tracks: []);

    test('delay 중에는 0 (첫 키프레임 값 유지)', () {
      expect(localTime(base, 50), 0);
      expect(localTime(base, 100), 0);
      expect(at(fade.delayed(200), 150, MotionProp.opacity), 0);
    });

    test('none 은 끝에서 멈춘다', () {
      expect(localTime(base, 600), 500);
      expect(localTime(base, 5000), 1000);
    });

    test('loop 는 delay 없이 [0, duration] 만 반복한다', () {
      const loop = Timeline(
        durationMs: 1000,
        delayMs: 100,
        repeat: MotionRepeat.loop,
        tracks: [],
      );
      expect(localTime(loop, 1100), 0);
      expect(localTime(loop, 1350), 250);
      expect(localTime(loop, 2350), 250);
    });

    test('pingpong 은 홀수 주기에 거꾸로 간다', () {
      const pp = Timeline(
        durationMs: 1000,
        delayMs: 100,
        repeat: MotionRepeat.pingpong,
        tracks: [],
      );
      expect(localTime(pp, 600), 500);
      expect(localTime(pp, 1350), 750);
      expect(localTime(pp, 1600), 500);
      expect(localTime(pp, 2350), 250);
    });
  });

  test('evaluateEnd 는 각 트랙의 마지막 키프레임 값', () {
    final out = newMotionValues();
    evaluateEnd(fade, out);
    expect(out[MotionProp.opacity.index], 1);
    expect(out[MotionProp.translateY.index], 0);
    expect(out[MotionProp.scale.index], 1);
  });

  test('출력 버퍼를 재사용해도 이전 프레임 값이 남지 않는다', () {
    const a = Timeline(
      durationMs: 10,
      tracks: [
        Track(MotionProp.rotate, [Keyframe(0, 90)]),
      ],
    );
    final out = newMotionValues();
    evaluate(a, 0, out);
    evaluate(fade, 0, out);
    expect(out[MotionProp.rotate.index], 0);
  });

  test('데이터 클래스 동등성과 delayed', () {
    const a = Timeline(
      durationMs: 10,
      tracks: [
        Track(MotionProp.opacity, [Keyframe(0, 1)]),
      ],
    );
    const b = Timeline(
      durationMs: 10,
      tracks: [
        Track(MotionProp.opacity, [Keyframe(0, 1)]),
      ],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.delayed(100).delayed(20).delayMs, 120);
    expect(a.delayed(100), isNot(a));
  });
}
