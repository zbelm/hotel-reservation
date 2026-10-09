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
  final _password = TextEditingController();
  bool _useLink = false;
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  String _explain(Object e) {
    final msg = errorText(e);
    if (RegExp('invalid login credentials', caseSensitive: false).hasMatch(msg)) {
      return tr("Wrong email or password. If you haven't set a password yet, use the email link once, then set one in My stays.",
          'Mali ang email o password. Kung wala ka pang password, gamitin muna ang email link, saka maglagay ng password sa Mga booking ko.');
    }
    if (RegExp('rate limit|too many', caseSensitive: false).hasMatch(msg)) {
      return tr('Too many sign-in emails were sent in the last hour. Sign in with your password, or try the email link again in about an hour.',
          'Masyadong maraming sign-in email ngayong oras. Mag-sign in gamit ang password, o subukan ulit ang email link pagkalipas ng mga isang oras.');
    }
    return msg;
  }

  Future<void> _signInWithPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = tr('Enter your email and password', 'Ilagay ang email at password mo'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success AuthGate sees the new session and shows the app
      await db.auth.signInWithPassword(email: email, password: _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = _explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switch(bool useLink) => setState(() {
        _useLink = useLink;
        _sent = false;
        _code.clear();
        _error = null;
      });

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
      setState(() => _error = _explain(e));
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
      if (mounted) setState(() => _error = _explain(e));
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
            Text(
                _useLink
                    ? tr("We'll email you a link that signs you in. After that, set a password in My stays so you don't need emails again.",
                        'Magpapadala kami ng link na magsa-sign in sa iyo. Pagkatapos, maglagay ng password sa Mga booking ko para hindi na kailangan ng email.')
                    : tr('Sign in with your email and password.', 'Mag-sign in gamit ang email at password mo.'),
                style: TextStyle(color: muted, fontSize: 16)),
            const SizedBox(height: 32),
            if (!_useLink) ...[
              AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _signInWithPassword(),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _busy ? null : _signInWithPassword,
                  child: Text(_busy ? tr('Signing in…', 'Sina-sign in…') : tr('Sign in', 'Mag-sign in'))),
              const SizedBox(height: 16),
              Text(tr('First time, or forgot your password?', 'Unang beses, o nakalimutan ang password?'), style: TextStyle(color: muted)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _switch(true),
                  child: Text(tr('Email me a sign-in link', 'Ipadala ang sign-in link sa email ko')),
                ),
              ),
            ] else if (!_sent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _sendCode, child: Text(_busy ? tr('Sending…', 'Ipinapadala…') : tr('Email me a sign-in link', 'Ipadala ang sign-in link'))),
              TextButton(
                onPressed: () => _switch(false),
                child: Text(tr('Sign in with a password instead', 'Mag-sign in gamit ang password')),
              ),
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
