import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../auth.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Mode { signIn, signUp, forgot, link }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _showPassword = false;
  bool _byCode = false; // passwordless sign-in: email a 6-digit code instead of a link
  bool _codeOpen = false; // chose a link, but typing the code from the same email
  String? _sent; // the confirmation message once an email has gone out
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
    bool has(String pattern) => RegExp(pattern, caseSensitive: false).hasMatch(msg);
    if (has('invalid login credentials')) {
      return tr('Wrong email or password. If you used to sign in with an email link, you may not have a password yet: tap "Email me a link or code" below.',
          'Mali ang email o password. Kung email link ang gamit mo dati, baka wala ka pang password: pindutin ang "Ipadala ang link o code" sa ibaba.');
    }
    if (has('email not confirmed')) {
      return tr('Please confirm your email first. Check your inbox for the link we sent.',
          'Kumpirmahin muna ang email mo. Tingnan sa inbox ang link na ipinadala namin.');
    }
    if (has('already registered|already exists')) return _existsText;
    if (has('rate limit|too many')) {
      return tr('Too many emails were sent in the last hour. Please try again later, or sign in with your password.',
          'Masyadong maraming email ang naipadala ngayong oras. Subukan ulit mamaya, o mag-sign in gamit ang password.');
    }
    if (has('only request this after|security purposes')) {
      return tr('Please wait a minute before asking for another email.',
          'Maghintay muna ng isang minuto bago humingi ng panibagong email.');
    }
    if (has('token has expired|otp_expired')) {
      return tr('That code is wrong or has expired. Check the newest email, or send a new code.',
          'Mali o expired na ang code na iyon. Tingnan ang pinakabagong email, o magpadala ng bagong code.');
    }
    return msg;
  }

  String get _existsText => tr('An account with this email already exists. Sign in instead, or reset your password.',
      'May account na ang email na ito. Mag-sign in na lang, o i-reset ang password.');

  void _switch(_Mode mode) => setState(() {
        _mode = mode;
        _sent = null;
        _codeOpen = false;
        _code.clear();
        _password.clear();
        _error = null;
      });

  /// Checks the email (and password when needed), then runs one auth call with shared busy/error handling.
  Future<void> _run(Future<void> Function(String email) action, {bool needsPassword = false, bool newPassword = false}) async {
    if (_busy) return;
    final email = _email.text.trim();
    String? problem = emailProblem(email);
    if (problem == null && needsPassword && _password.text.isEmpty) {
      problem = tr('Enter your password', 'Ilagay ang password mo');
    } else if (problem == null && newPassword) {
      problem = newPasswordProblem(_password.text);
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(email);
    } catch (e) {
      if (mounted) setState(() => _error = _explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // On success AuthGate sees the new session and shows the app
  Future<void> _signIn() => _run((email) => db.auth.signInWithPassword(email: email, password: _password.text), needsPassword: true);

  Future<void> _signUp() => _run((email) async {
        // They chose a password here, so no "set a password" offer after confirming
        final res = await db.auth.signUp(
            email: email, password: _password.text, emailRedirectTo: authRedirect, data: {'has_password': true});
        // Supabase hides existing accounts by returning a user with no identities
        if (res.user != null && (res.user!.identities?.isEmpty ?? false)) throw AuthException(_existsText);
        if (res.session == null && mounted) {
          setState(() => _sent = tr(
              'Almost done. We sent a confirmation email to $email. Open the link on this phone, or type the 6-digit code from it here.',
              'Malapit na. Nagpadala kami ng confirmation email sa $email. Buksan ang link sa teleponong ito, o i-type dito ang 6-digit na code mula rito.'));
        }
      }, newPassword: true);

  Future<void> _sendReset() => _run((email) async {
        await db.auth.resetPasswordForEmail(email, redirectTo: authRedirect);
        if (mounted) {
          setState(() => _sent = tr(
              'If $email has an account, a reset link is on its way. Open it on this phone to choose a new password.',
              'Kung may account ang $email, papunta na ang reset link. Buksan ito sa teleponong ito para pumili ng bagong password.'));
        }
      });

  Future<void> _sendLink() => _run((email) async {
        await db.auth.signInWithOtp(email: email, emailRedirectTo: authRedirect);
        if (!mounted) return;
        _code.clear();
        setState(() => _sent = _byCode
            ? tr('We sent a 6-digit code to $email. Type it below to sign in.',
                'Nagpadala kami ng 6-digit na code sa $email. I-type ito sa ibaba para mag-sign in.')
            : tr('Open the email we sent to $email on this phone and tap the sign-in link. The app opens and signs you in.',
                'Buksan sa teleponong ito ang email na ipinadala namin sa $email at pindutin ang sign-in link. Magbubukas ang app at masa-sign in ka.'));
      });

  Future<void> _resendConfirmation() => _run((email) async {
        await db.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: authRedirect);
        if (!mounted) return;
        _code.clear();
        setState(() => _sent = tr('We sent a new confirmation email to $email. Open the link on this phone, or type the 6-digit code from it here.',
            'Nagpadala kami ng bagong confirmation email sa $email. Buksan ang link sa teleponong ito, o i-type dito ang 6-digit na code mula rito.'));
      });

  Future<void> _verify() =>
      _run((email) => db.auth.verifyOTP(type: OtpType.email, email: email, token: _code.text.trim()));

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (title, intro) = switch (_mode) {
      _Mode.signIn => (tr('Sign in to book\nyour stay', 'Mag-sign in para\nmag-book'),
          tr('Welcome back. Sign in to book and manage your stays.', 'Maligayang pagbabalik. Mag-sign in para mag-book at makita ang mga booking mo.')),
      _Mode.signUp => (tr('Create your\naccount', 'Gumawa ng\naccount'),
          tr('Book faster and see all your stays in one place.', 'Mas mabilis mag-book at makikita mo ang lahat ng booking mo sa isang lugar.')),
      _Mode.forgot => (tr('Reset your\npassword', 'I-reset ang\npassword'),
          tr("Enter your email and we'll send you a link to choose a new password.",
              'Ilagay ang email mo at magpapadala kami ng link para pumili ng bagong password.')),
      _Mode.link => (tr('Sign in with\nyour email', 'Mag-sign in gamit\nang email'),
          tr("No password needed. Choose what we email you: a link to tap, or a 6-digit code to type here.",
              'Walang password na kailangan. Piliin ang ipapadala namin: link na pipindutin, o 6-digit na code na ita-type dito.')),
    };

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
            Text(title, style: displayStyle(context, 36)),
            const SizedBox(height: 12),
            Text(intro, style: TextStyle(color: muted, fontSize: 16)),
            const SizedBox(height: 24),
            if (_mode == _Mode.signIn || _mode == _Mode.signUp) ...[
              SegmentedButton<_Mode>(
                segments: [
                  ButtonSegment(value: _Mode.signIn, label: Text(tr('Sign in', 'Mag-sign in'))),
                  ButtonSegment(value: _Mode.signUp, label: Text(tr('Create account', 'Gumawa ng account'))),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _switch(s.first),
              ),
              const SizedBox(height: 24),
            ],
            if (_sent != null) ..._sentView(muted) else ..._form(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: tones(context).bad)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: switch (_mode) {
                _Mode.forgot || _Mode.link =>
                  TextButton(onPressed: () => _switch(_Mode.signIn), child: Text(tr('Back to sign in', 'Bumalik sa sign in'))),
                _Mode.signUp => TextButton(
                    onPressed: () => _switch(_Mode.link),
                    child: Text(tr('Sign in with an email link or code instead', 'Mag-sign in na lang gamit ang email link o code'))),
                _Mode.signIn => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emailField({required VoidCallback onSubmit, bool last = false}) => TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Email'),
        onSubmitted: last ? (_) => onSubmit() : null,
      );

  Widget _passwordField({required bool isNew, required VoidCallback onSubmit}) => TextField(
        controller: _password,
        obscureText: !_showPassword,
        autofillHints: [isNew ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: isNew ? tr('Choose a password', 'Pumili ng password') : 'Password',
          helperText: isNew ? newPasswordHint : null,
          suffixIcon: IconButton(
            tooltip: _showPassword ? tr('Hide password', 'Itago ang password') : tr('Show password', 'Ipakita ang password'),
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        onSubmitted: (_) => onSubmit(),
      );

  Widget _submit(String label, String busyLabel, VoidCallback onPressed) =>
      FilledButton(onPressed: _busy ? null : onPressed, child: Text(_busy ? busyLabel : label));

  List<Widget> _form() => switch (_mode) {
        _Mode.signIn => [
            AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _emailField(onSubmit: _signIn),
                const SizedBox(height: 16),
                _passwordField(isNew: false, onSubmit: _signIn),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => _switch(_Mode.forgot), child: Text(tr('Forgot password?', 'Nakalimutan ang password?'))),
            ),
            _submit(tr('Sign in', 'Mag-sign in'), tr('Signing in…', 'Sina-sign in…'), _signIn),
            const SizedBox(height: 12),
            // Accounts made with an email link have no password they know, so this sits right under Sign in
            OutlinedButton(
                onPressed: _busy ? null : () => _switch(_Mode.link), child: Text(tr('Email me a link or code', 'Ipadala ang link o code'))),
          ],
        _Mode.signUp => [
            AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _emailField(onSubmit: _signUp),
                const SizedBox(height: 16),
                _passwordField(isNew: true, onSubmit: _signUp),
              ]),
            ),
            const SizedBox(height: 24),
            _submit(tr('Create account', 'Gumawa ng account'), tr('Creating your account…', 'Ginagawa ang account mo…'), _signUp),
          ],
        _Mode.forgot => [
            _emailField(onSubmit: _sendReset, last: true),
            const SizedBox(height: 24),
            _submit(tr('Send reset link', 'Ipadala ang reset link'), tr('Sending…', 'Ipinapadala…'), _sendReset),
          ],
        _Mode.link => [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('Email link', 'Email link')), icon: const Icon(Icons.link)),
                ButtonSegment(value: true, label: Text(tr('6-digit code', '6-digit na code')), icon: const Icon(Icons.pin_outlined)),
              ],
              selected: {_byCode},
              onSelectionChanged: (s) => setState(() => _byCode = s.first),
            ),
            const SizedBox(height: 16),
            _emailField(onSubmit: _sendLink, last: true),
            const SizedBox(height: 24),
            _submit(_byCode ? tr('Email me a code', 'Ipadala ang code') : tr('Email me a sign-in link', 'Ipadala ang sign-in link'),
                tr('Sending…', 'Ipinapadala…'), _sendLink),
          ],
      };

  // A sign-in email or a sign-up confirmation: both carry a link and a 6-digit code
  bool get _emailed => _mode == _Mode.link || _mode == _Mode.signUp;
  // Only a sign-in where they picked "6-digit code" opens straight on the code box
  bool get _codeFirst => _mode == _Mode.link && _byCode;

  List<Widget> _sentView(Color muted) => [
        Text(_sent!, style: TextStyle(color: tones(context).good, fontSize: 16, fontWeight: FontWeight.w600)),
        if (_emailed && !_codeFirst && !_codeOpen)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _codeOpen = true),
              child: Text(tr('Typing a code instead? Enter it here', 'Code ang gagamitin? Ilagay ito rito')),
            ),
          ),
        if (_emailed && (_codeFirst || _codeOpen)) ...[
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(labelText: tr('6-digit code', '6-digit na code'), counterText: ''),
            // Submits once on the 6th digit; _run ignores repeats while busy
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: 16),
          _submit(tr('Sign in', 'Mag-sign in'), tr('Checking…', 'Sinusuri…'), _verify),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (_emailed)
            TextButton(
                onPressed: _busy ? null : (_mode == _Mode.signUp ? _resendConfirmation : _sendLink),
                child: Text(tr('Send a new email', 'Magpadala ulit'))),
          TextButton(
            onPressed: () => setState(() {
              _sent = null;
              _codeOpen = false;
              _code.clear();
              _password.clear();
              _error = null;
            }),
            child: Text(tr('Use a different email', 'Gumamit ng ibang email')),
          ),
        ]),
      ];
}
