import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/timeflow_state.dart';
import '../theme/motion.dart';
import 'screens/app_detail_screen.dart';
import 'screens/day_detail_screen.dart';

/// A push route with a short travel + scale + fade, matching the theme's
/// expressive page transition.
Route<T> expressiveRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
        ) {
          return page;
        },
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasizedDecel,
            reverseCurve: AppMotion.emphasizedAccel,
          );
          final Animation<double> fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.045),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.975, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
  );
}

void openDayDetail(BuildContext context, DateTime day) {
  Navigator.of(context)
      .push<void>(expressiveRoute<void>(DayDetailScreen(day: dateOnly(day))));
}

void openAppDetail(
  BuildContext context,
  TimeFlowState state, {
  required String appId,
  required String appName,
  required DateTime start,
  required DateTime end,
  required String rangeLabel,
}) {
  Navigator.of(context).push<void>(
    expressiveRoute<void>(
      AppDetailScreen(
        appId: appId,
        appName: appName,
        start: dateOnly(start),
        end: dateOnly(end),
        rangeLabel: rangeLabel,
      ),
    ),
  );
}
