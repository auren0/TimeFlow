import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/timeflow_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../app_scope.dart';
import '../navigation.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_usage_tile.dart';
import '../widgets/day_timeline.dart';
import '../widgets/expressive_card.dart';
import '../widgets/hourly_chart.dart';
import '../widgets/section_header.dart';
import '../widgets/trend_chip.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final TimeFlowState state = TimeFlowScope.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final DateTime today = dateOnly(state.now);
        final DaySummary summary = state.store.summaryFor(day);
        final DaySummary previous = state.store.summaryFor(addDays(day, -1));
        final bool isToday = isSameDay(day, today);

        int peakHour = -1;
        for (int hour = 0; hour < 24; hour++) {
          if (summary.hourly[hour] > Duration.zero &&
              (peakHour == -1 ||
                  summary.hourly[hour] > summary.hourly[peakHour])) {
            peakHour = hour;
          }
        }

        final List<AppSession> sessions = List<AppSession>.of(
          summary.sessions,
        )..sort((AppSession a, AppSession b) => b.startMs.compareTo(a.startMs));

        return Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                elevation: 0,
                title: Text(
                  isToday ? 'Сегодня' : relativeDate(day, today),
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
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _DayHero(
                            summary: summary,
                            previous: previous,
                            isToday: isToday,
                          ),
                          const SizedBox(height: 14),
                          ExpressiveCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SectionHeader(
                                  title: 'По часам',
                                  subtitle: peakHour < 0
                                      ? 'Нет активности'
                                      : 'Пик — ${peakHour.toString().padLeft(2, '0')}:00 · ${formatDuration(summary.hourly[peakHour])}',
                                ),
                                const SizedBox(height: 18),
                                HourlyChart(
                                  hourly: summary.hourly,
                                  height: 140,
                                  highlightHour: isToday
                                      ? state.now.hour
                                      : null,
                                  animateKey: day,
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
                                const SectionHeader(
                                  title: 'Лента дня',
                                  subtitle: 'Когда и сколько времени ты провёл в приложениях',
                                ),
                                const SizedBox(height: 16),
                                DayTimeline(summary: summary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ExpressiveCard(
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: SectionHeader(
                                    title: 'Приложения',
                                    subtitle:
                                        '${pluralApps(summary.apps.length)} · ${formatDuration(summary.total)}',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (summary.apps.isEmpty)
                                  EmptyState(
                                    compact: true,
                                    icon:
                                        FluentIcons.calendar_cancel_24_regular,
                                    title: 'Нет данных',
                                    message:
                                        'В этот день активность не записана.',
                                  )
                                else
                                  for (final AppUsage app in summary.apps)
                                    AppUsageTile(
                                      usage: app,
                                      total: summary.total,
                                      showChevron: true,
                                      onTap: () => openAppDetail(
                                        context,
                                        state,
                                        appId: app.appId,
                                        appName: app.appName,
                                        start: day,
                                        end: day,
                                        rangeLabel: isToday
                                            ? 'Сегодня'
                                            : relativeDate(day, today),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ExpressiveCard(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SectionHeader(
                                  title: 'Сессии',
                                  subtitle: pluralSessions(sessions.length),
                                ),
                                const SizedBox(height: 8),
                                if (sessions.isEmpty)
                                  const EmptyState(
                                    compact: true,
                                    icon: FluentIcons.history_24_regular,
                                    title: 'Нет сессий',
                                    message: 'Здесь появится хронология использования приложений.',
                                  )
                                else
                                  for (int i = 0; i < sessions.length; i++) ...[
                                    _SessionRow(session: sessions[i]),
                                    if (i < sessions.length - 1)
                                      Divider(
                                        height: 1,
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.35,
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

class _DayHero extends StatelessWidget {
  const _DayHero({
    required this.summary,
    required this.previous,
    required this.isToday,
  });

  final DaySummary summary;
  final DaySummary previous;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppUsage? topApp = summary.topApp;
    final double share = topApp == null ? 0 : topApp.shareOf(summary.total);

    return ExpressiveCard(
      radius: AppRadius.hero,
      color: scheme.surfaceContainerLow,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  dateLong(summary.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isToday)
                Text(
                  'Сейчас',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: summary.total,
              style: theme.textTheme.displayLarge?.copyWith(
                color: scheme.onSurface,
                fontSize: 46,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TrendChip(
                current: summary.total,
                previous: previous.total,
                label: 'к вчера',
              ),
              if (summary.total.inSeconds > 0)
                Text(
                  pluralSessions(summary.sessionCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (topApp != null) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                AppAvatar(
                  appId: topApp.appId,
                  appName: topApp.appName,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${topApp.appName} · ${formatPercent(share)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  formatDurationCompact(topApp.duration),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  value: '${summary.sessionCount}',
                  label: pluralSessionsWord(summary.sessionCount),
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${summary.apps.length}',
                  label: 'приложений',
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: summary.total.inSeconds == 0
                      ? '—'
                      : formatDurationCompact(summary.longestSession),
                  label: 'макс. сессия',
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.65),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          AppAvatar(appId: session.appId, appName: session.appName, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatClock(session.start)} – ${formatClock(session.end)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
