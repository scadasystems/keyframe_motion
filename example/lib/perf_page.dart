import 'dart:convert';

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 씬 하나에 요소 N개를 공유 클록으로 동시 재생하고 FrameTiming 으로 프레임 시간을 잰다.
/// 결과는 화면과 로그(`MOTION_PERF {json}`)에 남는다 — `adb logcat` 이나 `flutter run` 출력에서 수집.
class PerfPage extends StatefulWidget {
  const PerfPage({super.key});

  @override
  State<PerfPage> createState() => _PerfPageState();
}

/// 측정 조합. transformClip 은 opacity+transform+clip, effects 는 blur·shimmer·tint 를 포함한 씬, extras 는 색 행렬·상대 이동·원형 clip·feather.
enum EffectSet { opacityTransform, transform3d, transformClip, effects, extras }

const _full = MotionQualityLevel.full, _reduced = MotionQualityLevel.reduced;

const _sweep = [
  (10, EffectSet.opacityTransform, _full),
  (30, EffectSet.opacityTransform, _full),
  (60, EffectSet.opacityTransform, _full),
  (30, EffectSet.transform3d, _full),
  (30, EffectSet.transformClip, _full),
  (10, EffectSet.effects, _full),
  (30, EffectSet.effects, _full),
  (30, EffectSet.effects, _reduced),
  (30, EffectSet.extras, _full),
  (30, EffectSet.extras, _reduced),
];

const _wipe = Timeline(
  durationMs: 1000,
  repeat: MotionRepeat.pingpong,
  tracks: [
    Track(MotionProp.clipRight, [
      Keyframe(0, 0),
      Keyframe(1000, 1, curve: Curves.easeInOutCubic),
    ]),
  ],
);

const _warmup = Duration(seconds: 2);
const _measure = Duration(seconds: 10);

List<Timeline> _timelinesFor(EffectSet set) => switch (set) {
  EffectSet.opacityTransform => const [
    Timeline(
      durationMs: 600,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.scale, [
          Keyframe(0, 1),
          Keyframe(600, 1.08, curve: Curves.easeInOut),
        ]),
      ],
    ),
    Timeline(
      durationMs: 1200,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.translateY, [
          Keyframe(0, 0),
          Keyframe(1200, -6, curve: Curves.easeInOut),
        ]),
      ],
    ),
    Timeline(
      durationMs: 1400,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.opacity, [
          Keyframe(0, 0.45),
          Keyframe(1400, 1, curve: Curves.easeInOut),
        ]),
      ],
    ),
    Timeline(
      durationMs: 1200,
      repeat: MotionRepeat.loop,
      tracks: [
        Track(MotionProp.rotate, [Keyframe(0, 0), Keyframe(1200, 360)]),
      ],
    ),
    Timeline(
      durationMs: 900,
      repeat: MotionRepeat.loop,
      tracks: [
        Track(MotionProp.translateX, [
          Keyframe(0, -30),
          Keyframe(500, 0, curve: Curves.easeOutCubic),
          Keyframe(900, 0),
        ]),
        Track(MotionProp.opacity, [
          Keyframe(0, 0),
          Keyframe(300, 1),
          Keyframe(900, 1),
        ]),
      ],
    ),
  ],
  EffectSet.transformClip => [
    ..._timelinesFor(EffectSet.opacityTransform),
    _wipe,
    const Timeline(
      durationMs: 700,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.clipLeft, [Keyframe(0, 0.5), Keyframe(700, 0)]),
        Track(MotionProp.clipRight, [Keyframe(0, 0.5), Keyframe(700, 0)]),
      ],
    ),
  ],
  EffectSet.effects => const [
    MotionPresets.shimmer,
    Timeline(
      durationMs: 1400,
      repeat: MotionRepeat.loop,
      tracks: [
        Track(MotionProp.tint, [
          Keyframe(0, 0),
          Keyframe(250, 0.65, curve: Curves.easeOut),
          Keyframe(900, 0, curve: Curves.easeIn),
          Keyframe(1400, 0),
        ], color: Color(0xFFFF2D2D)),
      ],
    ),
    Timeline(
      durationMs: 900,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.blur, [
          Keyframe(0, 0),
          Keyframe(900, 8, curve: Curves.easeInOut),
        ]),
      ],
    ),
    _wipe,
  ],
  EffectSet.extras => const [
    Timeline(
      durationMs: 1600,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.saturate, [Keyframe(0, 1), Keyframe(1600, 0)]),
        Track(MotionProp.hueRotate, [Keyframe(0, 0), Keyframe(1600, 90)]),
      ],
    ),
    Timeline(
      durationMs: 1000,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.clipCircle, [
          Keyframe(0, 0.2),
          Keyframe(1000, 1, curve: Curves.easeInOut),
        ]),
      ],
    ),
    Timeline(
      durationMs: 1000,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.clipRight, [
          Keyframe(0, 0),
          Keyframe(1000, 1, curve: Curves.easeInOutCubic),
        ]),
        Track(MotionProp.feather, [Keyframe(0, 0.3)]),
      ],
    ),
    Timeline(
      durationMs: 900,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.translateXRel, [
          Keyframe(0, -0.2),
          Keyframe(900, 0, curve: Curves.easeOutCubic),
        ]),
        Track(MotionProp.brightness, [Keyframe(0, 1), Keyframe(900, 1.4)]),
      ],
    ),
  ],
  EffectSet.transform3d => const [
    Timeline(
      durationMs: 1400,
      repeat: MotionRepeat.pingpong,
      tracks: [
        Track(MotionProp.rotateY, [
          Keyframe(0, -60),
          Keyframe(1400, 60, curve: Curves.easeInOut),
        ]),
      ],
    ),
    Timeline(
      durationMs: 1800,
      repeat: MotionRepeat.loop,
      origin: FractionalOffset.bottomCenter,
      tracks: [
        Track(MotionProp.skewX, [
          Keyframe(0, 0),
          Keyframe(120, -14),
          Keyframe(300, 9),
          Keyframe(480, -4),
          Keyframe(650, 0),
          Keyframe(1800, 0),
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
    ),
    Timeline(
      durationMs: 1100,
      repeat: MotionRepeat.pingpong,
      origin: FractionalOffset.topCenter,
      tracks: [
        Track(MotionProp.rotate, [
          Keyframe(0, -9),
          Keyframe(1100, 9, curve: Curves.easeInOut),
        ]),
      ],
    ),
  ],
};

class _Result {
  _Result(this.count, this.set, this.quality, List<FrameTiming> frames)
    : n = frames.length,
      buildP90 = _p90(frames.map((f) => f.buildDuration)),
      rasterP90 = _p90(frames.map((f) => f.rasterDuration)),
      totalP90 = _p90(frames.map((f) => f.totalSpan)),
      over33 = frames.isEmpty
          ? 0
          : frames.where((f) => f.totalSpan.inMicroseconds > 33000).length /
                frames.length;

  final int count;
  final EffectSet set;
  final MotionQualityLevel quality;
  final int n;
  final double buildP90, rasterP90, totalP90, over33;

  // 측정 시간 동안 들어온 프레임 수 → 평균 fps
  double get fps => n / _measure.inMilliseconds * 1000;

  static double _p90(Iterable<Duration> ds) {
    final xs = ds.map((d) => d.inMicroseconds / 1000).toList()..sort();
    return xs.isEmpty ? 0 : xs[((xs.length - 1) * 0.9).round()];
  }

  bool get pass => totalP90 < 33 && over33 < 0.05;

  Map<String, Object> toJson() => {
    'count': count,
    'set': set.name,
    'quality': quality.name,
    'frames': n,
    'fps': double.parse(fps.toStringAsFixed(1)),
    'buildP90': double.parse(buildP90.toStringAsFixed(2)),
    'rasterP90': double.parse(rasterP90.toStringAsFixed(2)),
    'totalP90': double.parse(totalP90.toStringAsFixed(2)),
    'over33': double.parse((over33 * 100).toStringAsFixed(2)),
    'pass': pass,
  };
}

class _PerfPageState extends State<PerfPage>
    with SingleTickerProviderStateMixin {
  late final MotionController _clock = MotionController(vsync: this)..play();
  int _count = 30;
  EffectSet _set = EffectSet.opacityTransform;
  MotionQualityLevel _quality = _full;
  final List<_Result> _results = [];
  String _status = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSweep());
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _runSweep() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results.clear();
    });
    for (final (count, set, quality) in _sweep) {
      if (!mounted) return;
      setState(() {
        _count = count;
        _set = set;
        _quality = quality;
        _status = '측정 중: ${set.name} × $count (${quality.name})';
      });
      await Future<void>.delayed(_warmup);
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> t) => frames.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      await Future<void>.delayed(_measure);
      SchedulerBinding.instance.removeTimingsCallback(collect);
      final r = _Result(count, set, quality, frames);
      debugPrint('MOTION_PERF ${jsonEncode(r.toJson())}');
      if (mounted) setState(() => _results.add(r));
    }
    debugPrint('MOTION_PERF_DONE');
    if (mounted) {
      setState(() {
        _running = false;
        _status = '완료';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timelines = _timelinesFor(_set);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1015),
      body: Stack(
        children: [
          // 480×270 씬 좌표 캔버스를 화면에 맞춰 통째로 키운다 — 플레이어와 같은 방식
          Positioned.fill(
            child: FittedBox(
              child: SizedBox(
                width: 480,
                height: 270,
                child: MotionQuality(
                  level: _quality,
                  child: Stack(
                    children: [
                      for (var i = 0; i < _count; i++)
                        Positioned(
                          left: 6 + (i % 10) * 47.4,
                          top: 8 + (i ~/ 10) * 43.0,
                          width: 40,
                          height: 32,
                          child: Motion(
                            timeline: timelines[i % timelines.length],
                            controller: _clock,
                            child: _Tile(index: i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                color: const Color(0xCC000000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_status),
                    for (final r in _results)
                      Text(
                        '${r.set.name.padRight(16)} ×${r.count.toString().padLeft(2)} ${r.quality.name.padRight(7)}  '
                        '${r.fps.toStringAsFixed(1)}fps  p90 ${r.totalP90.toStringAsFixed(1)}ms  '
                        '>33ms ${(r.over33 * 100).toStringAsFixed(1)}%  ${r.pass ? 'PASS' : 'FAIL'}',
                      ),
                    if (!_running)
                      TextButton(
                        onPressed: _runSweep,
                        child: const Text('다시 측정'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xFFF59E0B),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        '₩${4900 + index * 100}',
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
      ),
    ),
  );
}
