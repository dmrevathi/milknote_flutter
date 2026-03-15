import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/lang_provider.dart';
import '../theme.dart';
import 'home_screen.dart';

// ═══════════════════════════════════════════════════════
// LIST MONTHLY CALC
// ═══════════════════════════════════════════════════════
class ListMonthlyCalcScreen extends StatefulWidget {
  const ListMonthlyCalcScreen({super.key});
  @override
  State<ListMonthlyCalcScreen> createState() => _ListMonthlyCalcScreenState();
}

class _ListMonthlyCalcScreenState extends State<ListMonthlyCalcScreen> {
  List<dynamic> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getCalcReportList(page: _page);
      final total = int.tryParse(res['total']?.toString() ?? '0') ?? 0;
      setState(() {
        _items = res['items'] ?? [];
        _totalPages = (total / 25).ceil().clamp(1, 9999);
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(
        title: '📋 மாதாந்திர அறிக்கைகள்',
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/monthly-calc')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(children: [
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text('எந்த அறிக்கைகளும் கிடைக்கவில்லை.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return Card(
                              child: ListTile(
                            title: Text(item['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(item['created_on'] ?? ''),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: kLightGreen,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('${item['total']} L',
                                  style: const TextStyle(
                                      color: kGreen,
                                      fontWeight: FontWeight.w700)),
                            ),
                            onTap: () =>
                                context.go('/monthly-calc/${item['id']}'),
                          ));
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _fetch();
                          }
                        : null,
                    child: const Text('முந்தையது'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_page / $_totalPages',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton(
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() => _page++);
                            _fetch();
                          }
                        : null,
                    child: const Text('அடுத்தது'),
                  ),
                ]),
              ),
            ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// EDIT MILK
// ═══════════════════════════════════════════════════════
class EditMilkScreen extends StatefulWidget {
  final String connectionId;
  final String date;
  const EditMilkScreen(
      {super.key, required this.connectionId, required this.date});
  @override
  State<EditMilkScreen> createState() => _EditMilkScreenState();
}

class _EditMilkScreenState extends State<EditMilkScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res =
          await ApiService.getMilkByDate(widget.connectionId, widget.date);
      final raw = (res['data'] as List? ?? [])
          .where((r) => r['date'] == widget.date)
          .map((r) => {
                ...Map<String, dynamic>.from(r),
                'is_active_bool':
                    (r['is_active'] == 1 || r['is_active'] == '1'),
              })
          .toList();
      setState(() => _records = raw.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final formatted = _records
          .map((r) => {
                ...r,
                'is_active': (r['is_active_bool'] as bool) ? 1 : 0,
              })
          .toList();
      final res = await ApiService.editMilk(
          widget.connectionId, widget.date, auth.userId!, formatted);
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('வெற்றிகரமாக சேமிக்கப்பட்டது ✅'),
            backgroundColor: kGreen));
        context.go('/monthly-report');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.date.split('-');
    final displayDate =
        parts.length == 3 ? '${parts[2]}-${parts[1]}-${parts[0]}' : widget.date;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              '${context.read<LangProvider>().t['editMilkReport']?['editMilkReport'] ?? 'Edit Milk'} ($displayDate)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(children: [
              Expanded(
                  child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return Card(
                      child: SwitchListTile(
                    title: Text('${r['quantity']} லிட்டர்',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: r['is_active_bool'] as bool,
                    activeColor: kGreen,
                    onChanged: (v) =>
                        setState(() => _records[i]['is_active_bool'] = v),
                  ));
                },
              )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('நிரந்தரமாக சேமி'),
                  ),
                ),
              ),
            ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// COW PERSON MONTHLY (Role 3)
// ═══════════════════════════════════════════════════════
class CowMonthlyScreen extends StatefulWidget {
  const CowMonthlyScreen({super.key});
  @override
  State<CowMonthlyScreen> createState() => _CowMonthlyScreenState();
}

class _CowMonthlyScreenState extends State<CowMonthlyScreen> {
  List<dynamic> _persons = [];
  dynamic _selected;
  DateTime _month = DateTime.now();
  List<dynamic> _records = [];
  double _total = 0;
  bool _loadingPersons = true;
  bool _loadingReport = false;

  @override
  void initState() {
    super.initState();
    _fetchPersons();
  }

  Future<void> _fetchPersons() async {
    setState(() => _loadingPersons = true);
    try {
      final auth = context.read<AuthProvider>();
      final data = await ApiService.getMilkPersonList(auth.userId!);
      setState(() {
        _persons = data is List ? data : [];
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loadingPersons = false);
    }
  }

  Future<void> _fetchReport() async {
    if (_selected == null) return;
    setState(() => _loadingReport = true);
    try {
      final res = await ApiService.getMonthlyMilk(
          _selected['connection_id'].toString(),
          DateFormat('yyyy-MM').format(_month));
      setState(() {
        _records = res['records'] ?? [];
        _total = double.tryParse(res['grand_total']?.toString() ?? '0') ?? 0;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _month,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d != null) setState(() => _month = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(
          title: context.read<LangProvider>().t['sideBar']
                  ?['milkManMonthlyMilkValue'] ??
              'Monthly Milk'),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_loadingPersons)
                const CircularProgressIndicator(color: kGreen)
              else
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<dynamic>(
                    value: _selected,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('-- பால்காரர் தேர்வு --'),
                    items: _persons
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p['name']} (${p['phone_number']})')))
                        .toList(),
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month,
                            color: kGreen, size: 18),
                        const SizedBox(width: 8),
                        Text('மாதம்: ${DateFormat('yyyy-MM').format(_month)}',
                            style: const TextStyle(
                                color: kGreen, fontWeight: FontWeight.w700)),
                      ]),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadingReport ? null : _fetchReport,
                    child: _loadingReport
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('பால் விபரம் காட்டு'),
                  )),
            ])),
        Expanded(
          child: _records.isEmpty
              ? const Center(
                  child:
                      Text('No records', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _records.length,
                  itemBuilder: (_, i) {
                    final r = _records[i];
                    final parts = (r['date'] ?? '').split('-');
                    final d = parts.length == 3
                        ? '${parts[2]}-${parts[1]}-${parts[0]}'
                        : r['date'];
                    return Card(
                        child: ListTile(
                      title: Text(d,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${r['quantities']} L | மொத்தம்: ${r['total_quantity']} L'),
                    ));
                  },
                ),
        ),
        if (_total > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: kGreen,
            child: Text('மொத்த பால்: $_total லிட்டர்',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MONTHLY INPUT (no login required)
// ═══════════════════════════════════════════════════════
class MonthlyInputScreen extends StatefulWidget {
  const MonthlyInputScreen({super.key});
  @override
  State<MonthlyInputScreen> createState() => _MonthlyInputScreenState();
}

class _MonthlyInputScreenState extends State<MonthlyInputScreen> {
  final Map<int, List<double>> _data = {};
  bool _saving = false;

  double _getVal(int day, int idx) => _data[day]?[idx] ?? 0.0;

  void _setVal(int day, int idx, double val) {
    setState(() {
      _data[day] ??= [0.0, 0.0];
      _data[day]![idx] = val;
    });
  }

  double get _grandTotal => _data.values.fold(0.0, (s, e) => s + e[0] + e[1]);

  void _showPicker(int day, int idx, bool isFrac) {
    final opts = isFrac
        ? [0.0, 0.25, 0.50, 0.75]
        : [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];

    showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: opts.map((v) {
                    final cur = isFrac
                        ? (_getVal(day, idx) % 1)
                        : _getVal(day, idx).floorToDouble();
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (isFrac) {
                          _setVal(
                              day, idx, _getVal(day, idx).floorToDouble() + v);
                        } else {
                          _setVal(day, idx, v + (_getVal(day, idx) % 1));
                        }
                      },
                      child: Container(
                        width: 64,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cur == v ? kGreen : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isFrac
                              ? '.${(v * 100).toInt().toString().padLeft(2, '0')}'
                              : v.toInt().toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: cur == v ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  }).toList()),
            ));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.userId == null) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('Sign up to save'),
                  content: const Text(
                      'You need an account to save monthly records.'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/signup');
                        },
                        child: const Text('Register')),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                  ],
                ));
        return;
      }
      final total = _grandTotal.toStringAsFixed(2);
      final dataMap = _data.map((k, v) => MapEntry(k.toString(), v));
      await ApiService.saveCalcReport(
          auth.userId!, 'Monthly Entry', total, dataMap);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved! Total: $total L'), backgroundColor: kGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Monthly Milk Entry'),
        leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/login')),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: Text('${_grandTotal.toStringAsFixed(2)} L',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: kLightGreen,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: const Row(children: [
            SizedBox(
                width: 32,
                child: Text('Day',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            Expanded(
                child: Text('Morning',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: kGreen))),
            Expanded(
                child: Text('Evening',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: kGreen))),
          ]),
        ),
        Expanded(
            child: ListView.builder(
          itemCount: 31,
          itemBuilder: (_, i) {
            final day = i + 1;
            final m = _getVal(day, 0);
            final e = _getVal(day, 1);
            return Container(
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                SizedBox(
                    width: 32,
                    child: Text('$day',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(
                    child: _Cell(
                        label: m.floor().toString(),
                        onTap: () => _showPicker(day, 0, false))),
                Expanded(
                    child: _Cell(
                        label:
                            '.${((m % 1) * 100).toInt().toString().padLeft(2, '0')}',
                        onTap: () => _showPicker(day, 0, true),
                        light: true)),
                Expanded(
                    child: _Cell(
                        label: e.floor().toString(),
                        onTap: () => _showPicker(day, 1, false))),
                Expanded(
                    child: _Cell(
                        label:
                            '.${((e % 1) * 100).toInt().toString().padLeft(2, '0')}',
                        onTap: () => _showPicker(day, 1, true),
                        light: true)),
              ]),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('💾 Save Monthly Data'),
              )),
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
  Widget build(BuildContext context) => GestureDetector(
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
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
}
