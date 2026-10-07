import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';
import 'booking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.roomTypeId,
    required this.roomName,
    required this.offer,
    required this.checkIn,
    required this.checkOut,
    required this.adults,
    required this.children,
  });

  final String roomTypeId, roomName, checkIn, checkOut;
  final Map<String, dynamic> offer;
  final int adults, children;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _requests = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = db.auth.currentUser;
    _email.text = user?.email ?? '';
    if (user != null) {
      db.from('profiles').select('full_name, phone').eq('id', user.id).maybeSingle().then((p) {
        if (!mounted || p == null) return;
        if (_name.text.isEmpty) _name.text = (p['full_name'] as String?) ?? '';
        if (_phone.text.isEmpty) _phone.text = (p['phone'] as String?) ?? '';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _requests]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    Map<String, dynamic> booking;
    try {
      booking = Map<String, dynamic>.from(await db.rpc('create_booking', params: {
        'p_room_type_id': widget.roomTypeId,
        'p_rate_plan_id': widget.offer['rate_plan_id'],
        'p_check_in': widget.checkIn,
        'p_check_out': widget.checkOut,
        'p_adults': widget.adults,
        'p_children': widget.children,
        'p_guest_name': _name.text.trim(),
        'p_guest_email': _email.text.trim(),
        'p_guest_phone': _phone.text.trim(),
        'p_special_requests': _requests.text.trim(),
        'p_source': 'mobile',
      }) as Map);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
      return;
    }

    final bookingId = booking['id'] as String;
    String? payError;
    try {
      final url = await createCheckout(bookingId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      payError = errorText(e);
    }
    if (!mounted) return;

    // Show the booking; it refreshes when the guest comes back from paying
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => BookingScreen(bookingId: bookingId, paymentError: payError)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final refundable = offer['refundable'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text("Who's staying?")),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.roomName, style: displayStyle(context, 22)),
                  Text(offer['name'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  InfoRow('Check-in', niceDate(widget.checkIn, year: true)),
                  InfoRow('Check-out', niceDate(widget.checkOut, year: true)),
                  InfoRow('Guests', guests(widget.adults, widget.children)),
                  const Divider(height: 20),
                  Row(children: [
                    const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(offer['total']), style: displayStyle(context, 24)),
                  ]),
                  const SizedBox(height: 6),
                  Text(refundable ? 'Free cancellation until ${offer['free_cancel_hours']}h before check-in.' : "This rate can't be refunded.",
                      style: TextStyle(color: refundable ? Palette.good : Palette.sun)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the guest name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Mobile number', hintText: '+63 917 123 4567'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _requests,
              decoration: const InputDecoration(labelText: 'Special requests (optional)'),
              maxLines: 3,
            ),
            if (_error != null) ErrorNote(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Holding your room…' : 'Continue to payment · ${money(offer['total'])}'),
            ),
            const SizedBox(height: 8),
            Text('Your room is held for 15 minutes while you pay with GCash, Maya, GrabPay, QR Ph or card.',
                textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
