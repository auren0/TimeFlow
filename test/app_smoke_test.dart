import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeflow/app.dart';
import 'package:timeflow/data/demo_data.dart';
import 'package:timeflow/data/models.dart';
import 'package:timeflow/state/timeflow_state.dart';
import 'package:timeflow/ui/widgets/app_usage_tile.dart';

/// Builds a state with demo data without touching platform channels. This keeps
/// the smoke test focused on layout and rendering.
TimeFlowState _demoState() {
  final DateTime now = DateTime(2026, 11, 10, 16, 30);
  final DateTime today = dateOnly(now);
  final TimeFlowState state = TimeFlowState()
    ..demoActive = true
    ..now = now;
  state.store.replaceAll(
    DemoData.generate(today: today, daysBack: 420, now: now),
  );
  return state;
}

void main() {
  testWidgets('renders every tab on a narrow phone without layout errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TimeFlowState state = _demoState();
    await tester.pumpWidget(TimeFlowApp(state: state));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);

    for (final String tab in <String>['Календарь', 'Приложения', 'Настройки']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders every tab with large accessibility text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final TimeFlowState state = _demoState();
    await tester.pumpWidget(TimeFlowApp(state: state));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);

    for (final String tab in <String>['Календарь', 'Приложения', 'Настройки']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('opens day and app detail screens on a narrow phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final TimeFlowState state = _demoState();
    await tester.pumpWidget(TimeFlowApp(state: state));
    await tester.pump(const Duration(milliseconds: 800));

    final Finder hero = find.text('Экранное время').last;
    await tester.ensureVisible(hero);
    await tester.pump();
    await tester.tap(hero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.text('Лента дня'), findsOneWidget);

    final Finder appTile = find.byType(AppUsageTile).last;
    await tester.ensureVisible(appTile);
    await tester.pump();
    await tester.tap(appTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.text('ВСЕГО'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders the desktop rail layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TimeFlowState state = _demoState();
    await tester.pumpWidget(TimeFlowApp(state: state));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
