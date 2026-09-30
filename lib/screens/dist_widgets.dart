import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';

/// Random 4 digit password suggestion for a new customer.
String randomPassword() => (1000 + Random().nextInt(9000)).toString();

const TextInputType kDecimalKeyboard =
    TextInputType.numberWithOptions(decimal: true);

final List<TextInputFormatter> kDecimalFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

/// "<  September 2026  >"  (month is "yyyy-MM")
class MonthSwitcher extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;

  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  String _shift(int delta) {
    final p = month.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]) + delta, 1);
    return DateFormat('yyyy-MM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(_shift(-1)),
          ),
          Expanded(
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(_shift(1)),
          ),
        ],
      ),
    );
  }
}

/// Opens a share sheet (pick WhatsApp) with the customer's login details.
Future<void> shareInvite({
  required String name,
  required String phone,
  String? password, // null => account not created by us: no password line
}) async {
  final prefs = await SharedPreferences.getInstance();
  final dist = prefs.getString('milk_person_name') ?? '';
  final who = dist.isEmpty ? '' : ' $dist,';
  final msg = 'வணக்கம் $name,\n'
      'நான்$who உங்கள் பால் விநியோகஸ்தர். '
      'Milk Note ஆப்-ல் உங்கள் பால் கணக்கைப் பார்க்கலாம்.\n\n'
      '📱 Phone: $phone\n'
      '${password == null ? '🔑 உங்கள் ஏற்கனவே உள்ள password-ஐ பயன்படுத்தவும்' : '🔑 Password: $password'}\n\n'
      '👉 Download: $kPlayStoreUrl';
  await Share.share(msg, subject: 'Milk Note login');
}

/// Change price for one customer from a chosen date onwards.
/// Returns true if the price was saved.
Future<bool> showPriceDialog(
  BuildContext context,
  int customerId, {
  double? currentPrice,
}) async {
  final priceCtrl = TextEditingController(
      text: currentPrice == null ? '' : fmtNum(currentPrice));
  DateTime date = DateTime.now();
  String? err;
  bool saving = false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Change price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: kDecimalKeyboard,
              inputFormatters: kDecimalFormatters,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'New price per litre (₹)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setS(() => date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Applies from'),
                child: Text(DateFormat('dd MMM yyyy').format(date)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Earlier dates keep their old price.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: kRed, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    final price = double.tryParse(priceCtrl.text.trim());
                    if (price == null || price <= 0) {
                      setS(() => err = 'Enter a valid price');
                      return;
                    }
                    setS(() {
                      saving = true;
                      err = null;
                    });
                    try {
                      await DistApi.setPrice(customerId, ymd(date), price);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setS(() {
                        saving = false;
                        err = errMsg(e);
                      });
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
