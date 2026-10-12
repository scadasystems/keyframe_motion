import 'dart:convert';
import 'dart:io';

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// MotionPresets 전부 (방향 함수는 기본값)
final presets = <String, Timeline>{
  'fadeIn': MotionPresets.fadeIn,
  'slideIn': MotionPresets.slideIn(),
  'zoomIn': MotionPresets.zoomIn,
  'pop': MotionPresets.pop,
  'flipIn': MotionPresets.flipIn,
  'wipeIn': MotionPresets.wipeIn(),
  'blurIn': MotionPresets.blurIn,
  'pulse': MotionPresets.pulse,
  'float': MotionPresets.float,
  'shake': MotionPresets.shake,
  'blink': MotionPresets.blink,
  'shimmer': MotionPresets.shimmer,
  'swing': MotionPresets.swing,
  'jelly': MotionPresets.jelly,
  'riseUp': MotionPresets.riseUp,
  'doorOpen': MotionPresets.doorOpen,
  'fadeOut': MotionPresets.fadeOut,
  'slideOut': MotionPresets.slideOut(),
  'zoomOut': MotionPresets.zoomOut,
};

double valueAt(Timeline tl, MotionProp p, double t) {
  final out = newMotionValues();
  evaluate(tl, t, out);
  return out[p.index];
}

void main() {
  test('모든 프리셋이 JSON 문자열 왕복 후에도 같다', () {
    for (final MapEntry(:key, :value) in presets.entries) {
      final back = Timeline.fromJson(jsonDecode(jsonEncode(value.toJson())));
      expect(back, value, reason: key);
    }
  });

  test('웹 데모에 있는 프리셋은 데모 타임라인과 같다', () {
    final demo = {
      for (final d
          in jsonDecode(
                File('test/fixtures/demo_timelines.json').readAsStringSync(),
              )
              as List)
        d['id'] as String: Timeline.fromJson(d['elements'][0]['timeline']),
    };
    final shared = presets.keys.where(demo.containsKey).toList();
    expect(shared, hasLength(16)); // 퇴장 3종만 데모에 없다
    for (final id in shared) {
      expect(presets[id], demo[id], reason: id);
    }
  });

  test('방향 인자가 이동·클립 속성을 고른다', () {
    final up = MotionPresets.slideIn(from: AxisDirection.up, distance: 50);
    expect(valueAt(up, MotionProp.translateY, 0), -50);
    expect(valueAt(up, MotionProp.translateX, 0), 0);
    expect(
      valueAt(
        MotionPresets.slideOut(to: AxisDirection.left),
        MotionProp.translateX,
        600,
      ),
      -400,
    );
    final fromBottom = MotionPresets.wipeIn(from: AxisDirection.down);
    expect(valueAt(fromBottom, MotionProp.clipTop, 0), 1);
    expect(valueAt(fromBottom, MotionProp.clipTop, 800), 0);
  });

  test('퇴장은 끝난 뒤 숨은 상태로 남는다', () {
    for (final tl in [
      MotionPresets.fadeOut,
      MotionPresets.slideOut(),
      MotionPresets.zoomOut,
    ]) {
      expect(valueAt(tl, MotionProp.opacity, 99999), 0);
    }
  });
}
