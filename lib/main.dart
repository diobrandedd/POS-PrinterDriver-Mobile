import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thermal_print/src/print_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThermalPrintApp());
}

class ThermalPrintApp extends StatelessWidget {
  const ThermalPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F6F4A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Thermal Print',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: base,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: base.surface,
          foregroundColor: base.onSurface,
          elevation: 0,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  PrinterProfile _profile = const PrinterProfile();
  bool _connected = false;
  bool _busy = false;
  String? _statusMessage;
  StreamSubscription<IncomingPrint>? _incomingSub;
  IncomingPrint? _pending;

  @override
  void initState() {
    super.initState();
    _refresh();
    _incomingSub = PrintBridge.instance.incoming.listen(_onIncoming);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final profile = await PrintBridge.instance.getProfile();
      final status = await PrintBridge.instance.getStatus();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _connected = status['connected'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = e.toString());
    }
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    final denied = statuses.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    );
    return !denied || await Permission.bluetoothConnect.isGranted;
  }

  Future<void> _run(Future<void> Function() action, {String? okMessage}) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _ensurePermissions();
      await action();
      await _refresh();
      if (!mounted) return;
      setState(() => _statusMessage = okMessage ?? 'Done');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = e.message ?? e.code);
      _snack(e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = e.toString());
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onIncoming(IncomingPrint job) async {
    if (job.autoPrint) {
      await _printIncoming(job);
      return;
    }
    if (!mounted) return;
    setState(() {
      _pending = job;
      _index = 3;
    });
  }

  Future<void> _printIncoming(IncomingPrint job) async {
    await _run(() async {
      switch (job.kind) {
        case 'text':
          await PrintBridge.instance.printText(job.text ?? '');
        case 'textUri':
        case 'image':
        case 'pdf':
        case 'uri':
          if (job.uri == null) throw Exception('Missing content URI');
          await PrintBridge.instance.printUri(job.uri!, mimeType: job.mimeType);
        case 'imageBytes':
          if (job.bytes == null) throw Exception('Missing image bytes');
          await PrintBridge.instance.printImage(job.bytes!);
        case 'pdfBytes':
          if (job.bytes == null) throw Exception('Missing PDF bytes');
          await PrintBridge.instance.printPdf(job.bytes!);
        case 'raw':
          if (job.base64 == null) throw Exception('Missing raw data');
          await PrintBridge.instance.printBase64(job.base64!);
        default:
          if (job.text != null) {
            await PrintBridge.instance.printText(job.text!);
          } else if (job.uri != null) {
            await PrintBridge.instance.printUri(job.uri!, mimeType: job.mimeType);
          } else {
            throw Exception('Unsupported share payload');
          }
      }
      if (mounted) setState(() => _pending = null);
    }, okMessage: 'Printed ${job.previewLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        profile: _profile,
        connected: _connected,
        busy: _busy,
        statusMessage: _statusMessage,
        onRefresh: _refresh,
        onConnect: () => _run(() async {
          await PrintBridge.instance.connect(_profile);
        }, okMessage: 'Connected'),
        onDisconnect: () => _run(() async {
          await PrintBridge.instance.disconnect();
        }, okMessage: 'Disconnected'),
        onTestPrint: () => _run(() async {
          await PrintBridge.instance.printTest();
        }, okMessage: 'Test print sent'),
        onOpenPrinters: () => setState(() => _index = 1),
      ),
      PrintersPage(
        profile: _profile,
        busy: _busy,
        onChanged: (p) async {
          setState(() => _profile = p);
          await PrintBridge.instance.saveProfile(p);
          await _refresh();
        },
        onConnect: (p) => _run(() async {
          setState(() => _profile = p);
          await PrintBridge.instance.connect(p);
        }, okMessage: 'Connected to printer'),
        ensurePermissions: _ensurePermissions,
      ),
      SettingsPage(
        profile: _profile,
        onSave: (p) async {
          setState(() => _profile = p);
          await PrintBridge.instance.saveProfile(p);
          _snack('Settings saved');
          await _refresh();
        },
      ),
      PreviewPage(
        pending: _pending,
        busy: _busy,
        onPrint: _pending == null ? null : () => _printIncoming(_pending!),
        onClear: () => setState(() => _pending = null),
        onPrintText: (text) => _run(() async {
          await PrintBridge.instance.printText(text);
        }, okMessage: 'Printed text'),
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: 'Printers'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.preview_outlined), selectedIcon: Icon(Icons.preview), label: 'Preview'),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.profile,
    required this.connected,
    required this.busy,
    required this.statusMessage,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTestPrint,
    required this.onOpenPrinters,
  });

  final PrinterProfile profile;
  final bool connected;
  final bool busy;
  final String? statusMessage;
  final VoidCallback onRefresh;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onTestPrint;
  final VoidCallback onOpenPrinters;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : (profile.address.isNotEmpty ? profile.address : 'No printer selected');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Thermal Print',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Personal ESC/POS driver — no watermark',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: connected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      connected ? 'Connected' : 'Not connected',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(name),
                const SizedBox(height: 4),
                Text(
                  '${profile.transport.toUpperCase()} · ${profile.paperWidthMm}mm · ${profile.graphicsCommand}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : onTestPrint,
          icon: const Icon(Icons.receipt_long),
          label: const Text('Test print'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onConnect,
                child: const Text('Connect'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onDisconnect,
                child: const Text('Disconnect'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onOpenPrinters,
          child: const Text('Choose Bluetooth / USB / Network printer'),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (statusMessage != null) ...[
          const SizedBox(height: 16),
          Text(statusMessage!),
        ],
        const SizedBox(height: 24),
        Text(
          'Tips',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('1. Pair your KJ-5802H (or any ESC/POS printer) in Android Bluetooth settings.'),
        const Text('2. Select it under Printers, then tap Test print.'),
        const Text('3. Enable Thermal Print in Settings → Connected devices → Printing.'),
        const Text('4. Share images/PDFs/text to this app, or use thermalprint: URIs.'),
      ],
    );
  }
}

class PrintersPage extends StatefulWidget {
  const PrintersPage({
    super.key,
    required this.profile,
    required this.busy,
    required this.onChanged,
    required this.onConnect,
    required this.ensurePermissions,
  });

  final PrinterProfile profile;
  final bool busy;
  final ValueChanged<PrinterProfile> onChanged;
  final ValueChanged<PrinterProfile> onConnect;
  final Future<bool> Function() ensurePermissions;

  @override
  State<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends State<PrintersPage> {
  late String _transport = widget.profile.transport;
  List<BtDevice> _bt = [];
  List<UsbDeviceInfo> _usb = [];
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  String? _error;

  @override
  void initState() {
    super.initState();
    _hostCtrl.text = widget.profile.transport == 'tcp' ? widget.profile.address : '';
    _portCtrl.text = '${widget.profile.tcpPort}';
    _reload();
  }

  @override
  void didUpdateWidget(covariant PrintersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _transport = widget.profile.transport;
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      await widget.ensurePermissions();
      final bt = await PrintBridge.instance.listBluetoothDevices();
      final usb = await PrintBridge.instance.listUsbDevices();
      if (!mounted) return;
      setState(() {
        _bt = bt;
        _usb = usb;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text('Printers', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'bluetooth', label: Text('Bluetooth'), icon: Icon(Icons.bluetooth)),
            ButtonSegment(value: 'usb', label: Text('USB'), icon: Icon(Icons.usb)),
            ButtonSegment(value: 'tcp', label: Text('Wi‑Fi'), icon: Icon(Icons.wifi)),
          ],
          selected: {_transport},
          onSelectionChanged: (s) => setState(() => _transport = s.first),
        ),
        const SizedBox(height: 12),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_transport == 'bluetooth') ...[
          Row(
            children: [
              const Expanded(child: Text('Paired Bluetooth devices')),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_bt.isEmpty)
            const Text('No bonded devices. Pair the printer in Android Settings first.')
          else
            ..._bt.map((d) {
              final selected = widget.profile.address == d.address && widget.profile.transport == 'bluetooth';
              return ListTile(
                leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(d.name),
                subtitle: Text(d.address),
                onTap: () {
                  final next = widget.profile.copyWith(
                    transport: 'bluetooth',
                    address: d.address,
                    displayName: d.name,
                  );
                  widget.onChanged(next);
                },
                trailing: TextButton(
                  onPressed: widget.busy
                      ? null
                      : () {
                          final next = widget.profile.copyWith(
                            transport: 'bluetooth',
                            address: d.address,
                            displayName: d.name,
                          );
                          widget.onConnect(next);
                        },
                  child: const Text('Connect'),
                ),
              );
            }),
        ],
        if (_transport == 'usb') ...[
          Row(
            children: [
              const Expanded(child: Text('USB devices')),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_usb.isEmpty)
            const Text('No USB printers detected. Use an OTG cable if needed.')
          else
            ..._usb.map((d) {
              final selected = widget.profile.address == d.deviceName && widget.profile.transport == 'usb';
              return ListTile(
                leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(d.productName),
                subtitle: Text('${d.deviceName}\nVID ${d.vendorId} / PID ${d.productId}'),
                isThreeLine: true,
                onTap: () {
                  final next = widget.profile.copyWith(
                    transport: 'usb',
                    address: d.deviceName,
                    displayName: d.productName,
                  );
                  widget.onChanged(next);
                },
                trailing: TextButton(
                  onPressed: widget.busy
                      ? null
                      : () {
                          final next = widget.profile.copyWith(
                            transport: 'usb',
                            address: d.deviceName,
                            displayName: d.productName,
                          );
                          widget.onConnect(next);
                        },
                  child: const Text('Connect'),
                ),
              );
            }),
        ],
        if (_transport == 'tcp') ...[
          const Text('Network printer (AppSocket / port 9100)'),
          const SizedBox(height: 8),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'IP address / host',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portCtrl,
            decoration: const InputDecoration(
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () {
                    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
                    final next = widget.profile.copyWith(
                      transport: 'tcp',
                      address: _hostCtrl.text.trim(),
                      displayName: _hostCtrl.text.trim(),
                      tcpPort: port,
                    );
                    widget.onConnect(next);
                  },
            child: const Text('Save & connect'),
          ),
        ],
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.profile, required this.onSave});

  final PrinterProfile profile;
  final ValueChanged<PrinterProfile> onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _width = widget.profile.paperWidthMm;
  late String _graphics = widget.profile.graphicsCommand;
  late bool _autoCut = widget.profile.autoCut;
  late String _codePage = widget.profile.codePage;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _width = widget.profile.paperWidthMm;
      _graphics = widget.profile.graphicsCommand;
      _autoCut = widget.profile.autoCut;
      _codePage = widget.profile.codePage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        const Text('Paper width'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 58, label: Text('58mm (384)')),
            ButtonSegment(value: 80, label: Text('80mm (576)')),
          ],
          selected: {_width},
          onSelectionChanged: (s) => setState(() => _width = s.first),
        ),
        const SizedBox(height: 16),
        const Text('Graphics command'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'gs_v_0', label: Text('GS v 0')),
            ButtonSegment(value: 'esc_star', label: Text('ESC *')),
          ],
          selected: {_graphics},
          onSelectionChanged: (s) => setState(() => _graphics = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          _graphics == 'esc_star'
              ? 'Epson-style bit-image mode'
              : 'Best for most 58mm clones including KJ-5802H',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SwitchListTile(
          title: const Text('Auto cut'),
          value: _autoCut,
          onChanged: (v) => setState(() => _autoCut = v),
        ),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          initialSelection: _codePage,
          label: const Text('Text code page'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'CP437', label: 'CP437'),
            DropdownMenuEntry(value: 'CP850', label: 'CP850'),
            DropdownMenuEntry(value: 'CP858', label: 'CP858'),
            DropdownMenuEntry(value: 'CP866', label: 'CP866'),
            DropdownMenuEntry(value: 'windows-1252', label: 'Windows-1252'),
            DropdownMenuEntry(value: 'UTF-8', label: 'UTF-8'),
          ],
          onSelected: (v) {
            if (v != null) setState(() => _codePage = v);
          },
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.onSave(
              widget.profile.copyWith(
                paperWidthMm: _width,
                graphicsCommand: _graphics,
                autoCut: _autoCut,
                codePage: _codePage,
                dotsPerLine: _width >= 80 ? 576 : 384,
              ),
            );
          },
          child: const Text('Save settings'),
        ),
        const SizedBox(height: 16),
        Text(
          'System print: enable “Thermal Print” under Android Settings → Connected devices → Connection preferences → Printing.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({
    super.key,
    required this.pending,
    required this.busy,
    required this.onPrint,
    required this.onClear,
    required this.onPrintText,
  });

  final IncomingPrint? pending;
  final bool busy;
  final VoidCallback? onPrint;
  final VoidCallback onClear;
  final ValueChanged<String> onPrintText;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text('Preview / Share', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Shared files and thermalprint: links land here.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (pending == null)
          const Text('Nothing queued. Share an image, PDF, or text to Thermal Print.')
        else ...[
          Card(
            child: ListTile(
              title: Text(pending.previewLabel),
              subtitle: Text(
                () {
                  final text = pending.text;
                  if (text != null && text.isNotEmpty) {
                    return text.length <= 160 ? text : '${text.substring(0, 160)}…';
                  }
                  return pending.uri ?? pending.mimeType ?? 'Ready to print';
                }(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: widget.busy ? null : widget.onPrint,
            icon: const Icon(Icons.print),
            label: const Text('Print shared content'),
          ),
          TextButton(onPressed: widget.onClear, child: const Text('Clear')),
        ],
        const SizedBox(height: 24),
        const Text('Quick text print'),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type receipt text…',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.busy || _textCtrl.text.trim().isEmpty
              ? null
              : () => widget.onPrintText(_textCtrl.text),
          child: const Text('Print text'),
        ),
        const SizedBox(height: 24),
        Text('URI API examples', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(
          'thermalprint:text,${Uri.encodeComponent('Hello from Thermal Print')}\n'
          'thermalprint:base64,${base64Encode(utf8.encode('Hello raw\\n'))}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
