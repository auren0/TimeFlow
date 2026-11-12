import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_settings.dart';
import 'state/timeflow_state.dart';
import 'theme/app_theme.dart';
import 'ui/app_scope.dart';
import 'ui/app_shell.dart';

class TimeFlowApp extends StatelessWidget {
  const TimeFlowApp({super.key, required this.state});

  final TimeFlowState state;

  @override
  Widget build(BuildContext context) {
    return TimeFlowScope(
      state: state,
      child: ValueListenableBuilder<int>(
        valueListenable: state.themeRevision,
        builder: (BuildContext context, int revision, Widget? _) {
          final AppPalette palette = paletteForIndex(
            state.settings.paletteIndex,
          );
          final bool isOled = state.settings.themeMode == AppThemeMode.oled;
          final ThemeMode flutterThemeMode = switch (state.settings.themeMode) {
            AppThemeMode.system => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark || AppThemeMode.oled => ThemeMode.dark,
          };
          final String? fontFamily = state.settings.fontFamily;

          return MaterialApp(
            title: 'TimeFlow',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ru'),
            supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            scrollBehavior: const _AppScrollBehavior(),
            theme: buildAppTheme(
              brightness: Brightness.light,
              seed: palette.seed,
              fontFamily: fontFamily,
              isOled: false,
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              seed: palette.seed,
              fontFamily: fontFamily,
              isOled: isOled,
            ),
            themeMode: flutterThemeMode,
            themeAnimationDuration: const Duration(milliseconds: 350),
            themeAnimationCurve: Curves.easeOutCubic,
            builder: (BuildContext context, Widget? child) {
              final ThemeData theme = Theme.of(context);
              final bool dark = theme.brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: dark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: theme.colorScheme.surface,
                  systemNavigationBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

/// Allows drag-scrolling with a mouse or trackpad, which feels natural on
/// desktop while keeping touch behaviour unchanged.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
