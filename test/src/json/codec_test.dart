import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:keyframe_motion/keyframe_motion.dart';
import 'package:keyframe_motion/src/widget/color_matrix.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 웹 데모 엔진이 계산한 타임라인과 시점별 값 (design/motion-demo 에서 추출).
final List<dynamic> fixture = jsonDecode(
  File('test/fixtures/demo_timelines.json').readAsStringSync(),
);

Map<String, Object?> valid() => {
  'v': 1,
  'durationMs': 600,
  'tracks': [
    {
      'prop': 'opacity',
      'keys': [
        {'t': 0, 'v': 0},
        {'t': 300, 'v': 1, 'curve': 'easeOut'},
      ],
    },
  ],
};

void expectPath(void Function(Map<String, dynamic> j) mutate, String path) {
  final j = jsonDecode(jsonEncode(valid())) as Map<String, dynamic>;
  mutate(j);
  expect(
    () => Timeline.fromJson(j),
    throwsA(isA<MotionFormatException>().having((e) => e.path, 'path', path)),
  );
  expect(Timeline.tryFromJson(j), isNull);
}

Timeline randomTimeline(Random r) {
  final duration = 1 + r.nextInt(5000);
  final curves = [
    ...motionCurves.values,
    SpringCurve(stiffness: 50.0 + r.nextInt(400), damping: 1.0 + r.nextInt(40)),
  ];
  final origins = [
    FractionalOffset.center,
    FractionalOffset.topLeft,
    FractionalOffset.bottomCenter,
    FractionalOffset(r.nextDouble(), r.nextDouble()),
  ];
  return Timeline(
    durationMs: duration,
    delayMs: r.nextInt(1000),
    repeat: MotionRepeat.values[r.nextInt(3)],
    origin: origins[r.nextInt(origins.length)],
    tracks: [
      for (var i = 0; i < 1 + r.nextInt(4); i++)
        () {
          final prop = MotionProp.values[r.nextInt(MotionProp.values.length)];
          final times = [
            for (var n = 0; n < 1 + r.nextInt(5); n++) r.nextInt(duration + 1),
          ]..sort();
          return Track(
            prop,
            [
              for (final t in times)
                Keyframe(
                  t,
                  (r.nextDouble() - 0.5) * 800,
                  curve: curves[r.nextInt(curves.length)],
                ),
            ],
            color: prop == MotionProp.tint || prop == MotionProp.shimmer
                ? Color(r.nextInt(1 << 32))
                : null,
          );
        }(),
    ],
  );
}

void main() {
  group('왕복', () {
    test('데모 타임라인 37개: fromJson(toJson(t)) == t', () {
      for (final demo in fixture) {
        for (final el in demo['elements']) {
          final tl = Timeline.fromJson(el['timeline']);
          expect(
            Timeline.fromJson(jsonDecode(jsonEncode(tl.toJson()))),
            tl,
            reason: demo['id'],
          );
        }
      }
    });

    test('toJson 문자열이 데모(JS)가 쓴 JSON 과 글자까지 같다 (정수는 14.0 이 아니라 14)', () {
      for (final demo in fixture) {
        for (final el in demo['elements']) {
          final tl = Timeline.fromJson(el['timeline']);
          expect(
            jsonEncode(tl.toJson()),
            jsonEncode(el['timeline']),
            reason: demo['id'],
          );
        }
      }
    });

    test('랜덤 생성 100건 왕복', () {
      final r = Random(20261012);
      for (var i = 0; i < 100; i++) {
        final tl = randomTimeline(r);
        expect(
          Timeline.fromJson(jsonDecode(jsonEncode(tl.toJson()))),
          tl,
          reason: '#$i ${jsonEncode(tl.toJson())}',
        );
      }
    });

    test('기본값은 생략하고 나머지는 스키마 순서대로 쓴다', () {
      final j = Timeline.fromJson(valid()).toJson();
      expect(j.keys, ['v', 'delayMs', 'durationMs', 'repeat', 'tracks']);
      final keys = ((j['tracks'] as List).first as Map)['keys'] as List;
      expect(keys.first, {'t': 0, 'v': 0.0});
      expect(keys.last, {'t': 300, 'v': 1.0, 'curve': 'easeOut'});
    });

    test('값 채널 왕복, 채널이 없으면 키를 쓰지 않는다', () {
      const tl = Timeline(
        durationMs: 1000,
        tracks: [],
        channels: [
          Channel('price', [
            Keyframe(0, 4900),
            Keyframe(1000, 3900, curve: Curves.easeOutCubic),
          ]),
          Channel('remain', [Keyframe(0, 6), Keyframe(1000, 0)]),
        ],
      );
      final json = jsonDecode(jsonEncode(tl.toJson()));
      expect(json['channels'][0], {
        'name': 'price',
        'keys': [
          {'t': 0, 'v': 4900},
          {'t': 1000, 'v': 3900, 'curve': 'easeOutCubic'},
        ],
      });
      expect(Timeline.fromJson(json), tl);
      expect(
        Timeline.fromJson(valid()).toJson().containsKey('channels'),
        isFalse,
      );
      expect(tl.delayed(100).channels, tl.channels);
    });

    test('JSON 으로 표현할 수 없는 곡선은 toJson 에서 알린다', () {
      const tl = Timeline(
        durationMs: 10,
        tracks: [
          Track(MotionProp.opacity, [Keyframe(10, 1, curve: Interval(0, 0.5))]),
        ],
      );
      expect(tl.toJson, throwsArgumentError);
    });
  });

  test('데모 엔진과 같은 값·채널·색 행렬을 낸다 (요소 47개 × 58시점)', () {
    final out = newMotionValues();
    var compared = 0, matrices = 0;
    for (final demo in fixture) {
      for (final el in demo['elements']) {
        final tl = Timeline.fromJson(el['timeline']);
        final channels = Float64List(tl.channels.length);
        for (final s in el['samples']) {
          final t = (s['t'] as num).toDouble();
          final why = '${demo['id']} t=$t';
          evaluate(tl, t, out);
          evaluateChannels(tl, t, channels);
          (s['values'] as Map<String, dynamic>).forEach((key, v) {
            final got = key.startsWith('channel:')
                ? channels[tl.channels.indexWhere(
                    (c) => 'channel:${c.name}' == key,
                  )]
                : out[MotionProp.values.byName(key).index];
            expect(
              got,
              closeTo((v as num).toDouble(), 1e-6),
              reason: '$why $key',
            );
            compared++;
          });
          if (s['matrix'] case final List<dynamic> m) {
            final tint = tl.tracks
                .where((tr) => tr.prop == MotionProp.tint)
                .firstOrNull;
            final color = tint == null
                ? null
                : tint.color ?? const Color(0xFF000000);
            final mine = motionColorMatrix(
              brightness: out[MotionProp.brightness.index],
              saturate: out[MotionProp.saturate.index],
              hueRotate: out[MotionProp.hueRotate.index],
              tint: color,
              tintStrength: color == null
                  ? 0
                  : color.a * out[MotionProp.tint.index].clamp(0.0, 1.0),
            );
            for (var i = 0; i < 20; i++) {
              expect(
                mine[i],
                closeTo((m[i] as num).toDouble(), 1e-6),
                reason: '$why matrix[$i]',
              );
            }
            matrices++;
          }
        }
      }
    }
    expect(compared, greaterThan(47 * 58)); // 비교가 실제로 돌았는지
    expect(
      matrices,
      5 * 58,
    ); // 색 요소 5개(saleFlash·soldOut·flash·hueCycle·grayTint)
  });

  group('검증 (경로)', () {
    test('버전', () {
      expectPath((j) => j['v'] = 2, r'$.v');
      expectPath((j) => j.remove('v'), r'$.v');
      expect(
        () => Timeline.fromJson({...valid(), 'v': 2}),
        throwsA(
          isA<MotionFormatException>().having(
            (e) => e.message,
            'message',
            contains('지원하지 않는 스키마 버전 2'),
          ),
        ),
      );
    });

    test('타임라인 필드', () {
      expectPath((j) => j['durationMs'] = 0, r'$.durationMs');
      expectPath((j) => j['durationMs'] = 1.5, r'$.durationMs');
      expectPath((j) => j['delayMs'] = -1, r'$.delayMs');
      expectPath((j) => j['repeat'] = 'forever', r'$.repeat');
      expectPath((j) => j['origin'] = 'middle', r'$.origin');
      expectPath((j) => j['origin'] = [0.5], r'$.origin');
      expectPath((j) => j['tracks'] = {}, r'$.tracks');
    });

    test('트랙', () {
      expectPath((j) => j['tracks'][0]['prop'] = 'glow', r'$.tracks[0].prop');
      expectPath(
        (j) => j['tracks'][0]['color'] = '#FF0000',
        r'$.tracks[0].color',
      );
      expectPath((j) => j['tracks'][0]['keys'] = [], r'$.tracks[0].keys');
      expectPath((j) {
        j['tracks'][0]['prop'] = 'tint';
        j['tracks'][0]['color'] = 'red';
      }, r'$.tracks[0].color');
    });

    test('키프레임', () {
      expectPath(
        (j) => j['tracks'][0]['keys'][1]['t'] = 9999,
        r'$.tracks[0].keys[1].t',
      );
      expectPath(
        (j) => j['tracks'][0]['keys'][1]['t'] = 10.5,
        r'$.tracks[0].keys[1].t',
      );
      expectPath((j) {
        j['tracks'][0]['keys'][0]['t'] = 400;
      }, r'$.tracks[0].keys[1].t');
      expectPath(
        (j) => j['tracks'][0]['keys'][0]['v'] = '1',
        r'$.tracks[0].keys[0].v',
      );
      expectPath(
        (j) => j['tracks'][0]['keys'][1]['curve'] = 'wobble',
        r'$.tracks[0].keys[1].curve',
      );
      expectPath(
        (j) => j['tracks'][0]['keys'][1]['curve'] = {
          'spring': {'stiffness': 100},
        },
        r'$.tracks[0].keys[1].curve',
      );
      expectPath(
        (j) => j['tracks'][0]['keys'][1]['curve'] = {
          'spring': {'stiffness': 100, 'damping': -1},
        },
        r'$.tracks[0].keys[1].curve',
      );
    });

    test('값 채널', () {
      Map<String, Object?> ch(Object? name) => {
        'name': name,
        'keys': [
          {'t': 0, 'v': 1},
        ],
      };
      expectPath((j) => j['channels'] = {}, r'$.channels');
      expectPath((j) => j['channels'] = [ch('')], r'$.channels[0].name');
      expectPath((j) => j['channels'] = [ch(3)], r'$.channels[0].name');
      expectPath(
        (j) => j['channels'] = [ch('a'), ch('a')],
        r'$.channels[1].name',
      );
      expectPath(
        (j) => j['channels'] = [
          {'name': 'a', 'keys': []},
        ],
        r'$.channels[0].keys',
      );
      expectPath(
        (j) => j['channels'] = [
          {
            'name': 'a',
            'keys': [
              {'t': 9999, 'v': 1},
            ],
          },
        ],
        r'$.channels[0].keys[0].t',
      );
    });

    test('객체가 아닌 입력도 크래시 없이 null', () {
      for (final bad in [
        null,
        1,
        'x',
        [],
        {
          'v': 1,
          'durationMs': 10,
          'tracks': [1],
        },
      ]) {
        expect(Timeline.tryFromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  test('색·기준점·스프링 해석', () {
    final tl = Timeline.fromJson({
      'v': 1,
      'durationMs': 100,
      'origin': [0.3, 0.4],
      'tracks': [
        {
          'prop': 'tint',
          'color': '#80FF2D2D',
          'keys': [
            {'t': 0, 'v': 0},
            {
              't': 100,
              'v': 1,
              'curve': {
                'spring': {'stiffness': 200, 'damping': 10, 'mass': 2},
              },
            },
          ],
        },
        {
          'prop': 'shimmer',
          'color': '#FFFFFF',
          'keys': [
            {'t': 0, 'v': 0},
          ],
        },
      ],
    });
    expect(tl.origin, const FractionalOffset(0.3, 0.4));
    expect(tl.tracks[0].color, const Color(0x80FF2D2D));
    expect(tl.tracks[1].color, const Color(0xFFFFFFFF));
    expect(
      tl.tracks[0].keys[1].curve,
      const SpringCurve(stiffness: 200, damping: 10, mass: 2),
    );
    expect((tl.toJson()['tracks'] as List)[1]['color'], '#FFFFFF');
    expect(tl.toJson()['origin'], [0.3, 0.4]);
    expect(
      Timeline.fromJson({
        ...valid(),
        'origin': 'bottomCenter',
      }).toJson()['origin'],
      'bottomCenter',
    );
    expect(Timeline.fromJson(valid()).tracks[0].keys[0].curve, Curves.linear);
  });
}
