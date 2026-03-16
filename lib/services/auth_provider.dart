import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? token;
  String? userId;
  String? roleId;
  bool isLoading = true;

  bool get isLoggedIn => token != null;
  bool get isMilkPerson => roleId == '2';
  bool get isCowPerson => roleId == '3';

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('current_user_id');
    roleId = prefs.getString('role_id');
    isLoading = false;
    notifyListeners();
  }

  Future<void> saveLogin(String t, String uid, String rid,
      {String name = '', String phone = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', t);
    await prefs.setString('current_user_id', uid);
    await prefs.setString('role_id', rid);
    if (name.isNotEmpty) await prefs.setString('milk_person_name', name);
    if (phone.isNotEmpty) await prefs.setString('milk_person_phone', phone);
    token = t;
    userId = uid;
    roleId = rid;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('current_user_id');
    await prefs.remove('role_id');
    token = null;
    userId = null;
    roleId = null;
    notifyListeners();
  }
}
