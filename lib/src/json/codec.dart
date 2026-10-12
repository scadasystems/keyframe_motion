import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../curves/curve_names.dart';
import '../curves/spring.dart';
import '../timeline/timeline.dart';

/// 스키마 v1 위반. [path] 는 `$.tracks[1].keys[0].t` 처럼 문제가 된 JSON 위치.
class MotionFormatException extends FormatException {
  MotionFormatException(this.path, String message) : super('$path: $message');

  final String path;
}

const supportedSchemaVersion = 1;

const Map<String, FractionalOffset> _origins = {
  'topLeft': FractionalOffset.topLeft,
  'topCenter': FractionalOffset.topCenter,
  'topRight': FractionalOffset.topRight,
  'centerLeft': FractionalOffset.centerLeft,
  'center': FractionalOffset.center,
  'centerRight': FractionalOffset.centerRight,
  'bottomLeft': FractionalOffset.bottomLeft,
  'bottomCenter': FractionalOffset.bottomCenter,
  'bottomRight': FractionalOffset.bottomRight,
};

const _colorProps = {MotionProp.tint, MotionProp.shimmer};
final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

Never _fail(String path, String message) =>
    throw MotionFormatException(path, message);

Map<String, Object?> _object(Object? v, String path) =>
    v is Map<String, Object?> ? v : _fail(path, '객체여야 합니다');

bool _isNum(Object? v) => v is num && v.isFinite;

/// 서버 데이터를 읽는다 — 검증 실패 시 [MotionFormatException].
Timeline decodeTimeline(Object? json, [String path = r'$']) {
  final j = _object(json, path);
  final v = j['v'];
  if (v != supportedSchemaVersion) {
    _fail(
      '$path.v',
      v is int && v > supportedSchemaVersion
          ? '지원하지 않는 스키마 버전 $v (이 엔진은 $supportedSchemaVersion)'
          : '1 이어야 합니다',
    );
  }
  final duration = j['durationMs'];
  if (duration is! int || duration <= 0) {
    _fail('$path.durationMs', '양의 정수(ms)여야 합니다');
  }
  final delay = j['delayMs'] ?? 0;
  if (delay is! int || delay < 0) _fail('$path.delayMs', '0 이상 정수여야 합니다');
  final repeatName = j['repeat'] ?? 'none';
  final repeat =
      MotionRepeat.values.where((r) => r.name == repeatName).firstOrNull ??
      _fail('$path.repeat', '"none" | "loop" | "pingpong" 중 하나');
  final tracksJson = j['tracks'];
  if (tracksJson is! List) _fail('$path.tracks', '배열이어야 합니다');

  return Timeline(
    durationMs: duration,
    delayMs: delay,
    repeat: repeat,
    origin: _decodeOrigin(j['origin'], '$path.origin'),
    tracks: [
      for (var i = 0; i < tracksJson.length; i++)
        _decodeTrack(tracksJson[i], '$path.tracks[$i]', duration),
    ],
    channels: _decodeChannels(j['channels'], '$path.channels', duration),
  );
}

List<Channel> _decodeChannels(Object? json, String path, int duration) {
  if (json == null) return const [];
  if (json is! List) _fail(path, '배열이어야 합니다');
  final seen = <String>{};
  return [
    for (var i = 0; i < json.length; i++)
      () {
        final cp = '$path[$i]';
        final c = _object(json[i], cp);
        final name = c['name'];
        if (name is! String || name.isEmpty) {
          _fail('$cp.name', '비어 있지 않은 문자열이어야 합니다');
        }
        if (!seen.add(name)) _fail('$cp.name', '이름 "$name" 이 겹칩니다');
        return Channel(name, _decodeKeys(c['keys'], '$cp.keys', duration));
      }(),
  ];
}

/// 플레이어용 — 지원하지 않는 버전·속성·곡선을 포함해 어떤 실패든 null.
Timeline? tryDecodeTimeline(Object? json) {
  try {
    return decodeTimeline(json);
  } on FormatException {
    return null;
  }
}

FractionalOffset _decodeOrigin(Object? o, String path) {
  if (o == null) return FractionalOffset.center;
  if (o is String) return _origins[o] ?? _fail(path, '알 수 없는 기준점 "$o"');
  if (o is List && o.length == 2 && o.every(_isNum)) {
    return FractionalOffset((o[0] as num).toDouble(), (o[1] as num).toDouble());
  }
  _fail(path, '9방향 이름 또는 [x, y]');
}

Track _decodeTrack(Object? json, String path, int duration) {
  final t = _object(json, path);
  final propName = t['prop'];
  final prop =
      MotionProp.values.where((p) => p.name == propName).firstOrNull ??
      _fail('$path.prop', '알 수 없는 속성 "$propName"');
  final colorJson = t['color'];
  Color? color;
  if (colorJson != null) {
    if (!_colorProps.contains(prop)) {
      _fail('$path.color', 'tint·shimmer 트랙에서만 허용');
    }
    if (colorJson is! String || !_hex.hasMatch(colorJson)) {
      _fail('$path.color', '#RRGGBB 또는 #AARRGGBB');
    }
    final hex = colorJson.substring(1);
    color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
  }
  return Track(
    prop,
    _decodeKeys(t['keys'], '$path.keys', duration),
    color: color,
  );
}

List<Keyframe> _decodeKeys(Object? keysJson, String path, int duration) {
  if (keysJson is! List || keysJson.isEmpty) {
    _fail(path, '키프레임이 1개 이상 필요합니다');
  }
  var prev = -1;
  final keys = <Keyframe>[];
  for (var n = 0; n < keysJson.length; n++) {
    final kp = '$path[$n]';
    final k = _object(keysJson[n], kp);
    final time = k['t'];
    if (time is! int || time < 0 || time > duration) {
      _fail('$kp.t', '0~durationMs 정수여야 합니다');
    }
    if (time < prev) _fail('$kp.t', '시간이 오름차순이어야 합니다');
    prev = time;
    final value = k['v'];
    if (!_isNum(value)) _fail('$kp.v', '숫자여야 합니다');
    keys.add(
      Keyframe(
        time,
        (value as num).toDouble(),
        curve: _decodeCurve(k['curve'], '$kp.curve'),
      ),
    );
  }
  return keys;
}

Curve _decodeCurve(Object? c, String path) {
  if (c == null) return Curves.linear;
  if (c is String) return motionCurves[c] ?? _fail(path, '알 수 없는 곡선 "$c"');
  final spring = c is Map ? c['spring'] : null;
  if (spring is Map) {
    final k = spring['stiffness'],
        d = spring['damping'],
        m = spring['mass'] ?? 1;
    if (_isNum(k) &&
        _isNum(d) &&
        _isNum(m) &&
        (k as num) > 0 &&
        (d as num) > 0 &&
        (m as num) > 0) {
      return SpringCurve(
        stiffness: k.toDouble(),
        damping: d.toDouble(),
        mass: m.toDouble(),
      );
    }
  }
  _fail(path, '{ "spring": { stiffness>0, damping>0, mass? } }');
}

Map<String, Object?> encodeTimeline(Timeline tl) => {
  'v': supportedSchemaVersion,
  'delayMs': tl.delayMs,
  'durationMs': tl.durationMs,
  'repeat': tl.repeat.name,
  if (tl.origin != FractionalOffset.center) 'origin': _encodeOrigin(tl.origin),
  'tracks': [
    for (final t in tl.tracks)
      {
        'prop': t.prop.name,
        if (t.color != null) 'color': _encodeColor(t.color!),
        'keys': _encodeKeys(t.keys),
      },
  ],
  if (tl.channels.isNotEmpty)
    'channels': [
      for (final c in tl.channels)
        {'name': c.name, 'keys': _encodeKeys(c.keys)},
    ],
};

List<Map<String, Object?>> _encodeKeys(List<Keyframe> keys) => [
  for (final k in keys)
    {
      't': k.t,
      'v': _num(k.v),
      if (k.curve != Curves.linear) 'curve': _encodeCurve(k.curve),
    },
];

/// 정수인 값은 정수로 — VM 은 `14.0`, 웹은 `14` 로 써서 복사한 JSON 이 플랫폼마다 달라지는 것을 막는다.
num _num(double x) =>
    x == x.truncateToDouble() && x.abs() < 1e15 ? x.toInt() : x;

Object _encodeOrigin(FractionalOffset o) {
  for (final e in _origins.entries) {
    if (e.value == o) return e.key;
  }
  return [_num(o.dx), _num(o.dy)];
}

String _encodeColor(Color c) {
  final argb = c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  return argb.startsWith('FF') ? '#${argb.substring(2)}' : '#$argb';
}

Object _encodeCurve(Curve c) {
  if (c is SpringCurve) {
    return {
      'spring': {
        'stiffness': _num(c.stiffness),
        'damping': _num(c.damping),
        if (c.mass != 1) 'mass': _num(c.mass),
      },
    };
  }
  for (final e in motionCurves.entries) {
    if (identical(e.value, c)) return e.key;
  }
  if (c is Threshold && c.threshold == 1) return 'step';
  throw ArgumentError.value(
    c,
    'curve',
    'JSON 으로 표현할 수 없는 곡선 (motionCurves 또는 SpringCurve 만 가능)',
  );
}
