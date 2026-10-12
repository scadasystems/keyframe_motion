import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Matrix4 matrixWith(Map<MotionProp, double> values) {
  final v = newMotionValues();
  values.forEach((p, x) => v[p.index] = x);
  return motionMatrix(v);
}

Offset map(Matrix4 m, Offset p) => MatrixUtils.transformPoint(m, p);

void expectOffset(Offset a, Offset b) {
  expect(a.dx, closeTo(b.dx, 1e-9));
  expect(a.dy, closeTo(b.dy, 1e-9));
}

void main() {
  test('효과 없는 값이면 단위 행렬', () {
    expect(matrixWith({}).isIdentity(), isTrue);
  });

  test('이동은 맨 바깥 — 회전한 뒤 이동한다', () {
    final m = matrixWith({MotionProp.rotate: 90, MotionProp.translateX: 10});
    // 회전 먼저: (1,0) → (0,1) → +10 → (10,1). 순서가 바뀌면 (0,11).
    expectOffset(map(m, const Offset(1, 0)), const Offset(10, 1));
  });

  test('scale 이 skew 보다 안쪽 — 확대한 뒤 기울인다', () {
    final m = matrixWith({MotionProp.skewX: 45, MotionProp.scaleX: 2});
    // 확대 먼저: (0,1) → (0,1) → skew → (1,1). 순서가 바뀌면 (2,1).
    expectOffset(map(m, const Offset(0, 1)), const Offset(1, 1));
  });

  test('scale 은 scaleX·scaleY 에 곱해진다', () {
    final m = matrixWith({
      MotionProp.scale: 2,
      MotionProp.scaleX: 1.5,
      MotionProp.scaleY: 0.5,
    });
    expectOffset(map(m, const Offset(1, 1)), const Offset(3, 1));
  });

  test('원근은 3D 회전이 있을 때만 들어간다', () {
    expect(matrixWith({MotionProp.rotate: 30}).entry(3, 2), 0);
    expect(matrixWith({MotionProp.rotateY: 30}).entry(3, 2), isNot(0));
  });

  testWidgets('origin 이 회전 중심을 정한다', (tester) async {
    Future<Offset> topLeftWith(FractionalOffset origin) async {
      final tl = Timeline(
        durationMs: 10,
        origin: origin,
        tracks: const [
          Track(MotionProp.rotate, [Keyframe(0, 90)]),
        ],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Motion(
              key: ValueKey(origin),
              timeline: tl,
              autoplay: false,
              child: const SizedBox(key: Key('box'), width: 100, height: 50),
            ),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byKey(const Key('box')));
      return box.localToGlobal(Offset.zero);
    }

    // 왼쪽 위 기준: 꼭짓점이 제자리
    expectOffset(await topLeftWith(FractionalOffset.topLeft), Offset.zero);
    // 중앙(50,25) 기준 90° 회전: (0,0) → (75,-25)
    expectOffset(
      await topLeftWith(FractionalOffset.center),
      const Offset(75, -25),
    );
    // [x,y] 비율 — 오른쪽 아래(100,50) 기준: (0,0) → (150,-50)
    expectOffset(
      await topLeftWith(const FractionalOffset(1, 1)),
      const Offset(150, -50),
    );
  });
}
