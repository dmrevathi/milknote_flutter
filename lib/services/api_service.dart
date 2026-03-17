import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String _baseUrl = 'https://www.bluebro7.com/api/milknote/v1/index.php';

class ApiService {
  static Future<Map<String, dynamic>> post(
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    return data is Map<String, dynamic> ? data : {'data': data};
  }

  // ── Auth ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String phone, String password) =>
      post({
        'table_name': 'user',
        'action': 'login',
        'phone_number': phone,
        'password': password
      }, requiresAuth: false);

  static Future<Map<String, dynamic>> checkAccountExists(String phone) =>
      post({'action': 'is_acct_exists', 'phone': phone}, requiresAuth: false);

  static Future<Map<String, dynamic>> sendOtp(String phone) =>
      post({'action': 'send_otp', 'phone': phone}, requiresAuth: false);

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) =>
      post({'action': 'verify_otp', 'phone': phone, 'otp': otp},
          requiresAuth: false);

  static Future<Map<String, dynamic>> registerPerson(
          String phone, String name, String password, String role,
          {String msg91token = ''}) =>
      post({
        'action': 'add_person', // backend uses add_person action
        'phone': phone,
        'name': name,
        'password': password,
        'role': role,
        'msg91token': msg91token, // JWT access token verified by backend
      }, requiresAuth: false);

  // ── Cow Persons ──────────────────────────────────────
  static Future<dynamic> getCowPersonList(String milkPersonId) async {
    final res = await post(
        {'action': 'cow_person_list', 'milk_person_id': milkPersonId});
    return res['data'] ?? res;
  }

  static Future<dynamic> getMilkPersonList(String cowPersonId) async {
    final res = await post(
        {'action': 'milk_person_list', 'cow_person_id': cowPersonId});
    return res['data'] ?? res;
  }

  static Future<dynamic> searchCowPerson(String phone) async {
    final res = await post({
      'table_name': 'user',
      'action': 'list',
      'filters': {'phone_number': phone, 'role_id': '3'},
    });
    return res['data'] ?? res;
  }

  static Future<Map<String, dynamic>> registerCowPerson(
          String phone, String name, String password) =>
      post({
        'table_name': 'user',
        'action': 'create',
        'phone_number': phone,
        'name': name,
        'password': password,
        'note': password,
        'role_id': 3,
      });

  static Future<Map<String, dynamic>> connectCowPerson(
          String cowPersonId, String milkPersonId) =>
      post({
        'table_name': 'connection',
        'action': 'create',
        'cow_person_id': cowPersonId,
        'milk_person_id': milkPersonId,
      });

  // ── Milk Records ─────────────────────────────────────
  static Future<Map<String, dynamic>> addMilk(
          String connectionId, double quantity, String date) =>
      post({
        'table_name': 'milk',
        'action': 'create',
        'connection_id': connectionId,
        'quantity': quantity,
        'date': date
      });

  static Future<Map<String, dynamic>> getDailyMilk(
          String milkPersonId, String date) =>
      post({
        'table_name': 'milk',
        'action': 'daily_milk',
        'milk_person_id': milkPersonId,
        'date': date
      });

  static Future<Map<String, dynamic>> getMonthlyMilk(
          String connectionId, String month) =>
      post({
        'action': 'monthly_milk',
        'connection_id': connectionId,
        'month': month
      });

  static Future<Map<String, dynamic>> getFullReport(
          String milkPersonId, String fromDate, String toDate) =>
      post({
        'action': 'milk_report',
        'milk_person_id': milkPersonId,
        'from_date': fromDate,
        'to_date': toDate
      });

  static Future<Map<String, dynamic>> getMilkByDate(
          String connectionId, String date) =>
      post({
        'action': 'get_milk_by_date',
        'connection_id': connectionId,
        'date': date
      });

  static Future<Map<String, dynamic>> editMilk(String connectionId, String date,
          String updatedBy, List<Map<String, dynamic>> records) =>
      post({
        'action': 'edit_milk',
        'connection_id': connectionId,
        'date': date,
        'updated_by': updatedBy,
        'records': records
      });

  // ── Monthly Calc ─────────────────────────────────────
  static Future<Map<String, dynamic>> saveCalcReport(
          String userId, String name, String total, Map<String, dynamic> data,
          {String? reportId}) =>
      post({
        'table_name': 'tmp',
        'action': reportId != null ? 'update' : 'create',
        if (reportId != null) 'id': reportId,
        'user_id': userId,
        'name': name,
        'total': total,
        'data': jsonEncode({'total': total, 'days': data}),
      });

  static Future<Map<String, dynamic>> getCalcReportList(
          {int page = 1, int pageSize = 25}) =>
      post({
        'action': 'get_list_tmp_based_token',
        'page': page,
        'page_size': pageSize
      });

  static Future<Map<String, dynamic>> getCalcReport(String id) => post({
        'action': 'list',
        'table_name': 'tmp',
        'filters': {'id': id}
      });
}
