import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:flutter/material.dart';

import 'lab_page.dart';

/// 쇼케이스: 사이니지 샘플 씬 + 프리셋 전부를 한 화면에서 동시에 재생한다.
/// 모든 요소가 컨트롤러 하나(씬 클록)를 공유한다 — 플레이어와 같은 구조.
/// `/gallery?t=600` 이면 샘플 씬을 그 시점에 멈춘 채로 연다.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, this.query = const {}});

  final Map<String, String> query;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

/// 샘플 씬 한 바퀴 길이. 지나면 처음부터 다시 재생한다.
const _sceneMs = 8000;

class _GalleryPageState extends State<GalleryPage>
    with TickerProviderStateMixin {
  late final _scene = MotionController(vsync: this)..play();
  late final _grid = MotionController(vsync: this)..play();

  @override
  void initState() {
    super.initState();
    _scene.addListener(() {
      if (_scene.timeMs >= _sceneMs) _scene.seek(0);
    });
    if (double.tryParse(widget.query['t'] ?? '') case final t?) {
      _scene
        ..pause()
        ..seek(t);
    }
  }

  @override
  void dispose() {
    _scene.dispose();
    _grid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('/gallery 쇼케이스')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('샘플 씬', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: '처음부터',
              icon: const Icon(Icons.replay),
              onPressed: () => _scene
                ..seek(0)
                ..play(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: FittedBox(child: _SignageScene(clock: _scene)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '프리셋 — 눌러서 /lab 에서 열기',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        GridView.extent(
          maxCrossAxisExtent: 280,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 16 / 11,
          children: [
            for (final MapEntry(:key, :value) in presets.entries)
              _PresetTile(id: key, timeline: _replay(value), clock: _grid),
          ],
        ),
      ],
    ),
  );
}

/// 한 번만 재생되는 등장·퇴장 프리셋은 끝 상태를 1.2초 보여 준 뒤 반복하게 만든다.
Timeline _replay(Timeline tl) => tl.repeat != MotionRepeat.none
    ? tl
    : Timeline(
        durationMs: tl.durationMs + 1200,
        tracks: tl.tracks,
        delayMs: tl.delayMs,
        repeat: MotionRepeat.loop,
        origin: tl.origin,
        channels: tl.channels,
      );

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.id,
    required this.timeline,
    required this.clock,
  });

  final String id;
  final Timeline timeline;
  final MotionController clock;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.pushNamed(context, '/lab?preset=$id'),
      child: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: FittedBox(
                child: SizedBox(
                  width: 480,
                  height: 270,
                  child: ColoredBox(
                    color: const Color(0xFF0D1015),
                    child: Center(
                      child: SizedBox(
                        width: 220,
                        height: 120,
                        child: Motion(
                          timeline: timeline,
                          controller: clock,
                          child: const _DemoCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(id),
          ),
        ],
      ),
    ),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0xFFFFFFFF),
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Align(
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
  );
}

// ───────── 샘플 씬 (480×270 씬 좌표) ─────────

const _products = [
  ('제주 감귤 1kg', 4900, 6900),
  ('한우 불고기 300g', 12900, 15900),
  ('유기농 우유 1L', 2980, 3500),
];

const _saleFlash = Timeline(
  durationMs: 1400,
  repeat: MotionRepeat.loop,
  tracks: [
    Track(MotionProp.tint, [
      Keyframe(0, 0),
      Keyframe(250, 0.5, curve: Curves.easeOut),
      Keyframe(900, 0, curve: Curves.easeIn),
      Keyframe(1400, 0),
    ], color: Color(0xFFFF2D2D)),
  ],
);

const _marquee = Timeline(
  durationMs: 9000,
  repeat: MotionRepeat.loop,
  tracks: [
    Track(MotionProp.translateX, [Keyframe(0, 480), Keyframe(9000, -720)]),
  ],
);

/// 스태거는 그룹 기능 없이 요소마다 delay 를 준다 — 여기서는 `delayed(i * 150)`.
class _SignageScene extends StatelessWidget {
  const _SignageScene({required this.clock});

  final MotionController clock;

  Motion _m(Timeline? tl, Widget child) =>
      Motion(timeline: tl, controller: clock, child: child);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 480,
    height: 270,
    child: ClipRect(
      child: ColoredBox(
        color: const Color(0xFF14213D),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Stack(
            children: [
              // 제목: 왼쪽에서 들어온 뒤 빛이 지나간다 (등장 + 반복 주목을 겹침)
              Positioned(
                left: 24,
                top: 18,
                child: _m(
                  MotionPresets.slideIn(distance: 80),
                  _m(
                    MotionPresets.shimmer.delayed(900),
                    const Text(
                      '오늘의 특가',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFCA311),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 26,
                top: 58,
                child: _m(
                  MotionPresets.fadeIn.delayed(300),
                  const Text(
                    '10월 12일 하루만',
                    style: TextStyle(color: Color(0xFFB8C1D9)),
                  ),
                ),
              ),
              // SALE 배지: 튀어나온 뒤 맥박처럼 뛴다
              Positioned(
                right: 24,
                top: 16,
                width: 64,
                height: 64,
                child: _m(
                  MotionPresets.pop.delayed(1200),
                  _m(
                    MotionPresets.pulse.delayed(2100),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE63946),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'SALE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 상품 카드 3장: 아래에서 순서대로 솟아오르고, 가운데 카드는 붉게 깜빡인다
              for (final (i, (name, price, was)) in _products.indexed)
                Positioned(
                  left: 24 + i * 148.0,
                  top: 90,
                  width: 136,
                  height: 132,
                  child: _m(
                    MotionPresets.riseUp.delayed(500 + i * 150),
                    _m(
                      i == 1 ? _saleFlash.delayed(1800) : null,
                      _ProductCard(name: name, price: price, was: was),
                    ),
                  ),
                ),
              // 하단 흐르는 안내 문구
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 30,
                child: ColoredBox(
                  color: const Color(0xFF000000),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minHeight: 0, // 높이를 풀어야 문구가 띠 가운데에 온다
                    maxWidth: double.infinity,
                    child: _m(
                      _marquee,
                      const Text(
                        '  ★ 매장 내 모든 과일 20% 할인   ★ 3만원 이상 구매 시 무료 배송   ★ 포인트 2배 적립',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.was,
  });

  final String name;
  final int price, was;

  static String _won(int v) =>
      '₩${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',')}';

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1DA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(
                  Icons.shopping_basket,
                  color: Color(0xFFFCA311),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF14213D), fontSize: 11),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _won(price),
                style: const TextStyle(
                  color: Color(0xFFE63946),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _won(was),
                style: const TextStyle(
                  color: Color(0xFF8A94A6),
                  fontSize: 10,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
