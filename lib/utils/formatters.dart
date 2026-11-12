import '../data/models.dart';

const List<String> _monthsGenitive = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

const List<String> _monthsNominative = <String>[
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const List<String> _weekdaysShort = <String>[
  'пн',
  'вт',
  'ср',
  'чт',
  'пт',
  'сб',
  'вс',
];

const List<String> _weekdaysFull = <String>[
  'понедельник',
  'вторник',
  'среда',
  'четверг',
  'пятница',
  'суббота',
  'воскресенье',
];

/// "3 ч 24 мин", "24 мин", "0 мин".
String formatDuration(Duration value) {
  final int totalMinutes = value.inMinutes;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  if (totalMinutes == 0) {
    return value.inSeconds > 0 ? '${value.inSeconds} сек' : '0 мин';
  }
  if (hours <= 0) return '$minutes мин';
  if (minutes == 0) return '$hours ч';
  return '$hours ч $minutes мин';
}

/// "3ч 24м" — compact for rings and chips.
String formatDurationCompact(Duration value) {
  final int totalMinutes = value.inMinutes;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  if (totalMinutes == 0) {
    return value.inSeconds > 0 ? '${value.inSeconds}с' : '0м';
  }
  if (hours <= 0) return '${minutes.toString()}м';
  if (minutes == 0) return '${hours.toString()}ч';
  return '${hours.toString()}ч ${minutes.toString()}м';
}

/// "3:24" or "0:24" — for dense statistics.
String formatHoursColonMinutes(Duration value) {
  final int totalMinutes = value.inMinutes;
  return '${totalMinutes ~/ 60}:${(totalMinutes % 60).toString().padLeft(2, '0')}';
}

String formatClock(DateTime value) {
  final String h = value.hour.toString().padLeft(2, '0');
  final String m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatTimeRange(AppSession session) =>
    '${formatClock(session.start)} – ${formatClock(session.end)}';

String dateLong(DateTime date) =>
    '${date.day} ${_monthsGenitive[date.month - 1]}';

String dateWithWeekday(DateTime date) {
  final String weekday = _weekdaysFull[date.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${dateLong(date)}';
}

String dateNumeric(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String relativeDate(DateTime date, DateTime today) {
  final int diff = dayDifference(today, date);
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  if (diff == -1) return 'Завтра';
  return dateLong(date);
}

String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

String weekdayFull(DateTime date) => _weekdaysFull[date.weekday - 1];

String monthTitle(DateTime date) =>
    '${_monthsNominative[date.month - 1]} ${date.year}';

String monthTitleShort(DateTime date) =>
    '${_monthsNominative[date.month - 1]} ${date.year % 100}';

String formatPercent(double share) => '${(share * 100).round()}%';

String pluralDaysWord(int count) {
  final int mod10 = count.abs() % 10;
  final int mod100 = count.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'дня';
  }
  return 'дней';
}

String pluralSessionsWord(int count) {
  final int mod10 = count.abs() % 10;
  final int mod100 = count.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return 'сессия';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'сессии';
  }
  return 'сессий';
}

String pluralAppsWord(int count) {
  final int mod10 = count.abs() % 10;
  final int mod100 = count.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return 'приложение';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'приложения';
  }
  return 'приложений';
}

String pluralDays(int count) => '$count ${pluralDaysWord(count)}';

String pluralSessions(int count) => '$count ${pluralSessionsWord(count)}';

String pluralApps(int count) => '$count ${pluralAppsWord(count)}';

/// A short label for a trend between two durations, e.g. "−12%".
String trendLabel(Duration current, Duration previous) {
  if (previous.inMinutes < 1) return '';
  final double delta =
      (current.inMinutes - previous.inMinutes) / previous.inMinutes;
  final int percent = (delta * 100).round();
  if (percent == 0) return '0%';
  return '${percent > 0 ? '+' : ''}$percent%';
}
