import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/timeflow_state.dart';
import '../../utils/formatters.dart';
import '../app_scope.dart';
import '../navigation.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_usage_tile.dart';
import '../widgets/daily_bars.dart';
import '../widgets/expressive_card.dart';
import '../widgets/section_header.dart';
import '../widgets/trend_chip.dart';

enum AppRange { today, week, month }

extension AppRangeInfo on AppRange {
  String get label {
    switch (this) {
      case AppRange.today:
        return 'Сегодня';
      case AppRange.week:
        return '7 дней';
      case AppRange.month:
        return '30 дней';
    }
  }

  int get days {
    switch (this) {
      case AppRange.today:
        return 1;
      case AppRange.week:
        return 7;
      case AppRange.month:
        return 30;
    }
  }
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen>
    with AutomaticKeepAliveClientMixin {
  AppRange _range = AppRange.today;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
        final DateTime start = addDays(today, -(_range.days - 1));
        final RangeSummary summary = state.store.rangeSummary(start, today);

        final String query = _query.trim().toLowerCase();
        final List<AppUsage> allApps = summary.apps;
        final List<AppUsage> apps = query.isEmpty
            ? allApps
            : allApps
                  .where(
                    (AppUsage app) => app.appName.toLowerCase().contains(query),
                  )
                  .toList();
        final Map<String, int> rankById = <String, int>{
          for (int i = 0; i < allApps.length; i++) allApps[i].appId: i + 1,
        };

        final List<DateTime> dates = daysInRange(start, today);

        final Widget searchField = TextField(
          controller: _search,
          onChanged: (String value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск приложений',
            prefixIcon: const Icon(FluentIcons.search_24_regular),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    tooltip: 'Очистить',
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                  ),
          ),
        );

        final Widget rangeSelector = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<AppRange>(
            segments: const <ButtonSegment<AppRange>>[
              ButtonSegment<AppRange>(
                value: AppRange.today,
                label: Text('Сегодня'),
                icon: Icon(FluentIcons.calendar_today_24_regular, size: 17),
              ),
              ButtonSegment<AppRange>(
                value: AppRange.week,
                label: Text('7 дней'),
                icon: Icon(FluentIcons.calendar_ltr_24_regular, size: 17),
              ),
              ButtonSegment<AppRange>(
                value: AppRange.month,
                label: Text('30 дней'),
                icon: Icon(FluentIcons.calendar_month_24_regular, size: 17),
              ),
            ],
            selected: <AppRange>{_range},
            onSelectionChanged: (Set<AppRange> values) {
              if (values.isEmpty) return;
              setState(() => _range = values.first);
            },
            showSelectedIcon: false,
          ),
        );

        final Widget summaryCard = ExpressiveCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Всего за ${_range.label.toLowerCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedCounter(
                  value: summary.total,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StatusPill(
                    label: pluralDays(summary.activeDays),
                    icon: FluentIcons.calendar_checkmark_24_regular,
                  ),
                  StatusPill(
                    label: pluralApps(summary.apps.length),
                    icon: FluentIcons.apps_24_regular,
                    color: scheme.tertiary,
                  ),
                ],
              ),
              if (_range != AppRange.today &&
                  summary.total.inSeconds > 0) ...<Widget>[
                const SizedBox(height: 16),
                DailyBars(
                  values: summary.dailyTotals,
                  dates: dates,
                  height: 74,
                  showLabels: false,
                  barColor: scheme.primary,
                ),
              ],
            ],
          ),
        );

        final Widget list = ExpressiveCard(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SectionHeader(
                  title: query.isEmpty ? 'Все приложения' : 'Результаты',
                  subtitle: query.isEmpty
                      ? '${pluralApps(summary.apps.length)} за ${_range.label.toLowerCase()}'
                      : 'Найдено: ${apps.length}',
                ),
              ),
              const SizedBox(height: 8),
              if (apps.isEmpty)
                EmptyState(
                  compact: true,
                  icon: query.isEmpty
                      ? FluentIcons.weather_moon_24_regular
                      : FluentIcons.search_24_regular,
                  title: query.isEmpty
                      ? 'Пока нет данных'
                      : 'Ничего не найдено',
                  message: query.isEmpty
                      ? 'Используй приложения — и здесь появится подробная статистика.'
                      : 'Попробуй изменить запрос или выбрать другой период.',
                )
              else
                for (int i = 0; i < apps.length; i++)
                  AppUsageTile(
                    usage: apps[i],
                    total: summary.total,
                    rank: rankById[apps[i].appId] ?? i + 1,
                    showChevron: true,
                    onTap: () => openAppDetail(
                      context,
                      state,
                      appId: apps[i].appId,
                      appName: apps[i].appName,
                      start: start,
                      end: today,
                      rangeLabel: _range.label,
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
                'Приложения',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        searchField,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: rangeSelector,
                        ),
                        const SizedBox(height: 14),
                        summaryCard,
                        const SizedBox(height: 14),
                        list,
                      ],
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
