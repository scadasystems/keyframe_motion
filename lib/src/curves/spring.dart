import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// 0→1 스프링 궤적을 settle 시간까지 정규화한 곡선. 키프레임 구간 길이가 곧 스프링 재생 시간이다.
///
/// settle: 1ms 간격으로 10초까지 보며 |x−1| > 1e-3 또는 |v| > 1e-2 인 마지막 시점 + 1ms.
/// 웹 데모 엔진(`design/motion-demo`)도 같은 규칙을 쓴다.
class SpringCurve extends Curve {
  const SpringCurve({
    required this.stiffness,
    required this.damping,
    this.mass = 1,
  });

  final double stiffness;
  final double damping;
  final double mass;

  static final Map<(double, double, double), (SpringSimulation, double)>
  _cache = {};

  (SpringSimulation, double) get _resolved =>
      _cache[(stiffness, damping, mass)] ??= _build();

  (SpringSimulation, double) _build() {
    final sim = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0,
      1,
      0,
    );
    var last = -1;
    for (var i = 0; i <= 10000; i++) {
      final s = i / 1000;
      if ((sim.x(s) - 1).abs() > 1e-3 || sim.dx(s).abs() > 1e-2) last = i;
    }
    return (sim, (last + 1) / 1000);
  }

  /// 정규화 전 스프링이 멈추기까지의 시간(초). 상한 10.001초.
  double get settleSeconds => _resolved.$2;

  @override
  double transformInternal(double t) {
    final (sim, settle) = _resolved;
    return sim.x(t * settle);
  }

  @override
  bool operator ==(Object other) =>
      other is SpringCurve &&
      other.stiffness == stiffness &&
      other.damping == damping &&
      other.mass == mass;

  @override
  int get hashCode => Object.hash(stiffness, damping, mass);

  @override
  String toString() =>
      'SpringCurve(stiffness: $stiffness, damping: $damping, mass: $mass)';
}
