import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../i18n.dart';
import '../price_calendar.dart';
import '../theme.dart';
import '../widgets.dart';
import 'room_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late DateTimeRange _dates;
  int _adults = 2;
  int _children = 0;
  Future<List<Map<String, dynamic>>>? _results;

  @override
  void initState() {
    super.initState();
    final t = todayManila();
    _dates = DateTimeRange(start: t.add(const Duration(days: 1)), end: t.add(const Duration(days: 3)));
  }

  String get _checkIn => isoDate(_dates.start);
  String get _checkOut => isoDate(_dates.end);

  Future<void> _pickDates() async {
    final picked = await pickStayDates(context, initial: _dates, adults: _adults, children: _children);
    if (picked == null) return;
    setState(() {
      _dates = picked;
      _results = null; // old results were for other dates
    });
  }

  void _search() {
    setState(() {
      _results = db.rpc('search_availability', params: {
        'p_check_in': _checkIn,
        'p_check_out': _checkOut,
        'p_adults': _adults,
        'p_children': _children,
      }).then((rows) => List<Map<String, dynamic>>.from(rows as List));
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text(hotelName), actions: const [LangButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(tr('Watch the sun set over Manila Bay from your room.',
                  'Panoorin ang paglubog ng araw sa Manila Bay mula sa iyong kuwarto.'),
              style: displayStyle(context, 30)),
          const SizedBox(height: 8),
          Text(
            tr('Twelve rooms, a rooftop pool and a café that bakes its own pandesal. Pick your dates to see prices.',
                'Labindalawang kuwarto, rooftop pool, at café na may sariling lutong pandesal. Piliin ang petsa para makita ang presyo.'),
            style: TextStyle(color: muted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickDates,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.calendar_month_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${niceDate(_checkIn)}  →  ${niceDate(_checkOut)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('${nights(nightsBetween(_checkIn, _checkOut))} · ${tr('see prices on the calendar', 'tingnan ang presyo sa kalendaryo')}',
                                style: TextStyle(color: muted)),
                          ]),
                        ),
                        const Icon(Icons.edit_outlined, size: 18),
                      ]),
                    ),
                  ),
                  const Divider(height: 24),
                  Counter(label: tr('Adults', 'Matanda'), value: _adults, min: 1, max: 4, onChanged: (v) => setState(() => _adults = v)),
                  Counter(label: tr('Children', 'Bata'), value: _children, min: 0, max: 2, onChanged: (v) => setState(() => _children = v)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _search, child: Text(tr('Search rooms', 'Maghanap ng kuwarto'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_results != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _results,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Loading();
                if (snap.hasError) return ErrorNote(errorText(snap.error!));
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return ErrorNote(tr('No rooms fit that many guests. Try fewer guests, or call the front desk to book two rooms.',
                      'Walang kuwartong kasya ang ganoong dami ng bisita. Bawasan ang bisita, o tumawag sa front desk para mag-book ng dalawang kuwarto.'));
                }
                return Column(
                  children: [
                    for (final r in rows) ...[
                      _ResultCard(
                        room: r,
                        onTap: (r['available'] as int) < 1
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => RoomScreen(
                                    roomTypeId: r['room_type_id'] as String,
                                    roomName: r['name'] as String,
                                    checkIn: _checkIn,
                                    checkOut: _checkOut,
                                    adults: _adults,
                                    children: _children,
                                  ),
                                )),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.room, this.onTap});
  final Map<String, dynamic> room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final available = room['available'] as int;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 120, width: double.infinity, child: RoomArt(name: room['name'] as String)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room['name'] as String, style: displayStyle(context, 22)),
              const SizedBox(height: 4),
              Text(
                  tr('${room['bed_type']} bed · ${room['size_sqm']} m² · up to ${plural(room['max_adults'] as int, 'adult')}',
                      '${room['bed_type']} na kama · ${room['size_sqm']} m² · hanggang ${room['max_adults']} matanda'),
                  style: TextStyle(color: muted)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: available < 1
                      ? Text(tr('Sold out for these dates', 'Ubos na para sa mga petsang ito'),
                          style: const TextStyle(color: Palette.bad, fontWeight: FontWeight.w600))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('from ${money(room['lowest_nightly'])} a night', 'mula ${money(room['lowest_nightly'])} bawat gabi'),
                              style: TextStyle(color: muted)),
                          if (available <= 2)
                            Text(tr('Only $available left', '$available na lang ang natitira'),
                                style: const TextStyle(color: Palette.sun, fontWeight: FontWeight.w600)),
                        ]),
                ),
                if (available > 0) Text(money(room['lowest_total']), style: displayStyle(context, 24)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
