import 'dart:math' as math;

import 'package:keyframe_motion/src/widget/color_matrix.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 0~1 RGB 에 4×5 행렬(이동 열 0~255)을 적용한다.
List<double> apply(List<double> m, List<double> c) => [
  for (var r = 0; r < 3; r++)
    m[r * 5] * c[0] +
        m[r * 5 + 1] * c[1] +
        m[r * 5 + 2] * c[2] +
        m[r * 5 + 4] / 255,
];

// CSS Filter Effects 정의를 그대로 옮긴 기준값
List<double> cssSaturate(List<double> c, double s) => [
  (0.213 + 0.787 * s) * c[0] +
      (0.715 - 0.715 * s) * c[1] +
      (0.072 - 0.072 * s) * c[2],
  (0.213 - 0.213 * s) * c[0] +
      (0.715 + 0.285 * s) * c[1] +
      (0.072 - 0.072 * s) * c[2],
  (0.213 - 0.213 * s) * c[0] +
      (0.715 - 0.715 * s) * c[1] +
      (0.072 + 0.928 * s) * c[2],
];

List<double> cssHue(List<double> c, double deg) {
  final a = deg * math.pi / 180, cs = math.cos(a), sn = math.sin(a);
  return [
    (0.213 + cs * 0.787 - sn * 0.213) * c[0] +
        (0.715 - cs * 0.715 - sn * 0.715) * c[1] +
        (0.072 - cs * 0.072 + sn * 0.928) * c[2],
    (0.213 - cs * 0.213 + sn * 0.143) * c[0] +
        (0.715 + cs * 0.285 + sn * 0.140) * c[1] +
        (0.072 - cs * 0.072 - sn * 0.283) * c[2],
    (0.213 - cs * 0.213 - sn * 0.787) * c[0] +
        (0.715 - cs * 0.715 + sn * 0.715) * c[1] +
        (0.072 + cs * 0.928 + sn * 0.072) * c[2],
  ];
}

void expectRgb(List<double> a, List<double> b) {
  for (var i = 0; i < 3; i++) {
    expect(a[i], closeTo(b[i], 1e-9), reason: 'channel $i: $a vs $b');
  }
}

void main() {
  const c = [0.2, 0.4, 0.6];

  test('기본값이면 단위 행렬', () {
    expect(motionColorMatrix(), [
      for (var i = 0; i < 20; i++) i % 6 == 0 ? 1 : 0,
    ]);
  });

  test('각 속성 단독이 CSS 공식과 같다', () {
    expectRgb(apply(motionColorMatrix(brightness: 1.5), c), [0.3, 0.6, 0.9]);
    expectRgb(apply(motionColorMatrix(saturate: 0), c), cssSaturate(c, 0));
    expectRgb(apply(motionColorMatrix(saturate: 1.8), c), cssSaturate(c, 1.8));
    expectRgb(apply(motionColorMatrix(hueRotate: 137), c), cssHue(c, 137));
  });

  test('합성 순서는 brightness → saturate → hueRotate → tint', () {
    final expected = cssHue(cssSaturate([0.3, 0.6, 0.9], 0.4), 60);
    final tint = [1.0, 0.0, 0.0];
    final mixed = [
      for (var i = 0; i < 3; i++) expected[i] * 0.75 + tint[i] * 0.25,
    ];
    expectRgb(
      apply(
        motionColorMatrix(
          brightness: 1.5,
          saturate: 0.4,
          hueRotate: 60,
          tint: const Color(0xFFFF0000),
          tintStrength: 0.25,
        ),
        c,
      ),
      mixed,
    );
  });

  test('tint 1 이면 원래 색과 상관없이 정확히 그 색', () {
    const red = Color(0xFFFF2D2D);
    final m = motionColorMatrix(brightness: 2, tint: red, tintStrength: 1);
    expectRgb(apply(m, c), [red.r, red.g, red.b]);
    expect(m.sublist(15), [0, 0, 0, 1, 0]); // 알파는 그대로
  });
}
