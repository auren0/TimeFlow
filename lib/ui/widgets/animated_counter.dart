import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../utils/formatters.dart';

/// Smoothly counts from 0 (or the previous value) whenever the duration
/// changes. Uses tabular figures so digits don't jitter.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 850),
    this.textAlign,
    this.maxLines,
  });

  final Duration value;
  final TextStyle? style;
  final String Function(Duration value)? formatter;
  final Duration duration;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final String Function(Duration) format = formatter ?? formatDuration;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.inMilliseconds.toDouble()),
      duration: duration,
      curve: AppMotion.emphasizedDecel,
      builder: (BuildContext context, double millis, Widget? _) {
        return Text(
          format(Duration(milliseconds: millis.round())),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        );
      },
    );
  }
}
