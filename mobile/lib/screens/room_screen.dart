import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../i18n.dart';
import '../reviews.dart';
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
              if ((isFil ? room['description_fil'] ?? room['description'] : room['description']) != null)
                Text('${isFil ? room['description_fil'] ?? room['description'] : room['description']}',
                    style: const TextStyle(fontSize: 16, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final a in amenities) Chip(label: Text(a), visualDensity: VisualDensity.compact)]),
              const SizedBox(height: 20),
              Text('${niceDate(widget.checkIn)} → ${niceDate(widget.checkOut)} · ${guests(widget.adults, widget.children)}',
                  style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text(tr('Choose a rate', 'Pumili ng rate'), style: displayStyle(context, 22)),
              const SizedBox(height: 12),
              if (offers.isEmpty)
                Text(tr('No rates are open for these dates.', 'Walang bukas na rate para sa mga petsang ito.'), style: TextStyle(color: muted)),
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
              SectionTitle(tr('Good to know', 'Mabuting malaman'), top: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    InfoRow('Check-in', tr('From $checkInTime, with a valid ID', 'Mula $checkInTime, may valid na ID')),
                    InfoRow('Check-out', tr('By $checkOutTime', 'Hanggang $checkOutTime')),
                    InfoRow(tr('Payment', 'Bayad'),
                        tr('In full when you book, taxes included', 'Buong bayad kapag nag-book, kasama ang buwis')),
                    InfoRow(tr('Front desk', 'Front desk'), tr('Open 24 hours', 'Bukas 24 oras')),
                  ]),
                ),
              ),
              SectionTitle(tr('Guest reviews', 'Mga review ng bisita')),
              ReviewsSection(roomTypeId: widget.roomTypeId),
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
            refundable
                ? tr('Free cancellation or date change until ${offer['free_cancel_hours']}h before check-in',
                    'Libreng pagkansela o pagpalit ng petsa hanggang ${offer['free_cancel_hours']} oras bago ang check-in')
                : tr("Non-refundable: can't be cancelled for a refund", 'Non-refundable: walang refund kapag kinansela'),
            style: TextStyle(color: refundable ? Palette.good : Palette.sun, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            offer['includes_breakfast'] == true
                ? tr('Breakfast for two every morning', 'Almusal para sa dalawa tuwing umaga')
                : tr('Breakfast not included (₱450 a person in the café)', 'Hindi kasama ang almusal (₱450 bawat tao sa café)'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (bookable)
            FilledButton(onPressed: onReserve, child: Text(tr('Reserve this rate', 'I-reserve ang rate na ito')))
          else
            Text(
                (offer['available'] as int) < 1
                    ? tr('Sold out for these dates', 'Ubos na para sa mga petsang ito')
                    : tr('Needs a stay of ${offer['min_stay']}+ nights', 'Kailangang ${offer['min_stay']} gabi o higit pa'),
                style: const TextStyle(color: Palette.bad)),
        ]),
      ),
    );
  }
}
