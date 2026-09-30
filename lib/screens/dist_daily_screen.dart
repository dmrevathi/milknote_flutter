import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';
import 'dist_widgets.dart';
import 'home_screen.dart';

/// Distributor: enter morning / evening litres for all customers for one date.
class DistDailyScreen extends StatefulWidget {
  const DistDailyScreen({super.key});

  @override
  State<DistDailyScreen> createState() => _DistDailyScreenState();
}

class _DistDailyScreenState extends State<DistDailyScreen> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  final Map<int, TextEditingController> _mCtrl = {};
  final Map<int, TextEditingController> _eCtrl = {};
  final Map<int, String> _origM = {};
  final Map<int, String> _origE = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clearCtrls();
    super.dispose();
  }

  void _clearCtrls() {
    for (final c in _mCtrl.values) {
      c.dispose();
    }
    for (final c in _eCtrl.values) {
      c.dispose();
    }
    _mCtrl.clear();
    _eCtrl.clear();
    _origM.clear();
    _origE.clear();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DistApi.dailySheet(ymd(_date));
      _clearCtrls();
      for (final r in list) {
        final id = toInt(r['customer_id']);
        final m = r['morning_qty'] == null ? '' : fmtNum(toD(r['morning_qty']));
        final e = r['evening_qty'] == null ? '' : fmtNum(toD(r['evening_qty']));
        _mCtrl[id] = TextEditingController(text: m);
        _eCtrl[id] = TextEditingController(text: e);
        _origM[id] = m;
        _origE[id] = e;
      }
      if (!mounted) return;
      setState(() {
        _rows = list;
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

  bool get _hasChanges {
    for (final id in _mCtrl.keys) {
      if (_mCtrl[id]!.text.trim() != _origM[id] ||
          _eCtrl[id]!.text.trim() != _origE[id]) {
        return true;
      }
    }
    return false;
  }

  double get _totalLitres {
    var t = 0.0;
    for (final id in _mCtrl.keys) {
      t += double.tryParse(_mCtrl[id]!.text.trim()) ?? 0;
      t += double.tryParse(_eCtrl[id]!.text.trim()) ?? 0;
    }
    return t;
  }

  /// Blank after a value existed => 0 (no milk). Invalid => null.
  double? _parse(String text) {
    if (text.isEmpty) return 0;
    final v = double.tryParse(text);
    if (v == null || v < 0 || v > 999) return null;
    return v;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? kRed : kGreen),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Discard the entries you have not saved?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changeDate(DateTime d) async {
    if (!await _confirmDiscard()) return;
    setState(() => _date = d);
    _load();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) _changeDate(d);
  }

  Future<void> _save() async {
    final jobs = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final id = toInt(r['customer_id']);
      final m = _mCtrl[id]!.text.trim();
      final e = _eCtrl[id]!.text.trim();
      double? mv;
      double? ev;
      if (m != _origM[id]) {
        mv = _parse(m);
        if (mv == null) {
          _snack('Invalid morning litres for ${r['name']}', error: true);
          return;
        }
      }
      if (e != _origE[id]) {
        ev = _parse(e);
        if (ev == null) {
          _snack('Invalid evening litres for ${r['name']}', error: true);
          return;
        }
      }
      if (mv != null || ev != null) {
        jobs.add({'id': id, 'm': mv, 'e': ev});
      }
    }
    if (jobs.isEmpty) {
      _snack('Nothing to save');
      return;
    }

    setState(() => _saving = true);
    try {
      final date = ymd(_date);
      for (final j in jobs) {
        await DistApi.saveEntry(
          customerId: j['id'] as int,
          date: date,
          morning: j['m'] as double?,
          evening: j['e'] as double?,
        );
      }
      if (!mounted) return;
      _snack('Saved ${jobs.length} customer${jobs.length == 1 ? '' : 's'}');
    } catch (e) {
      if (!mounted) return;
      _snack(errMsg(e), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _load(); // show exactly what the server has
  }

  void _openCard(Map<String, dynamic> r) {
    context.push('/dist-card', extra: {
      'customer_id': toInt(r['customer_id']),
      'name': r['name'].toString(),
      'month': ym(_date),
    }).then((_) {
      if (mounted && !_hasChanges) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MilkNoteAppBar(title: 'Daily Entry'),
      body: Column(
        children: [
          _dateBar(),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ),
    );
  }

  Widget _dateBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    _changeDate(_date.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        DateFormat('EEE, dd MMM yyyy').format(_date),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    _changeDate(_date.add(const Duration(days: 1))),
              ),
            ],
          ),
          if (_rows.isNotEmpty)
            Text('Total: ${fmtNum(_totalLitres)} L',
                style: const TextStyle(
                    color: kGreen, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No customers yet.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/dist-customers'),
                icon: const Icon(Icons.person_add),
                label: const Text('Add customer'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _rows.length,
      itemBuilder: (_, i) {
        final r = _rows[i];
        final id = toInt(r['customer_id']);
        final address = (r['address'] ?? '').toString();
        return Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r['name'].toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: kGreen),
                      tooltip: 'Monthly card',
                      onPressed: () => _openCard(r),
                    ),
                  ],
                ),
                if (address.isNotEmpty)
                  Text(address,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _qtyField(_mCtrl[id]!, 'Morning / காலை')),
                    const SizedBox(width: 12),
                    Expanded(child: _qtyField(_eCtrl[id]!, 'Evening / மாலை')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _qtyField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: kDecimalKeyboard,
      inputFormatters: kDecimalFormatters,
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (_) => setState(() {}),
    );
  }
}
