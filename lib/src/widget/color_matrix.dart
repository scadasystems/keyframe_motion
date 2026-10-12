import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// brightness → saturate → hueRotate → tint 를 `ColorFilter.matrix` 용 4×5 행렬(20개, 이동 열은 0~255) 하나로 합친다.
/// 계수는 CSS Filter Effects 의 brightness·saturate·hue-rotate 와 같다. [tintStrength] 는 tint 색 알파를 이미 곱한 값.
List<double> motionColorMatrix({
  double brightness = 1,
  double saturate = 1,
  double hueRotate = 0,
  Color? tint,
  double tintStrength = 0,
}) {
  final b = brightness < 0 ? 0.0 : brightness;
  final s = saturate < 0 ? 0.0 : saturate;
  final sat = [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s,
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s,
  ];
  final rad = hueRotate * math.pi / 180, c = math.cos(rad), n = math.sin(rad);
  final hue = [
    0.213 + c * 0.787 - n * 0.213,
    0.715 - c * 0.715 - n * 0.715,
    0.072 - c * 0.072 + n * 0.928, //
    0.213 - c * 0.213 + n * 0.143,
    0.715 + c * 0.285 + n * 0.140,
    0.072 - c * 0.072 - n * 0.283,
    0.213 - c * 0.213 - n * 0.787,
    0.715 - c * 0.715 + n * 0.715,
    0.072 + c * 0.928 + n * 0.072,
  ];
  // m = hue · sat · (b·I)
  final m = List<double>.filled(9, 0);
  for (var r = 0; r < 3; r++) {
    for (var k = 0; k < 3; k++) {
      var acc = 0.0;
      for (var j = 0; j < 3; j++) {
        acc += hue[r * 3 + j] * sat[j * 3 + k];
      }
      m[r * 3 + k] = acc * b;
    }
  }
  final a = tint == null ? 0.0 : tintStrength.clamp(0.0, 1.0);
  final keep = 1 - a;
  final tc = tint == null ? const [0.0, 0.0, 0.0] : [tint.r, tint.g, tint.b];
  return [
    m[0] * keep, m[1] * keep, m[2] * keep, 0, tc[0] * 255 * a, //
    m[3] * keep, m[4] * keep, m[5] * keep, 0, tc[1] * 255 * a,
    m[6] * keep, m[7] * keep, m[8] * keep, 0, tc[2] * 255 * a,
    0, 0, 0, 1, 0,
  ];
}
