import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thermal_print/src/api/rts_client.dart';
import 'package:thermal_print/src/api/rts_models.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';
import 'package:thermal_print/src/print_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RtsClient.instance.init();
  runApp(const ThermalPosApp());
}

class ThermalPosApp extends StatelessWidget {
  const ThermalPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F6F4A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'POS Thermal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: RtsClient.instance.isLoggedIn ? const PosShell() : const LoginPage(),
    );
  }
}

Future<void> printReceipt(SaleReceipt receipt) async {
  await PrintBridge.instance.printText(formatSaleReceiptText(receipt));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _pin = TextEditingController();
  final _api = TextEditingController(text: RtsClient.instance.baseUrl);
  bool _busy = false;
  String? _error;
  bool _showApi = false;

  @override
  void dispose() {
    _pin.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RtsClient.instance.setBaseUrl(_api.text);
      await RtsClient.instance.posLogin(_pin.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PosShell()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('POS Terminal', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Sign in with POS PIN. Sales sync to RTS / Pyx Tracker.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'POS PIN',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _busy ? null : _login(),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showApi = !_showApi),
              child: Text(_showApi ? 'Hide API settings' : 'API settings'),
            ),
            if (_showApi) ...[
              TextField(
                controller: _api,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  border: OutlineInputBorder(),
                  helperText: 'Default: https://pyxtracker.pyxfood.com/rts/api/v1',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enter POS'),
            ),
          ],
        ),
      ),
    );
  }
}

class PosShell extends StatefulWidget {
  const PosShell({super.key});

  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> {
  int _index = 0;
  PrinterProfile _profile = const PrinterProfile();
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _refreshPrinter();
  }

  Future<void> _refreshPrinter() async {
    try {
      final profile = await PrintBridge.instance.getProfile();
      final status = await PrintBridge.instance.getStatus();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _connected = status['connected'] == true;
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await RtsClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SellPage(onPrinted: () => _snack('Receipt printed')),
      ArPage(onPrinted: () => _snack('AR receipt printed')),
      HistoryPage(onMessage: _snack),
      PrinterHub(
        profile: _profile,
        connected: _connected,
        onProfileChanged: (p) async {
          setState(() => _profile = p);
          await PrintBridge.instance.saveProfile(p);
          await _refreshPrinter();
        },
        onRefresh: _refreshPrinter,
      ),
      SettingsPage(
        profile: _profile,
        onSaveProfile: (p) async {
          setState(() => _profile = p);
          await PrintBridge.instance.saveProfile(p);
          _snack('Printer settings saved');
        },
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Sell'),
          NavigationDestination(icon: Icon(Icons.credit_score_outlined), selectedIcon: Icon(Icons.credit_score), label: 'AR'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: 'Printer'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class SellPage extends StatefulWidget {
  const SellPage({super.key, required this.onPrinted});
  final VoidCallback onPrinted;

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final _scan = TextEditingController();
  final _buyer = TextEditingController();
  final _seller = TextEditingController();
  final _lines = <CartLine>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RtsClient.instance.getDefaultSeller().then((s) {
      if (mounted && _seller.text.isEmpty) _seller.text = s;
    });
  }

  @override
  void dispose() {
    _scan.dispose();
    _buyer.dispose();
    _seller.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (a, b) => a + b.lineTotal);

  Future<void> _addCode() async {
    final code = _scan.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await RtsClient.instance.unifiedLookup(code);
      if (item.lookupKind == 'unique_honey' || item.lookupKind == 'unique_dept') {
        final exists = _lines.any((l) => l.lookup.unitId != null && l.lookup.unitId == item.unitId);
        if (exists) throw RtsException('That unit is already in the cart.');
        _lines.add(CartLine(lookup: item, qty: 1, unitPrice: item.suggestedPrice));
      } else {
        final idx = _lines.indexWhere((l) =>
            l.lookup.productId == item.productId &&
            l.lookup.lookupKind == item.lookupKind &&
            l.lookup.code == item.code);
        if (idx >= 0) {
          _lines[idx].qty += 1;
        } else {
          _lines.add(CartLine(lookup: item, qty: 1, unitPrice: item.suggestedPrice));
        }
      }
      _scan.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    if (_lines.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RtsClient.instance.setDefaultSeller(_seller.text);
      final items = _lines
          .map((l) => l.lookup.toCheckoutLine(qty: l.qty, listUnitPrice: l.unitPrice))
          .toList();
      final receipt = await RtsClient.instance.unifiedCheckout(
        buyerName: _buyer.text.trim(),
        sellerName: _seller.text.trim(),
        items: items,
      );
      try {
        await printReceipt(receipt);
        widget.onPrinted();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sale saved, but print failed: $e')),
          );
        }
      }
      setState(() {
        _lines.clear();
        _buyer.clear();
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sale complete'),
            content: Text('${receipt.receiptNo}\nTotal PHP ${receipt.total.toStringAsFixed(2)}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Sell', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          controller: _scan,
          decoration: InputDecoration(
            labelText: 'Scan / type barcode',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(onPressed: _busy ? null : _addCode, icon: const Icon(Icons.add)),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addCode(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _buyer,
          decoration: const InputDecoration(labelText: 'Customer name', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _seller,
          decoration: const InputDecoration(labelText: 'Seller name', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ..._lines.asMap().entries.map((e) {
          final i = e.key;
          final line = e.value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(line.title),
            subtitle: Text('PHP ${line.unitPrice.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (line.lookup.requiresQty || line.lookup.lookupKind == 'sku')
                  IconButton(
                    onPressed: () => setState(() {
                      if (line.qty > 1) {
                        line.qty -= 1;
                      } else {
                        _lines.removeAt(i);
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                Text('${line.qty}'),
                if (line.lookup.requiresQty || line.lookup.lookupKind == 'sku')
                  IconButton(
                    onPressed: () => setState(() => line.qty += 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                IconButton(
                  onPressed: () => setState(() => _lines.removeAt(i)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        const Divider(),
        Text('Total: PHP ${_total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy || _lines.isEmpty || _buyer.text.trim().isEmpty || _seller.text.trim().isEmpty
              ? null
              : _checkout,
          icon: const Icon(Icons.payments),
          label: Text(_busy ? 'Processing…' : 'Cash checkout & print'),
        ),
      ],
    );
  }
}

class ArPage extends StatefulWidget {
  const ArPage({super.key, required this.onPrinted});
  final VoidCallback onPrinted;

  @override
  State<ArPage> createState() => _ArPageState();
}

class _ArPageState extends State<ArPage> {
  final _scan = TextEditingController();
  final _debtor = TextEditingController();
  final _mobile = TextEditingController();
  final _seller = TextEditingController();
  final _lines = <CartLine>[];
  List<StaffMember> _staff = [];
  StaffMember? _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RtsClient.instance.getDefaultSeller().then((s) {
      if (mounted && _seller.text.isEmpty) _seller.text = s;
    });
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await RtsClient.instance.staffPicker();
      if (mounted) setState(() => _staff = staff);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scan.dispose();
    _debtor.dispose();
    _mobile.dispose();
    _seller.dispose();
    super.dispose();
  }

  Future<void> _addCode() async {
    final code = _scan.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await RtsClient.instance.unifiedLookup(code);
      _lines.add(CartLine(lookup: item, qty: 1, unitPrice: item.suggestedPrice));
      _scan.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _selected?.name ?? _debtor.text.trim();
      final items = _lines
          .map((l) => l.lookup.toCheckoutLine(qty: l.qty, listUnitPrice: l.unitPrice))
          .toList();
      final receipt = await RtsClient.instance.unifiedArCheckout(
        debtorName: name,
        sellerName: _seller.text.trim(),
        items: items,
        debtorUserId: _selected?.id,
        debtorMobile: _mobile.text.trim(),
      );
      try {
        await printReceipt(receipt);
        widget.onPrinted();
      } catch (_) {}
      setState(() {
        _lines.clear();
        _debtor.clear();
        _mobile.clear();
        _selected = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AR saved: ${receipt.receiptNo}')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtorOk = (_selected != null) || _debtor.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('AR Credit', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DropdownMenu<int?>(
          initialSelection: _selected?.id,
          label: const Text('Staff debtor'),
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: null, label: '— Manual name —'),
            ..._staff.map((s) => DropdownMenuEntry(
                  value: s.id,
                  label: '${s.name}${s.deptName != null ? ' (${s.deptName})' : ''}',
                )),
          ],
          onSelected: (id) => setState(() {
            if (id == null) {
              _selected = null;
            } else {
              _selected = _staff.firstWhere((s) => s.id == id);
              _debtor.text = _selected!.name;
            }
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _debtor,
          decoration: const InputDecoration(labelText: 'Debtor name', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mobile,
          decoration: const InputDecoration(labelText: 'Mobile (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _seller,
          decoration: const InputDecoration(labelText: 'Seller name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _scan,
          decoration: InputDecoration(
            labelText: 'Scan item',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(onPressed: _busy ? null : _addCode, icon: const Icon(Icons.add)),
          ),
          onSubmitted: (_) => _addCode(),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ..._lines.map((l) => ListTile(
              title: Text(l.title),
              trailing: Text('PHP ${l.lineTotal.toStringAsFixed(2)}'),
            )),
        FilledButton(
          onPressed: _busy || _lines.isEmpty || !debtorOk || _seller.text.trim().isEmpty ? null : _checkout,
          child: const Text('AR checkout & print'),
        ),
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.onMessage});
  final ValueChanged<String> onMessage;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<SaleReceipt> _rows = [];
  bool _busy = false;
  String? _error;
  String _period = 'day';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await RtsClient.instance.salesHistory(
        period: _period,
        receipt: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      final checkouts = data['checkouts'] as Map? ?? {};
      final rows = (checkouts['rows'] as List?) ?? const [];
      setState(() {
        _rows = rows
            .map((e) => SaleReceipt.fromHistoryRow(Map<dynamic, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reprint(SaleReceipt row) async {
    try {
      final full = await RtsClient.instance.receiptGet(row.saleId);
      await printReceipt(full);
      widget.onMessage('Reprinted ${full.receiptNo}');
    } catch (e) {
      widget.onMessage(e.toString());
    }
  }

  Future<void> _refund(SaleReceipt row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund sale?'),
        content: Text('Fully refund ${row.receiptNo}? Stock will be restocked and RTS will update.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Refund')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RtsClient.instance.saleRefund(row.saleId, reason: 'Mobile POS refund');
      widget.onMessage('Refunded ${row.receiptNo}');
      await _load();
    } catch (e) {
      widget.onMessage(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales history', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day', label: Text('Day')),
                  ButtonSegment(value: 'week', label: Text('Week')),
                  ButtonSegment(value: 'month', label: Text('Month')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  _load();
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search receipt',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.search)),
                ),
                onSubmitted: (_) => _load(),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                return Card(
                  child: ListTile(
                    title: Text(row.receiptNo),
                    subtitle: Text(
                      '${row.buyerName}\n${row.soldAt ?? ''}\nPHP ${row.total.toStringAsFixed(2)}'
                      '${row.isAr ? ' · AR' : ''}${row.refunded ? ' · REFUNDED' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'reprint') _reprint(row);
                        if (v == 'refund') _refund(row);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'reprint', child: Text('Reprint')),
                        if (!row.refunded)
                          const PopupMenuItem(value: 'refund', child: Text('Refund')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PrinterHub extends StatefulWidget {
  const PrinterHub({
    super.key,
    required this.profile,
    required this.connected,
    required this.onProfileChanged,
    required this.onRefresh,
  });

  final PrinterProfile profile;
  final bool connected;
  final ValueChanged<PrinterProfile> onProfileChanged;
  final Future<void> Function() onRefresh;

  @override
  State<PrinterHub> createState() => _PrinterHubState();
}

class _PrinterHubState extends State<PrinterHub> {
  String _transport = 'bluetooth';
  List<BtDevice> _bt = [];
  List<UsbDeviceInfo> _usb = [];
  final _host = TextEditingController();
  final _port = TextEditingController(text: '9100');
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _transport = widget.profile.transport;
    if (widget.profile.transport == 'tcp') {
      _host.text = widget.profile.address;
      _port.text = '${widget.profile.tcpPort}';
    }
    _reload();
  }

  Future<void> _ensurePerms() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _reload() async {
    try {
      await _ensurePerms();
      final bt = await PrintBridge.instance.listBluetoothDevices();
      final usb = await PrintBridge.instance.listUsbDevices();
      if (mounted) {
        setState(() {
          _bt = bt;
          _usb = usb;
        });
      }
    } catch (e) {
      setState(() => _msg = e.toString());
    }
  }

  Future<void> _run(Future<void> Function() fn, String ok) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await _ensurePerms();
      await fn();
      await widget.onRefresh();
      setState(() => _msg = ok);
    } on PlatformException catch (e) {
      setState(() => _msg = e.message ?? e.code);
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Printer', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        Text(widget.connected ? 'Connected' : 'Not connected'),
        Text(widget.profile.displayName.isNotEmpty
            ? widget.profile.displayName
            : (widget.profile.address.isNotEmpty ? widget.profile.address : 'No printer')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(() => PrintBridge.instance.printTest(), 'Test print sent'),
          child: const Text('Test print'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => PrintBridge.instance.connect(widget.profile), 'Connected'),
                child: const Text('Connect'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await PrintBridge.instance.disconnect();
                        }, 'Disconnected'),
                child: const Text('Disconnect'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'bluetooth', label: Text('BT')),
            ButtonSegment(value: 'usb', label: Text('USB')),
            ButtonSegment(value: 'tcp', label: Text('Wi‑Fi')),
          ],
          selected: {_transport},
          onSelectionChanged: (s) => setState(() => _transport = s.first),
        ),
        if (_transport == 'bluetooth') ...[
          ..._bt.map((d) => ListTile(
                title: Text(d.name),
                subtitle: Text(d.address),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final next = widget.profile.copyWith(
                            transport: 'bluetooth',
                            address: d.address,
                            displayName: d.name,
                          );
                          widget.onProfileChanged(next);
                          _run(() => PrintBridge.instance.connect(next), 'Connected');
                        },
                  child: const Text('Use'),
                ),
              )),
          TextButton(onPressed: _reload, child: const Text('Refresh Bluetooth')),
        ],
        if (_transport == 'usb') ...[
          ..._usb.map((d) => ListTile(
                title: Text(d.productName),
                subtitle: Text(d.deviceName),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final next = widget.profile.copyWith(
                            transport: 'usb',
                            address: d.deviceName,
                            displayName: d.productName,
                          );
                          widget.onProfileChanged(next);
                          _run(() => PrintBridge.instance.connect(next), 'Connected');
                        },
                  child: const Text('Use'),
                ),
              )),
          TextButton(onPressed: _reload, child: const Text('Refresh USB')),
        ],
        if (_transport == 'tcp') ...[
          TextField(controller: _host, decoration: const InputDecoration(labelText: 'Host IP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _port, decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    final next = widget.profile.copyWith(
                      transport: 'tcp',
                      address: _host.text.trim(),
                      displayName: _host.text.trim(),
                      tcpPort: int.tryParse(_port.text.trim()) ?? 9100,
                    );
                    widget.onProfileChanged(next);
                    _run(() => PrintBridge.instance.connect(next), 'Connected');
                  },
            child: const Text('Save & connect'),
          ),
        ],
        if (_msg != null) ...[
          const SizedBox(height: 12),
          Text(_msg!),
        ],
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.profile,
    required this.onSaveProfile,
    required this.onLogout,
  });

  final PrinterProfile profile;
  final ValueChanged<PrinterProfile> onSaveProfile;
  final VoidCallback onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _width = widget.profile.paperWidthMm;
  late String _graphics = widget.profile.graphicsCommand;
  late bool _autoCut = widget.profile.autoCut;
  final _api = TextEditingController(text: RtsClient.instance.baseUrl);
  final _seller = TextEditingController();

  @override
  void initState() {
    super.initState();
    RtsClient.instance.getDefaultSeller().then((s) {
      if (mounted) _seller.text = s;
    });
  }

  @override
  void dispose() {
    _api.dispose();
    _seller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = RtsClient.instance.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Signed in as ${user?.name ?? 'POS'}'),
        const SizedBox(height: 16),
        TextField(
          controller: _api,
          decoration: const InputDecoration(labelText: 'RTS API base URL', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _seller,
          decoration: const InputDecoration(labelText: 'Default seller name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () async {
            await RtsClient.instance.setBaseUrl(_api.text);
            await RtsClient.instance.setDefaultSeller(_seller.text);
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('API settings saved')),
            );
          },
          child: const Text('Save API / seller'),
        ),
        const SizedBox(height: 24),
        const Text('Paper width'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 58, label: Text('58mm')),
            ButtonSegment(value: 80, label: Text('80mm')),
          ],
          selected: {_width},
          onSelectionChanged: (s) => setState(() => _width = s.first),
        ),
        const SizedBox(height: 12),
        const Text('Graphics'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'gs_v_0', label: Text('GS v 0')),
            ButtonSegment(value: 'esc_star', label: Text('ESC *')),
          ],
          selected: {_graphics},
          onSelectionChanged: (s) => setState(() => _graphics = s.first),
        ),
        SwitchListTile(
          title: const Text('Auto cut'),
          value: _autoCut,
          onChanged: (v) => setState(() => _autoCut = v),
        ),
        FilledButton(
          onPressed: () {
            widget.onSaveProfile(widget.profile.copyWith(
              paperWidthMm: _width,
              graphicsCommand: _graphics,
              autoCut: _autoCut,
              dotsPerLine: _width >= 80 ? 576 : 384,
            ));
          },
          child: const Text('Save printer settings'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
