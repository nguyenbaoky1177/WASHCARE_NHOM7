import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final instance = AppSettings._();
  static const _darkKey = 'washcare_dark_mode';
  static const _languageKey = 'washcare_language';

  bool _dark = false;
  Locale _locale = const Locale('vi');

  bool get dark => _dark;
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool(_darkKey) ?? false;
    _locale = Locale(prefs.getString(_languageKey) == 'en' ? 'en' : 'vi');
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    _dark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, value);
  }

  Future<void> setLanguage(String code) async {
    _locale = Locale(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  static String text(BuildContext context, String vi, String en) {
    return Localizations.localeOf(context).languageCode == 'en' ? en : vi;
  }
}
