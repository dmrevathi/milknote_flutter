import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/lang_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = 'v${info.version} (build ${info.buildNumber})');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phoneCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _showError('Phone and password required');
      return;
    }
    setState(() => _loading = true);
    try {
      final res =
          await ApiService.login(_phoneCtrl.text.trim(), _passCtrl.text);
      if (res['success'] == true || res['token'] != null) {
        final auth = context.read<AuthProvider>();
        await auth.saveLogin(
          res['token'],
          res['user']['id'].toString(),
          res['user']['role_id'].toString(),
          name: res['user']['name']?.toString() ?? '',
          phone:
              res['user']['phone_number']?.toString() ?? _phoneCtrl.text.trim(),
        );
        if (!mounted) return;
        final roleId = res['user']['role_id'].toString();
        context.go(roleId == '3' ? '/cow-monthly' : '/add-milk');
      } else {
        _showError(res['message'] ?? 'Login failed. Call 8825401886');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: kRed));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangProvider>();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language selector
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: lang.lang,
                    underline: const SizedBox(),
                    isDense: true,
                    items: kLanguages
                        .map((l) => DropdownMenuItem(
                              value: l['code'],
                              child: Text(l['label']!,
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (code) {
                      if (code != null) lang.setLanguage(code);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('🥛',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text('Milk Note',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kGreen)),
              const SizedBox(height: 36),

              Text(lang.tr('login', 'phoneLabel'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                    hintText: lang.tr('login', 'phoneLabel'), counterText: ''),
              ),
              const SizedBox(height: 14),

              Text(lang.tr('login', 'passwordLabel'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: lang.tr('login', 'passwordLabel')),
              ),
              const SizedBox(height: 20),

              _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kGreen))
                  : ElevatedButton(
                      onPressed: _login,
                      child: Text(lang.tr('login', 'login'))),

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/signup'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(lang.tr('login', 'register'),
                    style: const TextStyle(color: kGreen)),
              ),

              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: kGreen, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  lang.tr('login', 'footer'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _version,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
