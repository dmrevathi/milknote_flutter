import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

const List<Map<String, String>> kLanguages = [
  {'code': 'en', 'label': 'English'},
  {'code': 'ta', 'label': 'தமிழ்'},
  {'code': 'hi', 'label': 'हिन्दी'},
  {'code': 'ml', 'label': 'മലയാളം'},
  {'code': 'kn', 'label': 'ಕನ್ನಡ'},
  {'code': 'te', 'label': 'తెలుగు'},
  {'code': 'gu', 'label': 'ગુજરાતી'},
  {'code': 'bn', 'label': 'বাংলা'},
  {'code': 'mr', 'label': 'मराठी'},
];

class LangProvider extends ChangeNotifier {
  String _lang = 'ta';
  Map<String, dynamic> _t = {};

  String get lang => _lang;
  Map<String, dynamic> get t => _t;

  LangProvider() {
    _load('ta');
  }

  Future<void> setLanguage(String code) async {
    await _load(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }

  Future<void> _load(String code) async {
    try {
      final data = await rootBundle.loadString('assets/translations/$code.json');
      _t = jsonDecode(data);
      _lang = code;
      notifyListeners();
    } catch (_) {}
  }

  String tr(String section, String key) {
    return _t[section]?[key]?.toString() ?? key;
  }
}
