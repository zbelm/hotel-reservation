import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../i18n.dart';
import '../theme.dart';

/// Lets a signed-in guest or staff member choose a password, so later sign-ins need no email.
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = tr('Use at least 8 characters.', 'Gumamit ng hindi bababa sa 8 character.'));
      return;
    }
    if (_password.text != _again.text) {
      setState(() => _error = tr("The two passwords don't match.", 'Hindi magkapareho ang dalawang password.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) setState(() => _saved = true);
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
      appBar: AppBar(title: Text(tr('Your password', 'Ang password mo'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            tr('Set a password so you can sign in with it next time, without waiting for an email.',
                'Maglagay ng password para makapag-sign in ka gamit ito sa susunod, nang hindi na naghihintay ng email.'),
            style: TextStyle(color: muted, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(db.auth.currentUser?.email ?? '', style: TextStyle(color: muted)),
          const SizedBox(height: 24),
          if (_saved) ...[
            Text(
              tr('Password saved. Next time, sign in with your email and this password.',
                  'Na-save ang password. Sa susunod, mag-sign in gamit ang email mo at ang password na ito.'),
              style: const TextStyle(color: Palette.good, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Done', 'Tapos na'))),
          ] else ...[
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('New password', 'Bagong password'),
                helperText: tr('At least 8 characters.', 'Hindi bababa sa 8 character.'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _again,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: tr('Type it again', 'Ilagay ulit')),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? tr('Saving…', 'Sine-save…') : tr('Save password', 'I-save ang password')),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Palette.bad)),
          ],
        ],
      ),
    );
  }
}
