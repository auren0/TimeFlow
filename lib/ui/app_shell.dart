import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../state/timeflow_state.dart';
import '../theme/motion.dart';
import 'app_scope.dart';
import 'screens/apps_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/settings_screen.dart';

/// Responsive chrome: bottom navigation on phones, a rail on tablets/desktop.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final PageController _pageController = PageController(
    initialPage: 0,
    keepPage: false,
  );

  late final List<Widget> _pages = <Widget>[
    OverviewScreen(onNavigateTab: _select),
    const CalendarScreen(),
    const AppsScreen(),
    const SettingsScreen(),
  ];

  static const List<String> _labels = <String>[
    'Обзор',
    'Календарь',
    'Приложения',
    'Настройки',
  ];

  static const List<IconData> _icons = <IconData>[
    FluentIcons.home_24_regular,
    FluentIcons.calendar_ltr_24_regular,
    FluentIcons.apps_24_regular,
    FluentIcons.settings_24_regular,
  ];

  static const List<IconData> _selectedIcons = <IconData>[
    FluentIcons.home_24_filled,
    FluentIcons.calendar_ltr_24_filled,
    FluentIcons.apps_24_filled,
    FluentIcons.settings_24_filled,
  ];

  void _select(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (index == _index) return;
    setState(() => _index = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TimeFlowState state = TimeFlowScope.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 820;
        final bool extendedRail = constraints.maxWidth >= 1240;

        final Widget pages = Stack(
          children: <Widget>[
            PageView(
              controller: _pageController,
              physics: wide
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              onPageChanged: (int index) {
                if (index != _index) setState(() => _index = index);
              },
              children: _pages,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _SyncIndicator(state: state),
              ),
            ),
          ],
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    extended: extendedRail,
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    minWidth: 82,
                    groupAlignment: -0.85,
                    labelType: extendedRail
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: extendedRail
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            child: Text(
                              'TimeFlow',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          )
                        : null,
                    destinations: <NavigationRailDestination>[
                      for (int i = 0; i < _pages.length; i++)
                        NavigationRailDestination(
                          icon: Icon(_icons[i]),
                          selectedIcon: Icon(_selectedIcons[i]),
                          label: Text(_labels[i]),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.45),
                ),
                Expanded(child: pages),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: <NavigationDestination>[
              for (int i = 0; i < _pages.length; i++)
                NavigationDestination(
                  icon: Icon(_icons[i]),
                  selectedIcon: Icon(_selectedIcons[i]),
                  label: _labels[i],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.state});

  final TimeFlowState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        return AnimatedSwitcher(
          duration: AppMotion.short,
          child: state.syncing
              ? LinearProgressIndicator(
                  key: const ValueKey<String>('sync'),
                  value: state.syncTotal > 0 ? state.syncProgress : null,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox(key: ValueKey<String>('idle'), height: 2.5),
        );
      },
    );
  }
}
