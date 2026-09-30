import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/dist_api_service.dart';
import '../theme.dart';
import 'dist_widgets.dart';
import 'home_screen.dart';

/// Distributor: list of customers with add / edit / price / reset / remove.
class DistCustomersScreen extends StatefulWidget {
  const DistCustomersScreen({super.key});

  @override
  State<DistCustomersScreen> createState() => _DistCustomersScreenState();
}

class _DistCustomersScreenState extends State<DistCustomersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DistApi.customerList();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _all;
    return _all
        .where((c) =>
            c['name'].toString().toLowerCase().contains(_q) ||
            c['phone_number'].toString().contains(_q))
        .toList();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? kRed : kGreen),
    );
  }

  Future<void> _add() async {
    await context.push('/dist-add-customer');
    if (mounted) _load();
  }

  Future<void> _openCard(Map<String, dynamic> c) async {
    await context.push('/dist-card', extra: {
      'customer_id': toInt(c['customer_id']),
      'name': c['name'].toString(),
    });
    if (mounted) _load();
  }

  Future<void> _onMenu(String action, Map<String, dynamic> c) async {
    final id = toInt(c['customer_id']);
    switch (action) {
      case 'price':
        final ok = await showPriceDialog(context, id,
            currentPrice:
                c['current_price'] == null ? null : toD(c['current_price']));
        if (ok && mounted) {
          _snack('Price updated');
          _load();
        }
        break;
      case 'edit':
        await _editDetails(c);
        break;
      case 'share':
        await _shareLogin(c);
        break;
      case 'remove':
        await _remove(c);
        break;
    }
  }

  Future<void> _editDetails(Map<String, dynamic> c) async {
    final canEditName = c['can_edit_name'] == true;
    final nameCtrl = TextEditingController(text: c['name'].toString());
    final addrCtrl =
        TextEditingController(text: (c['address'] ?? '').toString());
    String? err;
    bool saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  enabled: canEditName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    helperText: canEditName
                        ? null
                        : 'Name can be changed only by the distributor who created this account',
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  maxLines: 3,
                  maxLength: 255,
                  decoration:
                      const InputDecoration(labelText: 'Address (விலாசம்)'),
                ),
                if (err != null)
                  Text(err!,
                      style: const TextStyle(color: kRed, fontSize: 13)),
              ],
            ),
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
                      final name = nameCtrl.text.trim();
                      if (canEditName && name.isEmpty) {
                        setS(() => err = 'Name is required');
                        return;
                      }
                      setS(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await DistApi.updateCustomer(
                          toInt(c['customer_id']),
                          name: canEditName ? name : null,
                          address: addrCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setS(() {
                          saving = false;
                          err = errMsg(e);
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
      _snack('Customer updated');
      _load();
    }
  }

  /// The old password is stored as a hash and cannot be shown, so for accounts
  /// this distributor created we set a new password and share it. For any other
  /// account we only share the phone number and app link.
  Future<void> _shareLogin(Map<String, dynamic> c) async {
    final name = c['name'].toString();
    final phone = c['phone_number'].toString();

    if (c['can_reset_password'] != true) {
      await shareInvite(name: name, phone: phone);
      return;
    }

    final ctrl = TextEditingController(text: randomPassword());
    String? err;
    bool saving = false;
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Share login info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The old password is stored securely and cannot be shown. '
                'Set a new password to send to $name.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              if (err != null)
                Text(err!, style: const TextStyle(color: kRed, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final p = ctrl.text.trim();
                      if (p.length < 4) {
                        setS(() =>
                            err = 'Password must be at least 4 characters');
                        return;
                      }
                      setS(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await DistApi.resetPassword(toInt(c['customer_id']), p);
                        if (ctx.mounted) Navigator.pop(ctx, p);
                      } catch (e) {
                        setS(() {
                          saving = false;
                          err = errMsg(e);
                        });
                      }
                    },
              icon: const Icon(Icons.share),
              label: const Text('Save & Share'),
            ),
          ],
        ),
      ),
    );
    if (newPass == null || !mounted) return;
    await shareInvite(name: name, phone: phone, password: newPass);
  }

  Future<void> _remove(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove customer'),
        content: Text(
            'Remove ${c['name']} from your list? Their old records are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DistApi.removeCustomer(toInt(c['customer_id']));
      if (!mounted) return;
      _snack('Customer removed');
      _load();
    } catch (e) {
      if (mounted) _snack(errMsg(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MilkNoteAppBar(title: 'Customers'),
      bottomNavigationBar: const KeyboardAwareBanner(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name or phone',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
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
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(_all.isEmpty
            ? 'No customers yet. Tap Add.'
            : 'No customer matches your search.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88), // room for the FAB
        itemCount: list.length,
        itemBuilder: (_, i) {
          final c = list[i];
          final address = (c['address'] ?? '').toString();
          final price = c['current_price'] == null
              ? '—'
              : '₹${fmtNum(toD(c['current_price']))}/L';
          return Card(
            color: Colors.white,
            child: ListTile(
              onTap: () => _openCard(c),
              title: Text(c['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${c['phone_number']}  ·  $price'
                '${address.isEmpty ? '' : '\n$address'}',
              ),
              isThreeLine: address.isNotEmpty,
              trailing: PopupMenuButton<String>(
                onSelected: (v) => _onMenu(v, c),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'price', child: Text('Change price')),
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit name & address')),
                  const PopupMenuItem(
                      value: 'share', child: Text('Share login info')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
