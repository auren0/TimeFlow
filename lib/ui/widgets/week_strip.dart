import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';

/// Seven day selectors ending today.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.totalFor,
    required this.onSelected,
  });

  final DateTime selected;
  final DateTime today;
  final Duration Function(DateTime day) totalFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => addDays(today, -(6 - i)),
    );

    return Row(
      children: <Widget>[
        for (int i = 0; i < days.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _DayPill(
              date: days[i],
              total: totalFor(days[i]),
              selected: isSameDay(days[i], selected),
              isToday: isSameDay(days[i], today),
              onTap: () => onSelected(days[i]),
              scheme: scheme,
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.date,
    required this.total,
    required this.selected,
    required this.isToday,
    required this.onTap,
    required this.scheme,
    required this.theme,
  });

  final DateTime date;
  final Duration total;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Tooltip(
      message:
          '${dateLong(date)} · ${total.inSeconds == 0 ? "нет данных" : formatDuration(total)}',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                weekdayShort(date),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer.withValues(alpha: 0.75)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    total.inSeconds <= 0 ? '—' : formatDurationCompact(total),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: selected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? (selected ? scheme.onPrimaryContainer : scheme.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
