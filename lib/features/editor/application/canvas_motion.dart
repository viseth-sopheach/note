import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Animates the canvas transform: eased wheel scrolling and view resets.
final class CanvasMotion {
  CanvasMotion({
    required TickerProvider vsync,
    required this.transform,
    required this.clamp,
    required this.reduceMotion,
    Duration smoothing = const Duration(milliseconds: 120),
  }) : _tauMs = smoothing.inMilliseconds / 3,
       _vsync = vsync {
    _anim = AnimationController(vsync: vsync)..addListener(_onAnim);
  }

  final TransformationController transform;

  /// Returns the allowed translation for [scale].
  final Offset Function(Offset translation, double scale) clamp;
  final bool Function() reduceMotion;

  final TickerProvider _vsync;
  final double _tauMs;
  late final Ticker _ticker = _vsync.createTicker(_onTick);
  late final AnimationController _anim;

  Offset _target = Offset.zero;
  Duration _last = Duration.zero;
  double _s0 = 1, _s1 = 1;
  Offset _t0 = Offset.zero, _t1 = Offset.zero;

  double get _scale => transform.value.storage[0];
  Offset get _translation =>
      Offset(transform.value.storage[12], transform.value.storage[13]);

  void _set(double s, Offset t) {
    transform.value = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, t.dx, t.dy, 0, 1);
  }

  /// Adds [delta] (screen pixels) to the scroll target and eases towards it.
  void scrollBy(Offset delta) {
    if (_anim.isAnimating) _anim.stop();
    final from = _ticker.isActive ? _target : _translation;
    _target = clamp(from + delta, _scale);
    if (reduceMotion()) {
      _ticker.stop();
      _set(_scale, _target);
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    final current = _translation;
    final remaining = _target - current;
    if (remaining.distance < 0.25) {
      _set(_scale, _target);
      _ticker.stop();
      return;
    }
    final k = 1 - math.exp(-dtMs / _tauMs);
    _set(_scale, current + remaining * k);
  }

  /// Animates to [scale] and [translation] (already clamped by the caller).
  void animateTo({
    required double scale,
    required Offset translation,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    stop();
    if (reduceMotion()) {
      _set(scale, translation);
      return;
    }
    _s0 = _scale;
    _t0 = _translation;
    _s1 = scale;
    _t1 = translation;
    _anim
      ..duration = duration
      ..forward(from: 0);
  }

  void _onAnim() {
    final t = Curves.easeOutCubic.transform(_anim.value);
    _set(lerpDouble(_s0, _s1, t)!, Offset.lerp(_t0, _t1, t)!);
  }

  /// Call when the user takes over (touch, pinch, scrollbar drag).
  void stop() {
    _ticker.stop();
    _anim.stop();
  }

  void dispose() {
    _ticker.dispose();
    _anim.dispose();
  }
}