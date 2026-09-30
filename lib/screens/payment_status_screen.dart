import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';
import 'dist_widgets.dart';
import 'home_screen.dart';

/// Pick a month and see total / paid / balance.
/// Distributor: one row per customer.  Consumer: one row per distributor.
class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({super.key});

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  late String _month;
  late bool _isDist;
  bool _loading = true;
  bool _pendingOnly = false;
  String? _error;
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _month = ym(DateTime.now());
    _isDist = context.read<AuthProvider>().isDistributor;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _d == null;
      _error = null;
    });
    try {
      final res = await DistApi.paymentStatus(_month);
      if (!mounted) return;
      setState(() {
        _d = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errMsg(e);
        _loading = false;
      });
    }
  }

  void _openCard(Map<String, dynamic> c) {
    final name = (_isDist ? c['consumer_name'] : c['distributor_name']).toString();
    context.push('/dist-card', extra: {
      'customer_id': toInt(c['customer_id']),
      'name': name,
      'month': _month,
    }).then((_) {
      if (mounted) _load(); // payments may have changed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(
        title: _isDist ? 'Payment Status' : 'My Milk Bill',
      ),
      bottomNavigationBar: const KeyboardAwareBanner(),
      body: Column(
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (m) {
              setState(() {
                _month = m;
                _d = null;
              });
              _load();
            },
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    if (_error != null || _d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Could not load', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final d = _d!;
    var list = (d['customers'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (_pendingOnly) {
      list = list.where((c) => toD(c['balance']) > 0).toList();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _totals(d),
          const SizedBox(height: 8),
          if (_isDist)
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Pending only'),
                selected: _pendingOnly,
                selectedColor: kLightGreen,
                onSelected: (v) => setState(() => _pendingOnly = v),
              ),
            ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _pendingOnly
                      ? 'No pending balance for this month.'
                      : (_isDist
                          ? 'No customers yet.'
                          : 'No distributor has added you yet.'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          for (final c in list) _row(c),
        ],
      ),
    );
  }

  Widget _totals(Map<String, dynamic> d) {
    final bal = toD(d['total_balance']);
    final advance = bal < 0;
    final balColor = advance ? Colors.blue.shade700 : (bal > 0 ? kRed : kGreen);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          _stat('Total', '₹${fmtNum(toD(d['total_amount']))}'),
          _stat('Received', '₹${fmtNum(toD(d['total_paid']))}'),
          _stat(advance ? 'Advance' : 'Balance', '₹${fmtNum(bal.abs())}',
              color: balColor),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final name = (_isDist ? c['consumer_name'] : c['distributor_name']).toString();
    final bal = toD(c['balance']);
    final amount = toD(c['total_amount']);

    String trailing;
    Color color;
    if (bal > 0) {
      trailing = '₹${fmtNum(bal)} due';
      color = kRed;
    } else if (bal < 0) {
      trailing = 'Advance ₹${fmtNum(bal.abs())}';
      color = Colors.blue.shade700;
    } else if (amount > 0) {
      trailing = 'Paid';
      color = kGreen;
    } else {
      trailing = '—';
      color = Colors.black45;
    }

    return Card(
      color: Colors.white,
      child: ListTile(
        onTap: () => _openCard(c),
        title:
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${fmtNum(toD(c['total_litres']))} L  ·  ₹${fmtNum(amount)}'
          '  ·  received ₹${fmtNum(toD(c['paid']))}',
        ),
        trailing: Text(trailing,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
