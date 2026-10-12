# keyframe_motion

**English** | [한국어](README.ko.md)

Keyframe timeline animations for Flutter, with spring curves and a versioned JSON format.

Describe an animation as plain data (a `Timeline`), play it with a `Motion` widget, and store or send it as JSON.
Built for digital signage scenes where many elements animate together on low-end devices.

- **Keyframes on 25 properties**: opacity, translate (px or relative), scale, 2D/3D rotate, skew, clip and circle wipes, soft edges, tint, brightness, saturation, hue, blur, shimmer
- **Value channels**: named numbers (a price, a countdown) that `Motion.builder` hands to your widget every frame
- **Spring curves** (`SpringCurve`) next to every standard Flutter curve
- **JSON in and out** with strict validation and error paths (`$.tracks[0].keys[1].t`)
- **One clock for a whole scene**: share a `MotionController` across any number of widgets
- **Cheap per frame**: the child is built once; each frame only updates layer values, and timeline evaluation allocates nothing
- **Quality switch**: `MotionQuality.reduced` drops the expensive effects (blur, shimmer) on weak GPUs
- **19 presets**: `fadeIn`, `slideIn`, `pop`, `flipIn`, `wipeIn`, `shimmer`, `jelly`, …
- No dependencies beyond the Flutter SDK

## Installation

Add the package as a git dependency:

```yaml
dependencies:
  keyframe_motion:
    git:
      url: https://github.com/scadasystems/keyframe_motion.git
      ref: main
```

Requires Dart `^3.11.5`. Tested with Flutter 3.47.

## Quick start

```dart
import 'package:keyframe_motion/keyframe_motion.dart';

// Plays once on mount.
Motion(timeline: MotionPresets.fadeIn, child: const Text('Hello'));

// Direction-aware presets take parameters.
Motion(
  timeline: MotionPresets.slideIn(from: AxisDirection.left, distance: 200),
  child: priceCard,
);
```

## Writing a timeline

A `Timeline` is immutable. Times are integer milliseconds. Translations are logical pixels.

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

- A keyframe's `curve` shapes the segment that **ends** at that keyframe.
- Before the first keyframe a track holds its first value. After the last keyframe it holds the last value.
- Properties without a track stay at their rest value (1 for opacity and scales, 0 for the rest).

| Field | Default | Meaning |
|---|---|---|
| `durationMs` | required | Length of one pass |
| `delayMs` | `0` | Waited once before the first pass. The element shows its first keyframe values while waiting. |
| `repeat` | `none` | `none` stops on the last values, `loop` restarts, `pingpong` plays back and forth. Repeats never re-wait the delay. |
| `origin` | `FractionalOffset.center` | Pivot for rotate, scale and skew |

### Properties

| `MotionProp` | Value | Notes |
|---|---|---|
| `opacity` | 0–1 | |
| `translateX`, `translateY` | px | |
| `scale`, `scaleX`, `scaleY` | factor | `scale` multiplies `scaleX` and `scaleY` |
| `rotate` | degrees | Around Z |
| `rotateX`, `rotateY` | degrees | 3D flip with a fixed perspective. Positive `rotateY` brings the right edge closer. |
| `skewX`, `skewY` | degrees | |
| `clipLeft`, `clipTop`, `clipRight`, `clipBottom` | 0–1 | Fraction of the element cut from that side. Use for wipes and reveals. |
| `tint` | 0–1 | Blends the track `color` over the element. With no color it darkens to black. |
| `blur` | sigma px | Expensive. Skipped in `reduced` quality. |
| `shimmer` | 0–1 | A light band sweeps across as the value goes 0→1. The band color is the track `color`. Expensive. Skipped in `reduced` quality. |
| `brightness` | factor, default 1 | Multiplies the colors. Same formula as CSS `brightness()`. |
| `saturate` | factor, default 1 | 0 is grayscale. Same formula as CSS `saturate()`. |
| `hueRotate` | degrees | Same formula as CSS `hue-rotate()`. |
| `translateXRel`, `translateYRel` | fraction of the element's size | 1 moves by the element's own width or height. Adds to the px translation. |
| `clipCircle` | 0–1 | Circle around `origin`. 1 reaches the farthest corner, so the whole element shows. |
| `feather` | 0–1 | Softens the edges of clip wipes by this fraction of the element's size. Expensive. Skipped in `reduced` quality (the wipe stays hard). |

Transforms compose as: relative translate → translate → origin → perspective → rotate (Z, X, Y) → skew → scale.

`brightness`, `saturate`, `hueRotate` and `tint` are combined into one color matrix, applied in that order, so they cost a single layer. Tint comes last: at 1 the element is exactly the tint color.

### Curves

- Any Flutter `Curve` works in Dart. Only the named curves below survive JSON.
- `motionCurves` maps names to curves: `linear`, `ease`, `easeIn`, `easeOut`, `easeInOut`, `easeInCubic`, `easeOutCubic`,
  `easeInOutCubic`, `easeInBack`, `easeOutBack`, `fastOutSlowIn`, `decelerate`, `bounceIn`, `bounceOut`, `elasticOut`, `step`.
- `step` holds the previous value and jumps at the keyframe (`Threshold(1)`).
- `SpringCurve(stiffness:, damping:, mass:)` follows a real spring from 0 to 1, overshoot included, compressed into the segment.

## Playback control

Without a controller, `Motion` creates its own clock and starts it when `autoplay` is true.
To control playback, or to keep many elements in sync, pass a `MotionController`:

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
      // Stagger: compute delays when authoring.
      Motion(timeline: MotionPresets.riseUp.delayed(i * 150), controller: clock, child: card),
  ]);
}
```

| `MotionController` | |
|---|---|
| `play()` / `pause()` | Start or stop the clock |
| `seek(ms)` | Jump to a time. Works while paused, for scrubbers and previews. |
| `reverse()` | Flip the direction. A reversed clock stops at 0. Call `play()` too if paused. |
| `timeMs`, `isPlaying`, `isReversed` | Current state. The controller is a `ChangeNotifier`. |

Example: wipe in from the left, then later retract the same way:

```dart
Motion(timeline: MotionPresets.wipeIn(), controller: c, child: banner);
c.play();
// later
c..seek(800)..reverse()..play(); // 800 = wipeIn duration
```

## JSON

```dart
final json = timeline.toJson();               // Map, ready for jsonEncode
final strict = Timeline.fromJson(map);        // throws MotionFormatException with a path
final safe = Timeline.tryFromJson(map);       // null on any problem
```

For data from a server, use `tryFromJson`. `Motion(timeline: null)` draws the child without animation, so bad data never breaks a screen.

Schema version 1:

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

| Key | Rule |
|---|---|
| `v` | Must be `1`. Newer versions are rejected, so old players skip unknown formats. |
| `durationMs` | Positive integer |
| `delayMs` | Integer ≥ 0, optional |
| `repeat` | `"none"`, `"loop"` or `"pingpong"`, optional |
| `origin` | `topLeft`, `topCenter`, `topRight`, `centerLeft`, `center`, `centerRight`, `bottomLeft`, `bottomCenter`, `bottomRight`, or `[x, y]` fractions. Optional. |
| `tracks[].prop` | A `MotionProp` name |
| `tracks[].color` | `#RRGGBB` or `#AARRGGBB`, only on `tint` and `shimmer` |
| `channels` | Optional. `[{ "name": "price", "keys": [...] }]`. Names are non-empty and unique. Keys follow the track rules. |
| `tracks[].keys` | At least one keyframe. `t` is an integer in `0..durationMs`, ascending. `v` is a number. |
| `keys[].curve` | A curve name, `"step"`, or `{ "spring": { "stiffness", "damping", "mass"? } }`. Omitted means `linear`. |

`toJson` writes keys in a fixed order and writes whole numbers as integers, so the output is identical on mobile and web.
Validation messages are currently written in Korean.

### Value channels

A channel is a keyframed number that is not drawn. `Motion.builder` rebuilds its widget every frame with the current values,
so use it for small widgets such as a price label. Other tracks in the same timeline still apply.

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

`v[name]` is null when the timeline is null or has no channel with that name.

### Sequencing in one timeline

Enter, hold and exit can live in one timeline. This element wipes in from the left, stays, then retracts to the left:

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

## Quality and accessibility

```dart
MotionQuality(
  level: isLowEndDevice ? MotionQualityLevel.reduced : MotionQualityLevel.full,
  child: scene,
);
```

- `reduced` skips `blur`, `shimmer` and `feather`. Every other property still animates.
- The default is `full`. The package does not detect device performance itself. The app decides.
- When `MediaQuery.disableAnimations` is on, `Motion` shows the final keyframe values without animating.

## Presets

`MotionPresets` contains timelines you can use as is, or as a starting point (`toJson()`, edit, `fromJson()`).

| Group | Presets |
|---|---|
| Enter | `fadeIn`, `slideIn({from, distance})`, `zoomIn`, `pop` (spring), `flipIn`, `wipeIn({from})`, `blurIn`, `riseUp`, `doorOpen` |
| Attention (repeating) | `pulse`, `float`, `shake`, `blink`, `shimmer`, `swing`, `jelly` |
| Exit (holds the hidden state) | `fadeOut`, `slideOut({to, distance})`, `zoomOut` |

## Performance

`Motion` builds its child once. Each frame, an `AnimatedBuilder` evaluates the timeline into a reused buffer and updates
standard `Opacity`, `Transform`, `ClipRect`, `ColorFiltered`, `ImageFiltered` and `ShaderMask` layers.
Wrapper layers are chosen from the timeline's tracks once, so the widget tree never changes shape during playback.

Measured with the example `/perf` scene (profile mode, 10 s windows):

| Device | Scene | p90 frame time | Frames over 33 ms |
|---|---|---|---|
| RK3588 tablet, Impeller | 60 elements, opacity + transform | 13.3 ms | 0% |
| RK3588 tablet, Impeller | 30 elements with blur, shimmer, tint | 14.1 ms | 0% |
| RK3288 (Android 7, Skia) | 60 elements, opacity + transform | 18.8 ms | 0% |
| RK3288 (Android 7, Skia) | 30 elements with blur, shimmer, tint | 33.6 ms | 13.5% |
| RK3288 (Android 7, Skia) | same, `reduced` quality | 22.9 ms | 0% |
| RK3288 (Android 7, Skia) | 30 elements with color matrix, circle clip, feather, relative move | 27.0 ms | 1.0% |
| RK3288 (Android 7, Skia) | same, `reduced` quality | 21.3 ms | 0% |

On weak GPUs, use `reduced` quality for scenes with many blur or shimmer elements.

## Example app

```bash
cd example
flutter run                 # mobile / desktop
flutter run -d chrome       # web
```

| Route | |
|---|---|
| `/gallery` | Sample signage scene and every preset playing at once. `/gallery?t=600` freezes the scene at 600 ms. |
| `/lab` | Pick a preset or edit JSON live. Play, pause, scrub, switch repeat and quality, and copy the JSON. `/lab?preset=blurIn&t=300&q=reduced` opens a frozen frame. |
| `/perf` | Runs N elements on one clock and logs frame timings as `MOTION_PERF {...}` |

## Development

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags golden   # unit and widget tests
flutter test --tags golden           # golden images, macOS only
```

Low-level access is exported for tools such as editors: `evaluate(timeline, t, out)` fills a value buffer for any time
without a widget, and `motionMatrix(values)` builds the transform matrix.
