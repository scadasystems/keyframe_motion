/// Flutter 키프레임 타임라인 애니메이션 — 스프링, JSON 직렬화.
library;

export 'src/curves/curve_names.dart';
export 'src/curves/spring.dart';
export 'src/presets.dart';
export 'src/json/codec.dart' show MotionFormatException, supportedSchemaVersion;
export 'src/timeline/evaluate.dart'
    show evaluate, evaluateChannels, evaluateEnd, localTime, newMotionValues;
export 'src/timeline/timeline.dart';
export 'src/widget/controller.dart';
export 'src/widget/motion.dart'
    show Motion, MotionChannelBuilder, MotionChannels;
export 'src/widget/quality.dart';
export 'src/widget/transform.dart' show motionMatrix;
