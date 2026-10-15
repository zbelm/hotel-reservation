import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'i18n.dart';
import 'screens/bookings_screen.dart';
import 'screens/hotel_screen.dart';
import 'screens/login_screen.dart';
import 'screens/password_screen.dart';
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

// Lets AuthGate open screens and show messages from auth events, outside any widget's context
final _navigator = GlobalKey<NavigatorState>();
final _messenger = GlobalKey<ScaffoldMessengerState>();

class HotelApp extends StatelessWidget {
  const HotelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Switching language rebuilds the screens in the new language
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => MaterialApp(
        title: hotelName,
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: AuthGate(key: ValueKey(lang)),
      ),
    );
  }
}

/// Shows sign-in until there is a session, then the app. Also reacts to email links:
/// a password-reset link opens the new-password screen, and a broken or expired link
/// shows a message instead of silently leaving the guest on the sign-in screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = Supabase.instance.client.auth;
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {}); // signed in or out: rebuild to show the right screen
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _navigator.currentState?.push(MaterialPageRoute(builder: (_) => const PasswordScreen(reset: true)));
        }
      },
      onError: (Object e) => _messenger.currentState?.showSnackBar(SnackBar(
        content: Text(tr('That sign-in link has expired or was already used. Please request a new one.',
            'Expired na o nagamit na ang sign-in link na iyon. Humingi ng bago.')),
      )),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _auth.currentSession == null ? const LoginScreen() : const HomeShell();
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
  int _staysOpened = 0; // reload My stays each time it's opened, not on every tab change

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const SearchScreen(),
          const HotelScreen(),
          BookingsScreen(key: ValueKey('bookings-$_staysOpened')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          if (i == 2 && _tab != 2) _staysOpened++;
          _tab = _savedTab = i;
        }),
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
