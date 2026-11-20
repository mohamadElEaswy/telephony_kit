// Pure Dart date, time and duration formatting for call screens and call
// logs. No dependency on `intl`, so the labels are plain strings that an app
// can replace with its own translations.

/// The words used by [CallTimeFormatter]. The defaults are English; pass your
/// own to show another language.
class CallTimeLabels {
  const CallTimeLabels({
    this.today = 'Today',
    this.yesterday = 'Yesterday',
    this.justNow = 'Just now',
    this.minutesAgo = '{n} min ago',
    this.am = 'AM',
    this.pm = 'PM',
    this.hours = 'h',
    this.minutes = 'min',
    this.seconds = 's',
    this.utc = 'GMT',
    this.months = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    this.shortMonths = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    this.weekdays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    this.shortWeekdays = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ],
  });

  final String today;
  final String yesterday;
  final String justNow;

  /// Used for times less than an hour ago; `{n}` is replaced by the minutes.
  final String minutesAgo;
  final String am;
  final String pm;

  /// Unit suffixes used by [CallTimeFormatter.durationWords].
  final String hours;
  final String minutes;
  final String seconds;

  /// Prefix for time zone offsets, as in `GMT+02:00`.
  final String utc;

  /// January first.
  final List<String> months;
  final List<String> shortMonths;

  /// Monday first, matching [DateTime.weekday] - 1.
  final List<String> weekdays;
  final List<String> shortWeekdays;
}

/// Formats call times and durations the way phone apps show them.
///
/// Times are shown in the device's local time zone. Call log dates come from
/// Android as UTC milliseconds, so the same call shows the right local time
/// after the user travels or the clocks change. Pass [utcOffset] to show
/// times at a fixed offset instead (useful in tests, or to show a time in
/// another place).
///
/// ```dart
/// final f = TelephonyKit.instance.timeFormatter; // follows the 12/24h setting
/// f.relative(entry.date);      // "14:05", "Yesterday", "Monday", "12 Nov"
/// f.dateTime(entry.date);      // "Today, 14:05"
/// f.duration(entry.duration);  // "2:05"
/// f.durationWords(entry.duration); // "2 min 5 s"
/// ```
class CallTimeFormatter {
  const CallTimeFormatter({
    this.use24HourFormat = true,
    this.labels = const CallTimeLabels(),
    this.utcOffset,
  });

  /// Shows `14:05` instead of `2:05 PM`. Match the phone setting with
  /// `TelephonyKit.uses24HourFormat`, or Flutter's
  /// `MediaQuery.alwaysUse24HourFormatOf(context)`.
  final bool use24HourFormat;

  /// The words to use.
  final CallTimeLabels labels;

  /// Show times at this offset from UTC instead of the device time zone.
  final Duration? utcOffset;

  /// [time] converted to the wall clock this formatter shows. The result's
  /// fields (year, hour and so on) are the ones to display.
  DateTime wallClock(DateTime time) {
    final offset = utcOffset;
    if (offset == null) return time.toLocal();
    final utc = time.toUtc().add(offset);
    // A UTC DateTime whose fields read as the wall clock at [offset].
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
    );
  }

  /// The offset from UTC used for [time]: [utcOffset], or the device time
  /// zone's offset at that moment (which changes with daylight saving).
  Duration offsetAt(DateTime time) =>
      utcOffset ?? time.toLocal().timeZoneOffset;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Whole calendar days from [from] to [to], both wall clock times.
  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// The time of day: `14:05` or `2:05 PM`. With [seconds], `14:05:09`.
  String time(DateTime time, {bool seconds = false}) {
    final t = wallClock(time);
    final sec = seconds ? ':${_two(t.second)}' : '';
    if (use24HourFormat) return '${_two(t.hour)}:${_two(t.minute)}$sec';
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? labels.am : labels.pm;
    return '$hour:${_two(t.minute)}$sec $suffix';
  }

  /// The date: `12 Nov`, or `12 Nov 2025` when it is not in the current
  /// year (or always with [withYear]). With [long], `12 November 2025`.
  String date(
    DateTime time, {
    DateTime? now,
    bool withYear = false,
    bool long = false,
  }) {
    final t = wallClock(time);
    final n = wallClock(now ?? DateTime.now());
    final month = (long ? labels.months : labels.shortMonths)[t.month - 1];
    final year = withYear || t.year != n.year ? ' ${t.year}' : '';
    return '${t.day} $month$year';
  }

  /// A day heading for a list of calls: `Today`, `Yesterday`, a weekday
  /// within the last week, then the [date].
  String day(DateTime time, {DateTime? now}) {
    final t = wallClock(time);
    final n = wallClock(now ?? DateTime.now());
    final days = _daysBetween(t, n);
    if (days == 0) return labels.today;
    if (days == 1) return labels.yesterday;
    if (days > 1 && days < 7) return labels.weekdays[t.weekday - 1];
    return date(time, now: now);
  }

  /// A short label for a call log row: the [time] for calls today,
  /// `Yesterday`, a weekday within the last week, then the [date].
  /// With [ago], calls in the last hour read `Just now` or `5 min ago`.
  String relative(DateTime time, {DateTime? now, bool ago = false}) {
    final current = now ?? DateTime.now();
    if (ago) {
      final passed = current.difference(time);
      if (!passed.isNegative && passed < const Duration(hours: 1)) {
        if (passed.inMinutes < 1) return labels.justNow;
        return labels.minutesAgo.replaceAll('{n}', '${passed.inMinutes}');
      }
    }
    final days = _daysBetween(wallClock(time), wallClock(current));
    if (days == 0) return this.time(time);
    return day(time, now: current);
  }

  /// The day and time: `Today, 14:05`, `Monday, 9:30 AM`, `12 Nov, 14:05`.
  String dateTime(DateTime time, {DateTime? now}) =>
      '${day(time, now: now)}, ${this.time(time)}';

  /// Everything, for a details screen:
  /// `Wednesday, 12 November 2025, 14:05:09 GMT+02:00`.
  String full(DateTime time, {bool timeZone = true}) {
    final t = wallClock(time);
    final zone = timeZone ? ' ${offsetLabel(time)}' : '';
    return '${labels.weekdays[t.weekday - 1]}, '
        '${date(time, withYear: true, long: true)}, '
        '${this.time(time, seconds: true)}$zone';
  }

  /// The offset from UTC at [time], such as `GMT+02:00`, `GMT-03:30` or
  /// `GMT` for zero.
  String offsetLabel(DateTime time) {
    final offset = offsetAt(time);
    if (offset == Duration.zero) return labels.utc;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return '${labels.utc}$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }

  /// A stopwatch style duration: `0:45`, `12:03`, `1:02:03`.
  String duration(Duration duration) {
    final total = duration.isNegative ? 0 : duration.inSeconds;
    final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
    if (h > 0) return '$h:${_two(m)}:${_two(s)}';
    return '$m:${_two(s)}';
  }

  /// A duration in words: `45 s`, `2 min 5 s`, `1 h 2 min`. Seconds are
  /// left out from an hour up.
  String durationWords(Duration duration) {
    final total = duration.isNegative ? 0 : duration.inSeconds;
    final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
    final parts = <String>[
      if (h > 0) '$h ${labels.hours}',
      if (m > 0) '$m ${labels.minutes}',
      if (h == 0 && (s > 0 || m == 0)) '$s ${labels.seconds}',
    ];
    return parts.join(' ');
  }
}

/// Splits [items] (newest first) into runs that share a calendar day in the
/// formatter's time zone, for "Today / Yesterday / Monday" section headers.
/// [dateOf] reads each item's time.
List<MapEntry<DateTime, List<T>>> groupByDay<T>(
  Iterable<T> items,
  DateTime Function(T item) dateOf, {
  CallTimeFormatter formatter = const CallTimeFormatter(),
}) {
  final groups = <MapEntry<DateTime, List<T>>>[];
  DateTime? currentDay;
  for (final item in items) {
    final time = dateOf(item);
    final t = formatter.wallClock(time);
    final day = DateTime.utc(t.year, t.month, t.day);
    if (currentDay != day || groups.isEmpty) {
      currentDay = day;
      groups.add(MapEntry(time, [item]));
    } else {
      groups.last.value.add(item);
    }
  }
  return groups;
}
