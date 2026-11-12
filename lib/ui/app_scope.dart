import 'package:flutter/widgets.dart';

import '../state/timeflow_state.dart';

/// Provides the [TimeFlowState] to the widget tree without subscribing to its
/// notifications. Screens opt into updates with [ListenableBuilder], which lets
/// a live-tracking tick repaint only visible content.
class TimeFlowScope extends InheritedWidget {
  const TimeFlowScope({super.key, required this.state, required super.child});

  final TimeFlowState state;

  static TimeFlowState of(BuildContext context) {
    final TimeFlowScope? scope = context
        .getInheritedWidgetOfExactType<TimeFlowScope>();
    assert(scope != null, 'TimeFlowScope is missing above this context');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(TimeFlowScope oldWidget) => oldWidget.state != state;
}
