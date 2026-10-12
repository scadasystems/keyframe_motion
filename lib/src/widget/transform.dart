import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../timeline/timeline.dart';

const _deg = math.pi / 180;

/// 고정 합성 순서: translate · origin · perspective · rotate · rotateX · rotateY · skew · scale · origin⁻¹.
/// origin 은 `Transform.alignment` 가 맡는다(이동과는 교환 가능하므로 결과가 같다).
Matrix4 motionMatrix(Float64List v) {
  final rx = v[MotionProp.rotateX.index], ry = v[MotionProp.rotateY.index];
  final skx = v[MotionProp.skewX.index], sky = v[MotionProp.skewY.index];
  final s = v[MotionProp.scale.index];
  final m = Matrix4.translationValues(
    v[MotionProp.translateX.index],
    v[MotionProp.translateY.index],
    0,
  );
  // 원근 1/1000 은 3D 회전이 있을 때만 의미가 있다.
  if (rx != 0 || ry != 0) m.multiply(Matrix4.identity()..setEntry(3, 2, 0.001));
  m
    ..rotateZ(v[MotionProp.rotate.index] * _deg)
    ..rotateX(rx * _deg)
    ..rotateY(ry * _deg);
  if (skx != 0 || sky != 0) {
    m.multiply(
      Matrix4.identity()
        ..setEntry(0, 1, math.tan(skx * _deg))
        ..setEntry(1, 0, math.tan(sky * _deg)),
    );
  }
  return m..multiply(
    Matrix4.diagonal3Values(
      s * v[MotionProp.scaleX.index],
      s * v[MotionProp.scaleY.index],
      1,
    ),
  );
}

const transformProps = {
  MotionProp.translateX,
  MotionProp.translateY,
  MotionProp.scale,
  MotionProp.scaleX,
  MotionProp.scaleY,
  MotionProp.rotate,
  MotionProp.rotateX,
  MotionProp.rotateY,
  MotionProp.skewX,
  MotionProp.skewY,
};
