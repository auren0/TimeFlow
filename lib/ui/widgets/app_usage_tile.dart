import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/app_visuals.dart';
import '../../data/models.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';
import 'app_avatar.dart';

/// One ranked application row with a proportional usage bar.
class AppUsageTile extends StatelessWidget {
  const AppUsageTile({
    super.key,
    required this.usage,
    required this.total,
    this.onTap,
    this.showBar = true,
    this.showChevron = false,
    this.rank,
    this.compact = false,
    this.trailingLabel,
  });

  final AppUsage usage;
  final Duration total;
  final VoidCallback? onTap;
  final bool showBar;
  final bool showChevron;
  final int? rank;
  final bool compact;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color color = AppVisuals.forApp(usage.appId, usage.appName).color;
    final double share = usage.shareOf(total).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 7 : 9,
        ),
        child: Row(
          children: <Widget>[
            if (rank != null) ...<Widget>[
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            AppAvatar(
              appId: usage.appId,
              appName: usage.appName,
              size: compact ? 36 : 44,
            ),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool tight =
                              compact || constraints.maxWidth < 230;
                          final String durationLabel =
                              trailingLabel ??
                              (tight
                                  ? formatDurationCompact(usage.duration)
                                  : formatDuration(usage.duration));
                          return Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  usage.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.55,
                                ),
                                child: Text(
                                  durationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: 5),
                  if (showBar)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: ColoredBox(
                                color: scheme.surfaceContainerHighest,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: share),
                              duration: const Duration(milliseconds: 700),
                              curve: AppMotion.emphasizedDecel,
                              builder:
                                  (
                                    BuildContext context,
                                    double value,
                                    Widget? _,
                                  ) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: value.clamp(0.0, 1.0),
                                      heightFactor: 1,
                                      child: ColoredBox(color: color),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: showBar ? 4 : 0),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        pluralSessions(usage.sessionCount),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        formatPercent(share),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showChevron) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                FluentIcons.chevron_right_24_regular,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
