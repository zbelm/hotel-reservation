import 'package:intl/intl.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
final _iso = DateFormat('yyyy-MM-dd');
final _nice = DateFormat('EEE, MMM d');
final _niceYear = DateFormat('EEE, MMM d, y');
final _time = DateFormat('h:mm a');

String money(dynamic n) => _peso.format(num.tryParse('$n') ?? 0);

/// Dates travel to and from the database as YYYY-MM-DD in the hotel's time zone.
String isoDate(DateTime d) => _iso.format(d);
DateTime parseDate(String s) => DateTime.parse(s);
String niceDate(String iso, {bool year = false}) => (year ? _niceYear : _nice).format(parseDate(iso));
String niceTime(String timestamp) => _time.format(DateTime.parse(timestamp).toLocal());

/// Today in Manila (UTC+8), whatever the phone's own time zone is.
DateTime todayManila() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime(now.year, now.month, now.day);
}

int nightsBetween(String a, String b) => parseDate(b).difference(parseDate(a)).inDays;

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String guests(int adults, int children) => children > 0
    ? '${plural(adults, 'adult')}, ${plural(children, 'child', 'children')}'
    : plural(adults, 'adult');

const bookingStatusLabel = {
  'held': 'Awaiting payment',
  'confirmed': 'Confirmed',
  'checked_in': 'Checked in',
  'checked_out': 'Completed',
  'cancelled': 'Cancelled',
  'no_show': 'No-show',
  'expired': 'Expired',
};
