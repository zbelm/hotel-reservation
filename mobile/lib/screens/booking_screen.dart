import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.bookingId, this.paymentError});
  final String bookingId;
  final String? paymentError;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _b;
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _error = widget.paymentError == null ? null : "Payment couldn't start: ${widget.paymentError}";
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from PayMongo's page in the browser: check whether the payment landed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _b?['status'] == 'held') _load();
      });
    }
  }

  Future<void> _load() async {
    try {
      final row = await db.from('bookings').select(bookingSelect).eq('id', widget.bookingId).single();
      if (mounted) setState(() => _b = row);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await createCheckout(widget.bookingId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic>? plan) async {
    final refundable = plan?['refundable'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(refundable
            ? "Free if it's more than ${plan?['free_cancel_hours']} hours before check-in; after that the first night is kept."
            : 'This rate is non-refundable, so no money will be returned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep booking')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel', style: TextStyle(color: Palette.bad))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = Map<String, dynamic>.from(await db.rpc('cancel_booking', params: {'p_booking_id': widget.bookingId}) as Map);
      final refund = num.tryParse('${res['refund_due']}') ?? 0;
      setState(() => _notice = refund > 0
          ? 'Booking cancelled. ${money(refund)} will be refunded to your original payment method.'
          : 'Booking cancelled.');
      _load();
    } catch (e) {
      setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) {
      return Scaffold(appBar: AppBar(), body: _error != null ? Padding(padding: const EdgeInsets.all(16), child: ErrorNote(_error!)) : const Loading());
    }

    final rooms = List<Map<String, dynamic>>.from(b['booking_rooms'] as List? ?? const []);
    final br = rooms.isNotEmpty ? rooms.first : null;
    final plan = br?['rate_plans'] as Map<String, dynamic>?;
    final nightly = List<Map<String, dynamic>>.from(br?['nightly_prices'] as List? ?? const []);
    final status = b['status'] as String;
    final holdEnds = b['hold_expires_at'] as String?;
    final holdActive = status == 'held' && holdEnds != null && DateTime.parse(holdEnds).isAfter(DateTime.now());
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text('Booking ${b['code']}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(children: [
              Expanded(child: Text(br?['room_types']?['name'] as String? ?? 'Your stay', style: displayStyle(context, 28))),
              StatusChip(status),
            ]),
            Text(plan?['name'] as String? ?? '', style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            if (_error != null) ErrorNote(_error!),
            if (_notice != null) Text(_notice!, style: const TextStyle(color: Palette.good)),
            if (holdActive) ...[
              Card(
                color: Palette.sun.withValues(alpha: 0.10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Your room is held until ${niceTime(holdEnds!)}. Pay before then to confirm it.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _busy ? null : _pay, child: Text(_busy ? 'Opening checkout…' : 'Pay ${money(b['total'])}')),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (status == 'held' && !holdActive)
              const ErrorNote('This hold has ended and the room was released. Please book again.'),
            if (status == 'confirmed' || status == 'checked_in') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(data: b['code'] as String, size: 180),
                    ),
                    const SizedBox(height: 10),
                    Text(b['code'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3)),
                    Text('Show this at the front desk', style: TextStyle(color: muted)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow('Check-in', '${niceDate(b['check_in'] as String, year: true)}, from $checkInTime'),
                  InfoRow('Check-out', '${niceDate(b['check_out'] as String, year: true)}, by $checkOutTime'),
                  InfoRow('Guests', guests(b['adults'] as int, b['children'] as int)),
                  InfoRow('Guest', b['guest_name'] as String),
                  if (br?['rooms']?['number'] != null) InfoRow('Room', br!['rooms']['number'] as String),
                  if (plan != null)
                    InfoRow('Cancellation', plan['refundable'] == true ? 'Free until ${plan['free_cancel_hours']}h before check-in' : 'Non-refundable'),
                  const Divider(height: 24),
                  for (final n in nightly) InfoRow(niceDate(n['date'] as String), money(n['price'])),
                  const Divider(height: 24),
                  Row(children: [
                    Expanded(child: Text('Total · ${plural(nightsBetween(b['check_in'] as String, b['check_out'] as String), 'night')}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(b['total']), style: displayStyle(context, 22)),
                  ]),
                  Align(alignment: Alignment.centerRight, child: Text('Paid ${money(b['amount_paid'])}', style: TextStyle(color: muted))),
                  if ((num.tryParse('${b['refund_due']}') ?? 0) > 0)
                    Align(alignment: Alignment.centerRight, child: Text('Refund due ${money(b['refund_due'])}', style: const TextStyle(color: Palette.bad))),
                ]),
              ),
            ),
            if (status == 'confirmed') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _cancel(plan),
                style: OutlinedButton.styleFrom(foregroundColor: Palette.bad),
                child: const Text('Cancel booking'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
