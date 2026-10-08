import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../hotel.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'booking_screen.dart';
import 'hotel_screen.dart';

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
  String _arrival = 'not_sure';
  bool _agree = false;
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

  void _addRequest(String idea) {
    final now = _requests.text.trim();
    if (now.toLowerCase().contains(idea.toLowerCase())) return;
    _requests.text = now.isEmpty ? idea : '$now, $idea';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      setState(() => _error = tr('Please confirm you have read the house rules and cancellation terms.',
          'Pakikumpirma na nabasa mo na ang mga patakaran at tuntunin sa pagkansela.'));
      return;
    }
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

    // Arrival time and the agreement are extras: a failure here shouldn't stop the booking
    try {
      await db.rpc('save_booking_details', params: {
        'p_booking_id': bookingId,
        'p_arrival_time': _arrival,
        'p_accept_policies': true,
      });
    } catch (_) {}

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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final n = nightsBetween(widget.checkIn, widget.checkOut);
    final guestName = _name.text.trim().isEmpty ? tr('the guest named above', 'sa bisitang nakapangalan sa itaas') : _name.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(tr("Who's staying?", 'Sino ang tutuloy?'))),
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
                  Text(offer['name'] as String, style: TextStyle(color: muted)),
                  const SizedBox(height: 8),
                  InfoRow('Check-in', niceDate(widget.checkIn, year: true)),
                  InfoRow('Check-out', niceDate(widget.checkOut, year: true)),
                  InfoRow(tr('Guests', 'Mga bisita'), guests(widget.adults, widget.children)),
                  const Divider(height: 20),
                  Row(children: [
                    Expanded(
                        child: Text(tr('Total for ${nights(n)}', 'Kabuuan para sa ${nights(n)}'),
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(offer['total']), style: displayStyle(context, 24)),
                  ]),
                  Text(tr('In pesos. VAT and service charge included.', 'Nasa piso. Kasama na ang VAT at service charge.'),
                      style: TextStyle(color: muted, fontSize: 13)),
                ]),
              ),
            ),

            SectionTitle(tr('Guest details', 'Detalye ng bisita'), top: 20),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: tr('Full name, as on the ID', 'Buong pangalan, gaya ng nasa ID')),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('Enter the guest name', 'Ilagay ang pangalan ng bisita') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: tr('Email for the confirmation', 'Email para sa kumpirmasyon')),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v ?? '').contains('@') ? null : tr('Enter a valid email', 'Maglagay ng tamang email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: tr('Mobile number', 'Mobile number'), hintText: '+63 917 123 4567'),
              keyboardType: TextInputType.phone,
            ),

            SectionTitle(tr('Your arrival', 'Ang iyong pagdating'), top: 20),
            Text(
              tr('Roughly when will you arrive on ${niceDate(widget.checkIn)}? Check-in starts at $checkInTime, and the front desk is open all night.',
                  'Anong oras ka inaasahang darating sa ${niceDate(widget.checkIn)}? Nagsisimula ang check-in nang $checkInTime, at bukas buong gabi ang front desk.'),
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in hotel.arrivalTimes.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _arrival == entry.key,
                  onSelected: (_) => setState(() => _arrival = entry.key),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _requests,
              decoration: InputDecoration(
                labelText: tr('Requests for the hotel (optional)', 'Mga hiling sa hotel (opsyonal)'),
                helperText: tr("We'll do our best; requests aren't guaranteed.",
                    'Gagawin namin ang aming makakaya; hindi garantisado ang mga hiling.'),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final idea in hotel.requestIdeas)
                ActionChip(label: Text('+ $idea'), onPressed: () => _addRequest(idea)),
            ]),

            SectionTitle(tr('Before you pay', 'Bago magbayad'), top: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    refundable
                        ? tr('${offer['name']}: free to cancel or change dates until ${offer['free_cancel_hours']} hours before check-in. After that, the first night is kept.',
                            '${offer['name']}: libreng kanselahin o palitan ang petsa hanggang ${offer['free_cancel_hours']} oras bago ang check-in. Pagkatapos noon, hindi na ibabalik ang bayad sa unang gabi.')
                        : tr("${offer['name']}: this rate can't be refunded if you cancel or don't arrive.",
                            '${offer['name']}: walang refund ang rate na ito kapag kinansela o hindi ka dumating.'),
                    style: TextStyle(color: refundable ? Palette.good : Palette.sun, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('Bring a valid ID for $guestName. Check-in from $checkInTime, check-out by $checkOutTime.',
                      'Magdala ng valid na ID para kay $guestName. Check-in mula $checkInTime, check-out hanggang $checkOutTime.')),
                  const SizedBox(height: 8),
                  Text(tr('No pets or smoking in rooms. Quiet hours 10 PM to 7 AM.',
                      'Bawal ang alagang hayop at paninigarilyo sa kuwarto. Oras ng katahimikan: 10 PM hanggang 7 AM.')),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HotelScreen())),
                    child: Text(tr('Read all house rules', 'Basahin ang lahat ng patakaran')),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() {
                _agree = v ?? false;
                if (_agree) _error = null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(tr("I've read the house rules and this rate's cancellation terms.",
                  'Nabasa ko na ang mga patakaran ng hotel at ang mga tuntunin sa pagkansela ng rate na ito.')),
            ),
            if (_error != null) ErrorNote(_error!),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy
                  ? tr('Holding your room…', 'Inihahawak ang kuwarto mo…')
                  : tr('Hold my room and pay ${money(offer['total'])}', 'Ihawak ang kuwarto at magbayad ng ${money(offer['total'])}')),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Your room is held for 15 minutes while you pay with GCash, Maya, GrabPay, QR Ph or card.',
                  'Ihahawak ang kuwarto mo nang 15 minuto habang nagbabayad ka sa GCash, Maya, GrabPay, QR Ph o card.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
