import 'package:flutter/animation.dart';

/// JSON 곡선 이름 ↔ Curve. 웹 데모(`design/motion-demo`)와 같은 목록을 유지한다.
const Map<String, Curve> motionCurves = {
  'linear': Curves.linear,
  'ease': Curves.ease,
  'easeIn': Curves.easeIn,
  'easeOut': Curves.easeOut,
  'easeInOut': Curves.easeInOut,
  'easeInCubic': Curves.easeInCubic,
  'easeOutCubic': Curves.easeOutCubic,
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeInBack': Curves.easeInBack,
  'easeOutBack': Curves.easeOutBack,
  'fastOutSlowIn': Curves.fastOutSlowIn,
  'decelerate': Curves.decelerate,
  'bounceIn': Curves.bounceIn,
  'bounceOut': Curves.bounceOut,
  'elasticOut': Curves.elasticOut,
  // 구간 끝 전까지 이전 값을 유지하다가 끝에서 바로 바뀐다 — show/hide·깜빡임용
  'step': Threshold(1),
};
