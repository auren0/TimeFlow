import '../theme/app_theme.dart';

enum AppThemeMode { system, light, dark, oled }

class AppFontOption {
  const AppFontOption({required this.id, required this.name, this.fontFamily});

  final String id;
  final String name;
  final String? fontFamily;
}

const List<AppFontOption> kAppFonts = <AppFontOption>[
  AppFontOption(
    id: 'google_sans',
    name: 'Google Sans',
    fontFamily: 'GoogleSans',
  ),
  AppFontOption(
    id: 'jetbrains_mono',
    name: 'JetBrains Mono',
    fontFamily: 'JetBrainsMono',
  ),
  AppFontOption(
    id: 'science_gothic',
    name: 'Science Gothic',
    fontFamily: 'ScienceGothic',
  ),
  AppFontOption(id: 'system', name: 'Системный', fontFamily: null),
];

AppFontOption fontOptionForId(String id) {
  for (final AppFontOption option in kAppFonts) {
    if (option.id == id) return option;
  }
  return kAppFonts.first;
}

/// Persisted user preferences.
class AppSettings {
  AppThemeMode themeMode = AppThemeMode.system;
  int paletteIndex = 0;
  String fontId = 'google_sans';
  bool demoMode = false;
  int? lastSyncMs;

  /// Daily summary notification.
  bool notificationsEnabled = false;
  int notificationHour = 21;
  int notificationMinute = 0;

  /// Sessions that ended before this moment were explicitly cleared by the
  /// user and must never be imported from OS history again.
  int? historyCutoffMs;

  /// Executable paths learned from live tracking, used to extract real icons
  /// on Windows after a restart.
  Map<String, String> appPaths = <String, String>{};

  String? get fontFamily => fontOptionForId(fontId).fontFamily;

  void fromJson(Map<String, dynamic> json) {
    final int theme = (json['theme'] as num?)?.toInt() ?? 0;
    themeMode =
        AppThemeMode.values[theme.clamp(0, AppThemeMode.values.length - 1)];
    final int palette = (json['palette'] as num?)?.toInt() ?? 0;
    paletteIndex = palette.clamp(0, kPalettes.length - 1);
    fontId = (json['fontId'] as String?) ?? 'google_sans';
    demoMode = json['demo'] == true;
    lastSyncMs = (json['lastSync'] as num?)?.toInt();
    notificationsEnabled = json['notifications'] == true;
    notificationHour = ((json['notificationHour'] as num?)?.toInt() ?? 21)
        .clamp(0, 23);
    notificationMinute = ((json['notificationMinute'] as num?)?.toInt() ?? 0)
        .clamp(0, 59);
    historyCutoffMs = (json['historyCutoff'] as num?)?.toInt();
    final Object? paths = json['appPaths'];
    if (paths is Map) {
      appPaths = <String, String>{
        for (final MapEntry<Object?, Object?> entry in paths.entries)
          if (entry.key is String && entry.value is String)
            entry.key! as String: entry.value! as String,
      };
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'theme': themeMode.index,
    'palette': paletteIndex,
    'fontId': fontId,
    'demo': demoMode,
    'lastSync': lastSyncMs,
    'notifications': notificationsEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'historyCutoff': historyCutoffMs,
    if (appPaths.isNotEmpty) 'appPaths': appPaths,
  };
}
