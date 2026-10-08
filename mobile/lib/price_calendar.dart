import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'i18n.dart';
import 'theme.dart';

/// Opens a calendar that shows the lowest nightly price on each day and marks full nights.
/// Returns the chosen check-in and check-out, or null if the guest closes it.
Future<DateTimeRange?> pickStayDates(
  BuildContext context, {
  required DateTimeRange initial,
  int adults = 1,
  int children = 0,
  String? title,
  // Off when changing an existing booking: its own nights can look full, and the
  // database checks availability for the new dates anyway
  bool blockFullNights = true,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: _PriceCalendar(
          initial: initial, adults: adults, children: children, title: title, blockFullNights: blockFullNights),
    ),
  );
}

class _DayPrice {
  const _DayPrice(this.price, this.available);
  final num? price;
  final bool available;
}

// Prices for a month are kept for the visit, so flipping back and forth is instant
final _cache = <String, Map<String, _DayPrice>>{};

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

class _PriceCalendar extends StatefulWidget {
  const _PriceCalendar(
      {required this.initial, required this.adults, required this.children, this.title, this.blockFullNights = true});
  final DateTimeRange initial;
  final int adults, children;
  final String? title;
  final bool blockFullNights;

  @override
  State<_PriceCalendar> createState() => _PriceCalendarState();
}

class _PriceCalendarState extends State<_PriceCalendar> {
  late final DateTime _today = _day(todayManila());
  late DateTime _month;
  DateTime? _in;
  DateTime? _out;
  final _days = <String, _DayPrice>{};
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _in = _day(widget.initial.start);
    _out = _day(widget.initial.end);
    final start = _in!.isBefore(_today) ? _today : _in!;
    _month = DateTime.utc(start.year, start.month);
    _load();
  }

  DateTime get _firstMonth => DateTime.utc(_today.year, _today.month);
  DateTime get _lastMonth => DateTime.utc(_today.year, _today.month + 11);

  Future<void> _load() async {
    final from = _month.isBefore(_today) ? _today : _month;
    final to = DateTime.utc(_month.year, _month.month + 1);
    final key = '${isoDate(from)}|${isoDate(to)}|${widget.adults}|${widget.children}';
    final hit = _cache[key];
    if (hit != null) {
      setState(() => _days.addAll(hit));
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await db.rpc('price_calendar', params: {
        'p_from': isoDate(from),
        'p_to': isoDate(to),
        'p_adults': widget.adults,
        'p_children': widget.children,
      });
      final map = <String, _DayPrice>{};
      for (final r in rows as List) {
        final m = r as Map;
        map['${m['day']}'] = _DayPrice(num.tryParse('${m['lowest_price']}'), m['available'] == true);
      }
      _cache[key] = map;
      if (mounted) setState(() => _days.addAll(map));
    } catch (_) {
      // Prices are a help, not a must: the dates can still be picked without them
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(int months) {
    setState(() => _month = DateTime.utc(_month.year, _month.month + months));
    _load();
  }

  bool get _pickingCheckOut => _in != null && _out == null;

  void _tap(DateTime d) {
    setState(() {
      _message = null;
      if (!_pickingCheckOut || !d.isAfter(_in!)) {
        _in = d;
        _out = null;
        return;
      }
      final n = d.difference(_in!).inDays;
      if (n > 30) {
        _message = tr('Stays are limited to 30 nights.', 'Hanggang 30 gabi lang ang bawat booking.');
        return;
      }
      for (var i = 0; widget.blockFullNights && i < n; i++) {
        final info = _days[isoDate(_in!.add(Duration(days: i)))];
        if (info != null && !info.available) {
          _message = tr('Every room is taken on one of those nights. Try other dates.',
              'Puno ang lahat ng kuwarto sa isa sa mga gabing iyon. Subukan ang ibang petsa.');
          return;
        }
      }
      _out = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final weekdays = isFil ? ['L', 'L', 'M', 'M', 'H', 'B', 'S'] : ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final first = _month;
    final daysInMonth = DateTime.utc(first.year, first.month + 1).difference(first).inDays;
    final lead = first.weekday % 7; // Sunday first

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title ?? tr('Your dates', 'Ang iyong mga petsa'), style: displayStyle(context, 24)),
        const SizedBox(height: 4),
        Text(
          _pickingCheckOut
              ? tr('Now choose your check-out date', 'Ngayon, piliin ang petsa ng check-out')
              : tr('Choose your check-in date', 'Piliin ang petsa ng check-in'),
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton.outlined(
            onPressed: first.isAfter(_firstMonth) ? () => _go(-1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: tr('Previous month', 'Nakaraang buwan'),
          ),
          Expanded(
            child: Text(monthYear(first),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          IconButton.outlined(
            onPressed: first.isBefore(_lastMonth) ? () => _go(1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: tr('Next month', 'Susunod na buwan'),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final w in weekdays)
            Expanded(child: Text(w, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12))),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++) _cell(DateTime.utc(first.year, first.month, d), scheme),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!, style: const TextStyle(color: Palette.bad)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            tr('Lowest price for one night, in pesos. Totals depend on the room and rate you choose.',
                'Pinakamababang presyo para sa isang gabi, sa piso. Nakadepende ang kabuuan sa kuwarto at rate na pipiliin mo.'),
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
        FilledButton(
          onPressed: _in != null && _out != null
              ? () => Navigator.of(context).pop(DateTimeRange(start: _in!, end: _out!))
              : null,
          child: Text(_in != null && _out != null
              ? '${niceDate(isoDate(_in!))} → ${niceDate(isoDate(_out!))} · ${nights(_out!.difference(_in!).inDays)}'
              : tr('Choose your dates', 'Piliin ang mga petsa')),
        ),
      ]),
    );
  }

  Widget _cell(DateTime d, ColorScheme scheme) {
    final info = _days[isoDate(d)];
    final past = d.isBefore(_today);
    final full = info != null && !info.available;
    // A full day can still be the check-out day: nobody sleeps there that night
    final disabled = past || (full && !_pickingCheckOut && widget.blockFullNights);
    final isEnd = d == _in || d == _out;
    final inRange = _in != null && _out != null && d.isAfter(_in!) && d.isBefore(_out!);

    final String below;
    if (past) {
      below = '';
    } else if (full) {
      below = tr('Full', 'Puno');
    } else if (info?.price != null) {
      below = shortMoney(info!.price);
    } else {
      below = '';
    }

    final label = '${niceDate(isoDate(d), year: true)}'
        '${full ? tr(', full', ', puno') : info?.price != null ? tr(', from ${money(info!.price)}', ', mula ${money(info!.price)}') : ''}';

    final fg = isEnd
        ? scheme.onPrimary
        : disabled
            ? scheme.onSurface.withValues(alpha: 0.35)
            : scheme.onSurface;

    return Semantics(
      label: label,
      button: !disabled,
      selected: isEnd,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isEnd
              ? scheme.primary
              : inRange
                  ? scheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : () => _tap(d),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${d.day}',
                  style: TextStyle(
                    color: fg,
                    fontWeight: isEnd ? FontWeight.w700 : FontWeight.w500,
                    decoration: full && !past ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 2),
              Text(below,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 10,
                    color: isEnd ? scheme.onPrimary : (full ? Palette.bad : scheme.onSurfaceVariant),
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
