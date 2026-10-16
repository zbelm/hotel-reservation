import 'dart:async';
import 'dart:convert';

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
bool _passwordOffered = false;
StreamSubscription<AuthState>? _authLinks;

/// Reacts to email links once for the whole app: a password-reset link opens the
/// new-password screen, and a broken or expired link shows a message. Started once
/// from main() so rebuilding the app (for example on a language switch) can't replay it.
void listenForAuthLinks() {
  _authLinks ??= Supabase.instance.client.auth.onAuthStateChange.listen(
    (state) {
      if (state.event == AuthChangeEvent.passwordRecovery) _openReset();
      if (state.event == AuthChangeEvent.signedIn && state.session != null && needsPassword(state.session!)) _offerPassword();
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

/// True when this session came from an email link or code and the account has never saved a
/// password, so the guest would need another email to sign in next time.
bool needsPassword(Session session) {
  if (session.user.userMetadata?['has_password'] == true) return false;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(session.accessToken.split('.')[1]))));
    final amr = (payload['amr'] as List?) ?? const [];
    return amr.any((a) => const ['otp', 'magiclink', 'email/signup', 'invite'].contains((a as Map)['method']));
  } catch (_) {
    return false;
  }
}

// Signed in from an email with no password yet: offer one right away, once per app run,
// so the next sign-in is just email and password instead of another email
void _offerPassword() {
  if (_passwordOffered || _resetOpen) return;
  final nav = appNavigator.currentState;
  if (nav == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerPassword());
    return;
  }
  _passwordOffered = true;
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
