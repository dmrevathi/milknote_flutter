import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';
import 'dist_widgets.dart';

/// Distributor: add a milk consumer (no OTP) and share the login details.
class DistAddCustomerScreen extends StatefulWidget {
  const DistAddCustomerScreen({super.key});

  @override
  State<DistAddCustomerScreen> createState() => _DistAddCustomerScreenState();
}

class _DistAddCustomerScreenState extends State<DistAddCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  final _password = TextEditingController(text: randomPassword());
  DateTime _from = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _price.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? kRed : kGreen),
    );
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final price = double.tryParse(_price.text.trim());
    final password = _password.text.trim();

    if (name.isEmpty) return _snack('Enter customer name', error: true);
    if (phone.length != 10) {
      return _snack('Phone number must be 10 digits', error: true);
    }
    if (price == null || price <= 0) {
      return _snack('Enter price per litre', error: true);
    }
    if (password.length < 4) {
      return _snack('Password must be at least 4 characters', error: true);
    }

    setState(() => _saving = true);
    try {
      final res = await DistApi.addConsumer(
        name: name,
        phone: phone,
        password: password,
        address: _address.text.trim(),
        price: price,
        effectiveFrom: ymd(_from),
      );
      if (!mounted) return;
      final isNew = res['new_account'] == true;

      if (isNew) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Customer added'),
            content: Text('Send the login details to $name on WhatsApp?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Later',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  shareInvite(name: name, phone: phone, password: password);
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );
      } else {
        _snack('Customer added. This phone already had an account, '
            'so the old password is unchanged.');
      }
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(errMsg(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('Name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Customer name'),
            ),
            const SizedBox(height: 14),
            _label('Phone number'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  hintText: '10 digit number', counterText: ''),
            ),
            const SizedBox(height: 14),
            _label('Address (விலாசம்)'),
            TextField(
              controller: _address,
              maxLines: 2,
              maxLength: 255,
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 14),
            _label('Price per litre (₹)'),
            TextField(
              controller: _price,
              keyboardType: kDecimalKeyboard,
              inputFormatters: kDecimalFormatters,
              decoration: const InputDecoration(hintText: 'e.g. 20'),
            ),
            const SizedBox(height: 14),
            _label('Price applies from'),
            InkWell(
              onTap: _pickFrom,
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Text(DateFormat('dd MMM yyyy').format(_from)),
              ),
            ),
            const SizedBox(height: 14),
            _label('Password for the customer'),
            TextField(
              controller: _password,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 6),
            const Text(
              'The customer logs in with their phone number and this password '
              'to see their milk card. No OTP is needed.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _saving
                ? const Center(child: CircularProgressIndicator(color: kGreen))
                : ElevatedButton(
                    onPressed: _submit, child: const Text('Add customer')),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black54)),
      );
}
