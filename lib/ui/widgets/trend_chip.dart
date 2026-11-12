import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../utils/formatters.dart';

/// Compact comparison pill for day-over-day or period-over-period trends.
class TrendChip extends StatelessWidget {
  const TrendChip({
    super.key,
    required this.current,
    required this.previous,
    this.label = 'к вчера',
  });

  final Duration current;
  final Duration previous;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (previous.inMinutes < 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          current.inSeconds > 0 ? 'Первые данные' : 'Нет данных',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final double delta =
        (current.inMinutes - previous.inMinutes) / previous.inMinutes;
    final bool increase = delta >= 0;
    final Color tint = increase ? scheme.error : scheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget labelText = Text(
            '${trendLabel(current, previous)} $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                increase
                    ? FluentIcons.arrow_up_right_24_regular
                    : FluentIcons.arrow_down_right_24_regular,
                size: 14,
                color: tint,
              ),
              const SizedBox(width: 4),
              if (constraints.maxWidth.isFinite)
                Flexible(child: labelText)
              else
                labelText,
            ],
          );
        },
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 20 : 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 52 : 68,
            height: compact ? 52 : 68,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(compact ? 18 : 24),
            ),
            child: Icon(
              icon,
              size: compact ? 26 : 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (action != null) ...<Widget>[
            SizedBox(height: compact ? 14 : 20),
            action!,
          ],
        ],
      ),
    );
  }
}
