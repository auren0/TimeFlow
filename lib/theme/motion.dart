import 'package:flutter/animation.dart';

/// Motion tokens loosely following the Material 3 Expressive motion system.
///
/// Emphasized curves are snappy on the way in and soft on the way out, which
/// gives the interface its springy, "expressive" personality.
abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration long = Duration(milliseconds: 480);
  static const Duration page = Duration(milliseconds: 380);

  /// Standard emphasized easing.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Decelerating emphasized easing, used for entrances.
  static const Curve emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Accelerating emphasized easing, used for exits.
  static const Curve emphasizedAccel = Cubic(0.3, 0.0, 0.8, 0.15);

  /// A mild spring overshoot for playful scale changes.
  static const Curve spring = Cubic(0.34, 1.42, 0.64, 1.0);

  /// A softer spring used for larger surfaces.
  static const Curve softSpring = Cubic(0.22, 1.12, 0.36, 1.0);

  static const Interval enter = Interval(0.0, 0.72, curve: emphasizedDecel);
}
