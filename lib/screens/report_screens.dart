import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import '../services/ad_service.dart';
import 'home_screen.dart';

// ═══════════════════════════════════════════════════════
// DAILY REPORT
// ═══════════════════════════════════════════════════════
class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});
  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _date = DateTime.now();
  List<dynamic> _records = [];
  double _total = 0;
  bool _loading = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiService.getDailyMilk(
          auth.userId!, DateFormat('yyyy-MM-dd').format(_date));
      setState(() {
        _records = res['records'] ?? [];
        _total = double.tryParse(res['grand_total']?.toString() ?? '0') ?? 0;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context,
        initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) { setState(() => _date = d); _fetch(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(title: 'இன்றைய பால் கணக்கு',
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_today, color: kGreen, size: 18),
                const SizedBox(width: 8),
                Text(DateFormat('dd-MM-yyyy').format(_date),
                    style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kGreen)))
        else
          Expanded(child: _records.isEmpty
            ? const Center(child: Text('No records', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return Card(child: ListTile(
                    title: Text(r['cow_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(r['cow_phone'] ?? ''),
                    trailing: Text('${r['quantity']} L',
                        style: const TextStyle(color: kGreen,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ));
                },
              ),
          ),
        if (_total > 0)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('மொத்தம்: $_total லிட்டர்',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MONTHLY REPORT
// ═══════════════════════════════════════════════════════
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});
  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  List<dynamic> _persons = [];
  dynamic _selected;
  DateTime _month = DateTime.now();
  List<dynamic> _records = [];
  double _total = 0;
  bool _loadingPersons = true;
  bool _loadingReport = false;

  @override
  void initState() { super.initState(); _fetchPersons(); }

  Future<void> _fetchPersons() async {
    setState(() => _loadingPersons = true);
    try {
      final auth = context.read<AuthProvider>();
      final data = await ApiService.getCowPersonList(auth.userId!);
      setState(() { _persons = data is List ? data : []; _selected = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loadingPersons = false);
    }
  }

  Future<void> _fetchReport() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('மாட்டுக்காரர் தேர்வு செய்யவும்')));
      return;
    }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(context: context,
        initialDate: _month, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => _month = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(title: 'மாதாந்திர பால் கணக்கு'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (_loadingPersons)
              const CircularProgressIndicator(color: kGreen)
            else
              Container(
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<dynamic>(
                  value: _selected, isExpanded: true, underline: const SizedBox(),
                  hint: const Text('-- மாட்டுக்காரர் தேர்வு --'),
                  items: _persons.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p['name']} (${p['phone_number']})'))).toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickMonth,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.calendar_month, color: kGreen, size: 18),
                  const SizedBox(width: 8),
                  Text('மாதம்: ${DateFormat('yyyy-MM').format(_month)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadingReport ? null : _fetchReport,
                child: _loadingReport
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('பால் விபரம் காட்டு'),
              ),
            ),
          ]),
        ),
        Expanded(child: _records.isEmpty
          ? const Center(child: Text('No records', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                final parts = (r['date'] ?? '').split('-');
                final displayDate = parts.length == 3
                    ? '${parts[2]}-${parts[1]}-${parts[0]}' : r['date'];
                return Card(child: ListTile(
                  title: Text(displayDate,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r['quantities']} L | மொத்தம்: ${r['total_quantity']} L'),
                  trailing: TextButton(
                    child: const Text('மாற்று', style: TextStyle(color: kGreen)),
                    onPressed: () => context.go('/edit-milk',
                        extra: {
                          'connection_id': _selected['connection_id'].toString(),
                          'date': r['date'].toString(),
                        }),
                  ),
                ));
              },
            ),
        ),
        if (_total > 0)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('மொத்த பால்: $_total லிட்டர்',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        const BannerAdWidget(),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// FULL REPORT
// ═══════════════════════════════════════════════════════
class FullReportScreen extends StatefulWidget {
  const FullReportScreen({super.key});
  @override
  State<FullReportScreen> createState() => _FullReportScreenState();
}

class _FullReportScreenState extends State<FullReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<dynamic> _records = [];
  double _total = 0;
  bool _loading = false;

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiService.getFullReport(
          auth.userId!,
          DateFormat('yyyy-MM-dd').format(_from),
          DateFormat('yyyy-MM-dd').format(_to));
      setState(() {
        _records = res['records'] ?? [];
        _total = double.tryParse(res['grand_total']?.toString() ?? '0') ?? 0;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final d = await showDatePicker(context: context,
        initialDate: isFrom ? _from : _to,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(title: 'முழு பால் அறிக்கை'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: InkWell(
                onTap: () => _pickDate(true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Text('From: ${DateFormat('dd-MM-yyyy').format(_from)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: InkWell(
                onTap: () => _pickDate(false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Text('To: ${DateFormat('dd-MM-yyyy').format(_to)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
                ),
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _fetch,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('கணக்கு கொடு'),
              ),
            ),
          ]),
        ),
        Expanded(child: _records.isEmpty
          ? const Center(child: Text('No records', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                return Card(child: ListTile(
                  title: Text(r['cow_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(r['report_date'] ?? ''),
                  trailing: Text('${r['quantity']} L',
                      style: const TextStyle(color: kGreen,
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ));
              },
            ),
        ),
        if (_total > 0)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('மொத்தம்: $_total லிட்டர்',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        const BannerAdWidget(),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// REGISTER COW PERSON
// ═══════════════════════════════════════════════════════
class RegisterCowScreen extends StatefulWidget {
  const RegisterCowScreen({super.key});
  @override
  State<RegisterCowScreen> createState() => _RegisterCowScreenState();
}

class _RegisterCowScreenState extends State<RegisterCowScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _phoneCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _register() async {
    if (_phoneCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields required'), backgroundColor: kRed));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final pass = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
      final userRes = await ApiService.registerCowPerson(
          _phoneCtrl.text.trim(), _nameCtrl.text.trim(), pass);
      await ApiService.connectCowPerson(userRes['id'].toString(), auth.userId!);
      if (!mounted) return;
      if (!mounted) return;
      _phoneCtrl.clear();
      _nameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('மாட்டுக்காரர் பதிவு செய்யப்பட்டது மற்றும் இணைக்கப்பட்டார்! ✅'),
        backgroundColor: kGreen,
        duration: Duration(seconds: 3),
      ));
      context.go('/add-milk');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(title: 'மாட்டுக்காரரை பதிவு செய்'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('மாட்டுக்காரர் போன் நம்பர்',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              maxLength: 10, decoration: const InputDecoration(counterText: '')),
          const SizedBox(height: 14),
          const Text('மாட்டுக்காரர் பெயர் & ஊர்',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl),
          const SizedBox(height: 20),
          _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : ElevatedButton(
                  onPressed: _register,
                  child: const Text('மாட்டுக்காரரை பதிவு செய்')),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CONNECT COW PERSON
// ═══════════════════════════════════════════════════════
class ConnectCowScreen extends StatefulWidget {
  const ConnectCowScreen({super.key});
  @override
  State<ConnectCowScreen> createState() => _ConnectCowScreenState();
}

class _ConnectCowScreenState extends State<ConnectCowScreen> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _results = []; });
    try {
      final data = await ApiService.searchCowPerson(_searchCtrl.text.trim());
      setState(() => _results = data is List ? data : []);
      if (_results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results. Check phone number.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(dynamic person) async {
    try {
      final auth = context.read<AuthProvider>();
      await ApiService.connectCowPerson(person['id'].toString(), auth.userId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${person['name']} இணைக்கப்பட்டது!'),
          backgroundColor: kGreen));
      setState(() { _results = []; _searchCtrl.clear(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MilkNoteAppBar(title: 'மாட்டுக்காரரை இணை'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
                controller: _searchCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'போன் நம்பரை உள்ளிடவும்'))),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _loading ? null : _search, child: const Text('தேடு')),
          ]),
          const SizedBox(height: 16),
          if (_loading) const CircularProgressIndicator(color: kGreen),
          Expanded(child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final p = _results[i];
              return Card(child: ListTile(
                title: Text(p['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p['phone_number'] ?? ''),
                trailing: ElevatedButton(
                    onPressed: () => _connect(p), child: const Text('இணை')),
              ));
            },
          )),
        ]),
      ),
    );
  }
}
