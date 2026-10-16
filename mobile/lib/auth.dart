import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n.dart';
import 'screens/password_screen.dart';

/// Shortest password Supabase Auth accepts for this project (Authentication → Policies).
const minPasswordLength = 8;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Returns what's wrong with [email], or null when it looks valid.
String? emailProblem(String email) =>
    _emailPattern.hasMatch(email.trim()) ? null : tr('Enter a valid email address', 'Maglagay ng tamang email address');

/// Returns what's wrong with a new [password] (and its repeat, when asked twice), or null.
String? newPasswordProblem(String password, {String? again}) {
  if (password.length < minPasswordLength) {
    return tr('Use at least $minPasswordLength characters.', 'Gumamit ng hindi bababa sa $minPasswordLength character.');
  }
  if (again != null && password != again) {
    return tr("The two passwords don't match.", 'Hindi magkapareho ang dalawang password.');
  }
  return null;
}

String get newPasswordHint => tr('At least $minPasswordLength characters.', 'Hindi bababa sa $minPasswordLength character.');

// Lets the auth listener open screens and show messages outside any widget's context
final appNavigator = GlobalKey<NavigatorState>();
final appMessenger = GlobalKey<ScaffoldMessengerState>();

// Errors Supabase reports for an email link that expired, was already used, or was opened elsewhere
final _linkError = RegExp(r'otp_expired|access_denied|flow_state|code verifier|expired|invalid.*(link|token)', caseSensitive: false);

bool _resetOpen = false;
/// The sign-in (user id and time) the password offer was last shown for
String? _offeredFor;
StreamSubscription<AuthState>? _authLinks;

/// Reacts to email links once for the whole app: a password-reset link opens the
/// new-password screen, and a broken or expired link shows a message. Started once
/// from main() so rebuilding the app (for example on a language switch) can't replay it.
void listenForAuthLinks() {
  _authLinks ??= Supabase.instance.client.auth.onAuthStateChange.listen(
    (state) {
      if (state.event == AuthChangeEvent.passwordRecovery) _openReset();
      if (state.event == AuthChangeEvent.signedIn && state.session != null) _maybeOfferPassword(state.session!);
      if (state.event == AuthChangeEvent.signedOut) _offeredFor = null;
    },
    onError: (Object e) {
      // Only email-link problems get a message; session refresh errors (offline, etc.) retry on their own
      final text = e is AuthException ? '${e.code ?? ''} ${e.message}' : '$e';
      if (!_linkError.hasMatch(text)) return;
      appMessenger.currentState?.showSnackBar(SnackBar(
        content: Text(tr('That email link has expired or was already used. Please request a new one.',
            'Expired na o nagamit na ang email link na iyon. Humingi ng bago.')),
      ));
    },
  );
}

const _emailMethods = {AMRMethod.otp, AMRMethod.magiclink, AMRMethod.emailSignUp, AMRMethod.invite};

/// Whether the signed-in account has a password saved. Accounts from before the has_password
/// flag existed may have one without the flag, so this asks the database when the flag is missing.
Future<bool> accountHasPassword() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  if (user.userMetadata?['has_password'] == true) return true;
  try {
    return await Supabase.instance.client.rpc('account_has_password') == true;
  } catch (_) {
    return false;
  }
}

// Signed in from an email with no password yet: offer one right away, so the next sign-in is
// just email and password instead of another email. Only a sign-in from the last two minutes
// counts, so a session restored when the app reopens doesn't bring the offer back.
Future<void> _maybeOfferPassword(Session session) async {
  final auth = Supabase.instance.client.auth;
  final signIn = auth.mfa
      .getAuthenticatorAssuranceLevel()
      .currentAuthenticationMethods
      .where((a) => _emailMethods.contains(a.method) && DateTime.now().difference(a.timestamp).inSeconds < 120)
      .firstOrNull;
  if (signIn == null) return;
  final key = '${session.user.id}:${signIn.timestamp.millisecondsSinceEpoch}';
  if (_offeredFor == key) return;
  _offeredFor = key;
  if (await accountHasPassword()) return;
  _offerPassword();
}

void _offerPassword() {
  if (_resetOpen) return;
  final nav = appNavigator.currentState;
  if (nav == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerPassword());
    return;
  }
  nav.push(MaterialPageRoute(builder: (_) => const PasswordScreen(offer: true)));
}

void _openReset() {
  if (_resetOpen) return;
  final nav = appNavigator.currentState;
  if (nav == null) {
    // The link arrived while the app was still starting: try again once the first frame is up
    WidgetsBinding.instance.addPostFrameCallback((_) => _openReset());
    return;
  }
  _resetOpen = true;
  nav.push(MaterialPageRoute(builder: (_) => const PasswordScreen(reset: true))).whenComplete(() => _resetOpen = false);
}
