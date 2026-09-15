import 'dart:convert';

import 'package:flutter/services.dart';

class PrinterProfile {
  const PrinterProfile({
    this.transport = 'bluetooth',
    this.address = '',
    this.displayName = '',
    this.paperWidthMm = 58,
    this.graphicsCommand = 'gs_v_0',
    this.autoCut = true,
    this.codePage = 'CP437',
    this.tcpPort = 9100,
    this.dotsPerLine = 384,
  });

  final String transport;
  final String address;
  final String displayName;
  final int paperWidthMm;
  final String graphicsCommand;
  final bool autoCut;
  final String codePage;
  final int tcpPort;
  final int dotsPerLine;

  bool get isConfigured => address.trim().isNotEmpty || transport == 'usb';

  PrinterProfile copyWith({
    String? transport,
    String? address,
    String? displayName,
    int? paperWidthMm,
    String? graphicsCommand,
    bool? autoCut,
    String? codePage,
    int? tcpPort,
    int? dotsPerLine,
  }) {
    return PrinterProfile(
      transport: transport ?? this.transport,
      address: address ?? this.address,
      displayName: displayName ?? this.displayName,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      graphicsCommand: graphicsCommand ?? this.graphicsCommand,
      autoCut: autoCut ?? this.autoCut,
      codePage: codePage ?? this.codePage,
      tcpPort: tcpPort ?? this.tcpPort,
      dotsPerLine: dotsPerLine ?? this.dotsPerLine,
    );
  }

  Map<String, Object?> toMap() => {
        'transport': transport,
        'address': address,
        'displayName': displayName,
        'paperWidthMm': paperWidthMm,
        'graphicsCommand': graphicsCommand,
        'autoCut': autoCut,
        'codePage': codePage,
        'tcpPort': tcpPort,
      };

  factory PrinterProfile.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const PrinterProfile();
    return PrinterProfile(
      transport: map['transport'] as String? ?? 'bluetooth',
      address: map['address'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      paperWidthMm: (map['paperWidthMm'] as num?)?.toInt() ?? 58,
      graphicsCommand: map['graphicsCommand'] as String? ?? 'gs_v_0',
      autoCut: map['autoCut'] as bool? ?? true,
      codePage: map['codePage'] as String? ?? 'CP437',
      tcpPort: (map['tcpPort'] as num?)?.toInt() ?? 9100,
      dotsPerLine: (map['dotsPerLine'] as num?)?.toInt() ?? 384,
    );
  }
}

class BtDevice {
  const BtDevice({required this.name, required this.address});
  final String name;
  final String address;

  factory BtDevice.fromMap(Map<dynamic, dynamic> map) => BtDevice(
        name: map['name'] as String? ?? 'Unknown',
        address: map['address'] as String? ?? '',
      );
}

class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.deviceName,
    required this.productName,
    required this.vendorId,
    required this.productId,
    required this.hasPermission,
  });

  final String deviceName;
  final String productName;
  final int vendorId;
  final int productId;
  final bool hasPermission;

  factory UsbDeviceInfo.fromMap(Map<dynamic, dynamic> map) => UsbDeviceInfo(
        deviceName: map['deviceName'] as String? ?? '',
        productName: map['productName'] as String? ?? 'USB printer',
        vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
        productId: (map['productId'] as num?)?.toInt() ?? 0,
        hasPermission: map['hasPermission'] as bool? ?? false,
      );
}

class IncomingPrint {
  IncomingPrint({
    required this.kind,
    this.text,
    this.uri,
    this.mimeType,
    this.base64,
    this.bytes,
    this.autoPrint = false,
  });

  final String kind;
  final String? text;
  final String? uri;
  final String? mimeType;
  final String? base64;
  final Uint8List? bytes;
  final bool autoPrint;

  factory IncomingPrint.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? bytes;
    final b64 = map['bytesBase64'] as String?;
    if (b64 != null) {
      bytes = base64Decode(b64);
    }
    return IncomingPrint(
      kind: map['kind'] as String? ?? 'text',
      text: map['text'] as String?,
      uri: map['uri'] as String?,
      mimeType: map['mimeType'] as String?,
      base64: map['base64'] as String?,
      bytes: bytes,
      autoPrint: map['autoPrint'] as bool? ?? false,
    );
  }

  String get previewLabel {
    switch (kind) {
      case 'image':
      case 'imageBytes':
        return 'Image';
      case 'pdf':
      case 'pdfBytes':
        return 'PDF';
      case 'raw':
        return 'ESC/POS bytes';
      case 'textUri':
        return 'Text file';
      default:
        return 'Text';
    }
  }
}

class PrintBridge {
  PrintBridge._();
  static final PrintBridge instance = PrintBridge._();

  static const _channel = MethodChannel('com.personal.thermal_print/printer');
  static const _events = EventChannel('com.personal.thermal_print/incoming');

  Stream<IncomingPrint> get incoming =>
      _events.receiveBroadcastStream().map((event) {
        return IncomingPrint.fromMap(Map<dynamic, dynamic>.from(event as Map));
      });

  Future<PrinterProfile> getProfile() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getProfile');
    return PrinterProfile.fromMap(map);
  }

  Future<PrinterProfile> saveProfile(PrinterProfile profile) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'saveProfile',
      profile.toMap(),
    );
    return PrinterProfile.fromMap(map);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    return Map<String, dynamic>.from(map ?? {});
  }

  Future<List<BtDevice>> listBluetoothDevices() async {
    final list = await _channel.invokeMethod<List<dynamic>>('listBluetoothDevices');
    return (list ?? [])
        .map((e) => BtDevice.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<UsbDeviceInfo>> listUsbDevices() async {
    final list = await _channel.invokeMethod<List<dynamic>>('listUsbDevices');
    return (list ?? [])
        .map((e) => UsbDeviceInfo.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> connect([PrinterProfile? profile]) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'connect',
      profile?.toMap(),
    );
    return Map<String, dynamic>.from(map ?? {});
  }

  Future<Map<String, dynamic>> disconnect() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('disconnect');
    return Map<String, dynamic>.from(map ?? {});
  }

  Future<void> printTest() => _channel.invokeMethod<void>('printTest');

  /// Pulse the cash drawer via ESC/POS `ESC p` on the connected printer.
  /// [pin] 0 = drawer kick pin 2 (default), 1 = pin 5.
  Future<void> openCashDrawer({int pin = 0}) =>
      _channel.invokeMethod<void>('openCashDrawer', {'pin': pin});

  Future<void> printText(String text) =>
      _channel.invokeMethod<void>('printText', {'text': text});

  Future<void> printImage(Uint8List bytes) =>
      _channel.invokeMethod<void>('printImage', {'bytes': bytes});

  Future<void> printPdf(Uint8List bytes) =>
      _channel.invokeMethod<void>('printPdf', {'bytes': bytes});

  Future<void> printUri(String uri, {String? mimeType}) =>
      _channel.invokeMethod<void>('printUri', {
        'uri': uri,
        'mimeType': mimeType,
      });

  Future<void> printBase64(String data) =>
      _channel.invokeMethod<void>('printBase64', {'data': data});
}
