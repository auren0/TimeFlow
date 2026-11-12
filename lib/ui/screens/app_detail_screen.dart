import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/app_visuals.dart';
import '../../data/models.dart';
import '../../state/timeflow_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../app_scope.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_avatar.dart';
import '../widgets/daily_bars.dart';
import '../widgets/expressive_card.dart';
import '../widgets/hourly_chart.dart';
import '../widgets/section_header.dart';
import '../widgets/trend_chip.dart';

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({
    super.key,
    required this.appId,
    required this.appName,
    required this.start,
    required this.end,
    required this.rangeLabel,
  });

  final String appId;
  final String appName;
  final DateTime start;
  final DateTime end;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final TimeFlowState state = TimeFlowScope.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final RangeSummary range = state.store.rangeSummary(start, end);
        AppUsage? usage;
        for (final AppUsage app in range.apps) {
          if (app.appId == appId) {
            usage = app;
            break;
          }
        }

        final List<DateTime> dates = daysInRange(start, end);
        final bool singleDay = dates.length <= 1;
        final DateTime today = dateOnly(state.now);

        final List<AppSession> sessions = <AppSession>[];
        final List<Duration> dailyValues = <Duration>[];
        int activeAppDays = 0;
        for (final DateTime date in dates) {
          final DaySummary day = state.store.summaryFor(date);
          Duration value = Duration.zero;
          for (final AppUsage app in day.apps) {
            if (app.appId == appId) {
              value = app.duration;
              break;
            }
          }
          dailyValues.add(value);
          if (value.inSeconds > 0) activeAppDays++;
          for (final AppSession session in day.sessions) {
            if (session.appId == appId) sessions.add(session);
          }
        }
        sessions.sort(
          (AppSession a, AppSession b) => b.startMs.compareTo(a.startMs),
        );

        final Duration total = usage?.duration ?? Duration.zero;
        final double share = range.total.inMilliseconds <= 0
            ? 0
            : total.inMilliseconds / range.total.inMilliseconds;
        final Duration averageSession = sessions.isEmpty
            ? Duration.zero
            : Duration(milliseconds: total.inMilliseconds ~/ sessions.length);
        final Duration averageDay = activeAppDays <= 0
            ? Duration.zero
            : Duration(milliseconds: total.inMilliseconds ~/ activeAppDays);

        final Color accent = AppVisuals.forApp(appId, appName).color;

        List<Duration> hourly = const <Duration>[];
        if (singleDay) {
          hourly = summarizeDay(
            start,
            sessions.where((AppSession s) => s.startMs < s.endMs),
          ).hourly;
        }

        final bool isToday = isSameDay(start, today) && singleDay;

        return Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                elevation: 0,
                title: Text(
                  appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ExpressiveCard(
                            radius: AppRadius.hero,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                            color: scheme.surfaceContainerLow,
                            borderColor: scheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    AppAvatar(
                                      appId: appId,
                                      appName: appName,
                                      size: 54,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            appName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            rangeLabel,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'ВСЕГО',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedCounter(
                                    value: total,
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      '${formatPercent(share)} общего времени',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    Text(
                                      pluralSessions(sessions.length),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(
                                  height: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _MiniStat(
                                        value: formatDurationCompact(
                                          averageDay,
                                        ),
                                        label: 'в день',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MiniStat(
                                        value: formatDurationCompact(
                                          averageSession,
                                        ),
                                        label: 'средняя сессия',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MiniStat(
                                        value: '$activeAppDays',
                                        label: pluralDaysWord(activeAppDays),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ExpressiveCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SectionHeader(
                                  title: singleDay ? 'По часам' : 'По дням',
                                  subtitle: singleDay
                                      ? 'Активность в этом приложении'
                                      : 'Как менялось время за период',
                                ),
                                const SizedBox(height: 18),
                                if (total.inSeconds <= 0)
                                  const EmptyState(
                                    compact: true,
                                    icon: FluentIcons.chart_multiple_24_regular,
                                    title: 'Нет данных',
                                    message: 'За выбранный период активность не записана.',
                                  )
                                else if (singleDay)
                                  HourlyChart(
                                    hourly: hourly,
                                    height: 140,
                                    barColor: accent,
                                    highlightHour: isToday
                                        ? state.now.hour
                                        : null,
                                    animateKey: start,
                                  )
                                else
                                  DailyBars(
                                    values: dailyValues,
                                    dates: dates,
                                    highlightDate: isToday ? today : null,
                                    maxTotal: null,
                                    height: 140,
                                    barColor: accent,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ExpressiveCard(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SectionHeader(
                                  title: 'Сессии',
                                  subtitle: pluralSessions(sessions.length),
                                ),
                                const SizedBox(height: 6),
                                if (sessions.isEmpty)
                                  const EmptyState(
                                    compact: true,
                                    icon: FluentIcons.history_24_regular,
                                    title: 'Пока пусто',
                                    message: 'Здесь появится история использования приложения.',
                                  )
                                else ...<Widget>[
                                  for (final AppSession session
                                      in sessions.take(100))
                                    _AppSessionRow(
                                      session: session,
                                      showDate: !singleDay,
                                    ),
                                  if (sessions.length > 100)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'Показаны последние 100 из ${sessions.length}',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _AppSessionRow extends StatelessWidget {
  const _AppSessionRow({required this.session, required this.showDate});

  final AppSession session;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              FluentIcons.clock_24_regular,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  showDate
                      ? '${dateLong(session.start)} · ${formatTimeRange(session)}'
                      : formatTimeRange(session),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showDate ? weekdayFull(session.start) : 'Длительность',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatDuration(session.duration),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
