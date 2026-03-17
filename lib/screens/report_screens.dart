import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/lang_provider.dart';
import '../services/ad_service.dart';
import '../theme.dart';
import 'home_screen.dart' show MilkNoteAppBar, rootScaffoldKey;

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
    final t = context.watch<LangProvider>().t;
    return Scaffold(
      appBar: MilkNoteAppBar(
        title: t['sideBar']?['todayMilkRecord'] ?? 'Today Milk',
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
      ),
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
                Text('${t['dailyMilkReport']?['dateLabel'] ?? 'Date'}: ${DateFormat('dd-MM-yyyy').format(_date)}',
                    style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kGreen)))
        else
          Expanded(child: _records.isEmpty
            ? Center(child: Text(t['dailyMilkReport']?['errorMsg'] ?? 'No records',
                style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return Card(child: ListTile(
                    title: Text(r['cow_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(r['cow_phone'] ?? ''),
                    trailing: Text('${r['quantity']} ${t['dailyMilkReport']?['literLabel'] ?? 'L'}',
                        style: const TextStyle(color: kGreen,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ));
                },
              ),
          ),
        if (_total > 0)
          SafeArea(
            top: false,
            child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('${t['dailyMilkReport']?['total'] ?? 'Total'}: $_total ${t['dailyMilkReport']?['literLabel'] ?? 'L'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        SafeArea(top: false, child: const BannerAdWidget()),
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
  String _milkPersonName = '';

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

  Future<void> _fetchReport(Map t) async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t['monthlyMilkReport']?['select_cow_person'] ?? 'Select cow person')));
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

  Future<void> _exportPdf() async {
    if (_records.isEmpty) return;

    final pdf = pw.Document();
    final monthStr = DateFormat('MMMM yyyy').format(_month);
    final now = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final cowName = _selected['name']?.toString() ?? '';
    final cowPhone = _selected['phone_number']?.toString() ?? '';

    // Sort records by date ascending
    final sorted = List<dynamic>.from(_records)
      ..sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        return da.compareTo(db);
      });

    // Build table rows
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('1bbd36')),
        children: [
          _pdfCell('No', isHeader: true),
          _pdfCell('Date', isHeader: true),
          _pdfCell('Qty (L)', isHeader: true),
        ],
      ),
    ];

    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final rawDate = r['date']?.toString() ?? '';
      final parts = rawDate.split('-');
      final d = parts.length == 3
          ? '${parts[2]}-${parts[1]}-${parts[0]}'
          : rawDate;
      final qty = (r['total_quantity'] ?? r['quantities'] ?? r['quantity'] ?? '0').toString();

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
            color: i % 2 == 0 ? PdfColors.white : PdfColors.grey100),
        children: [
          _pdfCell('${i + 1}'),
          _pdfCell(d),
          _pdfCell(qty),
        ],
      ));
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => [
        // Header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('1bbd36'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Milk Note - Monthly Report',
                  style: pw.TextStyle(color: PdfColors.white,
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Month: $monthStr  |  Records: ${sorted.length}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 13)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Info grid
        pw.Row(children: [
          pw.Expanded(child: _pdfInfoBox('Milk Person',
              _milkPersonName.isNotEmpty ? _milkPersonName : '-')),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _pdfInfoBox('Cow Person', '$cowName ($cowPhone)')),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _pdfInfoBox('Report Month', monthStr)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _pdfInfoBox('Generated At', now)),
        ]),
        pw.SizedBox(height: 20),

        // Table — MultiPage handles overflow automatically
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
          },
          children: tableRows,
        ),
        pw.SizedBox(height: 16),

        // Total
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('1bbd36'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text('Total: $_total Liters',
              style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
        ),
      ],
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'MilkNote_${cowName}_$monthStr.pdf',
    );
  }

  pw.Widget _pdfInfoBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
            color: isHeader ? PdfColors.white : PdfColors.black,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 11,
          )),
    );
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(context: context,
        initialDate: _month, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => _month = d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LangProvider>().t;
    final auth = context.read<AuthProvider>();
    _milkPersonName = auth.userId ?? '';


    return Scaffold(
      appBar: MilkNoteAppBar(
        title: t['sideBar']?['monthlyMilkRecord'] ?? 'Monthly Milk',
        actions: _records.isNotEmpty ? [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ] : null,
      ),
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
                  hint: Text(t['monthlyMilkReport']?['select_cow_person'] ?? '-- Select --'),
                  items: _persons.map((p) => DropdownMenuItem(value: p,
                      child: Text('${p['name']} (${p['phone_number']})'))).toList(),
                  onChanged: (v) => setState(() {
                    _selected = v;
                  }),
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
                  Text('${t['monthlyMilkReport']?['month_label'] ?? 'Month'}: ${DateFormat('yyyy-MM').format(_month)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadingReport ? null : () => _fetchReport(t),
                child: _loadingReport
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(t['monthlyMilkReport']?['show_milk_button'] ?? 'Show'),
              ),
            ),
          ]),
        ),
        Expanded(child: _records.isEmpty
          ? Center(child: Text(t['monthlyMilkReport']?['select_cow_person'] ?? 'Select cow person and month',
              style: const TextStyle(color: Colors.grey)))
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
                  subtitle: Text('${r['quantities']} ${t['monthlyMilkReport']?['liter_label'] ?? 'L'} | '
                      '${t['monthlyMilkReport']?['total_label'] ?? 'Total'}: ${r['total_quantity']} ${t['monthlyMilkReport']?['liter_label'] ?? 'L'}'),
                ));
              },
            ),
        ),
        if (_total > 0)
          SafeArea(
            top: false,
            child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('${t['monthlyMilkReport']?['total_milk_label'] ?? 'Total'}: $_total ${t['monthlyMilkReport']?['liter_label'] ?? 'L'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        SafeArea(top: false, child: const BannerAdWidget()),
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

  Future<void> _fetch(Map t) async {
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
    final t = context.watch<LangProvider>().t;
    return Scaffold(
      appBar: MilkNoteAppBar(title: t['fullMilkReport']?['title'] ?? 'Full Report'),
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
                  child: Text('${t['fullMilkReport']?['fromDate'] ?? 'From'}: ${DateFormat('dd-MM-yyyy').format(_from)}',
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
                  child: Text('${t['fullMilkReport']?['toDate'] ?? 'To'}: ${DateFormat('dd-MM-yyyy').format(_to)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
                ),
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _fetch(t),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(t['fullMilkReport']?['generateReport'] ?? 'Generate'),
              ),
            ),
          ]),
        ),
        Expanded(child: _records.isEmpty
          ? Center(child: Text(t['fullMilkReport']?['total'] ?? 'No records',
              style: const TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                return Card(child: ListTile(
                  title: Text(r['cow_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(r['report_date'] ?? ''),
                  trailing: Text('${r['quantity']} ${t['fullMilkReport']?['liters'] ?? 'L'}',
                      style: const TextStyle(color: kGreen,
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ));
              },
            ),
        ),
        if (_total > 0)
          SafeArea(
            top: false,
            child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: kGreen,
            child: Text('${t['fullMilkReport']?['total'] ?? 'Total'}: $_total ${t['fullMilkReport']?['liters'] ?? 'L'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        SafeArea(top: false, child: const BannerAdWidget()),
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

  Future<void> _register(Map t) async {
    if (_phoneCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t['registerCowPerson']?['errorTitle'] ?? 'All fields required'),
          backgroundColor: kRed));
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
      _phoneCtrl.clear(); _nameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t['registerCowPerson']?['successMessage'] ?? 'Registered!'),
          backgroundColor: kGreen));
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
    final t = context.watch<LangProvider>().t;
    return Scaffold(
      appBar: MilkNoteAppBar(title: t['registerCowPerson']?['title'] ?? 'Register Cow Person'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t['registerCowPerson']?['phonePlaceholder'] ?? 'Phone',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                  hintText: t['registerCowPerson']?['phonePlaceholder'],
                  counterText: '')),
          const SizedBox(height: 14),
          Text(t['registerCowPerson']?['namePlaceholder'] ?? 'Name',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl,
              decoration: InputDecoration(
                  hintText: t['registerCowPerson']?['namePlaceholder'])),
          const SizedBox(height: 20),
          _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : ElevatedButton(
                  onPressed: () => _register(t),
                  child: Text(t['registerCowPerson']?['registerButton'] ?? 'Register')),
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

  Future<void> _search(Map t) async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _results = []; });
    try {
      final data = await ApiService.searchCowPerson(_searchCtrl.text.trim());
      setState(() => _results = data is List ? data : []);
      if (_results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t['connectCowPerson']?['noResultsMessage'] ?? 'No results')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(dynamic person, Map t) async {
    try {
      final auth = context.read<AuthProvider>();
      await ApiService.connectCowPerson(person['id'].toString(), auth.userId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${person['name']} ${t['connectCowPerson']?['connected'] ?? 'connected'}!'),
          backgroundColor: kGreen));
      setState(() { _results = []; _searchCtrl.clear(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LangProvider>().t;
    return Scaffold(
      appBar: MilkNoteAppBar(title: t['connectCowPerson']?['title'] ?? 'Connect Cow Person'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
                controller: _searchCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    hintText: t['connectCowPerson']?['phonePlaceholder'] ?? 'Enter phone'))),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: _loading ? null : () => _search(t),
                child: Text(t['connectCowPerson']?['searchButton'] ?? 'Search')),
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
                    onPressed: () => _connect(p, t),
                    child: Text(t['connectCowPerson']?['ok'] ?? 'Connect')),
              ));
            },
          )),
        ]),
      ),
    );
  }
}