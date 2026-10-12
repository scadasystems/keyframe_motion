import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Gradient, ImageFilter;

import 'package:flutter/widgets.dart';

import '../timeline/evaluate.dart';
import '../timeline/timeline.dart';
import 'color_matrix.dart';
import 'controller.dart';
import 'quality.dart';
import 'transform.dart';

const _defaultTint = Color(0xFF000000);
const _defaultShimmer = Color(0xB3FFFFFF);
const _colorProps = {
  MotionProp.tint,
  MotionProp.brightness,
  MotionProp.saturate,
  MotionProp.hueRotate,
};

/// 값 채널 이름 → 현재 값. 없는 이름이면 null.
class MotionChannels {
  const MotionChannels._(this._names, this._values);

  /// 타임라인이 없거나 채널이 없을 때.
  static const empty = MotionChannels._([], null);

  final List<Channel> _names;
  final Float64List? _values;

  double? operator [](String name) {
    for (var i = 0; i < _names.length; i++) {
      if (_names[i].name == name) return _values![i];
    }
    return null;
  }
}

typedef MotionChannelBuilder =
    Widget Function(BuildContext context, MotionChannels values);

/// [timeline] 을 [child] 에 적용한다. 재생 중 child 는 다시 빌드되지 않는다.
///
/// [controller] 를 넘기면 그 클록을 따르고(씬 클록 공유), 없으면 내부 클록을 만들어 [autoplay] 에 따라 재생한다.
/// [timeline] 이 null 이면(예: `Timeline.tryFromJson` 실패) child 를 모션 없이 그린다.
class Motion extends StatefulWidget {
  const Motion({
    super.key,
    required this.timeline,
    this.controller,
    this.autoplay = true,
    required Widget this.child,
  }) : builder = null;

  /// 값 채널을 쓰는 child 를 매 프레임 [builder] 로 만든다. 다른 속성 트랙도 함께 적용된다.
  /// builder 가 매 프레임 불리므로 숫자 텍스트처럼 작은 위젯에만 쓴다.
  const Motion.builder({
    super.key,
    required this.timeline,
    this.controller,
    this.autoplay = true,
    required MotionChannelBuilder this.builder,
  }) : child = null;

  final Timeline? timeline;
  final MotionController? controller;

  /// [controller] 를 넘기지 않았을 때만 쓴다. 넘긴 controller 는 호출한 쪽이 재생을 관리한다.
  final bool autoplay;
  final Widget? child;
  final MotionChannelBuilder? builder;

  @override
  State<Motion> createState() => _MotionState();
}

class _MotionState extends State<Motion> with SingleTickerProviderStateMixin {
  MotionController? _own;
  final Float64List _values = newMotionValues();
  Float64List _channelValues = Float64List(0);

  // 래퍼 구성은 타임라인마다 한 번 정한다 — 재생 중 트리 모양이 바뀌면 child 가 다시 마운트된다.
  Timeline? _shapeOf;
  MotionQualityLevel? _shapeQuality;
  bool _hasTransform = false;
  bool _hasOpacity = false;
  bool _hasClip = false;
  bool _hasBlur = false;
  bool _hasShimmer = false;
  bool _hasColor = false;
  bool _hasCircle = false;
  bool _hasRel = false;
  bool _featherX = false;
  bool _featherY = false;
  Color? _tint;
  Color _shimmerColor = _defaultShimmer;

  MotionController get _clock => widget.controller ?? _own!;

  @override
  void initState() {
    super.initState();
    _syncOwnController();
  }

  @override
  void didUpdateWidget(Motion old) {
    super.didUpdateWidget(old);
    if ((old.controller == null) != (widget.controller == null)) {
      _syncOwnController();
    }
  }

  void _syncOwnController() {
    if (widget.controller != null) {
      _own?.dispose();
      _own = null;
    } else if (_own == null) {
      _own = MotionController(vsync: this);
      if (widget.autoplay) _own!.play();
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _resolveShape(Timeline tl, MotionQualityLevel quality) {
    if (identical(tl, _shapeOf) && quality == _shapeQuality) return;
    _shapeOf = tl;
    _shapeQuality = quality;
    final full = quality == MotionQualityLevel.full;
    final props = {for (final t in tl.tracks) t.prop};
    _hasTransform = props.any(transformProps.contains);
    _hasOpacity = props.contains(MotionProp.opacity);
    final clipX =
        props.contains(MotionProp.clipLeft) ||
        props.contains(MotionProp.clipRight);
    final clipY =
        props.contains(MotionProp.clipTop) ||
        props.contains(MotionProp.clipBottom);
    final feather = full && props.contains(MotionProp.feather);
    _featherX = feather && clipX;
    _featherY = feather && clipY;
    // feather 가 맡은 축은 그라데이션이 가리므로 ClipRect 는 나머지 축만 자른다
    _hasClip = (clipX && !_featherX) || (clipY && !_featherY);
    _hasBlur = full && props.contains(MotionProp.blur);
    _hasShimmer = full && props.contains(MotionProp.shimmer);
    _hasColor = props.any(_colorProps.contains);
    _hasCircle = props.contains(MotionProp.clipCircle);
    _hasRel =
        props.contains(MotionProp.translateXRel) ||
        props.contains(MotionProp.translateYRel);
    _tint = null;
    _shimmerColor = _defaultShimmer;
    for (final t in tl.tracks) {
      if (t.prop == MotionProp.tint) _tint = t.color ?? _defaultTint;
      if (t.prop == MotionProp.shimmer && t.color != null) {
        _shimmerColor = t.color!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tl = widget.timeline;
    final builder = widget.builder;
    if (tl == null) {
      return builder?.call(context, MotionChannels.empty) ?? widget.child!;
    }
    _resolveShape(tl, MotionQuality.of(context));
    if (_channelValues.length != tl.channels.length) {
      _channelValues = Float64List(tl.channels.length);
    }
    final channels = MotionChannels._(tl.channels, _channelValues);
    Widget content(BuildContext context, Widget? child) =>
        child ?? builder!(context, channels);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      evaluateEnd(tl, _values);
      evaluateChannels(tl, 0, _channelValues, end: true);
      return _apply(tl, content(context, widget.child));
    }
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (context, child) {
        evaluate(tl, _clock.timeMs, _values);
        evaluateChannels(tl, _clock.timeMs, _channelValues);
        return _apply(tl, content(context, child));
      },
    );
  }

  // 안쪽부터: shimmer → blur → 색 행렬 → clipCircle → clipRect → feather(가로·세로) → opacity → transform → translateRel.
  // clip 은 요소 좌표에서 잘린 뒤 함께 변환된다.
  Widget _apply(Timeline tl, Widget child) {
    final v = _values;
    var w = child;
    if (_hasShimmer) {
      final p = v[MotionProp.shimmer.index];
      w = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => _shimmerShader(bounds, p, _shimmerColor),
        child: w,
      );
    }
    if (_hasBlur) {
      final sigma = math.max(0.0, v[MotionProp.blur.index]);
      w = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: w,
      );
    }
    if (_hasColor) {
      final tint = _tint;
      w = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          motionColorMatrix(
            brightness: v[MotionProp.brightness.index],
            saturate: v[MotionProp.saturate.index],
            hueRotate: v[MotionProp.hueRotate.index],
            tint: tint,
            tintStrength: tint == null
                ? 0
                : tint.a * v[MotionProp.tint.index].clamp(0.0, 1.0),
          ),
        ),
        child: w,
      );
    }
    if (_hasCircle) {
      w = ClipOval(
        clipper: _CircleClipper(v[MotionProp.clipCircle.index], tl.origin),
        child: w,
      );
    }
    if (_hasClip) {
      w = ClipRect(
        clipper: _InsetClipper(
          _featherX ? 0 : v[MotionProp.clipLeft.index],
          _featherY ? 0 : v[MotionProp.clipTop.index],
          _featherX ? 0 : v[MotionProp.clipRight.index],
          _featherY ? 0 : v[MotionProp.clipBottom.index],
        ),
        child: w,
      );
    }
    final f = v[MotionProp.feather.index];
    if (_featherX) {
      final lo = v[MotionProp.clipLeft.index],
          hi = v[MotionProp.clipRight.index];
      w = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => _featherShader(r, lo, hi, f, horizontal: true),
        child: w,
      );
    }
    if (_featherY) {
      final lo = v[MotionProp.clipTop.index],
          hi = v[MotionProp.clipBottom.index];
      w = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => _featherShader(r, lo, hi, f, horizontal: false),
        child: w,
      );
    }
    if (_hasOpacity) {
      w = Opacity(
        opacity: _values[MotionProp.opacity.index].clamp(0.0, 1.0),
        child: w,
      );
    }
    if (_hasTransform) {
      w = Transform(
        transform: motionMatrix(_values),
        alignment: tl.origin,
        child: w,
      );
    }
    if (_hasRel) {
      w = FractionalTranslation(
        translation: Offset(
          v[MotionProp.translateXRel.index],
          v[MotionProp.translateYRel.index],
        ),
        child: w,
      );
    }
    return w;
  }
}

/// 띠 폭 38%, 진행 0→1 동안 왼쪽 밖에서 오른쪽 밖으로 지나간다 (웹 데모와 같은 위치·폭).
Shader _shimmerShader(Rect bounds, double p, Color color) {
  final center = p * 1.7 - 0.31;
  final clear = color.withValues(alpha: 0);
  return LinearGradient(
    colors: [clear, color, clear],
    stops: [center - 0.19, center, center + 0.19],
    transform: const GradientRotation(-18 * math.pi / 180),
  ).createShader(bounds);
}

/// 요소 크기 비율(0~1)만큼 각 변에서 잘라낸다. 합이 1 을 넘으면 빈 영역.
class _InsetClipper extends CustomClipper<Rect> {
  _InsetClipper(double l, double t, double r, double b)
    : l = l.clamp(0.0, 1.0),
      t = t.clamp(0.0, 1.0),
      r = r.clamp(0.0, 1.0),
      b = b.clamp(0.0, 1.0);

  final double l, t, r, b;

  @override
  Rect getClip(Size size) {
    final left = size.width * l, top = size.height * t;
    final right = math.max(left, size.width * (1 - r)),
        bottom = math.max(top, size.height * (1 - b));
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldReclip(_InsetClipper old) =>
      old.l != l || old.t != t || old.r != r || old.b != b;
}

/// [origin] 을 중심으로 한 원. 값 1 = origin 에서 가장 먼 꼭짓점까지 (+1px: 모서리 안티에일리어스로 깎이지 않게).
class _CircleClipper extends CustomClipper<Rect> {
  _CircleClipper(this.value, this.origin);

  final double value;
  final FractionalOffset origin;

  @override
  Rect getClip(Size size) {
    final c = origin.alongSize(size);
    final far = [
      c.distance,
      (c - Offset(size.width, 0)).distance,
      (c - Offset(0, size.height)).distance,
      (c - Offset(size.width, size.height)).distance,
    ].reduce(math.max);
    return Rect.fromCircle(center: c, radius: math.max(0.0, value) * (far + 1));
  }

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.value != value || old.origin != origin;
}

/// feather 축 하나의 알파 곡선: 위치(요소 크기 비율)와 알파 쌍. 시작 쪽 clip [lo], 끝 쪽 clip [hi], 경계 폭 [f].
/// clip 0 이면 완전히 보이고 1 이면 완전히 숨도록 경계 중심을 `c = x·(1+f) − f/2` 로 옮긴다.
@visibleForTesting
(List<double>, List<double>) featherStops(double lo, double hi, double f) {
  f = f.clamp(1e-4, 1.0);
  final a0 = lo.clamp(0.0, 1.0) * (1 + f) - f, a1 = a0 + f;
  final b1 = (1 - hi.clamp(0.0, 1.0)) * (1 + f), b0 = b1 - f;
  if (a1 <= b0) return ([a0, a1, b0, b1], [0, 1, 1, 0]);
  if (b1 <= a0) return ([0, 1], [0, 0]);
  // 두 경계가 겹치면 두 경사의 교점이 가장 밝은 점
  return (
    [a0, (a0 + b1) / 2, b1],
    [0, ((b1 - a0) / (2 * f)).clamp(0.0, 1.0), 0],
  );
}

Shader _featherShader(
  Rect r,
  double lo,
  double hi,
  double f, {
  required bool horizontal,
}) {
  final (pos, alpha) = featherStops(lo, hi, f);
  final len = horizontal ? r.width : r.height;
  Offset at(double p) => horizontal
      ? Offset(r.left + p * len, r.top)
      : Offset(r.left, r.top + p * len);
  final first = pos.first, span = pos.last - first;
  return ui.Gradient.linear(
    at(first),
    at(pos.last),
    [for (final a in alpha) Color.fromRGBO(255, 255, 255, a)],
    [for (final p in pos) (p - first) / span],
  );
}
