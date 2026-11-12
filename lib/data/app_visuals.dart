import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

/// Visual identity for an application: a brand-ish color, an optional icon and
/// a stable fallback initial. Everything is deterministic so charts, avatars
/// and legends always agree.
@immutable
class AppVisual {
  const AppVisual({required this.color, this.icon});

  final Color color;
  final IconData? icon;
}

abstract final class AppVisuals {
  static const Map<String, AppVisual> _known = <String, AppVisual>{
    'instagram': AppVisual(
      color: Color(0xFFE1306C),
      icon: FluentIcons.camera_24_regular,
    ),
    'youtube': AppVisual(
      color: Color(0xFFFF0033),
      icon: FluentIcons.video_clip_24_regular,
    ),
    'telegram': AppVisual(
      color: Color(0xFF2AABEE),
      icon: FluentIcons.send_24_regular,
    ),
    'whatsapp': AppVisual(
      color: Color(0xFF25D366),
      icon: FluentIcons.chat_24_regular,
    ),
    'tiktok': AppVisual(
      color: Color(0xFFFE2C55),
      icon: FluentIcons.music_note_2_24_regular,
    ),
    'chrome': AppVisual(
      color: Color(0xFF4285F4),
      icon: FluentIcons.globe_24_regular,
    ),
    'edge': AppVisual(
      color: Color(0xFF0078D7),
      icon: FluentIcons.compass_northwest_24_regular,
    ),
    'firefox': AppVisual(
      color: Color(0xFFFF7139),
      icon: FluentIcons.fire_24_regular,
    ),
    'browser': AppVisual(
      color: Color(0xFF4285F4),
      icon: FluentIcons.globe_24_regular,
    ),
    'spotify': AppVisual(
      color: Color(0xFF1DB954),
      icon: FluentIcons.headphones_24_regular,
    ),
    'music': AppVisual(
      color: Color(0xFF1DB954),
      icon: FluentIcons.headphones_24_regular,
    ),
    'netflix': AppVisual(
      color: Color(0xFFE50914),
      icon: FluentIcons.movies_and_tv_24_regular,
    ),
    'notion': AppVisual(
      color: Color(0xFF9AA0A6),
      icon: FluentIcons.document_text_24_regular,
    ),
    'figma': AppVisual(
      color: Color(0xFFF24E1E),
      icon: FluentIcons.design_ideas_24_regular,
    ),
    'gmail': AppVisual(
      color: Color(0xFFEA4335),
      icon: FluentIcons.mail_24_regular,
    ),
    'mail': AppVisual(
      color: Color(0xFFEA4335),
      icon: FluentIcons.mail_24_regular,
    ),
    'discord': AppVisual(
      color: Color(0xFF5865F2),
      icon: FluentIcons.chat_multiple_24_regular,
    ),
    'steam': AppVisual(
      color: Color(0xFF66C0F4),
      icon: FluentIcons.games_24_regular,
    ),
    'game': AppVisual(
      color: Color(0xFF66C0F4),
      icon: FluentIcons.games_24_regular,
    ),
    'code': AppVisual(
      color: Color(0xFF007ACC),
      icon: FluentIcons.code_24_regular,
    ),
    'visual studio': AppVisual(
      color: Color(0xFF6C4FD3),
      icon: FluentIcons.window_console_20_regular,
    ),
    'word': AppVisual(
      color: Color(0xFF2B579A),
      icon: FluentIcons.document_bullet_list_24_regular,
    ),
    'excel': AppVisual(
      color: Color(0xFF217346),
      icon: FluentIcons.table_24_regular,
    ),
    'sheets': AppVisual(
      color: Color(0xFF0F9D58),
      icon: FluentIcons.table_24_regular,
    ),
    'slack': AppVisual(
      color: Color(0xFF611F69),
      icon: FluentIcons.tag_24_regular,
    ),
    'zoom': AppVisual(
      color: Color(0xFF2D8CFF),
      icon: FluentIcons.video_24_regular,
    ),
    'meet': AppVisual(
      color: Color(0xFF00897B),
      icon: FluentIcons.video_24_regular,
    ),
    'maps': AppVisual(
      color: Color(0xFF34A853),
      icon: FluentIcons.map_24_regular,
    ),
    'camera': AppVisual(
      color: Color(0xFFF4B400),
      icon: FluentIcons.camera_24_regular,
    ),
    'bank': AppVisual(
      color: Color(0xFF0F9D58),
      icon: FluentIcons.building_bank_24_regular,
    ),
    'duolingo': AppVisual(
      color: Color(0xFF58CC02),
      icon: FluentIcons.hat_graduation_24_regular,
    ),
    'timeflow': AppVisual(
      color: Color(0xFF6366F1),
      icon: FluentIcons.timer_24_regular,
    ),
    'settings': AppVisual(
      color: Color(0xFF7E8794),
      icon: FluentIcons.settings_24_regular,
    ),
    'explorer': AppVisual(
      color: Color(0xFFFFB900),
      icon: FluentIcons.folder_24_regular,
    ),
    'files': AppVisual(
      color: Color(0xFFFFB900),
      icon: FluentIcons.folder_24_regular,
    ),
    'photos': AppVisual(
      color: Color(0xFFF06292),
      icon: FluentIcons.image_24_regular,
    ),
    'messages': AppVisual(
      color: Color(0xFF4CAF50),
      icon: FluentIcons.chat_24_regular,
    ),
    'reddit': AppVisual(
      color: Color(0xFFFF4500),
      icon: FluentIcons.globe_24_regular,
    ),
    'calendar': AppVisual(
      color: Color(0xFF4285F4),
      icon: FluentIcons.calendar_month_24_regular,
    ),
    'instagram lite': AppVisual(
      color: Color(0xFFE1306C),
      icon: FluentIcons.camera_24_regular,
    ),
  };

  static final Map<String, AppVisual> _cache = <String, AppVisual>{};

  static AppVisual forApp(String appId, String appName) {
    final String key = appId.toLowerCase();
    final String cacheKey = '$key|${appName.toLowerCase()}';
    final AppVisual? cached = _cache[cacheKey];
    if (cached != null) return cached;

    AppVisual? visual;
    final String haystack = '$key ${appName.toLowerCase()}';
    for (final MapEntry<String, AppVisual> entry in _known.entries) {
      if (haystack.contains(entry.key)) {
        visual = entry.value;
        break;
      }
    }
    visual ??= AppVisual(color: colorFromString(appId), icon: null);
    _cache[cacheKey] = visual;
    return visual;
  }

  /// A deterministic, saturated color derived from an id.
  static Color colorFromString(String value) {
    int hash = 0;
    for (int i = 0; i < value.length; i++) {
      hash = (hash * 31 + value.codeUnitAt(i)) & 0x7fffffff;
    }
    final double hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.58, 0.54).toColor();
  }

  /// A stable two-letter-ish initial for fallback avatars.
  static String initial(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final List<String> words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2 && words.first.isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return trimmed.characters.first.toUpperCase();
  }
}

/// A small helper describing how "heavy" a duration is, used for calendar
/// heat levels and chart colors.
double usageIntensity(Duration value, Duration max) {
  if (max.inSeconds <= 0) return 0;
  final double raw = value.inSeconds / max.inSeconds;
  return math.pow(raw.clamp(0.0, 1.0), 1.25).toDouble();
}
