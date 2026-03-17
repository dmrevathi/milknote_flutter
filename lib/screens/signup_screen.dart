import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../services/api_service.dart';
import '../services/lang_provider.dart';
import '../theme.dart';

const String _widgetId = '356a646b494a323330353630';
const String _tokenAuth = '465765TVlD3Bn4KCYv68a9416dP1';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 1;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = '';
  String _msg91AccessToken = '';
  Map<dynamic, dynamic> _sendOtpResponse = {};

  @override
  void initState() {
    super.initState();
    OTPWidget.initializeWidget(_widgetId, _tokenAuth);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: kRed));

  Future<void> _sendOtp() async {
    final t = context.read<LangProvider>().t;
    if (_nameCtrl.text.trim().isEmpty) {
      _showError(t['signup']?['nameLabel'] ?? 'Name required');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text)) {
      _showError(t['signup']?['phoneRequired'] ?? 'Enter valid 10-digit phone');
      return;
    }
    if (_role.isEmpty) {
      _showError(t['signup']?['roleLabel'] ?? 'Select role');
      return;
    }

    try {
      final res = await ApiService.checkAccountExists(_phoneCtrl.text);
      if (res['status'] == true) {
        _showError(t['signup']?['accountExists'] ??
            'Account already exists! Call 8825401886');
        return;
      }

      final response = await OTPWidget.sendOTP({
        'identifier': '91${_phoneCtrl.text}',
      });

      setState(() => _sendOtpResponse = response ?? {});

      if (response != null) {
        setState(() => _step = 2);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(t['signup']?['otpSent'] ?? 'OTP sent!'),
              backgroundColor: kGreen));
      } else {
        _showError(
            t['signup']?['otpFailed'] ?? 'OTP send failed! Call 8825401886');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    final t = context.read<LangProvider>().t;
    if (_otpCtrl.text.trim().isEmpty) {
      _showError(t['signup']?['enterOtp'] ?? 'Enter OTP');
      return;
    }

    final verifyParams = <String, dynamic>{
      'identifier': '91${_phoneCtrl.text}',
      'otp': _otpCtrl.text.trim(),
    };

    // Map 'message' from sendOTP response to 'reqId' for verifyOTP
    _sendOtpResponse.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        if (key.toString() == 'message') {
          verifyParams['reqId'] = value;
        } else {
          verifyParams[key.toString()] = value;
        }
      }
    });

    try {
      final response = await OTPWidget.verifyOTP(verifyParams);

      if (response != null && response['type'] == 'success') {
        _msg91AccessToken = response['message']?.toString() ?? '';
        setState(() => _step = 3);
      } else {
        _showError(t['signup']?['invalidOtp'] ?? 'Invalid OTP. Try again.');
      }
    } catch (e) {
      _showError(t['signup']?['verificationFailed'] ?? 'Verification failed');
    }
  }

  Future<void> _register() async {
    final t = context.read<LangProvider>().t;
    if (_passCtrl.text.length < 4) {
      _showError(t['signup']?['passwordTooShort'] ??
          'Password must be at least 4 characters');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showError(t['signup']?['passwordMismatch'] ?? 'Passwords do not match');
      return;
    }

    try {
      final res = await ApiService.registerPerson(
        _phoneCtrl.text,
        _nameCtrl.text.trim(),
        _passCtrl.text,
        _role,
        msg91token: _msg91AccessToken,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text(t['signup']?['successTitle'] ?? 'Success!'),
                  content: Text(t['signup']?['registrationSuccess'] ??
                      'Registered successfully! Please login.'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/login');
                        },
                        child: Text(t['signup']?['ok'] ?? 'OK'))
                  ],
                ));
      } else {
        _showError(res['message'] ??
            res['error'] ??
            t['signup']?['registrationFailed'] ??
            'Registration failed. Call 8825401886');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LangProvider>().t;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(t['signup']?['title'] ?? 'Signup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 1; i <= 3; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _step >= i ? kGreen : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (i < 3) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 24),

            // Step 1 — Name, Phone, Role
            if (_step == 1) ...[
              _label(t['signup']?['nameLabel'] ?? 'Name'),
              TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                      hintText: t['signup']?['nameLabel'] ?? 'Name & Village')),
              const SizedBox(height: 14),
              _label(t['signup']?['phoneLabel'] ?? 'Phone'),
              TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                      hintText: '10-digit number', counterText: '')),
              const SizedBox(height: 14),
              _label(t['signup']?['roleLabel'] ?? 'Who are you?'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _role.isEmpty ? null : _role,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(t['signup']?['rolePlaceholder'] ?? '-- Select --'),
                  items: [
                    DropdownMenuItem(
                        value: '2',
                        child:
                            Text(t['signup']?['roleMilkman'] ?? 'Milk Person')),
                    DropdownMenuItem(
                        value: '3',
                        child:
                            Text(t['signup']?['roleCowman'] ?? 'Cow Person')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? ''),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _sendOtp,
                  child: Text(t['signup']?['otpButton'] ?? 'Send OTP')),
            ],

            // Step 2 — OTP
            if (_step == 2) ...[
              Text('+91${_phoneCtrl.text} க்கு OTP அனுப்பப்பட்டது',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: kGreen, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _label(t['signup']?['otpPlaceholder'] ?? 'Enter OTP'),
              TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                      hintText: '6-digit OTP', counterText: '')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _verifyOtp,
                  child: Text(t['signup']?['verifyButton'] ?? 'Verify OTP')),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('← Back')),
                TextButton(
                    onPressed: _sendOtp,
                    child: Text(t['signup']?['otpButton'] ?? 'Resend OTP')),
              ]),
            ],

            // Step 3 — Password
            if (_step == 3) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: kLightGreen,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_nameCtrl.text} (+91${_phoneCtrl.text}) ✅ Verified',
                  style: const TextStyle(
                      color: kGreen, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              _label(t['signup']?['passwordPlaceholder'] ?? 'Password'),
              TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      hintText: t['signup']?['passwordPlaceholder'] ??
                          'Min 4 characters')),
              const SizedBox(height: 14),
              _label(t['signup']?['confirmPasswordPlaceholder'] ??
                  'Confirm Password'),
              TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      hintText: t['signup']?['confirmPasswordPlaceholder'] ??
                          'Repeat password')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _register,
                  child: Text(t['signup']?['registerButton'] ?? 'Register')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black54)));
}
