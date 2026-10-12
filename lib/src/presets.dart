import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'curves/spring.dart';
import 'timeline/timeline.dart';

/// 자주 쓰는 타임라인. 값은 웹 데모(`design/motion-demo`)와 같다.
abstract final class MotionPresets {
  // ───────── 등장 ─────────

  static const fadeIn = Timeline(
    durationMs: 600,
    tracks: [
      Track(MotionProp.opacity, [
        Keyframe(0, 0),
        Keyframe(600, 1, curve: Curves.easeOut),
      ]),
    ],
  );

  /// [from] 쪽 바깥(씬 px [distance])에서 미끄러져 들어온다.
  static Timeline slideIn({
    AxisDirection from = AxisDirection.left,
    double distance = 400,
  }) {
    final (prop, sign) = _axis(from);
    return Timeline(
      durationMs: 700,
      tracks: [
        Track(prop, [
          Keyframe(0, sign * distance),
          const Keyframe(700, 0, curve: Curves.easeOutCubic),
        ]),
        const Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(300, 1)]),
      ],
    );
  }

  static const zoomIn = Timeline(
    durationMs: 500,
    tracks: [
      Track(MotionProp.scale, [
        Keyframe(0, 0.8),
        Keyframe(500, 1, curve: Curves.easeOut),
      ]),
      Track(MotionProp.opacity, [
        Keyframe(0, 0),
        Keyframe(500, 1, curve: Curves.easeOut),
      ]),
    ],
  );

  static const pop = Timeline(
    durationMs: 900,
    tracks: [
      Track(MotionProp.scale, [
        Keyframe(0, 0),
        Keyframe(900, 1, curve: SpringCurve(stiffness: 260, damping: 11)),
      ]),
    ],
  );

  static const flipIn = Timeline(
    durationMs: 700,
    tracks: [
      Track(MotionProp.rotateY, [
        Keyframe(0, 90),
        Keyframe(700, 0, curve: Curves.easeOutCubic),
      ]),
      Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(150, 1)]),
    ],
  );

  /// [from] 쪽부터 쓸어 내며 드러난다.
  static Timeline wipeIn({AxisDirection from = AxisDirection.left}) {
    final prop = switch (from) {
      AxisDirection.left => MotionProp.clipRight,
      AxisDirection.right => MotionProp.clipLeft,
      AxisDirection.up => MotionProp.clipBottom,
      AxisDirection.down => MotionProp.clipTop,
    };
    return Timeline(
      durationMs: 800,
      tracks: [
        Track(prop, const [
          Keyframe(0, 1),
          Keyframe(800, 0, curve: Curves.easeInOutCubic),
        ]),
      ],
    );
  }

  static const blurIn = Timeline(
    durationMs: 900,
    tracks: [
      Track(MotionProp.blur, [
        Keyframe(0, 14),
        Keyframe(900, 0, curve: Curves.easeOut),
      ]),
      Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(600, 1)]),
    ],
  );

  /// 아래 중앙에서 솟아오른다.
  static const riseUp = Timeline(
    durationMs: 800,
    origin: FractionalOffset.bottomCenter,
    tracks: [
      Track(MotionProp.scaleY, [
        Keyframe(0, 0),
        Keyframe(800, 1, curve: SpringCurve(stiffness: 300, damping: 14)),
      ]),
      Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(100, 1)]),
    ],
  );

  /// 왼쪽 경첩을 축으로 문처럼 열린다.
  static const doorOpen = Timeline(
    durationMs: 900,
    origin: FractionalOffset.centerLeft,
    tracks: [
      Track(MotionProp.rotateY, [
        Keyframe(0, -90),
        Keyframe(900, 0, curve: Curves.easeOutCubic),
      ]),
      Track(MotionProp.opacity, [Keyframe(0, 0), Keyframe(100, 1)]),
    ],
  );

  // ───────── 반복 주목 ─────────

  static const pulse = Timeline(
    durationMs: 600,
    repeat: MotionRepeat.pingpong,
    tracks: [
      Track(MotionProp.scale, [
        Keyframe(0, 1),
        Keyframe(600, 1.08, curve: Curves.easeInOut),
      ]),
    ],
  );

  static const float = Timeline(
    durationMs: 1200,
    repeat: MotionRepeat.pingpong,
    tracks: [
      Track(MotionProp.translateY, [
        Keyframe(0, 0),
        Keyframe(1200, -12, curve: Curves.easeInOut),
      ]),
    ],
  );

  static const shake = Timeline(
    durationMs: 1800,
    repeat: MotionRepeat.loop,
    tracks: [
      Track(MotionProp.translateX, [
        Keyframe(0, 0),
        Keyframe(80, -10),
        Keyframe(160, 10),
        Keyframe(240, -8),
        Keyframe(320, 8),
        Keyframe(400, -4),
        Keyframe(480, 0),
        Keyframe(1800, 0),
      ]),
    ],
  );

  static const blink = Timeline(
    durationMs: 1000,
    repeat: MotionRepeat.loop,
    tracks: [
      Track(MotionProp.opacity, [
        Keyframe(0, 1),
        Keyframe(600, 0, curve: Threshold(1)),
        Keyframe(1000, 1, curve: Threshold(1)),
      ]),
    ],
  );

  static const shimmer = Timeline(
    durationMs: 2200,
    repeat: MotionRepeat.loop,
    tracks: [
      Track(MotionProp.shimmer, [
        Keyframe(0, 0),
        Keyframe(1000, 1, curve: Curves.easeInOut),
        Keyframe(2200, 1),
      ], color: Color(0xB3FFF4D6)),
    ],
  );

  /// 위 중앙에 매달려 흔들린다.
  static const swing = Timeline(
    durationMs: 1100,
    repeat: MotionRepeat.pingpong,
    origin: FractionalOffset.topCenter,
    tracks: [
      Track(MotionProp.rotate, [
        Keyframe(0, -9),
        Keyframe(1100, 9, curve: Curves.easeInOut),
      ]),
    ],
  );

  /// 아래 중앙을 딛고 젤리처럼 출렁인다.
  static const jelly = Timeline(
    durationMs: 1800,
    repeat: MotionRepeat.loop,
    origin: FractionalOffset.bottomCenter,
    tracks: [
      Track(MotionProp.skewX, [
        Keyframe(0, 0),
        Keyframe(120, -14, curve: Curves.easeOut),
        Keyframe(300, 9, curve: Curves.easeInOut),
        Keyframe(480, -4, curve: Curves.easeInOut),
        Keyframe(650, 0, curve: Curves.easeOut),
        Keyframe(1800, 0),
      ]),
      Track(MotionProp.scaleX, [
        Keyframe(0, 1),
        Keyframe(120, 1.15),
        Keyframe(300, 0.92),
        Keyframe(480, 1.04),
        Keyframe(650, 1),
        Keyframe(1800, 1),
      ]),
      Track(MotionProp.scaleY, [
        Keyframe(0, 1),
        Keyframe(120, 0.88),
        Keyframe(300, 1.08),
        Keyframe(480, 0.97),
        Keyframe(650, 1),
        Keyframe(1800, 1),
      ]),
    ],
  );

  // ───────── 퇴장 (마지막 값에서 멈춘다) ─────────

  static const fadeOut = Timeline(
    durationMs: 400,
    tracks: [
      Track(MotionProp.opacity, [
        Keyframe(0, 1),
        Keyframe(400, 0, curve: Curves.easeIn),
      ]),
    ],
  );

  /// [to] 쪽 바깥(씬 px [distance])으로 미끄러져 나간다.
  static Timeline slideOut({
    AxisDirection to = AxisDirection.right,
    double distance = 400,
  }) {
    final (prop, sign) = _axis(to);
    return Timeline(
      durationMs: 600,
      tracks: [
        Track(prop, [
          const Keyframe(0, 0),
          Keyframe(600, sign * distance, curve: Curves.easeInCubic),
        ]),
        const Track(MotionProp.opacity, [
          Keyframe(0, 1),
          Keyframe(300, 1),
          Keyframe(600, 0),
        ]),
      ],
    );
  }

  static const zoomOut = Timeline(
    durationMs: 400,
    tracks: [
      Track(MotionProp.scale, [
        Keyframe(0, 1),
        Keyframe(400, 0.8, curve: Curves.easeIn),
      ]),
      Track(MotionProp.opacity, [
        Keyframe(0, 1),
        Keyframe(400, 0, curve: Curves.easeIn),
      ]),
    ],
  );

  /// 방향 → (이동 속성, 부호). 씬 좌표는 오른쪽·아래가 +.
  static (MotionProp, double) _axis(AxisDirection d) => switch (d) {
    AxisDirection.left => (MotionProp.translateX, -1),
    AxisDirection.right => (MotionProp.translateX, 1),
    AxisDirection.up => (MotionProp.translateY, -1),
    AxisDirection.down => (MotionProp.translateY, 1),
  };
}
