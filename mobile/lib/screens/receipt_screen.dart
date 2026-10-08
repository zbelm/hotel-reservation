import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../hotel.dart';
import '../i18n.dart';
import '../widgets.dart';

/// A summary of the booking and its payments that the guest can save or share as a PDF.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _Line {
  const _Line(this.label, this.amount);
  final String label;
  final num amount;
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Future<List<Map<String, dynamic>>> _payments = db
      .from('payments')
      .select('id, amount, method, provider, status, paid_at, created_at')
      .eq('booking_id', widget.booking['id'] as String)
      .order('created_at')
      .then((rows) => List<Map<String, dynamic>>.from(rows));

  Map<String, dynamic> get b => widget.booking;
  Map<String, dynamic>? get _br {
    final rooms = List<Map<String, dynamic>>.from(b['booking_rooms'] as List? ?? const []);
    return rooms.isNotEmpty ? rooms.first : null;
  }

  num _n(dynamic v) => num.tryParse('$v') ?? 0;

  List<_Line> get _nights => [
        for (final n in List<Map<String, dynamic>>.from(_br?['nightly_prices'] as List? ?? const []))
          _Line(niceDate(n['date'] as String, year: true), _n(n['price'])),
      ];

  String get _issued => longDate(DateTime.now().toIso8601String());

  String _paymentLabel(Map<String, dynamic> p) {
    final when = (p['paid_at'] ?? p['created_at']) as String?;
    final how = '${p['method'] ?? p['provider'] ?? ''}'.toUpperCase();
    return [if (when != null) longDate(when), if (how.isNotEmpty) how].join(' · ');
  }

  // ---- PDF ------------------------------------------------------------------
  // The built-in PDF font has no peso sign, so amounts read "PHP 3,800" in the file.

  String _pdfMoney(num n) => 'PHP ${NumberFormat('#,##0', 'en_US').format(n)}';

  Future<Uint8List> _pdf(PdfPageFormat format, List<Map<String, dynamic>> payments) async {
    final grey = PdfColor.fromInt(0xFF5E6B6A);
    pw.Widget row(String l, String r, {bool bold = false, double size = 11}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(l, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null))),
            pw.Text(r, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null)),
          ]),
        );
    pw.Widget label(String t) => pw.Text(t, style: pw.TextStyle(fontSize: 9, color: grey));

    final total = _n(b['total']), paid = _n(b['amount_paid']), refund = _n(b['refund_due']);
    final balance = total - paid;
    final doc = pw.Document(title: '${tr('Receipt', 'Resibo')} ${b['code']}', author: hotelName);
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(hotelName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(hotelAddress, style: pw.TextStyle(fontSize: 10, color: grey)),
              pw.Text('$hotelPhone · $hotelEmail', style: pw.TextStyle(fontSize: 10, color: grey)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(tr('Booking receipt', 'Resibo ng booking'), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('${tr('Issued', 'Petsa ng resibo')}: $_issued', style: pw.TextStyle(fontSize: 10, color: grey)),
          ]),
        ]),
        pw.Divider(color: PdfColors.grey400, height: 28),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label(tr('Guest', 'Bisita')),
              pw.Text('${b['guest_name']}'),
              pw.Text('${b['guest_email']}', style: pw.TextStyle(fontSize: 10, color: grey)),
              pw.SizedBox(height: 8),
              label(tr('Stay', 'Pananatili')),
              pw.Text('${niceDate(b['check_in'] as String, year: true)} ${tr('to', 'hanggang')} ${niceDate(b['check_out'] as String, year: true)}'),
              pw.Text('${nights(nightsBetween(b['check_in'] as String, b['check_out'] as String))}, ${guests(b['adults'] as int, b['children'] as int)}',
                  style: pw.TextStyle(fontSize: 10, color: grey)),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('Booking'),
              pw.Text('${b['code']}', style: pw.TextStyle(font: pw.Font.courier())),
              pw.SizedBox(height: 8),
              label('Rate'),
              pw.Text('${_br?['room_types']?['name'] ?? ''}, ${_br?['rate_plans']?['name'] ?? ''}'),
            ]),
          ),
        ]),
        pw.SizedBox(height: 16),
        row(tr('Night', 'Gabi'), tr('Amount', 'Halaga'), size: 9),
        pw.Divider(color: PdfColors.grey300, height: 4),
        for (final l in _nights) row(l.label, _pdfMoney(l.amount)),
        pw.Divider(color: PdfColors.grey700, height: 10),
        row(tr('Total', 'Kabuuan'), _pdfMoney(total), bold: true, size: 13),
        row(tr('Paid', 'Nabayaran'), _pdfMoney(paid)),
        if (refund > 0) row(tr('Refund due', 'Refund na matatanggap'), _pdfMoney(refund)),
        if (balance > 0 && b['status'] != 'cancelled') row(tr('Balance', 'Natitirang babayaran'), _pdfMoney(balance), bold: true),
        pw.SizedBox(height: 16),
        pw.Text(tr('Payments', 'Mga bayad'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (payments.isEmpty) pw.Text(tr('No payments yet.', 'Wala pang bayad.'), style: pw.TextStyle(color: grey)),
        for (final p in payments) row(_paymentLabel(p), _pdfMoney(_n(p['amount']))),
        pw.Divider(color: PdfColors.grey400, height: 28),
        pw.Text(tr('Prices include 12% VAT and service charge.', 'Kasama sa mga presyo ang 12% VAT at service charge.'),
            style: pw.TextStyle(fontSize: 9, color: grey)),
        pw.Text(
            tr("This is a summary of your booking and payments. It isn't a BIR official receipt; ask the front desk for one at check-out.",
                'Buod ito ng iyong booking at mga bayad. Hindi ito BIR official receipt; humingi nito sa front desk sa check-out.'),
            style: pw.TextStyle(fontSize: 9, color: grey)),
      ],
    ));
    return doc.save();
  }

  String get _fileName => 'Receipt-${b['code']}.pdf';

  Future<void> _save(List<Map<String, dynamic>> payments) async {
    await Printing.layoutPdf(name: _fileName, onLayout: (format) => _pdf(format, payments));
  }

  Future<void> _share(List<Map<String, dynamic>> payments) async {
    final bytes = await _pdf(PdfPageFormat.a4, payments);
    await Printing.sharePdf(bytes: bytes, filename: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final total = _n(b['total']), paid = _n(b['amount_paid']), refund = _n(b['refund_due']);
    final balance = total - paid;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Receipt', 'Resibo'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _payments,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Loading();
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: ErrorNote(errorText(snap.error!)));
          final payments = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hotelName, style: displayStyleSmall(context)),
                    Text(hotelAddress, style: TextStyle(color: muted, fontSize: 13)),
                    Text('${tr('Issued', 'Petsa ng resibo')}: $_issued', style: TextStyle(color: muted, fontSize: 13)),
                    const Divider(height: 24),
                    InfoRow(tr('Guest', 'Bisita'), '${b['guest_name']}'),
                    InfoRow('Booking', '${b['code']}'),
                    InfoRow(tr('Stay', 'Pananatili'),
                        '${niceDate(b['check_in'] as String, year: true)} – ${niceDate(b['check_out'] as String, year: true)}'),
                    InfoRow('Rate', '${_br?['room_types']?['name'] ?? ''}, ${_br?['rate_plans']?['name'] ?? ''}'),
                    const Divider(height: 24),
                    for (final l in _nights) InfoRow(l.label, money(l.amount)),
                    const Divider(height: 24),
                    InfoRow(tr('Total', 'Kabuuan'), money(total)),
                    InfoRow(tr('Paid', 'Nabayaran'), money(paid)),
                    if (refund > 0) InfoRow(tr('Refund due', 'Refund na matatanggap'), money(refund)),
                    if (balance > 0 && b['status'] != 'cancelled') InfoRow(tr('Balance', 'Natitirang babayaran'), money(balance)),
                    const Divider(height: 24),
                    Text(tr('Payments', 'Mga bayad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (payments.isEmpty) Text(tr('No payments yet.', 'Wala pang bayad.'), style: TextStyle(color: muted)),
                    for (final p in payments) InfoRow(_paymentLabel(p), money(p['amount'])),
                    const SizedBox(height: 12),
                    Text(tr('Prices include 12% VAT and service charge.', 'Kasama sa mga presyo ang 12% VAT at service charge.'),
                        style: TextStyle(color: muted, fontSize: 12)),
                    Text(
                        tr("This is a summary of your booking and payments. It isn't a BIR official receipt; ask the front desk for one at check-out.",
                            'Buod ito ng iyong booking at mga bayad. Hindi ito BIR official receipt; humingi nito sa front desk sa check-out.'),
                        style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _save(payments),
                icon: const Icon(Icons.download_outlined),
                label: Text(tr('Save or print as PDF', 'I-save o i-print bilang PDF')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _share(payments),
                icon: const Icon(Icons.share_outlined),
                label: Text(tr('Share the PDF', 'Ibahagi ang PDF')),
              ),
            ],
          );
        },
      ),
    );
  }
}

TextStyle displayStyleSmall(BuildContext context) =>
    TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface);
