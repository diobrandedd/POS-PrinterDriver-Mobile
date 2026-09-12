import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thermal_print/src/api/rts_client.dart';
import 'package:thermal_print/src/api/rts_models.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';
import 'package:thermal_print/src/pos/receipt_image.dart';
import 'package:thermal_print/src/print_bridge.dart';
import 'package:thermal_print/src/theme/pos_theme.dart';
import 'package:thermal_print/src/ui/pos_chrome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RtsClient.instance.init();
  runApp(const ThermalPosApp());
}

class ThermalPosApp extends StatelessWidget {
  const ThermalPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: posSystemUi,
      child: MaterialApp(
        title: 'Pyx POS',
        debugShowCheckedModeBanner: false,
        theme: buildPosTheme(),
        home: RtsClient.instance.isLoggedIn ? const PosShell() : const LoginPage(),
      ),
    );
  }
}

Future<void> printReceipt(SaleReceipt receipt) async {
  try {
    final png = await renderPosReceiptPng(receipt);
    await PrintBridge.instance.printImage(png);
  } catch (_) {
    await PrintBridge.instance.printText(formatSaleReceiptText(receipt));
  }
}

String get _staffName => RtsClient.instance.user?.name ?? 'Staff';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _api = TextEditingController(text: RtsClient.instance.baseUrl);
  bool _busy = false;
  bool _obscure = true;
  bool _showApi = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
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
      await RtsClient.instance.posStaffLogin(_user.text, _pass.text);
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: PosColors.forestSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.point_of_sale, color: PosColors.forest, size: 32),
                ),
                const SizedBox(height: 20),
                Text('Pyx POS', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Sign in with your staff account. Ask an executive to assign you under System Settings → Mobile POS staff.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _user,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  onSubmitted: (_) => _busy ? null : _login(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showApi = !_showApi),
                    child: Text(_showApi ? 'Hide API settings' : 'API settings'),
                  ),
                ),
                if (_showApi) ...[
                  TextField(
                    controller: _api,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      helperText: 'Default: https://pyxtracker.pyxfood.com/rts/api/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  PosErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enter POS'),
                ),
              ],
            ),
          ),
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
      SettingsPage(
        profile: _profile,
        connected: _connected,
        onProfileChanged: (p) async {
          setState(() => _profile = p);
          await PrintBridge.instance.saveProfile(p);
          await _refreshPrinter();
        },
        onRefreshPrinter: _refreshPrinter,
        onSavePaper: (p) async {
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
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_score_outlined),
            selectedIcon: Icon(Icons.credit_score),
            label: 'AR',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
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
  final _buyer = TextEditingController();
  final _lines = <CartLine>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptAdd();
    });
  }

  @override
  void dispose() {
    _buyer.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (a, b) => a + b.lineTotal);

  Future<void> _promptAdd() async {
    final code = await promptProductCode(context);
    if (code == null || !mounted) return;
    await _addCode(code);
  }

  Future<void> _addCode(String code) async {
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
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout(int discountPercent) async {
    if (_lines.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final seller = _staffName;
      final items = _lines
          .map((l) => l.lookup.toCheckoutLine(qty: l.qty, listUnitPrice: l.unitPrice))
          .toList();
      final receipt = await RtsClient.instance.unifiedCheckout(
        buyerName: _buyer.text.trim(),
        sellerName: seller,
        items: items,
        discountPercent: discountPercent,
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
            content: Text('${receipt.receiptNo}\nTotal ₱${receipt.total.toStringAsFixed(2)}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        if (mounted) _promptAdd();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCheckout = !_busy && _lines.isNotEmpty && _buyer.text.trim().isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: PosScrollPage(
            title: 'Sell',
            subtitle: 'Scan products, then checkout. Seller: $_staffName',
            trailing: StaffChip(name: _staffName),
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _promptAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyer,
                decoration: const InputDecoration(
                  labelText: 'Sold to',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                PosErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              if (_lines.isEmpty)
                const PosEmptyHint(
                  icon: Icons.qr_code_scanner,
                  title: 'Cart is empty',
                  body: 'Tap Add product to scan or type a barcode.',
                )
              else
                PosPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CartTile(
                          line: _lines[i],
                          onRemove: () => setState(() => _lines.removeAt(i)),
                          onDec: () => setState(() {
                            if (_lines[i].qty > 1) {
                              _lines[i].qty -= 1;
                            } else {
                              _lines.removeAt(i);
                            }
                          }),
                          onInc: () => setState(() => _lines[i].qty += 1),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 88),
            ],
          ),
        ),
        CheckoutBar(
          subtotal: _total,
          enabled: canCheckout,
          busy: _busy,
          onFull: () => _checkout(0),
          onTen: () => _checkout(10),
          onTwenty: () => _checkout(20),
        ),
      ],
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.line,
    required this.onRemove,
    required this.onDec,
    required this.onInc,
  });

  final CartLine line;
  final VoidCallback onRemove;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    final qtyEditable = line.lookup.requiresQty || line.lookup.lookupKind == 'sku';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      title: Text(line.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: MoneyText(line.unitPrice, style: Theme.of(context).textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qtyEditable)
            IconButton(onPressed: onDec, icon: const Icon(Icons.remove_circle_outline), visualDensity: VisualDensity.compact),
          Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (qtyEditable)
            IconButton(onPressed: onInc, icon: const Icon(Icons.add_circle_outline), visualDensity: VisualDensity.compact),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), visualDensity: VisualDensity.compact),
        ],
      ),
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
  final _debtor = TextEditingController();
  final _mobile = TextEditingController();
  final _lines = <CartLine>[];
  List<StaffMember> _staff = [];
  StaffMember? _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptAdd();
    });
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await RtsClient.instance.staffPicker();
      if (mounted) setState(() => _staff = staff);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debtor.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _promptAdd() async {
    final code = await promptProductCode(context, title: 'Add AR item');
    if (code == null || !mounted) return;
    await _addCode(code);
  }

  Future<void> _addCode(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await RtsClient.instance.unifiedLookup(code);
      _lines.add(CartLine(lookup: item, qty: 1, unitPrice: item.suggestedPrice));
      setState(() {});
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
        sellerName: _staffName,
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
    final total = _lines.fold(0.0, (a, b) => a + b.lineTotal);
    return PosScrollPage(
      title: 'AR credit',
      subtitle: 'Record charge to staff or walk-in debtor. Seller: $_staffName',
      trailing: StaffChip(name: _staffName),
      children: [
        DropdownMenu<int?>(
          initialSelection: _selected?.id,
          label: const Text('Staff debtor'),
          expandedInsets: EdgeInsets.zero,
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
        const SizedBox(height: 12),
        TextField(
          controller: _debtor,
          decoration: const InputDecoration(labelText: 'Debtor name', prefixIcon: Icon(Icons.badge_outlined)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mobile,
          decoration: const InputDecoration(labelText: 'Mobile (optional)', prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _promptAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          PosErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        if (_lines.isEmpty)
          const PosEmptyHint(
            icon: Icons.credit_score_outlined,
            title: 'No AR items yet',
            body: 'Add scanned products, then record the credit.',
          )
        else
          PosPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final l in _lines)
                  ListTile(
                    title: Text(l.title),
                    trailing: MoneyText(l.lineTotal),
                  ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: MoneyText(total, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || _lines.isEmpty || !debtorOk ? null : _checkout,
          style: FilledButton.styleFrom(backgroundColor: PosColors.gold),
          child: Text(_busy ? 'Saving…' : 'AR checkout & print'),
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
        content: Text(
          'Fully refund ${row.receiptNo}? Items return to packaging / finished inventory.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RtsClient.instance.saleRefund(row.saleId, reason: 'Mobile POS refund');
      if (mounted) Navigator.of(context).pop();
      widget.onMessage('Refunded ${row.receiptNo}');
      await _load();
    } catch (e) {
      widget.onMessage(e.toString());
    }
  }

  Future<void> _openDetail(SaleReceipt row) async {
    SaleReceipt detail = row;
    try {
      detail = await RtsClient.instance.receiptGet(row.saleId);
    } catch (_) {}
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.85;
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(detail.receiptNo, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (detail.soldAt != null && detail.soldAt!.isNotEmpty) detail.soldAt!,
                      if (detail.isAr) 'AR credit',
                      if (detail.refunded) 'REFUNDED',
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Buyer', detail.buyerName),
                  _detailRow('Seller', detail.sellerName),
                  if (detail.debtorMobile != null && detail.debtorMobile!.isNotEmpty)
                    _detailRow('Mobile', detail.debtorMobile!),
                  const Divider(height: 28),
                  Text('Items', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: detail.items.isEmpty
                        ? Text('No line items.', style: Theme.of(ctx).textTheme.bodySmall)
                        : ListView.separated(
                            itemCount: detail.items.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = detail.items[i];
                              final qty = item.qty == item.qty.roundToDouble()
                                  ? item.qty.toInt().toString()
                                  : item.qty.toStringAsFixed(2);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.name),
                                subtitle: Text('$qty × ₱${item.unitPrice.toStringAsFixed(2)}'),
                                trailing: Text(
                                  '₱${item.lineTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 24),
                  if (detail.subtotal != null)
                    _detailRow('Subtotal', '₱${detail.subtotal!.toStringAsFixed(2)}'),
                  if (detail.discountPercent != null && detail.discountPercent! > 0)
                    _detailRow(
                      'Discount (${detail.discountPercent}%)',
                      '-₱${(detail.discountAmount ?? 0).toStringAsFixed(2)}',
                    ),
                  _detailRow('TOTAL', '₱${detail.total.toStringAsFixed(2)}', emphasize: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reprint(detail),
                          icon: const Icon(Icons.print),
                          label: const Text('Reprint'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: detail.refunded ? null : () => _refund(detail),
                          icon: const Icon(Icons.undo),
                          label: Text(detail.refunded ? 'Refunded' : 'Refund'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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
              Text('History', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Tap a sale to reprint or refund.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
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
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search receipt',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
                ),
                onSubmitted: (_) => _load(),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PosErrorBanner(message: _error!),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _rows.isEmpty && !_busy
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: const [
                      PosEmptyHint(
                        icon: Icons.receipt_long_outlined,
                        title: 'No sales in this period',
                        body: 'Completed checkouts will show up here for reprint and refund.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final row = _rows[i];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openDetail(row),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: PosColors.line),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row.receiptNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            row.buyerName,
                                            if (row.soldAt != null) row.soldAt!,
                                            if (row.isAr) 'AR',
                                            if (row.refunded) 'Refunded',
                                          ].join(' · '),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  MoneyText(row.total),
                                  const Icon(Icons.chevron_right, color: PosColors.muted),
                                ],
                              ),
                            ),
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
    this.embedded = false,
  });

  final PrinterProfile profile;
  final bool connected;
  final ValueChanged<PrinterProfile> onProfileChanged;
  final Future<void> Function() onRefresh;
  final bool embedded;

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
    final body = <Widget>[
      Row(
        children: [
          StatusPill(label: widget.connected ? 'Connected' : 'Not connected', ok: widget.connected),
          const Spacer(),
          Text(
            widget.profile.displayName.isNotEmpty
                ? widget.profile.displayName
                : (widget.profile.address.isNotEmpty ? widget.profile.address : 'No printer'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy ? null : () => _run(() => PrintBridge.instance.printTest(), 'Test print sent'),
        child: const Text('Test print'),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => PrintBridge.instance.connect(widget.profile), 'Connected'),
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
      const SizedBox(height: 8),
      if (_transport == 'bluetooth') ...[
        ..._bt.map((d) => ListTile(
              contentPadding: EdgeInsets.zero,
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
              contentPadding: EdgeInsets.zero,
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
        TextField(controller: _host, decoration: const InputDecoration(labelText: 'Host IP')),
        const SizedBox(height: 8),
        TextField(controller: _port, decoration: const InputDecoration(labelText: 'Port')),
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
        Text(_msg!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ];

    if (widget.embedded) {
      return PosPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body));
    }

    return PosScrollPage(
      title: 'Printer',
      subtitle: 'Connection and transport',
      children: body,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.profile,
    required this.connected,
    required this.onProfileChanged,
    required this.onRefreshPrinter,
    required this.onSavePaper,
    required this.onLogout,
  });

  final PrinterProfile profile;
  final bool connected;
  final ValueChanged<PrinterProfile> onProfileChanged;
  final Future<void> Function() onRefreshPrinter;
  final ValueChanged<PrinterProfile> onSavePaper;
  final VoidCallback onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _width = widget.profile.paperWidthMm;
  late String _graphics = widget.profile.graphicsCommand;
  late bool _autoCut = widget.profile.autoCut;
  final _api = TextEditingController(text: RtsClient.instance.baseUrl);

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _width = widget.profile.paperWidthMm;
      _graphics = widget.profile.graphicsCommand;
      _autoCut = widget.profile.autoCut;
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = RtsClient.instance.user;
    return PosScrollPage(
      title: 'Settings',
      subtitle: 'Signed in as ${user?.name ?? 'POS'}',
      trailing: StaffChip(name: user?.name ?? 'POS'),
      children: [
        PosSection(
          title: 'Connection',
          subtitle: 'RTS / Pyx Tracker API',
          child: PosPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _api,
                  decoration: const InputDecoration(labelText: 'API base URL'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    await RtsClient.instance.setBaseUrl(_api.text);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('API settings saved')),
                    );
                  },
                  child: const Text('Save API'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        PosSection(
          title: 'Printer settings',
          subtitle: 'Connect your thermal printer and set paper options',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrinterHub(
                embedded: true,
                profile: widget.profile,
                connected: widget.connected,
                onProfileChanged: widget.onProfileChanged,
                onRefresh: widget.onRefreshPrinter,
              ),
              const SizedBox(height: 12),
              PosPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Paper width', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 58, label: Text('58mm')),
                        ButtonSegment(value: 80, label: Text('80mm')),
                      ],
                      selected: {_width},
                      onSelectionChanged: (s) => setState(() => _width = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text('Graphics', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'gs_v_0', label: Text('GS v 0')),
                        ButtonSegment(value: 'esc_star', label: Text('ESC *')),
                      ],
                      selected: {_graphics},
                      onSelectionChanged: (s) => setState(() => _graphics = s.first),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto cut'),
                      value: _autoCut,
                      onChanged: (v) => setState(() => _autoCut = v),
                    ),
                    FilledButton(
                      onPressed: () {
                        widget.onSavePaper(widget.profile.copyWith(
                          paperWidthMm: _width,
                          graphicsCommand: _graphics,
                          autoCut: _autoCut,
                          dotsPerLine: _width >= 80 ? 576 : 384,
                        ));
                      },
                      child: const Text('Save paper settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
