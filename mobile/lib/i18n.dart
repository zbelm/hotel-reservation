import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's language: 'en' (English) or 'fil' (Filipino). Remembered between launches.
final appLang = ValueNotifier<String>('en');

bool get isFil => appLang.value == 'fil';

/// Picks the English or Filipino text, e.g. `tr('Book', 'Mag-book')`.
String tr(String en, String fil) => isFil ? fil : en;

const _key = 'lang';

Future<void> loadLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    appLang.value = prefs.getString(_key) == 'fil' ? 'fil' : 'en';
  } catch (_) {
    // Storage isn't available (e.g. in tests): stay in English
  }
}

Future<void> setLang(String lang) async {
  appLang.value = lang;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang);
  } catch (_) {}
}
