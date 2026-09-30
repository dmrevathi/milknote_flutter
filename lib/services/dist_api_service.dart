import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same folder as the existing index.php.
const String _distUrl =
    'https://www.bluebro7.com/api/milknote/v1/index-milk-dist.php';

const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.milknote.app';

// ── Small helpers ────────────────────────────────────────

String errMsg(Object e) => e.toString().replaceFirst('Exception: ', '');

/// PHP may send numbers as int, double or string depending on the server
/// version, so always parse defensively.
int toInt(dynamic v) =>
    v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

double toD(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

/// 20.0 -> "20", 1.50 -> "1.5", 0.25 -> "0.25"
String fmtNum(num n) => n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String ym(DateTime d) => DateFormat('yyyy-MM').format(d);

// ── API ──────────────────────────────────────────────────

class DistApi {
  static Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse(_distUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic>? data;
    try {
      final d = jsonDecode(response.body);
      if (d is Map<String, dynamic>) data = d;
    } catch (_) {}

    // The server sends a readable message in "error" (also for 401 / 500).
    if (data != null && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    if (response.statusCode != 200 || data == null) {
      throw Exception('Server error: ${response.statusCode}');
    }
    return data;
  }

  // Distributor: customers
  static Future<Map<String, dynamic>> addConsumer({
    required String name,
    required String phone,
    required String password,
    required String address,
    required double price,
    String? effectiveFrom,
  }) =>
      _post({
        'action': 'add_consumer',
        'name': name,
        'phone': phone,
        'password': password,
        'address': address,
        'price': price,
        if (effectiveFrom != null) 'effective_from': effectiveFrom,
      });

  static Future<List<Map<String, dynamic>>> customerList() async {
    final res = await _post({'action': 'customer_list'});
    return (res['customers'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> updateCustomer(int customerId, String address) =>
      _post({
        'action': 'update_customer',
        'customer_id': customerId,
        'address': address,
      });

  static Future<void> removeCustomer(int customerId) =>
      _post({'action': 'remove_customer', 'customer_id': customerId});

  static Future<void> resetPassword(int customerId, String password) => _post({
        'action': 'reset_password',
        'customer_id': customerId,
        'password': password,
      });

  // Distributor: daily entry
  static Future<List<Map<String, dynamic>>> dailySheet(String date) async {
    final res = await _post({'action': 'daily_sheet', 'date': date});
    return (res['customers'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Pass only the value(s) you want to change; null is left untouched.
  static Future<void> saveEntry({
    required int customerId,
    required String date,
    double? morning,
    double? evening,
  }) =>
      _post({
        'action': 'save_entry',
        'customer_id': customerId,
        'date': date,
        if (morning != null) 'morning_qty': morning,
        if (evening != null) 'evening_qty': evening,
      });

  // Distributor: price and payments
  static Future<void> setPrice(
          int customerId, String effectiveFrom, double price) =>
      _post({
        'action': 'set_price',
        'customer_id': customerId,
        'effective_from': effectiveFrom,
        'price': price,
      });

  static Future<void> addPayment({
    required int customerId,
    required double amount,
    required String date,
    required String forMonth,
  }) =>
      _post({
        'action': 'add_payment',
        'customer_id': customerId,
        'amount': amount,
        'date': date,
        'for_month': forMonth,
      });

  static Future<void> deletePayment(int paymentId) =>
      _post({'action': 'delete_payment', 'payment_id': paymentId});

  // Distributor + consumer: read
  static Future<Map<String, dynamic>> monthCard(int customerId, String month) =>
      _post({
        'action': 'month_card',
        'customer_id': customerId,
        'month': month,
      });

  static Future<Map<String, dynamic>> paymentStatus(String month) =>
      _post({'action': 'payment_status', 'month': month});
}
