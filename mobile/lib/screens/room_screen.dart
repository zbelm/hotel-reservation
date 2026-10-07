import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.roomTypeId,
    required this.roomName,
    required this.checkIn,
    required this.checkOut,
    required this.adults,
    required this.children,
  });

  final String roomTypeId, roomName, checkIn, checkOut;
  final int adults, children;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _data = _load();

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _load() async {
    final room = await db.from('room_types').select().eq('id', widget.roomTypeId).single();
    final offers = await db.rpc('room_type_offers', params: {
      'p_room_type_id': widget.roomTypeId,
      'p_check_in': widget.checkIn,
      'p_check_out': widget.checkOut,
    });
    return (room, List<Map<String, dynamic>>.from(offers as List));
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Loading();
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: ErrorNote(errorText(snap.error!)));
          final (room, offers) = snap.data!;
          final amenities = List<String>.from(room['amenities'] as List);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 180, child: RoomArt(name: room['name'] as String)),
              ),
              const SizedBox(height: 16),
              if (room['description'] != null) Text(room['description'] as String, style: const TextStyle(fontSize: 16, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final a in amenities) Chip(label: Text(a), visualDensity: VisualDensity.compact)]),
              const SizedBox(height: 20),
              Text('${niceDate(widget.checkIn)} → ${niceDate(widget.checkOut)} · ${guests(widget.adults, widget.children)}',
                  style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text('Choose a rate', style: displayStyle(context, 22)),
              const SizedBox(height: 12),
              for (final o in offers) ...[
                _OfferCard(
                  offer: o,
                  onReserve: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      roomTypeId: widget.roomTypeId,
                      roomName: widget.roomName,
                      offer: o,
                      checkIn: widget.checkIn,
                      checkOut: widget.checkOut,
                      adults: widget.adults,
                      children: widget.children,
                    ),
                  )),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onReserve});
  final Map<String, dynamic> offer;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final refundable = offer['refundable'] == true;
    final bookable = offer['bookable'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(offer['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            Text(money(offer['total']), style: displayStyle(context, 22)),
          ]),
          if (offer['description'] != null) ...[
            const SizedBox(height: 4),
            Text(offer['description'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          Text(
            refundable ? 'Free cancellation until ${offer['free_cancel_hours']}h before check-in' : 'Non-refundable',
            style: TextStyle(color: refundable ? Palette.good : Palette.sun, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (bookable)
            FilledButton(onPressed: onReserve, child: const Text('Reserve'))
          else
            Text((offer['available'] as int) < 1 ? 'Sold out for these dates' : 'Needs a stay of ${offer['min_stay']}+ nights',
                style: const TextStyle(color: Palette.bad)),
        ]),
      ),
    );
  }
}
