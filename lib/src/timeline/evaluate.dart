import 'dart:typed_data';

import 'timeline.dart';

final Float64List _rest = Float64List.fromList([
  for (final p in MotionProp.values) p.restValue,
]);

/// [evaluate] 출력 버퍼. `MotionProp.index` 로 읽는다. 요소당 하나 만들어 재사용한다.
Float64List newMotionValues() => Float64List.fromList(_rest);

/// 씬 시간 [t](ms)를 타임라인 내부 시간으로 바꾼다 — delay·repeat·pingpong 처리.
double localTime(Timeline tl, double t) {
  final local = t - tl.delayMs;
  if (local <= 0) return 0;
  final d = tl.durationMs.toDouble();
  if (tl.repeat == MotionRepeat.none) return local < d ? local : d;
  final cycle = (local / d).floor();
  final m = local - cycle * d;
  return tl.repeat == MotionRepeat.pingpong && cycle.isOdd ? d - m : m;
}

/// [t] 시점의 모든 속성 값을 [out] 에 쓴다. 순수 함수이며 매 프레임 할당이 없다.
void evaluate(Timeline tl, double t, Float64List out) {
  out.setAll(0, _rest);
  final lt = localTime(tl, t);
  for (final track in tl.tracks) {
    out[track.prop.index] = _sample(track.keys, lt);
  }
}

/// 재생을 끈 상태(disableAnimations)에서 보여 줄 값 — 각 트랙의 마지막 키프레임.
void evaluateEnd(Timeline tl, Float64List out) {
  out.setAll(0, _rest);
  for (final track in tl.tracks) {
    out[track.prop.index] = track.keys.last.v;
  }
}

/// 값 채널을 [out] 에 `channels` 순서대로 쓴다. [end] 면 각 채널의 마지막 값(disableAnimations).
void evaluateChannels(
  Timeline tl,
  double t,
  Float64List out, {
  bool end = false,
}) {
  final lt = localTime(tl, t);
  for (var i = 0; i < tl.channels.length; i++) {
    final keys = tl.channels[i].keys;
    out[i] = end ? keys.last.v : _sample(keys, lt);
  }
}

double _sample(List<Keyframe> keys, double lt) {
  if (lt <= keys.first.t) return keys.first.v;
  for (var i = 1; i < keys.length; i++) {
    final k = keys[i];
    if (lt < k.t) {
      final p = keys[i - 1];
      return p.v + (k.v - p.v) * k.curve.transform((lt - p.t) / (k.t - p.t));
    }
  }
  return keys.last.v;
}
