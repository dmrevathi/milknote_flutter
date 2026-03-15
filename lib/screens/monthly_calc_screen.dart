import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'home_screen.dart';

class MonthlyCalcScreen extends StatefulWidget {
  final String? reportId;
  const MonthlyCalcScreen({super.key, this.reportId});

  @override
  State<MonthlyCalcScreen> createState() => _MonthlyCalcScreenState();
}

class _MonthlyCalcScreenState extends State<MonthlyCalcScreen> {
  // milkData[day] = [morning, evening] as doubles
  final Map<int, List<double>> _data = {};
  String _reportName = '';
  bool _loading = false;
  bool _saving = false;

  final List<double> _wholeOpts = [0,1,2,3,4,5,6,7,8,9];
  final List<double> _fracOpts = [0, 0.25, 0.50, 0.75];

  @override
  void initState() {
    super.initState();
    if (widget.reportId != null) _loadReport();
  }

  double _getVal(int day, int idx) => _data[day]?[idx] ?? 0.0;

  void _setVal(int day, int idx, double val) {
    setState(() {
      _data[day] ??= [0.0, 0.0];
      _data[day]![idx] = val;
    });
  }

  double get _grandTotal => _data.values.fold(0.0,
      (sum, entry) => sum + (entry[0]) + (entry[1]));

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getCalcReport(widget.reportId!);
      final record = res is List ? res[0] : res;
      _reportName = record['name'] ?? '';
      final parsed = jsonDecode(record['data'] ?? '{}');
      final days = parsed['days'] as Map? ?? {};
      days.forEach((k, v) {
        final day = int.tryParse(k.toString());
        if (day != null && v is List) {
          _data[day] = [
            double.tryParse(v[0].toString()) ?? 0.0,
            double.tryParse(v[1].toString()) ?? 0.0,
          ];
        }
      });
      setState(() {});
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_reportName.isEmpty) {
      final name = await _askReportName();
      if (name == null || name.isEmpty) return;
      _reportName = name;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final total = _grandTotal.toStringAsFixed(2);
      final dataMap = _data.map((k, v) => MapEntry(k.toString(), v));
      await ApiService.saveCalcReport(
          auth.userId!, _reportName, total, dataMap,
          reportId: widget.reportId);
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('✅ வெற்றி'),
        content: Text('"$_reportName" சேமிக்கப்பட்டது!\nமொத்தம்: $total L'),
        actions: [TextButton(onPressed: () {
          Navigator.pop(context);
          context.go('/list-calc');
        }, child: const Text('OK'))],
      ));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askReportName() {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('அறிக்கை பெயர்'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(hintText: 'எ.கா. அக்டோபர் அறிக்கை')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ரத்து')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('சேமி')),
      ],
    ));
  }

  void _showError(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: kRed));

  void _showPicker(int day, int idx, bool isFrac) {
    final opts = isFrac ? _fracOpts : _wholeOpts;
    final current = isFrac ? (_getVal(day, idx) % 1) : _getVal(day, idx).floorToDouble();

    showModalBottomSheet(context: context, builder: (_) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isFrac ? 'பகுதி (ml)' : 'முழு (லிட்டர்)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: opts.map((v) {
          final isSelected = (isFrac ? current : _getVal(day, idx).floorToDouble()) == v;
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              if (isFrac) {
                final whole = _getVal(day, idx).floorToDouble();
                _setVal(day, idx, whole + v);
              } else {
                final frac = _getVal(day, idx) % 1;
                _setVal(day, idx, v + frac);
              }
            },
            child: Container(
              width: 64, height: 48,
              decoration: BoxDecoration(
                color: isSelected ? kGreen : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(isFrac ? '.${(v * 100).toInt().toString().padLeft(2, '0')}' : v.toInt().toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16,
                      color: isSelected ? Colors.white : Colors.black87)),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('மாதாந்திர கணக்கீடு')),
        body: const Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    return Scaffold(
      appBar: MilkNoteAppBar(
        title: widget.reportId != null ? '✏️ திருத்து' : '📊 புதிய அறிக்கை',
      ),
      body: Column(children: [
        // Header
        Container(
          color: kLightGreen,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(children: [
            const SizedBox(width: 32, child: Text('Day', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const Expanded(child: Text('காலை', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kGreen))),
            const Expanded(child: Text('மாலை', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kGreen))),
          ]),
        ),
        // Grid
        Expanded(child: ListView.builder(
          itemCount: 31,
          itemBuilder: (_, i) {
            final day = i + 1;
            final morning = _getVal(day, 0);
            final evening = _getVal(day, 1);
            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                SizedBox(width: 32,
                    child: Text('$day', textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                // Morning whole
                Expanded(child: _Cell(
                  label: morning.floor().toString(),
                  onTap: () => _showPicker(day, 0, false),
                )),
                // Morning frac
                Expanded(child: _Cell(
                  label: '.${((morning % 1) * 100).toInt().toString().padLeft(2, '0')}',
                  onTap: () => _showPicker(day, 0, true),
                  light: true,
                )),
                // Evening whole
                Expanded(child: _Cell(
                  label: evening.floor().toString(),
                  onTap: () => _showPicker(day, 1, false),
                )),
                // Evening frac
                Expanded(child: _Cell(
                  label: '.${((evening % 1) * 100).toInt().toString().padLeft(2, '0')}',
                  onTap: () => _showPicker(day, 1, true),
                  light: true,
                )),
              ]),
            );
          },
        )),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(children: [
            Text('🧮 மொத்தம்: ${_grandTotal.toStringAsFixed(2)} L',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kGreen)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.reportId != null ? '💾 அறிக்கையை புதுப்பிக்கவும்' : '💾 அறிக்கையை சேமிக்கவும்'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool light;
  const _Cell({required this.label, required this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 40,
        decoration: BoxDecoration(
          color: light ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
