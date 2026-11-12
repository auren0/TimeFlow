import 'package:flutter/material.dart';

import '../../data/app_visuals.dart';
import '../../data/models.dart';
import '../../utils/formatters.dart';
import 'app_avatar.dart';

/// A compact "ribbon" timeline of the day: one lane per app, segments placed
/// proportionally between 00:00 and 24:00.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.summary,
    this.maxApps = 8,
    this.showHeader = true,
  });

  final DaySummary summary;
  final int maxApps;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<AppUsage> apps = summary.apps.take(maxApps).toList();
    if (apps.isEmpty) {
      return Text(
        'За этот день пока нет активности.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 520;
        final double nameWidth = narrow ? 92 : 150;
        final double valueWidth = narrow ? 48 : 62;
        final double trackWidth =
            (constraints.maxWidth - nameWidth - valueWidth - 20).clamp(
              40.0,
              double.infinity,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showHeader)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: nameWidth,
                      child: Text(
                        'Приложение',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HourAxis(theme: theme, scheme: scheme),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: valueWidth,
                      child: Text(
                        'Время',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final AppUsage app in apps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: nameWidth,
                      child: Row(
                        children: <Widget>[
                          AppAvatar(
                            appId: app.appId,
                            appName: app.appName,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: trackWidth,
                      height: 14,
                      child: _Lane(
                        app: app,
                        summary: summary,
                        scheme: scheme,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: valueWidth,
                      child: Text(
                        formatDurationCompact(app.duration),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(
                left: nameWidth + 10,
                right: valueWidth + 10,
              ),
              child: _HourAxisLabels(theme: theme, scheme: scheme),
            ),
          ],
        );
      },
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.app,
    required this.summary,
    required this.scheme,
    required this.theme,
  });

  final AppUsage app;
  final DaySummary summary;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color color = AppVisuals.forApp(app.appId, app.appName).color;
    final List<AppSession> sessions = summary.sessions
        .where((AppSession s) => s.appId == app.appId)
        .toList();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              for (final AppSession session in sessions)
                Positioned(
                  left: _fraction(session.start) * width,
                  width:
                      ((session.end.difference(session.start).inSeconds /
                                  86400) *
                              width)
                          .clamp(3.0, width),
                  top: 2,
                  bottom: 2,
                  child: Tooltip(
                    message:
                        '${app.appName}\n${formatTimeRange(session)} · ${formatDuration(session.duration)}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _fraction(DateTime time) {
    return ((time.hour * 3600 + time.minute * 60 + time.second) / 86400).clamp(
      0.0,
      0.999,
    );
  }
}

class _HourAxis extends StatelessWidget {
  const _HourAxis({required this.theme, required this.scheme});

  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return _HourAxisLabels(theme: theme, scheme: scheme);
  }
}

class _HourAxisLabels extends StatelessWidget {
  const _HourAxisLabels({required this.theme, required this.scheme});

  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['0', '6', '12', '18', '24'];
    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Align(
              alignment: i == 0
                  ? Alignment.centerLeft
                  : (i == labels.length - 1
                        ? Alignment.centerRight
                        : Alignment.center),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  labels[i],
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
