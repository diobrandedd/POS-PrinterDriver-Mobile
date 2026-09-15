import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:thermal_print/src/api/rts_models.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';

/// Renders the RTS-style receipt (logo + monospace body) to a 384px-wide PNG.
/// Amount rows are drawn as true left/right columns so item + ₱ stay on one line.
Future<Uint8List> renderPosReceiptPng(
  SaleReceipt receipt, {
  DateTime? printedAt,
  int width = 384,
}) async {
  final lines = buildSaleReceiptLines(receipt, printedAt: printedAt);

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

  const sidePad = 6.0;
  const topPad = 8.0;
  const bottomPad = 36.0;
  const logoGap = 12.0;
  final contentW = width - sidePad * 2;

  final fontSize = _monoFontSizeForColumns(contentW, kThermalCols);
  final minLineHeight = fontSize + 6;
  final logoH = logo != null ? (logo.height * (200 / logo.width)) : 0.0;

  // Measure first so the bitmap height includes multi-line footers.
  final measured = <_MeasuredRow>[];
  var bodyHeight = 0.0;
  for (final line in lines) {
    final row = _measureRow(line, fontSize, contentW, minLineHeight);
    measured.add(row);
    bodyHeight += row.height;
  }

  final height = (topPad +
          logoH +
          (logo != null ? logoGap : 0.0) +
          bodyHeight +
          bottomPad)
      .ceil()
      .clamp(1, 8000);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );

  var y = topPad;
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

  for (final row in measured) {
    row.paint(canvas, sidePad, y, contentW);
    y += row.height;
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

_MeasuredRow _measureRow(
  ReceiptLine line,
  double fontSize,
  double contentW,
  double minLineHeight,
) {
  switch (line.kind) {
    case ReceiptLineKind.blank:
      return _MeasuredRow.blank(minLineHeight * 0.55);
    case ReceiptLineKind.amount:
      // Left label + right price on the SAME baseline — never wrap apart.
      final priceW = _measureWidth(line.right, fontSize).clamp(72.0, contentW * 0.42);
      final gap = 8.0;
      final leftW = (contentW - priceW - gap).clamp(40.0, contentW);
      final left = _paragraph(
        line.left.isEmpty ? ' ' : line.left,
        fontSize,
        leftW,
        ui.TextAlign.left,
        maxLines: 2,
      );
      final right = _paragraph(
        line.right,
        fontSize,
        priceW,
        ui.TextAlign.right,
        maxLines: 1,
      );
      final h = [left.height, right.height, minLineHeight].reduce((a, b) => a > b ? a : b);
      return _MeasuredRow.amount(left, right, h, leftW, gap);
    case ReceiptLineKind.footer:
      final p = _paragraph(
        line.left,
        fontSize * 0.92,
        contentW,
        ui.TextAlign.center,
        maxLines: 3,
      );
      return _MeasuredRow.single(p, p.height < minLineHeight ? minLineHeight : p.height);
    case ReceiptLineKind.text:
    case ReceiptLineKind.rule:
      final p = _paragraph(
        line.left.isEmpty ? ' ' : line.left,
        fontSize,
        contentW,
        ui.TextAlign.left,
        maxLines: line.kind == ReceiptLineKind.rule ? 1 : 2,
      );
      return _MeasuredRow.single(p, p.height < minLineHeight ? minLineHeight : p.height);
  }
}

ui.Paragraph _paragraph(
  String text,
  double fontSize,
  double maxWidth,
  ui.TextAlign align, {
  int maxLines = 1,
}) {
  final pb = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: align,
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.15,
      maxLines: maxLines,
      ellipsis: maxLines == 1 ? '' : null,
    ),
  )
    ..pushStyle(
      ui.TextStyle(
        color: const ui.Color(0xFF000000),
        fontFamily: 'monospace',
        fontSize: fontSize,
      ),
    )
    ..addText(text);
  return pb.build()..layout(ui.ParagraphConstraints(width: maxWidth));
}

double _measureWidth(String text, double fontSize) {
  final p = _paragraph(text, fontSize, 10000, ui.TextAlign.left, maxLines: 1);
  return p.maxIntrinsicWidth;
}

double _monoFontSizeForColumns(double contentWidth, int columns) {
  const probeSize = 20.0;
  final probe = _paragraph('0' * columns, probeSize, 10000, ui.TextAlign.left);
  final measured = probe.maxIntrinsicWidth;
  if (measured <= 0) return 18;
  final size = probeSize * (contentWidth / measured) * 0.95;
  return size.clamp(15.0, 22.0);
}

class _MeasuredRow {
  _MeasuredRow.single(this.left, this.height)
      : right = null,
        leftWidth = 0,
        gap = 0,
        isAmount = false;

  _MeasuredRow.amount(this.left, this.right, this.height, this.leftWidth, this.gap)
      : isAmount = true;

  _MeasuredRow.blank(this.height)
      : left = null,
        right = null,
        leftWidth = 0,
        gap = 0,
        isAmount = false;

  final ui.Paragraph? left;
  final ui.Paragraph? right;
  final double height;
  final double leftWidth;
  final double gap;
  final bool isAmount;

  void paint(ui.Canvas canvas, double x, double y, double contentW) {
    if (left == null) return;
    if (isAmount && right != null) {
      canvas.drawParagraph(left!, ui.Offset(x, y));
      canvas.drawParagraph(right!, ui.Offset(x + leftWidth + gap, y));
      return;
    }
    canvas.drawParagraph(left!, ui.Offset(x, y));
  }
}
