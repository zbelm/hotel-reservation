import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'i18n.dart';
import 'screens/bookings_screen.dart';
import 'screens/hotel_screen.dart';
import 'screens/login_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // English and Filipino dates
  await loadLang();
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfig());
    return;
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const HotelApp());
}

class HotelApp extends StatelessWidget {
  const HotelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Switching language rebuilds the screens in the new language
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => MaterialApp(
        title: hotelName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: AuthGate(key: ValueKey(lang)),
      ),
    );
  }
}

/// Shows sign-in until there is a session, then the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) => auth.currentSession == null ? const LoginScreen() : const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

// Kept outside the widget so switching language stays on the same tab
int _savedTab = 0;

class _HomeShellState extends State<HomeShell> {
  int _tab = _savedTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const SearchScreen(),
          const HotelScreen(),
          BookingsScreen(key: ValueKey('bookings-$_tab')), // reloads when opened
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = _savedTab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search), label: tr('Book', 'Mag-book')),
          NavigationDestination(
              icon: const Icon(Icons.apartment_outlined), selectedIcon: const Icon(Icons.apartment), label: tr('Hotel', 'Hotel')),
          NavigationDestination(
              icon: const Icon(Icons.luggage_outlined), selectedIcon: const Icon(Icons.luggage), label: tr('My stays', 'Mga booking ko')),
        ],
      ),
    );
  }
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Missing Supabase settings.\n\nRun the app with:\n'
              'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
