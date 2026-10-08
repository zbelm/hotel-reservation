import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = tr('Enter a valid email address', 'Maglagay ng tamang email address'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.auth.signInWithOtp(email: email, emailRedirectTo: authRedirect);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success AuthGate sees the new session and shows the app
      await db.auth.verifyOTP(type: OtpType.email, email: _email.text.trim(), token: _code.text.trim());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Align(alignment: Alignment.centerRight, child: LangButton()),
            const SizedBox(height: 24),
            Text(hotelName.toUpperCase(),
                style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            Text(tr('Sign in to book\nyour stay', 'Mag-sign in para\nmag-book'), style: displayStyle(context, 36)),
            const SizedBox(height: 12),
            Text(tr("No password needed. We'll email you a sign-in link.", 'Hindi kailangan ng password. Magpapadala kami ng sign-in link sa email mo.'),
                style: TextStyle(color: muted, fontSize: 16)),
            const SizedBox(height: 32),
            if (!_sent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _sendCode, child: Text(_busy ? tr('Sending…', 'Ipinapadala…') : tr('Email me a sign-in link', 'Ipadala ang sign-in link'))),
            ] else ...[
              Text(
                tr('Open the email we sent to ${_email.text.trim()} on this phone and tap the sign-in link. The app opens and signs you in.',
                    'Buksan sa teleponong ito ang email na ipinadala namin sa ${_email.text.trim()} at pindutin ang sign-in link. Magbubukas ang app at masa-sign in ka.'),
                style: TextStyle(color: muted, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(tr('If your email shows a 6-digit code instead, type it here:', 'Kung 6-digit na code ang nasa email, ilagay ito rito:'),
                  style: TextStyle(color: muted)),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
                decoration: InputDecoration(labelText: tr('6-digit code (optional)', '6-digit na code (opsyonal)'), counterText: ''),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _verify, child: Text(_busy ? tr('Checking…', 'Sinusuri…') : tr('Sign in', 'Mag-sign in'))),
              TextButton(
                onPressed: () => setState(() {
                  _sent = false;
                  _code.clear();
                }),
                child: Text(tr('Use a different email', 'Gumamit ng ibang email')),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Palette.bad)),
            ],
          ],
        ),
      ),
    );
  }
}
