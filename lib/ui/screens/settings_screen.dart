import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/backup.dart';
import '../../state/app_settings.dart';
import '../../state/timeflow_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../utils/formatters.dart';
import '../app_scope.dart';
import '../widgets/expressive_card.dart';
import '../widgets/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _confirmClear(TimeFlowState state) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(FluentIcons.delete_24_regular),
          title: const Text('Очистить историю?'),
          content: const Text(
            'Все сохранённые сессии будут удалены с этого устройства. '
            'Настройки и выбранная тема останутся на месте. Это действие нельзя отменить.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Очистить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await state.clearData();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('История очищена')));
  }

  Future<void> _exportBackup(TimeFlowState state) async {
    try {
      final String json = state.createBackup();
      final Uint8List bytes = Uint8List.fromList(utf8.encode(json));
      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: 'Экспорт истории TimeFlow',
        fileName:
            'TimeFlow-backup-${dateNumeric(DateTime.now()).replaceAll('.', '-')}.json',
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (uri == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Резервная копия сохранена')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать: $error')),
      );
    }
  }

  Future<void> _importBackup(TimeFlowState state) async {
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: 'Импорт истории TimeFlow',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (file == null || !mounted) return;

    final String payload;
    try {
      payload = utf8.decode(await file.readAsBytes());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прочитать файл: $error')),
      );
      return;
    }

    if (!mounted) return;
    final bool? replace = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(FluentIcons.arrow_import_24_regular),
          title: const Text('Импорт истории'),
          content: const Text(
            'Объединить данные из файла с текущей историей или заменить её?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Объединить'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Заменить'),
            ),
          ],
        );
      },
    );
    if (replace == null || !mounted) return;

    try {
      final BackupImportResult result = await state.importBackup(
        payload,
        replace: replace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано: ${pluralDays(result.dayCount)}, '
            '${pluralSessions(result.sessionCount)}',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось импортировать: $error')),
      );
    }
  }

  Future<void> _pickNotificationTime(TimeFlowState state) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: state.settings.notificationHour,
        minute: state.settings.notificationMinute,
      ),
    );
    if (picked == null) return;
    await state.setNotificationTime(picked);
  }

  Future<void> _toggleNotifications(TimeFlowState state, bool enabled) async {
    final bool ok = await state.setNotificationsEnabled(enabled);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Разреши уведомления в настройках системы.'),
        ),
      );
    }
  }

  Future<void> _sendTestNotification(TimeFlowState state) async {
    await state.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Тестовое уведомление отправлено')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TimeFlowState state = TimeFlowScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = Theme.of(context);
        final int dayCount = state.store.dayCount;
        final DateTime? earliest = state.store.earliestDay;
        final DateTime? latest = state.store.latestDay;

        return CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              titleSpacing: 20,
              title: Text(
                'Настройки',
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
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (state.tracker.canReadHistory &&
                            !state.permissionGranted &&
                            !state.demoActive) ...<Widget>[
                          _PermissionWarning(state: state),
                          const SizedBox(height: 14),
                        ],
                        _AppearanceCard(state: state),
                        const SizedBox(height: 14),
                        _TrackingCard(state: state),
                        const SizedBox(height: 14),
                        _NotificationsCard(
                          state: state,
                          onToggle: (bool value) =>
                              _toggleNotifications(state, value),
                          onPickTime: () => _pickNotificationTime(state),
                          onTest: () => _sendTestNotification(state),
                        ),
                        const SizedBox(height: 14),
                        _DataCard(
                          state: state,
                          dayCount: dayCount,
                          earliest: earliest,
                          latest: latest,
                          onClear: () => _confirmClear(state),
                          onExport: () => _exportBackup(state),
                          onImport: () => _importBackup(state),
                        ),
                        const SizedBox(height: 14),
                        const _AboutCard(),
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

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.state});

  final TimeFlowState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ExpressiveCard(
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                FluentIcons.warning_24_regular,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Статистика пока не записывается',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Разреши TimeFlow доступ к статистике использования, чтобы видеть реальные данные.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onErrorContainer.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: state.requestPermission,
              icon: const Icon(FluentIcons.lock_open_24_regular, size: 18),
              label: const Text('Разрешить доступ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.state});

  final TimeFlowState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ExpressiveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: 'Оформление',
            subtitle: 'Тема и акцентный цвет интерфейса',
          ),
          const SizedBox(height: 18),
          Text(
            'Тема',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<AppThemeMode>(
              segments: const <ButtonSegment<AppThemeMode>>[
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.system,
                  label: Text('Авто'),
                  icon: Icon(FluentIcons.phone_laptop_24_regular, size: 17),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.light,
                  label: Text('Светлая'),
                  icon: Icon(FluentIcons.weather_sunny_24_regular, size: 17),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.dark,
                  label: Text('Тёмная'),
                  icon: Icon(FluentIcons.weather_moon_24_regular, size: 17),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.oled,
                  label: Text('OLED'),
                  icon: Icon(FluentIcons.dark_theme_24_regular, size: 17),
                ),
              ],
              selected: <AppThemeMode>{state.settings.themeMode},
              onSelectionChanged: (Set<AppThemeMode> values) {
                if (values.isEmpty) return;
                state.setThemeMode(values.first);
              },
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Шрифт',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final AppFontOption font in kAppFonts)
                ChoiceChip(
                  label: Text(
                    font.name,
                    style: TextStyle(
                      fontFamily: font.fontFamily,
                      fontWeight: state.settings.fontId == font.id
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  selected: state.settings.fontId == font.id,
                  onSelected: (bool selected) {
                    if (selected) state.setFontId(font.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Акцент',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (int i = 0; i < kPalettes.length; i++)
                _PaletteSwatch(
                  palette: kPalettes[i],
                  selected: state.settings.paletteIndex == i,
                  onTap: () => state.setPalette(i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                FluentIcons.info_24_regular,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Цвета подбираются динамически по схеме Material 3.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: palette.name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.seed,
            ),
            child: selected
                ? const Icon(
                    FluentIcons.checkmark_24_regular,
                    color: Colors.white,
                    size: 19,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.state});

  final TimeFlowState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final bool android = state.tracker.canReadHistory;
    final bool windows = state.tracker.canTrackLive;
    final bool supported = state.tracker.isSupported;

    return ExpressiveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: 'Отслеживание',
            subtitle: 'Платформа: ${state.tracker.platformName}',
            trailing: supported
                ? StatusPill(
                    label: state.demoActive ? 'Демо' : 'Активно',
                    icon: FluentIcons.pulse_24_regular,
                    color: state.demoActive ? scheme.tertiary : scheme.primary,
                    pulse:
                        !state.demoActive &&
                        (android
                            ? state.permissionGranted
                            : windows && state.liveTracking),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        android
                            ? FluentIcons.shield_checkmark_24_regular
                            : (windows
                                  ? FluentIcons.desktop_24_regular
                                  : FluentIcons.beaker_24_regular),
                        color: scheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            android
                                ? 'Доступ к статистике'
                                : (windows
                                      ? 'Запись активного окна'
                                      : 'Системная статистика'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            android
                                ? (state.permissionGranted
                                      ? 'Разрешено. История использования синхронизируется автоматически.'
                                      : 'Нужен доступ, чтобы читать историю использования приложений из Android.')
                                : (windows
                                      ? 'TimeFlow записывает приложение в фокусе, пока сам запущен. Свернуть окно можно.'
                                      : 'На этой платформе нет публичного API статистики экранного времени.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (android && !state.permissionGranted) ...<Widget>[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.requestPermission,
                    icon: const Icon(
                      FluentIcons.lock_open_24_regular,
                      size: 18,
                    ),
                    label: const Text('Открыть настройки доступа'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: state.recheckPermission,
                    child: const Text('Я уже разрешил — проверить'),
                  ),
                ],
              ],
            ),
          ),
          if (android && state.permissionGranted) ...<Widget>[
            const SizedBox(height: 10),
            InkWell(
              onTap: state.syncing
                  ? null
                  : () => state.syncHistory(force: true),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        FluentIcons.arrow_sync_24_regular,
                        color: scheme.tertiary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Синхронизировать сейчас',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.syncing
                                ? 'Синхронизация… ${state.syncDone}/${state.syncTotal}'
                                : 'Последняя: ${state.lastSyncLabel ?? "ещё не было"}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.syncing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          value: state.syncTotal > 0
                              ? state.syncProgress
                              : null,
                        ),
                      )
                    else
                      Icon(
                        FluentIcons.arrow_clockwise_24_regular,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                FluentIcons.lock_closed_24_regular,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  android
                      ? 'TimeFlow читает только названия пакетов и время. Содержимое экрана, сообщения и вводимый текст недоступны.'
                      : 'Содержимое экрана не записывается. Фиксируются только имя приложения и время в фокусе.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.state,
    required this.onToggle,
    required this.onPickTime,
    required this.onTest,
  });

  final TimeFlowState state;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool enabled = state.settings.notificationsEnabled;
    final String time = TimeOfDay(
      hour: state.settings.notificationHour,
      minute: state.settings.notificationMinute,
    ).format(context);

    return ExpressiveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: 'Уведомления',
            subtitle: 'Ежедневная сводка экранного времени',
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: enabled,
            onChanged: onToggle,
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              FluentIcons.alert_24_regular,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(
              'Ежедневная сводка',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Раз в день присылать итоги вчерашнего дня.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          ListTile(
            enabled: enabled,
            onTap: enabled ? onPickTime : null,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              FluentIcons.clock_24_regular,
              color: scheme.onSurfaceVariant,
            ),
            title: const Text('Время сводки'),
            trailing: Text(
              time,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTest,
                icon: const Icon(FluentIcons.send_24_regular, size: 18),
                label: const Text('Проверить уведомление'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.state,
    required this.dayCount,
    required this.earliest,
    required this.latest,
    required this.onClear,
    required this.onExport,
    required this.onImport,
  });

  final TimeFlowState state;
  final int dayCount;
  final DateTime? earliest;
  final DateTime? latest;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ExpressiveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: 'Данные',
            subtitle: 'История остаётся только на этом устройстве',
          ),
          const SizedBox(height: 12),
          _SettingsRow(
            icon: FluentIcons.database_24_regular,
            title: dayCount == 0
                ? 'Нет сохранённых данных'
                : '${pluralDays(dayCount)} с данными',
            subtitle: earliest == null || latest == null
                ? 'Данные появятся после первой синхронизации'
                : 'С ${dateLong(earliest!)} по ${dateLong(latest!)}',
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _SettingsRow(
            icon: FluentIcons.document_save_24_regular,
            title: 'Экспорт истории',
            subtitle: 'Сохранить резервную копию в JSON',
            onTap: onExport,
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _SettingsRow(
            icon: FluentIcons.arrow_import_24_regular,
            title: 'Импорт истории',
            subtitle: 'Загрузить резервную копию из JSON',
            onTap: onImport,
          ),
          if (state.canRestoreHistory) ...<Widget>[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            _SettingsRow(
              icon: FluentIcons.history_24_regular,
              title: 'Восстановить историю',
              subtitle:
                  'Заново импортировать данные, которые Android ещё хранит',
              onTap: state.syncing ? null : state.restoreHistory,
            ),
          ],
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _SettingsRow(
            icon: FluentIcons.delete_24_regular,
            title: 'Очистить всё',
            subtitle: state.demoActive
                ? 'Демо-данные будут сгенерированы заново'
                : 'Удалить историю использования с устройства',
            danger: true,
            onTap: onClear,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.sm),
              bottomRight: Radius.circular(AppRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
    this.borderRadius,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color tint = danger ? scheme.error : scheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: tint, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? scheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                FluentIcons.chevron_right_24_regular,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ExpressiveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'TimeFlow',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Версия 1.0.0 · Material 3',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'TimeFlow показывает, сколько времени ты проводишь в приложениях, '
            'и помогает замечать закономерности. Никакой аналитики, аккаунтов и облака: '
            'все данные хранятся локально.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
