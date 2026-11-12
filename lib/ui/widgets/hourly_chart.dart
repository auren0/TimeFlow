import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A 24-hour activity chart. Bars grow with a staggered spring animation, and
/// the current hour is highlighted when the chart belongs to today.
class HourlyChart extends StatefulWidget {
  const HourlyChart({
    super.key,
    required this.hourly,
    this.height = 132,
    this.highlightHour,
    this.barColor,
    this.showLabels = true,
    this.animateKey,
  });

  final List<Duration> hourly;
  final double height;
  final int? highlightHour;
  final Color? barColor;
  final bool showLabels;

  /// Restarts the entrance animation when this value changes (for example the
  /// selected day). Live data updates repaint without resetting the bars.
  final Object? animateKey;

  @override
  State<HourlyChart> createState() => _HourlyChartState();
}

class _HourlyChartState extends State<HourlyChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  @override
  void didUpdateWidget(covariant HourlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int oldTotal = oldWidget.hourly.fold<int>(
      0,
      (int sum, Duration d) => sum + d.inSeconds,
    );
    final int newTotal = widget.hourly.fold<int>(
      0,
      (int sum, Duration d) => sum + d.inSeconds,
    );
    if (oldWidget.animateKey != widget.animateKey ||
        (oldTotal == 0 && newTotal > 0)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int totalSeconds = widget.hourly.fold<int>(
      0,
      (int sum, Duration d) => sum + d.inSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  painter: _HourlyPainter(
                    hourly: widget.hourly,
                    progress: _controller.value,
                    scheme: scheme,
                    highlightHour: widget.highlightHour,
                    barColor: widget.barColor,
                    totalSeconds: totalSeconds,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ),
        if (widget.showLabels) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final String label in <String>['00', '06', '12', '18', '24'])
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HourlyPainter extends CustomPainter {
  _HourlyPainter({
    required this.hourly,
    required this.progress,
    required this.scheme,
    required this.highlightHour,
    required this.barColor,
    required this.totalSeconds,
  });

  final List<Duration> hourly;
  final double progress;
  final ColorScheme scheme;
  final int? highlightHour;
  final Color? barColor;
  final int totalSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final double factor in <double>[0.25, 0.5, 0.75]) {
      final double y = size.height - size.height * factor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Color primary = barColor ?? scheme.primary;
    final Color secondary = barColor == null
        ? scheme.tertiary
        : Color.lerp(barColor, Colors.white, 0.3) ?? primary;

    int maxSeconds = 30 * 60;
    for (final Duration entry in hourly) {
      maxSeconds = math.max(maxSeconds, entry.inSeconds);
    }

    final double slot = size.width / 24;
    final double barWidth = math.max(3.0, math.min(slot * 0.54, 20.0));
    final double baseline = size.height - 2;
    final double available = size.height - 8;

    if (highlightHour != null) {
      final double markerX = slot * highlightHour! + slot / 2;
      final Paint marker = Paint()
        ..color = primary.withValues(alpha: 0.28)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(markerX, 0), Offset(markerX, baseline), marker);
      canvas.drawCircle(
        Offset(markerX, 2.5),
        2.5,
        Paint()..color = primary.withValues(alpha: 0.65),
      );
    }

    for (int hour = 0; hour < 24; hour++) {
      final Duration value = hour < hourly.length
          ? hourly[hour]
          : Duration.zero;
      final double norm = (value.inSeconds / maxSeconds).clamp(0.0, 1.0);
      final double stagger = ((progress * 1.55 - hour * 0.017)).clamp(0.0, 1.0);
      final double eased = Curves.easeOutCubic.transform(stagger);
      final double x = slot * hour + (slot - barWidth) / 2;

      if (value.inSeconds <= 0) {
        final Paint dot = Paint()
          ..color = scheme.outlineVariant.withValues(alpha: 0.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseline - 3, barWidth, 3),
            const Radius.circular(2),
          ),
          dot,
        );
        continue;
      }

      final double rawHeight = 6 + available * math.sqrt(norm);
      final double barHeight = math.max(4.0, rawHeight * eased);
      final Rect rect = Rect.fromLTWH(
        x,
        baseline - barHeight,
        barWidth,
        barHeight,
      );
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(barWidth / 2),
      );

      final Color top = Color.lerp(
        primary,
        secondary,
        (norm * 0.85).clamp(0.0, 1.0),
      )!;
      final Paint paint = Paint()..color = top;
      canvas.drawRRect(rrect, paint);

      if (highlightHour == hour) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = scheme.onSurface.withValues(alpha: 0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.highlightHour != highlightHour ||
        oldDelegate.scheme != scheme ||
        oldDelegate.barColor != barColor ||
        oldDelegate.hourly != hourly;
  }
}
