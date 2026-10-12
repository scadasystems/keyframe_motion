import 'package:flutter/material.dart';

import 'gallery_page.dart';
import 'lab_page.dart';
import 'perf_page.dart';

void main() => runApp(const KeyframeMotionExample());

class KeyframeMotionExample extends StatelessWidget {
  const KeyframeMotionExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'keyframe_motion',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFC2410C)),
    // 쿼리(`/lab?preset=..&t=..`)를 받으려고 routes 대신 경로만 보고 고른다
    onGenerateRoute: (settings) {
      final uri = Uri.parse(settings.name ?? '/');
      final Widget page = switch (uri.path) {
        '/gallery' => GalleryPage(query: uri.queryParameters),
        '/lab' => LabPage(query: uri.queryParameters),
        '/perf' => const PerfPage(),
        _ => const _Home(),
      };
      return MaterialPageRoute(settings: settings, builder: (_) => page);
    },
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('keyframe_motion')),
    body: ListView(
      children: [
        ListTile(
          title: const Text('/gallery 쇼케이스'),
          subtitle: const Text('사이니지 샘플 씬, 프리셋·예시 30종 동시 재생'),
          onTap: () => Navigator.pushNamed(context, '/gallery'),
        ),
        ListTile(
          title: const Text('/lab 웹 모션 랩'),
          subtitle: const Text('프리셋 재생, JSON 편집, seek, 품질 전환'),
          onTap: () => Navigator.pushNamed(context, '/lab'),
        ),
        ListTile(
          title: const Text('/perf 성능 씬'),
          subtitle: const Text('요소 N개 동시 재생, 프레임 시간 측정'),
          onTap: () => Navigator.pushNamed(context, '/perf'),
        ),
      ],
    ),
  );
}
