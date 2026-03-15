import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/lang_provider.dart';
import '../services/ad_service.dart';
import '../theme.dart';
import 'home_screen.dart' show MilkNoteAppBar, rootScaffoldKey;

class AddMilkScreen extends StatefulWidget {
  const AddMilkScreen({super.key});
  @override
  State<AddMilkScreen> createState() => _AddMilkScreenState();
}

class _AddMilkScreenState extends State<AddMilkScreen> {
  List<dynamic> _cowPersons = [];
  dynamic _selectedPerson;
  int _wholeAmount = 0;
  double _fraction = 0.0;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _submitting = false;

  final List<Map<String, dynamic>> _fractionOptions = [
    {'label': '.0 (0 ml)', 'value': 0.0},
    {'label': '.25 (250 ml)', 'value': 0.25},
    {'label': '.50 (500 ml)', 'value': 0.50},
    {'label': '.75 (750 ml)', 'value': 0.75},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPersons();
  }

  Future<void> _fetchPersons() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final data = await ApiService.getCowPersonList(auth.userId!);
      setState(() {
        _cowPersons = data is List ? data : [];
        _selectedPerson = null;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final t = context.read<LangProvider>().t;
    if (_selectedPerson == null) {
      _showError(t['addMilk']?['selectMilkPerson'] ?? 'Select cow person');
      return;
    }
    final total = _wholeAmount + _fraction;
    if (total == 0) {
      _showError(t['addMilk']?['selectMilkPerson'] ?? 'Select amount');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.addMilk(
        _selectedPerson['connection_id'].toString(),
        total,
        DateFormat('yyyy-MM-dd').format(_date),
      );
      if (!mounted) return;
      final addedMsg =
          '${total.toStringAsFixed(2)} ${t['addMilk']?['liter'] ?? 'L'} - ${_selectedPerson['name']} ✅';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(addedMsg),
          backgroundColor: kGreen,
          duration: const Duration(seconds: 3)));
      setState(() {
        _wholeAmount = 0;
        _fraction = 0;
        _selectedPerson = null;
        _date = DateTime.now();
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: kRed));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LangProvider>().t;
    final total = _wholeAmount + _fraction;

    return Scaffold(
      appBar:
          MilkNoteAppBar(title: t['addMilk']?['addMilkLabel'] ?? 'Add Milk'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Total preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: kLightGreen,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          '${total.toStringAsFixed(2)} ${t['addMilk']?['liter'] ?? 'L'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kGreen)),
                    ),
                    const SizedBox(height: 16),

                    // Whole litres
                    _sectionLabel(
                        t['addMilk']?['literLabel'] ?? 'Liter (Whole)'),
                    _PickerDropdown<int>(
                      value: _wholeAmount,
                      items: List.generate(11, (i) => i),
                      labelBuilder: (v) =>
                          '$v ${t['addMilk']?['liter'] ?? 'L'}',
                      onChanged: (v) => setState(() => _wholeAmount = v),
                    ),
                    const SizedBox(height: 14),

                    // Fraction
                    _sectionLabel(t['addMilk']?['milliLiter'] ?? 'Milliliter'),
                    _PickerDropdown<double>(
                      value: _fraction,
                      items: _fractionOptions
                          .map((o) => o['value'] as double)
                          .toList(),
                      labelBuilder: (v) => _fractionOptions
                          .firstWhere((o) => o['value'] == v)['label'],
                      onChanged: (v) => setState(() => _fraction = v),
                    ),
                    const SizedBox(height: 14),

                    // Cow person
                    _sectionLabel(t['addMilk']?['chooseMilkPerson'] ??
                        'Select Cow Person'),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade300, width: 1.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<dynamic>(
                        value: _selectedPerson,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Text(t['addMilk']?['chooseMilkPerson'] ??
                            '-- Select --'),
                        items: _cowPersons
                            .map((cp) => DropdownMenuItem(
                                  value: cp,
                                  child: Text(
                                      '${cp['name']} (${cp['phone_number']})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPerson = v),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1.5)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, color: kGreen),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd-MM-yyyy (EEEE)').format(_date),
                              style: const TextStyle(
                                  color: kGreen, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _submitting
                        ? const Center(
                            child: CircularProgressIndicator(color: kGreen))
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(t['addMilk']?['add'] ?? 'Add Milk')),
                  ],
                ),
              )),
              const BannerAdWidget(),
            ]),
    );
  }

  Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black54)));
}

class _PickerDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final void Function(T) onChanged;

  const _PickerDropdown(
      {required this.value,
      required this.items,
      required this.labelBuilder,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1.5)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items
            .map(
                (v) => DropdownMenuItem(value: v, child: Text(labelBuilder(v))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
