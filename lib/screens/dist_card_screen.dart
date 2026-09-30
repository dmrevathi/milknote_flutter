import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_provider.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';
import 'dist_widgets.dart';

/// Monthly card for one customer (like the paper card).
/// Distributor can edit days, add / delete payments and change price.
/// Consumer sees it read-only.
class DistCardScreen extends StatefulWidget {
  final int customerId;
  final String title;
  final String? month; // "yyyy-MM"

  const DistCardScreen({
    super.key,
    required this.customerId,
    required this.title,
    this.month,
  });

  @override
  State<DistCardScreen> createState() => _DistCardScreenState();
}

class _DistCardScreenState extends State<DistCardScreen> {
  late String _month;
  late bool _isDist;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _month = widget.month ?? ym(DateTime.now());
    _isDist = context.read<AuthProvider>().isDistributor;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _d == null;
      _error = null;
    });
    try {
      final res = await DistApi.monthCard(widget.customerId, _month);
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

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? kRed : kGreen),
    );
  }

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(DateTime.parse('$_month-01'));

  // ── Actions ────────────────────────────────────────────

  void _shareBill() {
    final d = _d;
    if (d == null) return;
    final bal = toD(d['balance']);
    final msg = '🥛 Milk bill – $_monthLabel\n'
        '${widget.title}\n\n'
        'Litres: ${fmtNum(toD(d['total_litres']))}\n'
        'Amount: ₹${fmtNum(toD(d['total_amount']))}\n'
        'Received: ₹${fmtNum(toD(d['paid']))}\n'
        '${bal < 0 ? 'Advance' : 'Balance'}: ₹${fmtNum(bal.abs())}';
    Share.share(msg, subject: 'Milk bill $_monthLabel');
  }

  Future<void> _editDay(Map<String, dynamic> day) async {
    final origM = day['morning'] == null ? '' : fmtNum(toD(day['morning']));
    final origE = day['evening'] == null ? '' : fmtNum(toD(day['evening']));
    final mCtrl = TextEditingController(text: origM);
    final eCtrl = TextEditingController(text: origE);
    String? err;
    bool saving = false;
    final date = DateTime.parse(day['date'].toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(DateFormat('EEE, dd MMM').format(date)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mCtrl,
                keyboardType: kDecimalKeyboard,
                inputFormatters: kDecimalFormatters,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Morning / காலை (L)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: eCtrl,
                keyboardType: kDecimalKeyboard,
                inputFormatters: kDecimalFormatters,
                decoration:
                    const InputDecoration(labelText: 'Evening / மாலை (L)'),
              ),
              const SizedBox(height: 6),
              const Text('Enter 0 if no milk was given.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              if (err != null)
                Text(err!, style: const TextStyle(color: kRed, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final m = mCtrl.text.trim();
                      final e = eCtrl.text.trim();
                      // Only send what changed; blank after a value => 0.
                      double? mv;
                      double? ev;
                      if (m != origM) mv = m.isEmpty ? 0 : double.tryParse(m);
                      if (e != origE) ev = e.isEmpty ? 0 : double.tryParse(e);
                      if ((m != origM && mv == null) ||
                          (e != origE && ev == null)) {
                        setS(() => err = 'Enter valid litres');
                        return;
                      }
                      if (mv == null && ev == null) {
                        Navigator.pop(ctx, false);
                        return;
                      }
                      setS(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await DistApi.saveEntry(
                          customerId: widget.customerId,
                          date: day['date'].toString(),
                          morning: mv,
                          evening: ev,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (ex) {
                        setS(() {
                          saving = false;
                          err = errMsg(ex);
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _addPayment() async {
    final amtCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String? err;
    bool saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add payment / வரவு'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amtCtrl,
                keyboardType: kDecimalKeyboard,
                inputFormatters: kDecimalFormatters,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setS(() => date = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Paid on'),
                  child: Text(DateFormat('dd MMM yyyy').format(date)),
                ),
              ),
              const SizedBox(height: 8),
              Text('Counted for $_monthLabel',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (err != null)
                Text(err!, style: const TextStyle(color: kRed, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amt = double.tryParse(amtCtrl.text.trim());
                      if (amt == null || amt <= 0) {
                        setS(() => err = 'Enter a valid amount');
                        return;
                      }
                      setS(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await DistApi.addPayment(
                          customerId: widget.customerId,
                          amount: amt,
                          date: ymd(date),
                          forMonth: _month,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (ex) {
                        setS(() {
                          saving = false;
                          err = errMsg(ex);
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      _snack('Payment added');
      _load();
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payment'),
        content: Text('Delete the payment of ₹${fmtNum(toD(p['amount']))}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DistApi.deletePayment(toInt(p['payment_id']));
      if (!mounted) return;
      _snack('Payment deleted');
      _load();
    } catch (e) {
      if (mounted) _snack(errMsg(e), error: true);
    }
  }

  Future<void> _changePrice() async {
    final d = _d;
    if (d == null) return;
    final prices = (d['prices'] as List);
    double? current;
    final today = ymd(DateTime.now());
    for (final p in prices) {
      if (p['effective_from'].toString().compareTo(today) <= 0) {
        current = toD(p['price']);
      }
    }
    current ??= prices.isNotEmpty ? toD(prices.first['price']) : null;
    final ok = await showPriceDialog(context, widget.customerId,
        currentPrice: current);
    if (ok && mounted) {
      _snack('Price updated');
      _load();
    }
  }

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share bill',
            onPressed: _d == null ? null : _shareBill,
          ),
        ],
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _header(d),
          const SizedBox(height: 8),
          _summary(d),
          const SizedBox(height: 12),
          _dayTable(d),
          const SizedBox(height: 16),
          _paymentsSection(d),
          const SizedBox(height: 16),
          _pricesSection(d),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final c = Map<String, dynamic>.from(d['customer'] as Map);
    final lines = <String>[];
    if (_isDist) {
      if ((c['consumer_phone'] ?? '').toString().isNotEmpty) {
        lines.add('📱 ${c['consumer_phone']}');
      }
      if ((c['address'] ?? '').toString().isNotEmpty) {
        lines.add('📍 ${c['address']}');
      }
    } else {
      lines.add('Distributor: ${c['distributor_name']}');
      if ((c['distributor_phone'] ?? '').toString().isNotEmpty) {
        lines.add('📱 ${c['distributor_phone']}');
      }
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Text(lines.join('\n'),
        style: const TextStyle(color: Colors.black54, height: 1.4));
  }

  Widget _summary(Map<String, dynamic> d) {
    final bal = toD(d['balance']);
    final advance = bal < 0;
    final balColor = advance ? Colors.blue.shade700 : (bal > 0 ? kRed : kGreen);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              _stat('Litres', fmtNum(toD(d['total_litres']))),
              _stat('Amount', '₹${fmtNum(toD(d['total_amount']))}'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _stat('Received / வரவு', '₹${fmtNum(toD(d['paid']))}'),
              _stat(advance ? 'Advance' : 'Balance', '₹${fmtNum(bal.abs())}',
                  color: balColor),
            ]),
          ],
        ),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {int flex = 1, bool bold = false, Alignment align = Alignment.center}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _dayTable(Map<String, dynamic> d) {
    final days = (d['days'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final header = Container(
      color: kGreen,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Row(children: [
          _cell('தேதி', flex: 2, bold: true),
          _cell('காலை', flex: 3, bold: true),
          _cell('மாலை', flex: 3, bold: true),
          _cell('Litres', flex: 3, bold: true),
          _cell('Rate', flex: 3, bold: true),
          _cell('₹', flex: 4, bold: true),
        ]),
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final litres = toD(day['litres']);
      final has = day['morning'] != null || day['evening'] != null;
      final row = Container(
        decoration: BoxDecoration(
          color: i.isEven ? Colors.white : kLightGreen,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFdddddd), width: 0.5)),
        ),
        child: Row(children: [
          _cell('${day['day']}', flex: 2, bold: true),
          _cell(day['morning'] == null ? '' : fmtNum(toD(day['morning'])),
              flex: 3),
          _cell(day['evening'] == null ? '' : fmtNum(toD(day['evening'])),
              flex: 3),
          _cell(has ? fmtNum(litres) : '', flex: 3),
          _cell(has ? fmtNum(toD(day['price'])) : '', flex: 3),
          _cell(has ? fmtNum(toD(day['amount'])) : '', flex: 4),
        ]),
      );
      rows.add(_isDist ? InkWell(onTap: () => _editDay(day), child: row) : row);
    }

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        header,
        ...rows,
        if (_isDist)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Tap a day to edit',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }

  Widget _paymentsSection(Map<String, dynamic> d) {
    final pays = (d['payments'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Payments / வரவு',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (_isDist)
                TextButton.icon(
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
            ]),
            if (pays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('No payments for this month.',
                    style: TextStyle(color: Colors.black54)),
              ),
            for (final p in pays)
              Row(children: [
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy')
                        .format(DateTime.parse(p['date'].toString())),
                  ),
                ),
                Text('₹${fmtNum(toD(p['amount']))}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (_isDist)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: kRed),
                    onPressed: () => _deletePayment(p),
                  )
                else
                  const SizedBox(height: 40),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _pricesSection(Map<String, dynamic> d) {
    final prices = (d['prices'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
        .reversed
        .toList(); // newest first
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Price per litre',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (_isDist)
                TextButton.icon(
                  onPressed: _changePrice,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change'),
                ),
            ]),
            for (final p in prices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'From ${DateFormat('dd MMM yyyy').format(DateTime.parse(p['effective_from'].toString()))}',
                    ),
                  ),
                  Text('₹${fmtNum(toD(p['price']))}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
