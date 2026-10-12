import 'dart:convert';

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 프리셋을 고르거나 JSON 을 고쳐 바로 재생해 보는 화면. 웹·단말 둘 다 돈다.
///
/// 같은 시점 비교용 쿼리: `/lab?preset=blurIn&t=300&q=reduced` → 그 시점에 멈춘 채로 연다.
/// 웹은 `#/lab?...`, Android 는 `adb shell am start ... --es route '/lab?...'`.
class LabPage extends StatefulWidget {
  const LabPage({super.key, this.query = const {}});

  final Map<String, String> query;

  @override
  State<LabPage> createState() => _LabPageState();
}

/// 랩·갤러리가 같이 쓰는 목록
final presets = <String, Timeline>{
  'fadeIn': MotionPresets.fadeIn,
  'slideIn': MotionPresets.slideIn(),
  'zoomIn': MotionPresets.zoomIn,
  'pop': MotionPresets.pop,
  'flipIn': MotionPresets.flipIn,
  'wipeIn': MotionPresets.wipeIn(),
  'blurIn': MotionPresets.blurIn,
  'riseUp': MotionPresets.riseUp,
  'doorOpen': MotionPresets.doorOpen,
  'pulse': MotionPresets.pulse,
  'float': MotionPresets.float,
  'shake': MotionPresets.shake,
  'blink': MotionPresets.blink,
  'shimmer': MotionPresets.shimmer,
  'swing': MotionPresets.swing,
  'jelly': MotionPresets.jelly,
  'fadeOut': MotionPresets.fadeOut,
  'slideOut': MotionPresets.slideOut(),
  'zoomOut': MotionPresets.zoomOut,
  // 랩 전용 tint 예시 (프리셋 아님, 웹 데모 saleFlash 와 같은 값)
  'saleFlash': Timeline.fromJson(const {
    'v': 1,
    'durationMs': 1400,
    'repeat': 'loop',
    'tracks': [
      {
        'prop': 'tint',
        'color': '#FF2D2D',
        'keys': [
          {'t': 0, 'v': 0},
          {'t': 250, 'v': 0.65, 'curve': 'easeOut'},
          {'t': 900, 'v': 0, 'curve': 'easeIn'},
          {'t': 1400, 'v': 0},
        ],
      },
    ],
  }),
  // 색 행렬·상대 이동·원형 clip·feather·값 채널 예시 (프리셋 아님, 웹 데모와 같은 값)
  'soldOut': _json(
    r'{"v":1,"delayMs":0,"durationMs":3600,"repeat":"loop","tracks":[{"prop":"saturate","keys":[{"t":0,"v":1},{"t":600,"v":1},{"t":1200,"v":0,"curve":"easeInOut"},{"t":3000,"v":0},{"t":3600,"v":1,"curve":"easeInOut"}]}]}',
  ),
  'flash': _json(
    r'{"v":1,"delayMs":0,"durationMs":1600,"repeat":"loop","tracks":[{"prop":"brightness","keys":[{"t":0,"v":1},{"t":200,"v":1.7,"curve":"easeOut"},{"t":700,"v":1,"curve":"easeIn"},{"t":1600,"v":1}]}]}',
  ),
  'hueCycle': _json(
    r'{"v":1,"delayMs":0,"durationMs":6000,"repeat":"loop","tracks":[{"prop":"hueRotate","keys":[{"t":0,"v":0},{"t":6000,"v":360}]}]}',
  ),
  'grayTint': _json(
    r'{"v":1,"delayMs":0,"durationMs":1600,"repeat":"loop","tracks":[{"prop":"saturate","keys":[{"t":0,"v":0}]},{"prop":"brightness","keys":[{"t":0,"v":1.2}]},{"prop":"tint","color":"#FF2D2D","keys":[{"t":0,"v":0},{"t":800,"v":0.5,"curve":"easeOut"},{"t":1600,"v":0,"curve":"easeIn"}]}]}',
  ),
  'slideInRel': _json(
    r'{"v":1,"delayMs":0,"durationMs":700,"repeat":"none","tracks":[{"prop":"translateXRel","keys":[{"t":0,"v":-1},{"t":700,"v":0,"curve":"easeOutCubic"}]},{"prop":"opacity","keys":[{"t":0,"v":0},{"t":300,"v":1}]}]}',
  ),
  'irisIn': _json(
    r'{"v":1,"delayMs":0,"durationMs":3800,"repeat":"loop","tracks":[{"prop":"clipCircle","keys":[{"t":0,"v":0},{"t":700,"v":1,"curve":"easeOutCubic"},{"t":2600,"v":1},{"t":3200,"v":0,"curve":"easeInCubic"}]}]}',
  ),
  'irisCorner': _json(
    r'{"v":1,"delayMs":0,"durationMs":3800,"repeat":"loop","origin":"topLeft","tracks":[{"prop":"clipCircle","keys":[{"t":0,"v":0},{"t":900,"v":1,"curve":"easeOutCubic"},{"t":2600,"v":1},{"t":3200,"v":0,"curve":"easeInCubic"}]}]}',
  ),
  'featherWipe': _json(
    r'{"v":1,"delayMs":0,"durationMs":4000,"repeat":"loop","tracks":[{"prop":"clipRight","keys":[{"t":0,"v":1},{"t":1400,"v":0,"curve":"easeInOutCubic"},{"t":2600,"v":0},{"t":3400,"v":1,"curve":"easeInOutCubic"}]},{"prop":"feather","keys":[{"t":0,"v":0.3}]}]}',
  ),
  'featherBox': _json(
    r'{"v":1,"delayMs":0,"durationMs":2000,"repeat":"loop","tracks":[{"prop":"clipTop","keys":[{"t":0,"v":1},{"t":1000,"v":0,"curve":"easeOutCubic"}]},{"prop":"clipLeft","keys":[{"t":0,"v":0.5},{"t":1000,"v":0,"curve":"easeOutCubic"}]},{"prop":"feather","keys":[{"t":0,"v":0.25}]}]}',
  ),
  'priceDrop': _json(
    r'{"v":1,"delayMs":0,"durationMs":4000,"repeat":"loop","tracks":[{"prop":"scale","keys":[{"t":0,"v":1},{"t":1500,"v":1},{"t":1700,"v":1.08,"curve":"easeOut"},{"t":2000,"v":1,"curve":"easeIn"},{"t":4000,"v":1}]}],"channels":[{"name":"price","keys":[{"t":0,"v":4900},{"t":600,"v":4900},{"t":1600,"v":3900,"curve":"easeOutCubic"},{"t":4000,"v":3900}]}]}',
  ),
};

Timeline _json(String s) => Timeline.fromJson(jsonDecode(s));

const _indent = JsonEncoder.withIndent('  ');

class _LabPageState extends State<LabPage> with SingleTickerProviderStateMixin {
  late final _clock = MotionController(vsync: this);
  final _json = TextEditingController();
  String? _preset;
  Timeline? _timeline;
  String? _error;
  var _quality = MotionQualityLevel.full;

  @override
  void initState() {
    super.initState();
    final q = widget.query;
    _quality = q['q'] == 'reduced'
        ? MotionQualityLevel.reduced
        : MotionQualityLevel.full;
    _select(presets.containsKey(q['preset']) ? q['preset']! : 'fadeIn');
    final t = double.tryParse(q['t'] ?? '');
    if (t != null) {
      _clock
        ..pause()
        ..seek(t);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _json.dispose();
    super.dispose();
  }

  void _select(String id) {
    _preset = id;
    _json.text = _indent.convert(presets[id]!.toJson());
    _parse(_json.text);
  }

  /// 플레이어와 같은 규칙: 잘못된 JSON 이면 모션 없이 그리고, 오류 경로를 보여 준다.
  void _parse(String text) {
    try {
      _timeline = Timeline.fromJson(jsonDecode(text));
      _error = null;
    } on MotionFormatException catch (e) {
      _timeline = null;
      _error = e.message; // 이미 '경로: 이유' 형태
    } on FormatException catch (e) {
      _timeline = null;
      _error = 'JSON 문법 오류: ${e.message}';
    }
    _clock
      ..seek(0)
      ..play();
  }

  void _setRepeat(MotionRepeat r) {
    final tl = _timeline;
    if (tl == null) return;
    final next = Timeline(
      durationMs: tl.durationMs,
      tracks: tl.tracks,
      delayMs: tl.delayMs,
      repeat: r,
      origin: tl.origin,
      channels: tl.channels,
    );
    setState(() {
      _json.text = _indent.convert(next.toJson());
      _parse(_json.text);
    });
  }

  /// 스크러버 끝: 반복이면 두 바퀴까지 보여 준다.
  double get _end {
    final tl = _timeline;
    if (tl == null) return 1;
    final laps = tl.repeat == MotionRepeat.none ? 1 : 2;
    return (tl.delayMs + tl.durationMs * laps).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final list = ListView(
      children: [
        for (final id in presets.keys)
          ListTile(
            dense: true,
            title: Text(id),
            selected: id == _preset,
            onTap: () => setState(() => _select(id)),
          ),
      ],
    );
    final main = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Stage(timeline: _timeline, clock: _clock, quality: _quality),
        const SizedBox(height: 12),
        _controls(),
        const SizedBox(height: 12),
        _editor(),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('/lab 웹 모션 랩')),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 200, child: list),
                const VerticalDivider(width: 1),
                Expanded(child: main),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 160, child: list),
                const Divider(height: 1),
                Expanded(child: main),
              ],
            ),
    );
  }

  Widget _controls() => ListenableBuilder(
    listenable: _clock,
    builder: (_, _) => Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: _clock.isPlaying ? '일시정지' : '재생',
          icon: Icon(_clock.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _clock.isPlaying ? _clock.pause : _clock.play,
        ),
        IconButton(
          tooltip: '처음부터',
          icon: const Icon(Icons.replay),
          onPressed: () => _clock
            ..seek(0)
            ..play(),
        ),
        SizedBox(
          width: 320,
          child: Slider(
            max: _end,
            value: _clock.timeMs.clamp(0, _end),
            onChanged: (t) => _clock
              ..pause()
              ..seek(t),
          ),
        ),
        SizedBox(width: 72, child: Text('${_clock.timeMs.round()} ms')),
        SegmentedButton<MotionRepeat>(
          segments: [
            for (final r in MotionRepeat.values)
              ButtonSegment(value: r, label: Text(r.name)),
          ],
          selected: {?_timeline?.repeat},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) => _setRepeat(s.first),
        ),
        SegmentedButton<MotionQualityLevel>(
          segments: [
            for (final q in MotionQualityLevel.values)
              ButtonSegment(value: q, label: Text(q.name)),
          ],
          selected: {_quality},
          onSelectionChanged: (s) => setState(() => _quality = s.first),
        ),
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('JSON 복사'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _json.text));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('복사했습니다')));
          },
        ),
      ],
    ),
  );

  Widget _editor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error case final e?)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$e — 플레이어는 이 요소를 모션 없이 그립니다.',
            key: const Key('lab-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      TextField(
        key: const Key('lab-json'),
        controller: _json,
        maxLines: null,
        minLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (text) => setState(() => _parse(text)),
      ),
    ],
  );
}

/// 480×270 씬 가운데 220×120 카드. 골든(`test/src/widget/golden_test.dart`)과 같은 모양이라 나란히 비교할 수 있다.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.timeline,
    required this.clock,
    required this.quality,
  });

  final Timeline? timeline;
  final MotionController clock;
  final MotionQualityLevel quality;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: FittedBox(
          child: SizedBox(
            width: 480,
            height: 270,
            child: MotionQuality(
              level: quality,
              child: ColoredBox(
                color: const Color(0xFF0D1015),
                child: Stack(
                  children: [
                    Positioned(
                      left: 130,
                      top: 75,
                      width: 220,
                      height: 120,
                      child: switch (timeline) {
                        // 값 채널이 있으면 builder 로 매 프레임 채널 값을 카드에 쓴다
                        final tl? when tl.channels.isNotEmpty => Motion.builder(
                          key: const Key('lab-motion'),
                          timeline: tl,
                          controller: clock,
                          builder: (_, v) => _card([
                            for (final c in tl.channels)
                              '${c.name} ${v[c.name]!.round()}',
                          ]),
                        ),
                        _ => Motion(
                          key: const Key('lab-motion'),
                          timeline: timeline,
                          controller: clock,
                          child: _card(const []),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 흰 카드 + 왼쪽 주황 띠. [lines] 는 채널 값 표시용.
Widget _card(List<String> lines) => DecoratedBox(
  decoration: const BoxDecoration(
    color: Color(0xFFFFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(10)),
  ),
  child: Stack(
    fit: StackFit.expand,
    children: [
      const Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.3,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
            ),
          ),
        ),
      ),
      if (lines.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 76),
          child: Center(
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
    ],
  ),
);
