import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../hotel.dart';
import '../i18n.dart';
import '../price_calendar.dart';
import '../theme.dart';
import '../widgets.dart';
import 'receipt_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.bookingId, this.paymentError});
  final String bookingId;
  final String? paymentError;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _b;
  Map<String, dynamic>? _myReview;
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _error = widget.paymentError == null
        ? null
        : tr("Payment couldn't start: ${widget.paymentError}", 'Hindi nasimulan ang pagbayad: ${widget.paymentError}');
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
      Map<String, dynamic>? review;
      if (row['status'] == 'checked_out') {
        review = await db.from('reviews').select().eq('booking_id', widget.bookingId).maybeSingle();
      }
      if (mounted) {
        setState(() {
          _b = row;
          _myReview = review;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  void _say({String? notice, String? error}) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _error = error;
    });
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
        title: Text(tr('Cancel this booking?', 'Kanselahin ang booking na ito?')),
        content: Text(refundable
            ? tr("Free if it's more than ${plan?['free_cancel_hours']} hours before check-in; after that the first night is kept.",
                'Libre kung higit ${plan?['free_cancel_hours']} oras pa bago ang check-in; pagkatapos noon, hindi na ibabalik ang bayad sa unang gabi.')
            : tr('This rate is non-refundable, so no money will be returned.',
                'Non-refundable ang rate na ito, kaya walang perang maibabalik.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Keep booking', 'Huwag kanselahin'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('Yes, cancel', 'Oo, kanselahin'), style: const TextStyle(color: Palette.bad))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = Map<String, dynamic>.from(await db.rpc('cancel_booking', params: {'p_booking_id': widget.bookingId}) as Map);
      final refund = num.tryParse('${res['refund_due']}') ?? 0;
      _say(
          notice: refund > 0
              ? tr('Booking cancelled. ${money(refund)} will be refunded to your original payment method.',
                  'Nakansela na ang booking. Ipapadala ang refund na ${money(refund)} sa orihinal na paraan ng pagbayad.')
              : tr('Booking cancelled.', 'Nakansela na ang booking.'));
      _load();
    } catch (e) {
      _say(error: errorText(e));
    }
  }

  // ---- Change dates ---------------------------------------------------------

  Future<void> _changeDates(Map<String, dynamic> b) async {
    final picked = await pickStayDates(
      context,
      initial: DateTimeRange(start: parseDate(b['check_in'] as String), end: parseDate(b['check_out'] as String)),
      adults: b['adults'] as int,
      children: b['children'] as int,
      title: tr('Change your dates', 'Palitan ang mga petsa'),
      blockFullNights: false,
    );
    if (picked == null || !mounted) return;
    final checkIn = isoDate(picked.start);
    final checkOut = isoDate(picked.end);
    if (checkIn == b['check_in'] && checkOut == b['check_out']) return;

    Future<Map<String, dynamic>> call(bool preview) async => Map<String, dynamic>.from(await db.rpc('change_booking_dates', params: {
          'p_booking_id': widget.bookingId,
          'p_check_in': checkIn,
          'p_check_out': checkOut,
          'p_preview': preview,
        }) as Map);

    Map<String, dynamic> quote;
    setState(() => _busy = true);
    try {
      quote = await call(true);
    } catch (e) {
      setState(() => _busy = false);
      _say(error: errorText(e));
      return;
    }
    setState(() => _busy = false);
    if (!mounted) return;

    final balance = num.tryParse('${quote['balance_due']}') ?? 0;
    final refund = num.tryParse('${quote['refund_due']}') ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Change your dates', 'Palitan ang mga petsa')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${niceDate(checkIn, year: true)} → ${niceDate(checkOut, year: true)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(nights(nightsBetween(checkIn, checkOut))),
          const SizedBox(height: 12),
          Text(tr('New total', 'Bagong kabuuan')),
          Text(money(quote['total']), style: displayStyle(context, 26)),
          Text(tr('was ${money(quote['old_total'])}', 'dati ay ${money(quote['old_total'])}'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text(balance > 0
              ? tr('${money(balance)} more to pay. Pay it at the front desk when you arrive.',
                  '${money(balance)} pa ang babayaran. Bayaran ito sa front desk pagdating mo.')
              : refund > 0
                  ? tr('${money(refund)} will be refunded to your original payment method.',
                      'Ire-refund ang ${money(refund)} sa orihinal na paraan ng pagbayad.')
                  : tr('Same price, nothing more to pay.', 'Parehong presyo, wala nang babayaran.')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Not now', 'Huwag muna'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Change my dates', 'Palitan ang mga petsa ko')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await call(false);
      _say(notice: tr('Your dates are changed.', 'Napalitan na ang mga petsa mo.'));
      _load();
    } catch (e) {
      _say(error: errorText(e));
    }
  }

  // ---- ID upload ------------------------------------------------------------

  static const _idTypes = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic'};

  Future<void> _chooseId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('Take a photo', 'Kumuha ng litrato')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('Choose from your photos', 'Pumili mula sa mga litrato mo')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 2200, imageQuality: 85);
    } catch (e) {
      _say(error: tr("Couldn't open the camera or photos.", 'Hindi mabuksan ang camera o mga litrato.'));
      return;
    }
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _say(error: tr('That file is over 5 MB. Try a smaller photo.', 'Lampas 5 MB ang file. Subukan ang mas maliit na litrato.'));
      return;
    }
    final lower = file.name.toLowerCase();
    final fromName = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.heic')
                ? 'image/heic'
                : 'image/jpeg';
    final type = _idTypes.containsKey(file.mimeType) ? file.mimeType! : fromName;
    final path = '${widget.bookingId}/id-${DateTime.now().millisecondsSinceEpoch}.${_idTypes[type]}';
    final previous = _b?['id_document_path'] as String?;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final bucket = db.storage.from('guest-ids');
      await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
      await db.rpc('record_id_upload', params: {'p_booking_id': widget.bookingId, 'p_path': path});
      if (previous != null && previous != path) {
        try {
          await bucket.remove([previous]); // replace the earlier photo
        } catch (_) {}
      }
      _say(notice: tr('ID received. The front desk will check it when you arrive.',
          'Natanggap ang ID. Titingnan ito ng front desk pagdating mo.'));
      await _load();
    } catch (e) {
      _say(error: errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) {
      return Scaffold(
          appBar: AppBar(),
          body: _error != null ? Padding(padding: const EdgeInsets.all(16), child: ErrorNote(_error!)) : const Loading());
    }

    final rooms = List<Map<String, dynamic>>.from(b['booking_rooms'] as List? ?? const []);
    final br = rooms.isNotEmpty ? rooms.first : null;
    final plan = br?['rate_plans'] as Map<String, dynamic>?;
    final nightly = List<Map<String, dynamic>>.from(br?['nightly_prices'] as List? ?? const []);
    final status = b['status'] as String;
    final holdEnds = b['hold_expires_at'] as String?;
    final holdActive = status == 'held' && holdEnds != null && DateTime.parse(holdEnds).isAfter(DateTime.now());
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final arriving = arrivalLabel(b['arrival_time'] as String?);
    final requests = (b['special_requests'] as String?)?.trim() ?? '';
    final balance = (num.tryParse('${b['total']}') ?? 0) - (num.tryParse('${b['amount_paid']}') ?? 0);

    return Scaffold(
      appBar: AppBar(title: Text('Booking ${b['code']}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            Row(children: [
              Expanded(
                  child: Text(br?['room_types']?['name'] as String? ?? tr('Your stay', 'Ang iyong pananatili'),
                      style: displayStyle(context, 28))),
              StatusChip(status),
            ]),
            Text(plan?['name'] as String? ?? '', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            if (_error != null) Note(_error!, color: Palette.bad),
            if (_notice != null) Note(_notice!, color: Palette.good),
            if (holdActive) ...[
              Card(
                color: Palette.sun.withValues(alpha: 0.10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(tr('Your room is held until ${niceTime(holdEnds!)}. Pay before then to confirm it.',
                        'Hawak ang kuwarto mo hanggang ${niceTime(holdEnds!)}. Magbayad bago noon para makumpirma.')),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _busy ? null : _pay,
                        child: Text(_busy
                            ? tr('Opening checkout…', 'Binubuksan ang checkout…')
                            : tr('Pay ${money(b['total'])}', 'Magbayad ng ${money(b['total'])}'))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (status == 'held' && !holdActive)
              ErrorNote(tr('This hold has ended and the room was released. Please book again.',
                  'Tapos na ang paghawak at binitawan na ang kuwarto. Mag-book ulit.')),
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
                    Text(b['code'] as String,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3)),
                    Text(tr('Show this at the front desk', 'Ipakita ito sa front desk'), style: TextStyle(color: muted)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow('Check-in',
                      tr('${niceDate(b['check_in'] as String, year: true)}, from $checkInTime', '${niceDate(b['check_in'] as String, year: true)}, mula $checkInTime')),
                  InfoRow('Check-out',
                      tr('${niceDate(b['check_out'] as String, year: true)}, by $checkOutTime', '${niceDate(b['check_out'] as String, year: true)}, hanggang $checkOutTime')),
                  InfoRow(tr('Guests', 'Mga bisita'), guests(b['adults'] as int, b['children'] as int)),
                  InfoRow(tr('Guest', 'Bisita'), b['guest_name'] as String),
                  if (arriving != null) InfoRow(tr('Arriving', 'Darating'), arriving),
                  if (requests.isNotEmpty) InfoRow(tr('Requests', 'Mga hiling'), requests),
                  if (br?['rooms']?['number'] != null) InfoRow(tr('Room', 'Kuwarto'), br!['rooms']['number'] as String),
                  if (plan != null)
                    InfoRow(
                        tr('Cancellation', 'Pagkansela'),
                        plan['refundable'] == true
                            ? tr('Free until ${plan['free_cancel_hours']}h before check-in',
                                'Libre hanggang ${plan['free_cancel_hours']} oras bago ang check-in')
                            : 'Non-refundable'),
                  const Divider(height: 24),
                  for (final n in nightly) InfoRow(niceDate(n['date'] as String), money(n['price'])),
                  const Divider(height: 24),
                  Row(children: [
                    Expanded(
                        child: Text(
                            tr('Total for ${nights(nightsBetween(b['check_in'] as String, b['check_out'] as String))}',
                                'Kabuuan para sa ${nights(nightsBetween(b['check_in'] as String, b['check_out'] as String))}'),
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(b['total']), style: displayStyle(context, 22)),
                  ]),
                  Align(
                      alignment: Alignment.centerRight,
                      child: Text(tr('Paid ${money(b['amount_paid'])}', 'Nabayaran: ${money(b['amount_paid'])}'),
                          style: TextStyle(color: muted))),
                  if (status != 'held' && status != 'cancelled' && balance > 0)
                    Align(
                        alignment: Alignment.centerRight,
                        child: Text(tr('${money(balance)} left to pay', '${money(balance)} pa ang babayaran'),
                            style: const TextStyle(color: Palette.sun, fontWeight: FontWeight.w600))),
                  if ((num.tryParse('${b['refund_due']}') ?? 0) > 0)
                    Align(
                        alignment: Alignment.centerRight,
                        child: Text(tr('Refund due ${money(b['refund_due'])}', 'Refund na matatanggap: ${money(b['refund_due'])}'),
                            style: const TextStyle(color: Palette.bad))),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(booking: b))),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(tr('Receipt', 'Resibo')),
                    ),
                  ),
                ]),
              ),
            ),
            if (status == 'confirmed') _changeDatesCard(b, plan),
            if (status == 'confirmed' || holdActive) _idCard(b),
            if (status == 'checked_out') _ReviewCard(bookingId: widget.bookingId, existing: _myReview, onPosted: _load),
            if (status == 'confirmed') _beforeYouArrive(b),
            if (status == 'confirmed') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _cancel(plan),
                style: OutlinedButton.styleFrom(foregroundColor: Palette.bad),
                child: Text(tr('Cancel booking', 'Kanselahin ang booking')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _changeDatesCard(Map<String, dynamic> b, Map<String, dynamic>? plan) {
    final refundable = plan?['refundable'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Change your dates', 'Palitan ang mga petsa'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              refundable
                  ? tr("Same room and rate. You'll see the new price before anything changes.",
                      'Parehong kuwarto at rate. Makikita mo muna ang bagong presyo bago may mabago.')
                  : tr("This rate can't be changed online. Call the front desk and we'll help.",
                      'Hindi mapapalitan online ang rate na ito. Tumawag sa front desk at tutulungan ka namin.'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (refundable)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _changeDates(b),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(tr('Change dates', 'Palitan ang petsa')),
              )
            else
              OutlinedButton.icon(
                onPressed: () => launchUrl(phoneUrl),
                icon: const Icon(Icons.call_outlined),
                label: Text(tr('Call the front desk', 'Tumawag sa front desk')),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _idCard(Map<String, dynamic> b) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final verified = b['id_verified_at'] != null;
    final uploadedAt = b['id_uploaded_at'] as String?;
    final hasFile = b['id_document_path'] != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Send your ID before you arrive', 'Ipadala ang ID bago dumating'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (verified)
              Text(tr('Your ID has been checked. The photo has been deleted.', 'Na-check na ang ID mo. Binura na ang litrato.'),
                  style: const TextStyle(color: Palette.good))
            else ...[
              Text(
                hasFile && uploadedAt != null
                    ? tr('ID received ${longDate(uploadedAt)}. The front desk will check it when you arrive.',
                        'Natanggap ang ID noong ${longDate(uploadedAt)}. Titingnan ito ng front desk pagdating mo.')
                    : tr('Upload a clear photo of a government ID or passport for the guest named on the booking. Check-in is quicker, and only the front desk can see it.',
                        'Mag-upload ng malinaw na litrato ng government ID o pasaporte ng bisitang nakapangalan sa booking. Mas mabilis ang check-in, at ang front desk lang ang makakakita nito.'),
                style: TextStyle(color: hasFile ? Palette.good : muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _chooseId,
                icon: const Icon(Icons.badge_outlined),
                label: Text(_busy
                    ? tr('Uploading…', 'Ina-upload…')
                    : hasFile
                        ? tr('Upload a different photo', 'Mag-upload ng ibang litrato')
                        : tr('Upload a photo of your ID', 'I-upload ang litrato ng ID')),
              ),
              const SizedBox(height: 6),
              Text(tr('We delete the photo as soon as the front desk has checked it.',
                  'Binubura namin ang litrato sa sandaling ma-check ito ng front desk.'),
                  style: TextStyle(color: muted, fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _beforeYouArrive(Map<String, dynamic> b) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget item(String label, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: muted, fontSize: 13)),
            Text(body, style: const TextStyle(fontSize: 15)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Before you arrive', 'Bago ka dumating'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            item(tr('Where', 'Saan'), hotelAddress),
            item(tr('Bring', 'Dalhin'), tr('A valid ID for ${b['guest_name']}', 'Valid na ID para kay ${b['guest_name']}')),
            item('Check-in', tr('From $checkInTime. Show the QR code at the front desk.', 'Mula $checkInTime. Ipakita ang QR code sa front desk.')),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(mapsUrl, mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions_outlined),
                  label: Text(tr('Directions', 'Direksyon')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(phoneUrl),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(tr('Call', 'Tumawag')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// After check-out: leave a star rating and a few words, once per stay.
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.bookingId, required this.existing, required this.onPosted});
  final String bookingId;
  final Map<String, dynamic>? existing;
  final Future<void> Function() onPosted;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  final _text = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  bool _posted = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.rpc('submit_review', params: {'p_booking_id': widget.bookingId, 'p_rating': _rating, 'p_body': _text.text.trim()});
      _posted = true;
      await widget.onPosted();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final mine = widget.existing;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: mine != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_posted) Note(tr('Thank you. Your review is posted.', 'Salamat. Naka-post na ang review mo.'), color: Palette.good),
                  Text(tr('Your review', 'Ang review mo'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Stars((mine['rating'] as num?) ?? 0),
                  if ((mine['body'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text(mine['body'] as String),
                  ],
                  const SizedBox(height: 6),
                  Text('${mine['display_name']}', style: TextStyle(color: muted, fontSize: 13)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(tr('How was your stay?', 'Kumusta ang pananatili mo?'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Your review helps other guests decide. It shows with your first name and last initial.',
                        'Nakakatulong ang review mo sa ibang bisita. Ipapakita ito kasama ang pangalan mo at inisyal ng apelyido.'),
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => _rating = i),
                        tooltip: tr('$i star${i == 1 ? '' : 's'}', '$i bituin'),
                        iconSize: 36,
                        icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Palette.mango),
                      ),
                  ]),
                  TextField(
                    controller: _text,
                    maxLength: 1500,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                        labelText: tr('Tell other guests about your stay (optional)',
                            'Ikuwento sa ibang bisita ang iyong pananatili (opsyonal)')),
                  ),
                  if (_error != null) ErrorNote(_error!),
                  FilledButton(
                    onPressed: _busy || _rating == 0 ? null : _submit,
                    child: Text(_busy ? tr('Posting…', 'Ipinopost…') : tr('Post my review', 'I-post ang review ko')),
                  ),
                ]),
        ),
      ),
    );
  }
}
