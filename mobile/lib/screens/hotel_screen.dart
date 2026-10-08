import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../hotel.dart';
import '../i18n.dart';
import '../reviews.dart';
import '../theme.dart';
import '../widgets.dart';

/// Everything a guest wants to know before booking: the hotel, facilities, how to get
/// there, the house rules, reviews and common questions.
class HotelScreen extends StatelessWidget {
  const HotelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final h = hotel;
    return Scaffold(
      appBar: AppBar(title: Text(tr('The hotel', 'Ang hotel')), actions: const [LangButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(hotelName, style: displayStyle(context, 32)),
          const SizedBox(height: 4),
          Text(hotelAddress, style: TextStyle(color: muted)),
          const SizedBox(height: 16),
          Text(h.aboutHeading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
          for (final p in h.about) ...[
            const SizedBox(height: 10),
            Text(p, style: const TextStyle(fontSize: 16, height: 1.45)),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [for (final f in h.facts) InfoRow(f.title, f.body)]),
            ),
          ),

          SectionTitle(tr('Inside the hotel', 'Sa loob ng hotel')),
          Card(
            child: Column(children: [
              for (final f in h.facilities)
                ListTile(
                  leading: Icon(f.icon, color: Theme.of(context).colorScheme.primary),
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(f.detail),
                ),
            ]),
          ),

          SectionTitle(tr('Getting here', 'Paano makarating')),
          for (final line in h.gettingHere)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.place_outlined, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: const TextStyle(fontSize: 15, height: 1.35))),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(mapsUrl, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.map_outlined),
                label: Text(tr('Open in Maps', 'Buksan sa Maps')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(phoneUrl),
                icon: const Icon(Icons.call_outlined),
                label: Text(tr('Call us', 'Tumawag')),
              ),
            ),
          ]),

          SectionTitle(tr('House rules and cancellation', 'Patakaran at pagkansela')),
          Text(
            tr('In short: bring an ID, pay when you book, and flexible rates can be cancelled or changed free until 48 hours before you arrive.',
                'Sa madaling salita: magdala ng ID, magbayad kapag nag-book, at puwedeng kanselahin o palitan nang libre ang flexible rate hanggang 48 oras bago ka dumating.'),
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 10),
          _Expandables(items: h.policies),

          SectionTitle(tr('What guests say', 'Sabi ng mga bisita')),
          const ReviewsSection(),

          SectionTitle(tr('Questions guests ask', 'Mga madalas itanong')),
          _Expandables(items: h.faqs),
          const SizedBox(height: 16),
          Text(
            tr('Anything else? Call the front desk on $hotelPhone, any time.',
                'May iba ka pang tanong? Tumawag sa front desk sa $hotelPhone, kahit anong oras.'),
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Expandables extends StatelessWidget {
  const _Expandables({required this.items});
  final List<TextPair> items;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ExpansionTile(
              title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(items[i].body, style: const TextStyle(height: 1.45))],
            ),
          ],
        ]),
      );
}
