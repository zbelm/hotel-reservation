import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'booking_screen.dart';
import 'password_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookings = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = db.auth.currentUser!.id;
    final rows = await db
        .from('bookings')
        .select(bookingSelect)
        .eq('guest_id', uid)
        .neq('status', 'expired')
        .order('check_in', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _bookings = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('My stays', 'Mga booking ko')),
        actions: [
          const LangButton(),
          IconButton(
            tooltip: tr('Set a password', 'Maglagay ng password'),
            icon: const Icon(Icons.key_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PasswordScreen())),
          ),
          IconButton(
            tooltip: tr('Sign out', 'Mag-sign out'),
            icon: const Icon(Icons.logout),
            onPressed: () => db.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookings,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            if (snap.hasError) return ListView(padding: const EdgeInsets.all(16), children: [ErrorNote(errorText(snap.error!))]);
            final rows = snap.data!;
            if (rows.isEmpty) {
              return ListView(padding: const EdgeInsets.all(32), children: [
                Text(tr("You haven't booked a stay yet. Tap Book to find a room.",
                        'Wala ka pang booking. Pindutin ang Mag-book para maghanap ng kuwarto.'),
                    textAlign: TextAlign.center),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final b = rows[i];
                final rooms = List<Map<String, dynamic>>.from(b['booking_rooms'] as List? ?? const []);
                final roomName = rooms.isNotEmpty ? (rooms.first['room_types']?['name'] as String? ?? tr('Room', 'Kuwarto')) : tr('Room', 'Kuwarto');
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Text(roomName, style: displayStyle(context, 19)),
                    subtitle: Text(
                      '${niceDate(b['check_in'] as String, year: true)} · ${nights(nightsBetween(b['check_in'] as String, b['check_out'] as String))}\n${b['code']}',
                    ),
                    isThreeLine: true,
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(b['total']), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      StatusChip(b['status'] as String),
                    ]),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingScreen(bookingId: b['id'] as String)));
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
