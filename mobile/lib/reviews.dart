import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'i18n.dart';
import 'widgets.dart';

/// Published reviews from guests who stayed, for the whole hotel or one room type.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, this.roomTypeId, this.limit = 5});
  final String? roomTypeId;
  final int limit;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late final Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _data = _load();

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _load() async {
    var query = db.from('reviews').select().eq('is_published', true);
    if (widget.roomTypeId != null) query = query.eq('room_type_id', widget.roomTypeId!);
    final rows = await query.order('created_at', ascending: false).limit(widget.limit);
    final summary = await db.rpc('review_summary', params: {'p_room_type_id': widget.roomTypeId});
    return (Map<String, dynamic>.from(summary as Map), List<Map<String, dynamic>>.from(rows));
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Loading();
        // Reviews are extra: if they can't load, leave the space empty rather than alarm the guest
        if (snap.hasError) return const SizedBox.shrink();
        final (summary, rows) = snap.data!;
        final count = (summary['count'] as num?)?.toInt() ?? 0;
        final average = num.tryParse('${summary['average']}');
        if (count == 0 || average == null) {
          return Text(
            tr('No reviews yet. Guests can leave one after they check out.',
                'Wala pang review. Puwedeng mag-review ang mga bisita pagkatapos nilang mag-check out.'),
            style: TextStyle(color: muted),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Stars(average, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('$average out of 5 from ${plural(count, 'review')}', '$average sa 5 mula sa $count review'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            tr('Only guests who stayed with us can review, after they check out.',
                'Ang mga bisitang tumuloy lang sa amin ang puwedeng mag-review, pagkatapos nilang mag-check out.'),
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final r in rows) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stars((r['rating'] as num?) ?? 0, size: 16),
                  if ((r['body'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(r['body'] as String, style: const TextStyle(height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${r['display_name']} · ${tr('Stayed', 'Tumuloy noong')} ${monthYear(parseDate(r['stayed_on'] as String))}',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}
