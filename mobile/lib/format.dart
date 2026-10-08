import 'package:intl/intl.dart';

import 'i18n.dart';

final _peso = NumberFormat.currency(locale: 'en_US', symbol: '₱', decimalDigits: 0);
final _plain = NumberFormat('#,##0', 'en_US');
final _iso = DateFormat('yyyy-MM-dd');

// Filipino dates when the app is in Filipino (falls back to English if the phone lacks the data)
String get _locale => isFil && DateFormat.localeExists('fil') ? 'fil' : 'en_US';

String money(dynamic n) => _peso.format(num.tryParse('$n') ?? 0);

/// "3,800" without the peso sign, for tight spaces like the calendar.
String shortMoney(dynamic n) => _plain.format(num.tryParse('$n') ?? 0);

/// Dates travel to and from the database as YYYY-MM-DD in the hotel's time zone.
String isoDate(DateTime d) => _iso.format(d);
DateTime parseDate(String s) => DateTime.parse(s);
String niceDate(String iso, {bool year = false}) =>
    DateFormat(year ? 'EEE, MMM d, y' : 'EEE, MMM d', _locale).format(parseDate(iso));
String niceTime(String timestamp) => DateFormat('h:mm a', _locale).format(DateTime.parse(timestamp).toLocal());
String monthYear(DateTime d) => DateFormat('MMMM y', _locale).format(d);
String longDate(String timestamp) => DateFormat('MMMM d, y', _locale).format(DateTime.parse(timestamp).toLocal());

/// Today in Manila (UTC+8), whatever the phone's own time zone is.
DateTime todayManila() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime(now.year, now.month, now.day);
}

int nightsBetween(String a, String b) => parseDate(b).difference(parseDate(a)).inDays;

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String nights(int n) => isFil ? '$n gabi' : plural(n, 'night');

String guests(int adults, int children) {
  if (isFil) return children > 0 ? '$adults matanda, $children bata' : '$adults matanda';
  return children > 0
      ? '${plural(adults, 'adult')}, ${plural(children, 'child', 'children')}'
      : plural(adults, 'adult');
}

const _statusEn = {
  'held': 'Awaiting payment',
  'confirmed': 'Confirmed',
  'checked_in': 'Checked in',
  'checked_out': 'Completed',
  'cancelled': 'Cancelled',
  'no_show': 'No-show',
  'expired': 'Expired',
};

const _statusFil = {
  'held': 'Naghihintay ng bayad',
  'confirmed': 'Kumpirmado',
  'checked_in': 'Naka-check in',
  'checked_out': 'Tapos na',
  'cancelled': 'Kinansela',
  'no_show': 'Hindi dumating',
  'expired': 'Nag-expire',
};

String statusLabel(String status) => (isFil ? _statusFil : _statusEn)[status] ?? status;
