import 'package:flutter/material.dart';

import '../../data/app_visuals.dart';
import '../../data/models.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';

/// Monday-first month grid with per-day heat levels.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.totalFor,
    required this.onSelected,
    this.maxTotal = const Duration(hours: 8),
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final Duration Function(DateTime day) totalFor;
  final ValueChanged<DateTime> onSelected;
  final Duration maxTotal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime first = DateTime(month.year, month.month, 1);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int leading = (first.weekday + 6) % 7;
    final int cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final double cellHeight = MediaQuery.textScalerOf(context).scale(46);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdayHeaders[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (int row = 0; row * 7 < cellCount; row++) ...<Widget>[
          SizedBox(
            height: cellHeight,
            child: Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: _cell(context, row * 7 + col - leading, daysInMonth),
                  ),
              ],
            ),
          ),
          if (row + 1 < (cellCount ~/ 7)) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber, int daysInMonth) {
    if (dayNumber < 0 || dayNumber >= daysInMonth) {
      return const SizedBox.shrink();
    }
    final DateTime date = DateTime(month.year, month.month, dayNumber + 1);
    final Duration total = totalFor(date);
    final bool isSelected = isSameDay(date, selected);
    final bool isToday = isSameDay(date, today);
    final bool isFuture = dateOnly(date).isAfter(dateOnly(today));
    final double intensity = isFuture ? 0 : usageIntensity(total, maxTotal);

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background = isFuture
        ? Colors.transparent
        : Color.lerp(
            scheme.surfaceContainerLow,
            scheme.primary,
            (intensity * 0.92).clamp(0.0, 1.0),
          )!;
    final Color foreground = intensity > 0.42
        ? scheme.onPrimary
        : (isFuture
              ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
              : scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: isFuture
            ? dateLong(date)
            : '${dateLong(date)} · ${total.inSeconds == 0 ? "нет данных" : formatDuration(total)}',
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isFuture ? null : () => onSelected(date),
          child: AnimatedContainer(
            duration: AppMotion.short,
            curve: AppMotion.emphasized,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? scheme.onSurface
                    : (isToday ? scheme.primary : Colors.transparent),
                width: isSelected ? 1.8 : 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${dayNumber + 1}',
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: isSelected || isToday
                    ? FontWeight.w600
                    : FontWeight.w500,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<String> _weekdayHeaders = <String>[
  'Пн',
  'Вт',
  'Ср',
  'Чт',
  'Пт',
  'Сб',
  'Вс',
];
