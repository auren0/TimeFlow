import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/timeflow_state.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';
import '../app_scope.dart';
import '../navigation.dart';
import '../widgets/app_usage_tile.dart';
import '../widgets/expressive_card.dart';
import '../widgets/month_calendar.dart';
import '../widgets/section_header.dart';
import '../widgets/trend_chip.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selected = dateOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _lastToday = dateOnly(DateTime.now());
  int _direction = 1;

  @override
  bool get wantKeepAlive => true;

  void _select(DateTime day) {
    if (isSameDay(day, _selected)) {
      openDayDetail(context, day);
      return;
    }
    setState(() => _selected = day);
  }

  void _changeMonth(int delta, DateTime today) {
    final DateTime target = DateTime(_month.year, _month.month + delta, 1);
    final DateTime currentMonth = DateTime(today.year, today.month, 1);
    if (target.isAfter(currentMonth)) return;
    final int maxDay = DateTime(target.year, target.month + 1, 0).day;
    final int desiredDay = _selected.day.clamp(1, maxDay);
    DateTime nextSelected = DateTime(target.year, target.month, desiredDay);
    if (nextSelected.isAfter(today)) nextSelected = today;
    setState(() {
      _direction = delta;
      _month = target;
      _selected = nextSelected;
    });
  }

  void _goToday(DateTime today) {
    setState(() {
      _direction = 1;
      _month = DateTime(today.year, today.month, 1);
      _selected = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TimeFlowState state = TimeFlowScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final DateTime today = dateOnly(state.now);
        if (!isSameDay(today, _lastToday)) {
          final bool followedToday = isSameDay(_selected, _lastToday);
          final bool followedMonth = isSameDay(
            _month,
            DateTime(_lastToday.year, _lastToday.month, 1),
          );
          _lastToday = today;
          if (followedToday) _selected = today;
          if (followedToday || followedMonth) {
            _month = DateTime(today.year, today.month, 1);
          }
        }
        final DateTime first = DateTime(_month.year, _month.month, 1);
        final DateTime last = DateTime(_month.year, _month.month + 1, 0);
        final RangeSummary monthSummary = state.store.rangeSummary(first, last);

        Duration maxTotal = const Duration(hours: 6);
        for (final DateTime day in daysInRange(first, last)) {
          final Duration total = state.store.summaryFor(day).total;
          if (total > maxTotal) maxTotal = total;
        }

        final DaySummary selectedSummary = state.store.summaryFor(_selected);
        final DaySummary previousSummary = state.store.summaryFor(
          addDays(_selected, -1),
        );
        final bool selectedIsToday = isSameDay(_selected, today);
        final bool canGoNext = _month.isBefore(
          DateTime(today.year, today.month, 1),
        );

        final Widget calendarCard = ExpressiveCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => _changeMonth(-1, today),
                    tooltip: 'Предыдущий месяц',
                    icon: const Icon(FluentIcons.chevron_left_24_regular),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppMotion.short,
                      child: Text(
                        monthTitle(_month),
                        key: ValueKey<String>(monthTitle(_month)),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canGoNext ? () => _changeMonth(1, today) : null,
                    tooltip: 'Следующий месяц',
                    icon: const Icon(FluentIcons.chevron_right_24_regular),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onHorizontalDragEnd: (DragEndDetails details) {
                  final double velocity = details.primaryVelocity ?? 0;
                  if (velocity < -120) {
                    if (canGoNext) _changeMonth(1, today);
                  } else if (velocity > 120) {
                    _changeMonth(-1, today);
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: AppMotion.emphasizedDecel,
                  switchOutCurve: AppMotion.emphasizedAccel,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final Animation<Offset> offset = Tween<Offset>(
                          begin: Offset(_direction * 0.06, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                  child: KeyedSubtree(
                    key: ValueKey<String>('${_month.year}-${_month.month}'),
                    child: MonthCalendar(
                      month: _month,
                      today: today,
                      selected: _selected,
                      totalFor: (DateTime day) =>
                          state.store.summaryFor(day).total,
                      maxTotal: maxTotal,
                      onSelected: _select,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    'Меньше',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: <Color>[
                            scheme.surfaceContainerLow,
                            scheme.primary.withValues(alpha: 0.35),
                            scheme.primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Больше',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final Widget monthStats = Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                compact: true,
                icon: FluentIcons.timer_24_regular,
                label: 'За месяц',
                value: formatDurationCompact(monthSummary.total),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                compact: true,
                icon: FluentIcons.data_usage_24_regular,
                label: 'В среднем',
                value: formatDurationCompact(monthSummary.averagePerActiveDay),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                compact: true,
                icon: FluentIcons.fire_24_regular,
                label: 'Лучший день',
                value: monthSummary.topDay == null
                    ? '—'
                    : formatDurationCompact(monthSummary.topDay!.total),
              ),
            ),
          ],
        );

        final Widget dayPanel = _SelectedDayPanel(
          summary: selectedSummary,
          previous: previousSummary,
          today: today,
          selected: _selected,
          selectedIsToday: selectedIsToday,
          onOpen: () => openDayDetail(context, _selected),
          onOpenApp: (AppUsage usage) => openAppDetail(
            context,
            state,
            appId: usage.appId,
            appName: usage.appName,
            start: _selected,
            end: _selected,
            rangeLabel: selectedIsToday
                ? 'Сегодня'
                : relativeDate(_selected, today),
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
                'Календарь',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: <Widget>[
                IconButton(
                  onPressed: () => _goToday(today),
                  tooltip: 'Перейти к сегодня',
                  icon: const Icon(FluentIcons.calendar_today_24_regular),
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
                            final bool wide = constraints.maxWidth >= 980;
                            if (!wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  calendarCard,
                                  const SizedBox(height: 12),
                                  monthStats,
                                  const SizedBox(height: 14),
                                  dayPanel,
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          calendarCard,
                                          const SizedBox(height: 12),
                                          monthStats,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 2, child: dayPanel),
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
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.summary,
    required this.previous,
    required this.today,
    required this.selected,
    required this.selectedIsToday,
    required this.onOpen,
    required this.onOpenApp,
  });

  final DaySummary summary;
  final DaySummary previous;
  final DateTime today;
  final DateTime selected;
  final bool selectedIsToday;
  final VoidCallback onOpen;
  final ValueChanged<AppUsage> onOpenApp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ExpressiveCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selectedIsToday
                          ? 'Сегодня'
                          : relativeDate(selected, today),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateWithWeekday(selected),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      formatDurationCompact(summary.total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'за день',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TrendChip(current: summary.total, previous: previous.total),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          if (summary.apps.isEmpty)
            const EmptyState(
              compact: true,
              icon: FluentIcons.calendar_cancel_24_regular,
              title: 'Нет данных',
              message:
                  'За этот день время использования приложений не записано.',
            )
          else ...<Widget>[
            for (final AppUsage app in summary.apps.take(4))
              AppUsageTile(
                usage: app,
                total: summary.total,
                compact: true,
                showChevron: true,
                onTap: () => onOpenApp(app),
              ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(FluentIcons.chart_multiple_24_regular, size: 18),
              label: const Text('Подробнее о дне'),
            ),
          ],
        ],
      ),
    );
  }
}
