import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../services/api_service.dart';
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
  String _debugLog = '';
  Map<dynamic, dynamic> _sendOtpResponse = {}; // store full sendOTP response

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
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Name required');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text)) {
      _showError('Enter valid 10-digit phone');
      return;
    }
    if (_role.isEmpty) {
      _showError('Select role');
      return;
    }

    setState(() {
      _debugLog = 'Sending OTP...';
    });
    try {
      final res = await ApiService.checkAccountExists(_phoneCtrl.text);
      if (res['status'] == true) {
        _showError('Account already exists! Call 8825401886');
        return;
      }

      final response = await OTPWidget.sendOTP({
        'identifier': '91${_phoneCtrl.text}',
      });

      debugPrint('sendOTP full response: $response');
      setState(() {
        _sendOtpResponse = response ?? {};
        _debugLog = 'sendOTP: $response';
      });

      if (response != null) {
        setState(() => _step = 2);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('OTP sent! ✅'), backgroundColor: kGreen));
      } else {
        _showError('OTP send failed! Call 8825401886');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) {
      _showError('Enter OTP');
      return;
    }

    // Build verifyOTP params - pass ALL keys from sendOTP response
    final verifyParams = <String, dynamic>{
      'identifier': '91${_phoneCtrl.text}',
      'otp': _otpCtrl.text.trim(),
    };

    // Add all keys from sendOTP response to verifyOTP
    _sendOtpResponse.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        if (key.toString() == 'message') {
          verifyParams['reqId'] = value;
        } else {
          verifyParams[key.toString()] = value;
        }
      }
    });

    debugPrint('verifyOTP params: $verifyParams');
    setState(() => _debugLog = 'verifyOTP params: $verifyParams');

    try {
      final response = await OTPWidget.verifyOTP(verifyParams);

      debugPrint('verifyOTP response: $response');
      setState(() => _debugLog = 'verifyOTP: $response');

      if (response != null && response['type'] == 'success') {
        _msg91AccessToken = response['message']?.toString() ?? '';
        setState(() => _step = 3);
      } else {
        final errMsg = response?['message']?.toString() ?? 'Unknown error';
        _showError('Invalid OTP: $errMsg');
      }
    } catch (e) {
      debugPrint('verifyOTP error: $e');
      _showError('Verification failed: $e');
    }
  }

  Future<void> _register() async {
    if (_passCtrl.text.length < 4) {
      _showError('Password must be at least 4 characters');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showError('Passwords do not match');
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
                  title: const Text('வெற்றி! ✅'),
                  content:
                      const Text('பதிவு வெற்றிகரமாக முடிந்தது! உள்நுழையவும்.'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/login');
                        },
                        child: const Text('OK'))
                  ],
                ));
      } else {
        _showError(res['message'] ??
            res['error'] ??
            'Registration failed. Call 8825401886');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('பால் நபர் பதிவு')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug box
            if (_debugLog.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(
                  _debugLog,
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ),

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

            if (_step == 1) ...[
              _label('பெயர்'),
              TextField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Name & Village')),
              const SizedBox(height: 14),
              _label('போன் நம்பர்'),
              TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                      hintText: '10-digit number', counterText: '')),
              const SizedBox(height: 14),
              _label('நீங்கள் யார்?'),
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
                  hint: const Text('-- தேர்வு --'),
                  items: const [
                    DropdownMenuItem(value: '2', child: Text('பால்காரர்')),
                    DropdownMenuItem(value: '3', child: Text('மாட்டுக்காரர்')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? ''),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _sendOtp, child: const Text('OTP அனுப்பு')),
            ],

            if (_step == 2) ...[
              Text('+91${_phoneCtrl.text} க்கு OTP அனுப்பப்பட்டது',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: kGreen, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _label('OTP உள்ளிடவும்'),
              TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                      hintText: '6-digit OTP', counterText: '')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _verifyOtp, child: const Text('OTP சரிபார்')),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('← Back')),
                TextButton(
                    onPressed: _sendOtp, child: const Text('Resend OTP')),
              ]),
            ],

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
              _label('கடவுச்சொல்'),
              TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: 'Min 4 characters')),
              const SizedBox(height: 14),
              _label('கடவுச்சொல் மீண்டும்'),
              TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: 'Repeat password')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _register, child: const Text('என்னை பதிவு செய்')),
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
