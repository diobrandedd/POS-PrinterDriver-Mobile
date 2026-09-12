import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:thermal_print/src/api/rts_models.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';

/// Renders the RTS-style receipt (logo + monospace body) to a 384px-wide PNG
/// so ₱ / layout match the website Chrome print output on thermal paper.
Future<Uint8List> renderPosReceiptPng(
  SaleReceipt receipt, {
  DateTime? printedAt,
  int width = 384,
}) async {
  final body = formatSaleReceiptText(receipt, printedAt: printedAt);
  final lines = body.split('\n');

  ui.Image? logo;
  try {
    final data = await rootBundle.load('assets/pyxfoodpr.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 200,
    );
    final frame = await codec.getNextFrame();
    logo = frame.image;
  } catch (_) {
    logo = null;
  }

  const fontSize = 22.0;
  const lineHeight = 28.0;
  const sidePad = 8.0;
  final logoH = logo != null ? (logo.height * (200 / logo.width)) : 0.0;
  final logoGap = logo != null ? 12.0 : 0.0;
  final height = (logoH + logoGap + lines.length * lineHeight + 24).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  final bg = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bg,
  );

  var y = 8.0;
  if (logo != null) {
    final dx = (width - 200) / 2.0;
    canvas.drawImageRect(
      logo,
      ui.Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      ui.Rect.fromLTWH(dx, y, 200, logoH),
      ui.Paint(),
    );
    y += logoH + logoGap;
    logo.dispose();
  }

  for (final line in lines) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        fontFamily: 'monospace',
        fontSize: fontSize,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xFF000000),
          fontFamily: 'monospace',
          fontSize: fontSize,
        ),
      )
      ..addText(line.isEmpty ? ' ' : line);
    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: width - sidePad * 2));
    canvas.drawParagraph(paragraph, ui.Offset(sidePad, y));
    y += lineHeight;
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    throw StateError('Could not encode receipt image');
  }
  return bytes.buffer.asUint8List();
}
