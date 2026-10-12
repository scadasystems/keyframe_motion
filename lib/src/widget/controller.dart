import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 씬 클록. 경과 시간(ms)만 내보내고, delay·repeat 는 각 [Timeline] 이 해석한다.
/// 하나를 여러 `Motion` 이 공유하면 모두 같은 프레임 값으로 움직인다.
class MotionController extends ChangeNotifier {
  MotionController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  double _timeMs = 0;
  double _anchorMs = 0;
  int _direction = 1;

  double get timeMs => _timeMs;
  bool get isPlaying => _ticker.isActive;
  bool get isReversed => _direction < 0;

  void play() {
    if (_ticker.isActive) return;
    _anchorMs = _timeMs;
    _ticker.start();
  }

  void pause() => _ticker.stop();

  void seek(double ms) {
    _timeMs = ms < 0 ? 0 : ms;
    _restartFromHere();
    notifyListeners();
  }

  /// 재생 방향을 뒤집는다. 0 에 닿으면 멈춘다.
  void reverse() {
    _direction = -_direction;
    _restartFromHere();
  }

  void _restartFromHere() {
    if (!_ticker.isActive) return;
    _ticker.stop();
    _anchorMs = _timeMs;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _timeMs = _anchorMs + _direction * elapsed.inMicroseconds / 1000;
    if (_direction < 0 && _timeMs <= 0) {
      _timeMs = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
