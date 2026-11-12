import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';

/// A compact bar chart for daily totals (week / month trends).
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.values,
    required this.dates,
    this.highlightDate,
    this.maxTotal,
    this.height = 120,
    this.showLabels = true,
    this.barColor,
  });

  final List<Duration> values;
  final List<DateTime> dates;
  final DateTime? highlightDate;
  final Duration? maxTotal;
  final double height;
  final bool showLabels;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int maxSeconds = _maxSeconds();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: AppMotion.emphasizedDecel,
      builder: (BuildContext context, double progress, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (int i = 0; i < values.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Tooltip(
                          message: i < dates.length
                              ? '${dateLong(dates[i])} · ${formatDuration(values[i])}'
                              : formatDuration(values[i]),
                          waitDuration: const Duration(milliseconds: 500),
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 26),
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: _heightFactor(
                                  i,
                                  maxSeconds,
                                  progress,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        _colorFor(i, scheme) ??
                                        (barColor ?? scheme.primary),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showLabels) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (int i = 0; i < values.length; i++)
                    Expanded(
                      child: Text(
                        i < dates.length ? _label(dates[i], values.length) : '',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: _isHighlighted(i)
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: _isHighlighted(i)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  int _maxSeconds() {
    int maxSeconds = 30 * 60;
    for (final Duration value in values) {
      if (value.inSeconds > maxSeconds) maxSeconds = value.inSeconds;
    }
    final int? supplied = maxTotal?.inSeconds;
    if (supplied != null && supplied > 0) {
      maxSeconds = supplied;
    }
    return maxSeconds;
  }

  double _heightFactor(int index, int maxSeconds, double progress) {
    if (index >= values.length) return 0.02;
    final double norm = (values[index].inSeconds / maxSeconds).clamp(0.0, 1.0);
    final double stagger = ((progress * 1.35 - index * 0.02)).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(stagger);
    final double value = (0.025 + norm * 0.975 * eased).clamp(0.025, 1.0);
    return values[index].inMinutes <= 0 ? 0.02 : value;
  }

  bool _isHighlighted(int index) {
    if (highlightDate == null || index >= dates.length) return false;
    return isSameDay(dates[index], highlightDate!);
  }

  Color? _colorFor(int index, ColorScheme scheme) {
    if (highlightDate == null) return barColor;
    return _isHighlighted(index)
        ? scheme.primary
        : (barColor ?? scheme.primary).withValues(alpha: 0.38);
  }

  String _label(DateTime date, int count) {
    if (count > 20) {
      return date.day == 1 ? '${date.day}.${date.month}' : '${date.day}';
    }
    return weekdayShort(date);
  }
}
