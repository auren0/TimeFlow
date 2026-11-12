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
import '../widgets/expressive_card.dart';
import '../widgets/hourly_chart.dart';
import '../widgets/section_header.dart';
import '../widgets/trend_chip.dart';
import '../widgets/week_strip.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selected = dateOnly(DateTime.now());
  DateTime _lastToday = dateOnly(DateTime.now());

  @override
  bool get wantKeepAlive => true;

  void _selectDay(DateTime day, DateTime today) {
    final DateTime value = dateOnly(day);
    if (value.isAfter(today)) return;
    if (isSameDay(value, _selected)) return;
    setState(() => _selected = value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TimeFlowState state = TimeFlowScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = Theme.of(context);
        final DateTime today = dateOnly(state.now);
        // Follow the new day automatically if the user was viewing today when
        // midnight passed. If they deliberately opened an older day, keep it.
        if (!isSameDay(today, _lastToday)) {
          final bool followedToday = isSameDay(_selected, _lastToday);
          _lastToday = today;
          if (followedToday) _selected = today;
        }
        final DateTime selected = _selected.isAfter(today) ? today : _selected;
        final DaySummary summary = state.store.summaryFor(selected);
        final DaySummary previous = state.store.summaryFor(
          addDays(selected, -1),
        );
        final bool isToday = isSameDay(selected, today);
        final DateTime weekStart = addDays(today, -6);
        final RangeSummary week = state.store.rangeSummary(weekStart, today);

        int peakHour = -1;
        for (int hour = 0; hour < summary.hourly.length; hour++) {
          if (summary.hourly[hour] > Duration.zero &&
              (peakHour == -1 ||
                  summary.hourly[hour] > summary.hourly[peakHour])) {
            peakHour = hour;
          }
        }

        final Widget header = _DayHeader(
          selected: selected,
          today: today,
          isToday: isToday,
          onPrevious: () => _selectDay(addDays(selected, -1), today),
          onNext: isToday
              ? null
              : () => _selectDay(addDays(selected, 1), today),
        );

        final Widget banner = _banner(context, state);
        final Widget hero = _HeroCard(
          summary: summary,
          previous: previous,
          isToday: isToday,
          onOpen: () => openDayDetail(context, selected),
        );

        final Widget weekCard = ExpressiveCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SectionHeader(
                  title: 'Неделя',
                  subtitle: '${formatDuration(week.total)} за 7 дней',
                ),
              ),
              const SizedBox(height: 14),
              WeekStrip(
                selected: selected,
                today: today,
                totalFor: (DateTime day) => state.store.summaryFor(day).total,
                onSelected: (DateTime day) => _selectDay(day, today),
              ),
            ],
          ),
        );

        final Widget hourlyCard = ExpressiveCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHeader(
                title: 'По часам',
                subtitle: peakHour < 0
                    ? 'Нет активности за этот день'
                    : 'Пик — ${peakHour.toString().padLeft(2, '0')}:00 · ${formatDuration(summary.hourly[peakHour])}',
              ),
              const SizedBox(height: 18),
              HourlyChart(
                hourly: summary.hourly,
                height: 128,
                highlightHour: isToday ? state.now.hour : null,
                animateKey: selected,
              ),
            ],
          ),
        );

        final Widget topAppsCard = ExpressiveCard(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SectionHeader(
                  title: 'Приложения',
                  subtitle: summary.apps.isEmpty
                      ? 'Здесь появятся приложения, которые ты использовал'
                      : '${pluralApps(summary.apps.length)} · ${formatDuration(summary.total)}',
                  actionLabel: summary.apps.isEmpty ? null : 'Все',
                  onAction: summary.apps.isEmpty
                      ? null
                      : () => widget.onNavigateTab?.call(2),
                ),
              ),
              const SizedBox(height: 8),
              if (summary.apps.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: EmptyState(
                    compact: true,
                    icon: FluentIcons.weather_moon_24_regular,
                    title: 'Тихий день',
                    message: isToday
                        ? 'Пока нет записанной активности. Всё появится здесь автоматически.'
                        : 'За этот день нет сохранённых сессий.',
                  ),
                )
              else
                for (int i = 0; i < summary.apps.length && i < 5; i++)
                  AppUsageTile(
                    usage: summary.apps[i],
                    total: summary.total,
                    compact: true,
                    showChevron: true,
                    onTap: () => openAppDetail(
                      context,
                      state,
                      appId: summary.apps[i].appId,
                      appName: summary.apps[i].appName,
                      start: selected,
                      end: selected,
                      rangeLabel: isToday
                          ? 'Сегодня'
                          : relativeDate(selected, today),
                    ),
                  ),
            ],
          ),
        );

        return CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              titleSpacing: 20,
              title: Text(
                'TimeFlow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: <Widget>[
                if (state.syncing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        value: state.syncTotal > 0 ? state.syncProgress : null,
                      ),
                    ),
                  )
                else if (state.demoActive || state.tracker.canReadHistory)
                  IconButton(
                    onPressed: () => state.refreshToday(),
                    tooltip: 'Обновить данные',
                    icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
                  ),
                const SizedBox(width: 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool wide = constraints.maxWidth >= 960;
                            final bool hasBanner = banner is! SizedBox;
                            final List<Widget> mobile = <Widget>[
                              header,
                              const SizedBox(height: 16),
                              banner,
                              SizedBox(height: hasBanner ? 14 : 0),
                              hero,
                              const SizedBox(height: 14),
                              weekCard,
                              const SizedBox(height: 14),
                              hourlyCard,
                              const SizedBox(height: 14),
                              topAppsCard,
                            ];

                            if (!wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: mobile,
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                header,
                                const SizedBox(height: 16),
                                banner,
                                SizedBox(height: hasBanner ? 14 : 0),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          hero,
                                          const SizedBox(height: 16),
                                          hourlyCard,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          weekCard,
                                          const SizedBox(height: 16),
                                          topAppsCard,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _banner(BuildContext context, TimeFlowState state) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (state.tracker.canReadHistory &&
        !state.permissionGranted &&
        !state.demoActive) {
      return _BannerCard(
        icon: FluentIcons.shield_checkmark_24_regular,
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        title: 'Разреши доступ к статистике',
        message: 'Android хранит историю использования приложений. TimeFlow нужно разрешение, чтобы показывать её здесь.',
        action: FilledButton.icon(
          onPressed: state.requestPermission,
          icon: const Icon(FluentIcons.lock_open_24_regular, size: 18),
          label: const Text('Разрешить'),
        ),
      );
    }

    if (state.demoActive) {
      final String message = !state.tracker.isSupported
          ? 'На платформе ${state.tracker.platformName} системная статистика недоступна. Показаны демонстрационные данные, чтобы можно было оценить интерфейс.'
          : 'Включён демо-режим. Все цифры сгенерированы для примера — реальная статистика не записывается.';
      return _BannerCard(
        icon: FluentIcons.beaker_24_regular,
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        title: 'Демо-режим',
        message: message,
        action: TextButton(
          onPressed: () => widget.onNavigateTab?.call(3),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSecondaryContainer,
          ),
          child: const Text('Настроить'),
        ),
      );
    }

    if (state.syncError != null) {
      return _BannerCard(
        icon: FluentIcons.error_circle_24_regular,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        title: 'Ошибка синхронизации',
        message: state.syncError!,
        action: TextButton(
          onPressed: () => state.syncHistory(force: true),
          style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
          child: const Text('Повторить'),
        ),
      );
    }

    if (state.tracker.isSupported &&
        state.store.dayCount == 0 &&
        !state.syncing) {
      return _BannerCard(
        icon: FluentIcons.sparkle_24_regular,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
        title: 'TimeFlow запущен',
        message: state.tracker.canTrackLive
            ? 'Сверни окно и работай как обычно — время в приложениях начнёт записываться автоматически. Можно сразу посмотреть демо-данные.'
            : 'История использования появится после синхронизации. А пока можно посмотреть, как всё будет выглядеть.',
        action: FilledButton.tonal(
          onPressed: () => state.setDemoMode(true),
          child: const Text('Посмотреть демо'),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.selected,
    required this.today,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selected;
  final DateTime today;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isToday ? 'Сегодня' : relativeDate(selected, today),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dateWithWeekday(selected),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPrevious,
          tooltip: 'Предыдущий день',
          icon: const Icon(FluentIcons.chevron_left_24_regular),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          onPressed: onNext,
          tooltip: 'Следующий день',
          icon: const Icon(FluentIcons.chevron_right_24_regular),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.summary,
    required this.previous,
    required this.isToday,
    required this.onOpen,
  });

  final DaySummary summary;
  final DaySummary previous;
  final bool isToday;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppUsage? topApp = summary.topApp;
    final double topShare = topApp == null ? 0 : topApp.shareOf(summary.total);

    return ExpressiveCard(
      radius: AppRadius.hero,
      color: scheme.surfaceContainerLow,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Экранное время',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: summary.total,
              style: theme.textTheme.displayLarge?.copyWith(
                color: scheme.onSurface,
                fontSize: 48,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TrendChip(current: summary.total, previous: previous.total),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        topApp.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${formatPercent(topShare)} экранного времени',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                child: _HeroStat(
                  value: '${summary.sessionCount}',
                  label: 'сессий',
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '${summary.apps.length}',
                  label: 'приложений',
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: summary.total.inSeconds == 0
                      ? '—'
                      : formatDurationCompact(summary.averageSession),
                  label: 'средняя сессия',
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
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
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ExpressiveCard(
      color: background,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 520;
          final Widget text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: foreground, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.82),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                text,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}
