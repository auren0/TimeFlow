import 'package:flutter/material.dart';

import 'app.dart';
import 'data/notifications.dart';
import 'state/timeflow_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DailyNotifications.initialize();
  final TimeFlowState state = TimeFlowState();
  await state.init();
  runApp(TimeFlowApp(state: state));
}
