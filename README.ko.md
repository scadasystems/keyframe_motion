# keyframe_motion

[English](README.md) | **한국어**

Flutter 용 키프레임 타임라인 애니메이션입니다. 스프링 곡선과 버전이 붙은 JSON 형식을 지원합니다.

애니메이션을 데이터(`Timeline`)로 기술하고, `Motion` 위젯으로 재생하고, JSON 으로 저장하거나 전송합니다.
저사양 단말에서 많은 요소가 함께 움직이는 디지털 사이니지 씬을 위해 만들었습니다.

- **속성 25종에 키프레임**: opacity, 이동(px·상대), 크기, 2D/3D 회전, 기울이기(skew), 사각·원형 와이프, 부드러운 경계, tint, 밝기, 채도, 색상, blur, shimmer
- **값 채널**: 그리지 않는 이름 붙은 숫자(가격, 카운트다운). `Motion.builder` 가 매 프레임 위젯에 넘깁니다
- **스프링 곡선**(`SpringCurve`)과 Flutter 표준 곡선 전부
- **JSON 입출력**: 엄격한 검증과 오류 경로 표시(`$.tracks[0].keys[1].t`)
- **씬 전체가 클록 하나를 공유**: `MotionController` 하나를 위젯 몇 개든 함께 쓸 수 있음
- **프레임당 비용이 낮음**: child 는 한 번만 빌드하고 매 프레임 레이어 값만 바꿈. 타임라인 계산은 할당이 없음
- **품질 단계**: GPU 가 약한 단말에서는 `MotionQuality.reduced` 로 비싼 효과(blur, shimmer)를 생략
- **프리셋 19종**: `fadeIn`, `slideIn`, `pop`, `flipIn`, `wipeIn`, `shimmer`, `jelly`, …
- Flutter SDK 외 의존성 없음

## 설치

git 의존성으로 추가합니다.

```yaml
dependencies:
  keyframe_motion:
    git:
      url: https://github.com/scadasystems/keyframe_motion.git
      ref: main
```

Dart `^3.11.5` 가 필요합니다. Flutter 3.47 에서 테스트했습니다.

## 빠른 시작

```dart
import 'package:keyframe_motion/keyframe_motion.dart';

// 화면에 붙으면 한 번 재생됩니다.
Motion(timeline: MotionPresets.fadeIn, child: const Text('Hello'));

// 방향이 있는 프리셋은 인자를 받습니다.
Motion(
  timeline: MotionPresets.slideIn(from: AxisDirection.left, distance: 200),
  child: priceCard,
);
```

## 타임라인 작성

`Timeline` 은 불변 데이터입니다. 시간은 정수 ms, 이동은 논리 px 입니다.

```dart
const fadeUp = Timeline(
  durationMs: 600,
  tracks: [
    Track(MotionProp.opacity, [
      Keyframe(0, 0),
      Keyframe(300, 1, curve: Curves.easeOut),
    ]),
    Track(MotionProp.translateY, [
      Keyframe(0, 24),
      Keyframe(600, 0, curve: SpringCurve(stiffness: 300, damping: 20)),
    ]),
  ],
);
```

- 키프레임의 `curve` 는 그 키프레임에서 **끝나는** 구간의 모양을 정합니다.
- 첫 키프레임 전에는 첫 값을, 마지막 키프레임 뒤에는 마지막 값을 유지합니다.
- 트랙이 없는 속성은 기본값(opacity·크기는 1, 나머지는 0)에 머뭅니다.

| 필드 | 기본값 | 의미 |
|---|---|---|
| `durationMs` | 필수 | 한 바퀴 길이 |
| `delayMs` | `0` | 첫 재생 전에 한 번만 기다립니다. 기다리는 동안 첫 키프레임 값으로 보입니다. |
| `repeat` | `none` | `none` 은 마지막 값에서 멈추고, `loop` 은 처음부터 다시, `pingpong` 은 앞뒤로 오갑니다. 반복할 때는 delay 를 다시 기다리지 않습니다. |
| `origin` | `FractionalOffset.center` | 회전·크기·기울이기의 기준점 |

### 속성

| `MotionProp` | 값 | 설명 |
|---|---|---|
| `opacity` | 0–1 | |
| `translateX`, `translateY` | px | |
| `scale`, `scaleX`, `scaleY` | 배율 | `scale` 은 `scaleX`·`scaleY` 에 곱해집니다 |
| `rotate` | 도(°) | Z축 회전 |
| `rotateX`, `rotateY` | 도(°) | 원근이 고정된 3D 뒤집기. 양수 `rotateY` 는 오른쪽 변이 다가옵니다. |
| `skewX`, `skewY` | 도(°) | |
| `clipLeft`, `clipTop`, `clipRight`, `clipBottom` | 0–1 | 그쪽 변에서 요소 크기의 비율만큼 잘라냅니다. 와이프·리빌에 씁니다. |
| `tint` | 0–1 | 트랙 `color` 를 요소 위에 섞습니다. 색이 없으면 검정으로 어두워집니다. |
| `blur` | 시그마 px | 비쌉니다. `reduced` 품질에서 생략됩니다. |
| `shimmer` | 0–1 | 값이 0→1 로 가는 동안 빛 띠가 지나갑니다. 띠 색은 트랙 `color` 입니다. 비쌉니다. `reduced` 품질에서 생략됩니다. |
| `brightness` | 배율, 기본 1 | 색을 곱합니다. CSS `brightness()` 와 같은 식입니다. |
| `saturate` | 배율, 기본 1 | 0 이면 흑백입니다. CSS `saturate()` 와 같은 식입니다. |
| `hueRotate` | 도(°) | CSS `hue-rotate()` 와 같은 식입니다. |
| `translateXRel`, `translateYRel` | 요소 크기 비율 | 1 이면 자기 너비·높이만큼 이동합니다. px 이동과 더해집니다. |
| `clipCircle` | 0–1 | `origin` 을 중심으로 한 원입니다. 1 이면 가장 먼 꼭짓점까지 덮어 요소 전체가 보입니다. |
| `feather` | 0–1 | clip 와이프 경계를 요소 크기의 이 비율 폭으로 흐립니다. 비쌉니다. `reduced` 품질에서 생략됩니다(일반 와이프로 보임). |

변환 합성 순서: 상대 이동 → 이동 → 기준점 → 원근 → 회전(Z, X, Y) → 기울이기 → 크기.

`brightness`, `saturate`, `hueRotate`, `tint` 는 이 순서로 색 행렬 하나에 합쳐지므로 레이어 하나 비용입니다. tint 가 마지막이라 tint 1 이면 정확히 그 색이 됩니다.

### 곡선

- Dart 코드에서는 Flutter `Curve` 를 무엇이든 쓸 수 있습니다. JSON 으로 저장되는 것은 아래 이름 있는 곡선뿐입니다.
- `motionCurves` 가 이름과 곡선을 연결합니다: `linear`, `ease`, `easeIn`, `easeOut`, `easeInOut`, `easeInCubic`, `easeOutCubic`,
  `easeInOutCubic`, `easeInBack`, `easeOutBack`, `fastOutSlowIn`, `decelerate`, `bounceIn`, `bounceOut`, `elasticOut`, `step`.
- `step` 은 이전 값을 유지하다가 키프레임에서 바로 바뀝니다(`Threshold(1)`).
- `SpringCurve(stiffness:, damping:, mass:)` 는 0 에서 1 로 가는 실제 스프링 움직임(넘쳤다 돌아오는 것 포함)을 구간 길이에 맞춰 줄입니다.

## 재생 제어

컨트롤러를 넘기지 않으면 `Motion` 이 자체 클록을 만들고, `autoplay` 가 true 면 바로 재생합니다.
재생을 제어하거나 여러 요소를 맞춰 움직이려면 `MotionController` 를 넘깁니다.

```dart
class _SceneState extends State<Scene> with SingleTickerProviderStateMixin {
  late final clock = MotionController(vsync: this)..play();

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    Motion(timeline: MotionPresets.slideIn(), controller: clock, child: title),
    for (final (i, card) in cards.indexed)
      // 스태거: 저작할 때 delay 를 계산합니다.
      Motion(timeline: MotionPresets.riseUp.delayed(i * 150), controller: clock, child: card),
  ]);
}
```

| `MotionController` | |
|---|---|
| `play()` / `pause()` | 클록 시작·정지 |
| `seek(ms)` | 그 시간으로 이동합니다. 멈춘 상태에서도 되므로 스크러버·미리보기에 씁니다. |
| `reverse()` | 방향을 뒤집습니다. 거꾸로 가는 클록은 0 에서 멈춥니다. 멈춘 상태라면 `play()` 도 불러야 합니다. |
| `timeMs`, `isPlaying`, `isReversed` | 현재 상태. 컨트롤러는 `ChangeNotifier` 입니다. |

예: 왼쪽부터 드러난 뒤, 나중에 같은 경로로 다시 접혀 들어가기

```dart
Motion(timeline: MotionPresets.wipeIn(), controller: c, child: banner);
c.play();
// 나중에
c..seek(800)..reverse()..play(); // 800 = wipeIn 길이
```

## JSON

```dart
final json = timeline.toJson();               // jsonEncode 에 바로 넣을 수 있는 Map
final strict = Timeline.fromJson(map);        // 오류 경로가 담긴 MotionFormatException 을 던짐
final safe = Timeline.tryFromJson(map);       // 문제가 있으면 null
```

서버에서 받은 데이터에는 `tryFromJson` 을 쓰세요. `Motion(timeline: null)` 은 child 를 애니메이션 없이 그리므로, 잘못된 데이터 때문에 화면이 깨지지 않습니다.

스키마 버전 1:

```json
{
  "v": 1,
  "delayMs": 0,
  "durationMs": 600,
  "repeat": "none",
  "origin": "center",
  "tracks": [
    { "prop": "opacity", "keys": [{ "t": 0, "v": 0 }, { "t": 300, "v": 1, "curve": "easeOut" }] },
    { "prop": "translateY", "keys": [{ "t": 0, "v": 24 }, { "t": 600, "v": 0, "curve": { "spring": { "stiffness": 300, "damping": 20 } } }] },
    { "prop": "tint", "color": "#FF0000", "keys": [{ "t": 0, "v": 0 }, { "t": 600, "v": 0.5 }] }
  ]
}
```

| 키 | 규칙 |
|---|---|
| `v` | `1` 이어야 합니다. 더 새 버전은 거부되므로, 구버전 플레이어는 모르는 형식을 건너뜁니다. |
| `durationMs` | 양의 정수 |
| `delayMs` | 0 이상 정수, 생략 가능 |
| `repeat` | `"none"`, `"loop"`, `"pingpong"` 중 하나, 생략 가능 |
| `origin` | `topLeft`, `topCenter`, `topRight`, `centerLeft`, `center`, `centerRight`, `bottomLeft`, `bottomCenter`, `bottomRight` 또는 비율 `[x, y]`. 생략 가능 |
| `tracks[].prop` | `MotionProp` 이름 |
| `tracks[].color` | `#RRGGBB` 또는 `#AARRGGBB`. `tint`·`shimmer` 에서만 허용 |
| `channels` | 생략 가능. `[{ "name": "price", "keys": [...] }]`. 이름은 비어 있지 않고 겹치지 않아야 합니다. 키프레임 규칙은 트랙과 같습니다. |
| `tracks[].keys` | 키프레임 1개 이상. `t` 는 `0..durationMs` 정수이고 오름차순, `v` 는 숫자 |
| `keys[].curve` | 곡선 이름, `"step"`, 또는 `{ "spring": { "stiffness", "damping", "mass"? } }`. 생략하면 `linear` |

`toJson` 은 키를 정해진 순서로 쓰고 정수인 값은 정수로 씁니다. 그래서 모바일과 웹의 출력이 같습니다.
검증 오류 메시지는 현재 한국어로 나옵니다.

### 값 채널

채널은 그리지 않는 키프레임 숫자입니다. `Motion.builder` 는 매 프레임 현재 값으로 위젯을 다시 만들므로,
가격 표시처럼 작은 위젯에 씁니다. 같은 타임라인의 다른 트랙도 그대로 적용됩니다.

```dart
const priceDrop = Timeline(
  durationMs: 1600,
  tracks: [],
  channels: [
    Channel('price', [Keyframe(600, 4900), Keyframe(1600, 3900, curve: Curves.easeOutCubic)]),
  ],
);

Motion.builder(
  timeline: priceDrop,
  builder: (context, v) => Text(won(v['price'] ?? 3900)),
);
```

타임라인이 null 이거나 그 이름의 채널이 없으면 `v[name]` 은 null 입니다.

### 타임라인 하나에 이어 붙이기

등장·유지·퇴장을 타임라인 하나에 담을 수 있습니다. 이 요소는 왼쪽부터 드러나고, 머물렀다가, 다시 왼쪽으로 접혀 들어갑니다.

```json
{
  "v": 1, "durationMs": 5000,
  "tracks": [
    { "prop": "clipRight", "keys": [
      { "t": 0, "v": 1 },
      { "t": 800, "v": 0, "curve": "easeInOutCubic" },
      { "t": 4200, "v": 0 },
      { "t": 5000, "v": 1, "curve": "easeInOutCubic" }
    ]}
  ]
}
```

## 품질과 접근성

```dart
MotionQuality(
  level: isLowEndDevice ? MotionQualityLevel.reduced : MotionQualityLevel.full,
  child: scene,
);
```

- `reduced` 는 `blur`, `shimmer`, `feather` 를 생략합니다. 나머지 속성은 그대로 움직입니다.
- 기본값은 `full` 입니다. 패키지가 단말 성능을 스스로 판단하지 않으므로, 앱이 정합니다.
- `MediaQuery.disableAnimations` 가 켜져 있으면 `Motion` 은 움직이지 않고 마지막 키프레임 값을 보여 줍니다.

## 프리셋

`MotionPresets` 의 타임라인은 그대로 쓰거나 출발점으로 쓸 수 있습니다(`toJson()` → 수정 → `fromJson()`).

| 분류 | 프리셋 |
|---|---|
| 등장 | `fadeIn`, `slideIn({from, distance})`, `zoomIn`, `pop`(스프링), `flipIn`, `wipeIn({from})`, `blurIn`, `riseUp`, `doorOpen` |
| 주목(반복) | `pulse`, `float`, `shake`, `blink`, `shimmer`, `swing`, `jelly` |
| 퇴장(숨은 상태 유지) | `fadeOut`, `slideOut({to, distance})`, `zoomOut` |

## 성능

`Motion` 은 child 를 한 번만 빌드합니다. 매 프레임 `AnimatedBuilder` 가 재사용 버퍼에 타임라인 값을 계산하고,
표준 `Opacity`, `Transform`, `ClipRect`, `ColorFiltered`, `ImageFiltered`, `ShaderMask` 레이어의 값만 바꿉니다.
어떤 레이어로 감쌀지는 타임라인의 트랙을 보고 한 번만 정하므로, 재생 중에 위젯 트리 모양이 바뀌지 않습니다.

example 앱 `/perf` 씬으로 측정한 결과입니다(profile 모드, 10초 구간).

| 단말 | 씬 | p90 프레임 시간 | 33ms 초과 프레임 |
|---|---|---|---|
| RK3588 태블릿, Impeller | 요소 60개, opacity + transform | 13.3 ms | 0% |
| RK3588 태블릿, Impeller | 요소 30개, blur·shimmer·tint 포함 | 14.1 ms | 0% |
| RK3288 (Android 7, Skia) | 요소 60개, opacity + transform | 18.8 ms | 0% |
| RK3288 (Android 7, Skia) | 요소 30개, blur·shimmer·tint 포함 | 33.6 ms | 13.5% |
| RK3288 (Android 7, Skia) | 같은 씬, `reduced` 품질 | 22.9 ms | 0% |
| RK3288 (Android 7, Skia) | 요소 30개, 색 행렬·원형 clip·feather·상대 이동 | 27.0 ms | 1.0% |
| RK3288 (Android 7, Skia) | 같은 씬, `reduced` 품질 | 21.3 ms | 0% |

GPU 가 약한 단말에서 blur·shimmer 요소가 많은 씬은 `reduced` 품질을 쓰세요.

## example 앱

```bash
cd example
flutter run                 # 모바일·데스크톱
flutter run -d chrome       # 웹
```

| 경로 | |
|---|---|
| `/gallery` | 사이니지 샘플 씬과 모든 프리셋을 한 번에 재생합니다. `/gallery?t=600` 은 600ms 시점에 멈춘 씬을 엽니다. |
| `/lab` | 프리셋을 고르거나 JSON 을 바로 고쳐 재생합니다. 재생·일시정지, 스크러버, repeat·품질 전환, JSON 복사를 지원합니다. `/lab?preset=blurIn&t=300&q=reduced` 는 멈춘 프레임을 엽니다. |
| `/perf` | 요소 N개를 클록 하나로 재생하고 프레임 시간을 `MOTION_PERF {...}` 로그로 남깁니다. |

## 개발

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags golden   # 단위·위젯 테스트
flutter test --tags golden           # 골든 이미지, macOS 전용
```

에디터 같은 도구를 위해 저수준 API 도 공개합니다. `evaluate(timeline, t, out)` 은 위젯 없이 임의 시점의 값을 버퍼에 채우고,
`motionMatrix(values)` 는 변환 행렬을 만듭니다.
