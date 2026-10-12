import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../json/codec.dart';

/// 타임라인 트랙이 움직일 수 있는 속성. 순서(index)는 [evaluate] 출력 버퍼의 위치로 쓰인다.
enum MotionProp {
  opacity,
  translateX,
  translateY,
  scale,
  scaleX,
  scaleY,
  rotate,
  rotateX,
  rotateY,
  skewX,
  skewY,
  clipLeft,
  clipTop,
  clipRight,
  clipBottom,
  tint,
  blur,
  shimmer,
  // 기존 인덱스를 지키려고 새 속성은 끝에 붙인다
  brightness,
  saturate,
  hueRotate,
  translateXRel,
  translateYRel,
  clipCircle,
  feather;

  /// 트랙이 없을 때의 값 — 아무 효과도 없는 상태.
  double get restValue => switch (this) {
    opacity ||
    scale ||
    scaleX ||
    scaleY ||
    brightness ||
    saturate ||
    clipCircle => 1,
    _ => 0,
  };
}

enum MotionRepeat { none, loop, pingpong }

/// [t] 시점(ms)의 값 [v]. [curve] 는 직전 키프레임에서 이 키프레임까지의 구간에 적용된다.
@immutable
class Keyframe {
  const Keyframe(this.t, this.v, {this.curve = Curves.linear});

  final int t;
  final double v;
  final Curve curve;

  @override
  bool operator ==(Object other) =>
      other is Keyframe && other.t == t && other.v == v && other.curve == curve;

  @override
  int get hashCode => Object.hash(t, v, curve);

  @override
  String toString() => 'Keyframe($t, $v, $curve)';
}

@immutable
class Track {
  const Track(this.prop, this.keys, {this.color});

  final MotionProp prop;

  /// t 오름차순, 1개 이상.
  final List<Keyframe> keys;

  /// tint·shimmer 트랙의 색.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is Track &&
      other.prop == prop &&
      other.color == color &&
      listEquals(other.keys, keys);

  @override
  int get hashCode => Object.hash(prop, color, Object.hashAll(keys));
}

/// 그리지 않는 이름 붙은 숫자 트랙 — `Motion.builder` 가 매 프레임 값을 넘긴다(가격 숫자·진행 막대 등).
@immutable
class Channel {
  const Channel(this.name, this.keys);

  final String name;
  final List<Keyframe> keys;

  @override
  bool operator ==(Object other) =>
      other is Channel && other.name == name && listEquals(other.keys, keys);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(keys));
}

/// 요소 하나의 애니메이션. 불변 데이터이고, 시간 단위는 JSON 과 같은 정수 ms.
@immutable
class Timeline {
  const Timeline({
    required this.durationMs,
    required this.tracks,
    this.delayMs = 0,
    this.repeat = MotionRepeat.none,
    this.origin = FractionalOffset.center,
    this.channels = const [],
  });

  final int durationMs;
  final List<Track> tracks;

  /// 첫 재생 전에 한 번만 기다린다. 반복 시에는 다시 기다리지 않는다.
  final int delayMs;
  final MotionRepeat repeat;

  /// 회전·확대·기울이기·뒤집기의 기준점 (요소 크기 비율, 0~1 밖 허용).
  final FractionalOffset origin;

  /// 값 채널. 이름은 타임라인 안에서 겹치지 않는다.
  final List<Channel> channels;

  /// 스키마 v1 JSON 을 엄격하게 읽는다. 실패 시 `MotionFormatException`(JSON 경로 포함).
  factory Timeline.fromJson(Object? json) => decodeTimeline(json);

  /// 플레이어용 — 지원하지 않는 버전·속성·곡선이나 잘못된 입력이면 null (요소는 모션 없이 그린다).
  static Timeline? tryFromJson(Object? json) => tryDecodeTimeline(json);

  Map<String, Object?> toJson() => encodeTimeline(this);

  /// 스태거용 — delay 를 [ms] 만큼 늘린 복사본.
  Timeline delayed(int ms) => Timeline(
    durationMs: durationMs,
    tracks: tracks,
    delayMs: delayMs + ms,
    repeat: repeat,
    origin: origin,
    channels: channels,
  );

  @override
  bool operator ==(Object other) =>
      other is Timeline &&
      other.durationMs == durationMs &&
      other.delayMs == delayMs &&
      other.repeat == repeat &&
      other.origin == origin &&
      listEquals(other.tracks, tracks) &&
      listEquals(other.channels, channels);

  @override
  int get hashCode => Object.hash(
    durationMs,
    delayMs,
    repeat,
    origin,
    Object.hashAll(tracks),
    Object.hashAll(channels),
  );
}
