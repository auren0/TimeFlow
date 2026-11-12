import 'package:flutter_test/flutter_test.dart';
import 'package:timeflow/data/backup.dart';
import 'package:timeflow/data/models.dart';

void main() {
  test('encodes and decodes a backup', () {
    final DateTime day = DateTime(2026, 11, 10);
    final AppSession session = AppSession(
      appId: 'demo.app',
      appName: 'App',
      startMs: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
      endMs: DateTime(2026, 11, 10, 10).millisecondsSinceEpoch,
    );
    final String payload = TimeFlowBackup.encode(
      days: <String, List<AppSession>>{
        dayKey(day): <AppSession>[session],
      },
      themeIndex: 2,
      paletteIndex: 4,
    );

    final BackupPayload parsed = TimeFlowBackup.parse(payload);
    expect(parsed.days.keys, contains(dayKey(day)));
    expect(parsed.sessionCount, 1);
    expect(parsed.themeIndex, 2);
    expect(parsed.paletteIndex, 4);
    expect(parsed.days[dayKey(day)]!.single.appId, 'demo.app');
  });

  test('rejects unrelated JSON', () {
    expect(
      () => TimeFlowBackup.parse('{"hello":"world"}'),
      throwsFormatException,
    );
    expect(() => TimeFlowBackup.parse('not json'), throwsFormatException);
  });
}
