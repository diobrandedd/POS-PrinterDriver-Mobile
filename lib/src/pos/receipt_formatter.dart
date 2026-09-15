import 'package:thermal_print/src/api/rts_models.dart';

/// Matches RTS web POS receipt layout ([posThermalPrint.ts]).
const int kThermalCols = 28;
const String kThermalFooter = 'This is not an Official Receipt';

/// One printable receipt row. Amount rows keep label left + price right.
class ReceiptLine {
  const ReceiptLine.text(this.left) : right = '', kind = ReceiptLineKind.text, amountStyle = null;
  const ReceiptLine.amount(
    this.left,
    this.right, {
    this.amountStyle = ReceiptAmountStyle.normal,
  }) : kind = ReceiptLineKind.amount;
  const ReceiptLine.rule(this.left) : right = '', kind = ReceiptLineKind.rule, amountStyle = null;
  const ReceiptLine.blank() : left = '', right = '', kind = ReceiptLineKind.blank, amountStyle = null;
  const ReceiptLine.footer(this.left) : right = '', kind = ReceiptLineKind.footer, amountStyle = null;

  final ReceiptLineKind kind;
  final String left;
  final String right;
  final ReceiptAmountStyle? amountStyle;
}

enum ReceiptLineKind { text, amount, rule, blank, footer }

enum ReceiptAmountStyle { normal, emphasis, muted }

List<ReceiptLine> buildSaleReceiptLines(SaleReceipt receipt, {DateTime? printedAt}) {
  final when = printedAt ?? DateTime.now();
  final lines = <ReceiptLine>[
    ReceiptLine.text(_center('Pyx Food Products')),
    ReceiptLine.text(
      _center(receipt.isAr ? 'AR Credit Receipt' : 'Walk-in Sales Receipt'),
    ),
    ReceiptLine.text(_center(receipt.receiptNo)),
    ReceiptLine.text(_center(_formatEnPh(when))),
    ReceiptLine.rule('-' * kThermalCols),
    ReceiptLine.text('Buyer: ${receipt.buyerName}'),
  ];

  final seller = receipt.sellerName.trim();
  if (seller.isNotEmpty) {
    lines.add(ReceiptLine.text('Seller: $seller'));
  }
  if (receipt.debtorMobile != null && receipt.debtorMobile!.trim().isNotEmpty) {
    lines.add(ReceiptLine.text('Mobile: ${receipt.debtorMobile!.trim()}'));
  }
  lines.add(const ReceiptLine.blank());

  for (final item in receipt.items) {
    _addLabeledAmount(lines, _itemLabel(item), _peso(item.lineTotal));
  }

  if (receipt.discountPercent != null && receipt.discountPercent! > 0) {
    lines.add(ReceiptLine.rule('-' * kThermalCols));
    lines.add(
      ReceiptLine.amount('Subtotal', _peso(receipt.subtotal ?? receipt.total)),
    );
    lines.add(
      ReceiptLine.amount(
        'Discount (${receipt.discountPercent}%)',
        '-${_peso(receipt.discountAmount ?? 0)}',
      ),
    );
  }

  lines.add(ReceiptLine.rule('=' * kThermalCols));
  lines.add(
    ReceiptLine.amount(
      'TOTAL',
      _peso(receipt.total),
      amountStyle: ReceiptAmountStyle.emphasis,
    ),
  );
  if (!receipt.isAr && receipt.amountPaid != null) {
    lines.add(ReceiptLine.rule('-' * kThermalCols));
    lines.add(
      ReceiptLine.amount(
        'Cash',
        _peso(receipt.amountPaid!),
        amountStyle: ReceiptAmountStyle.muted,
      ),
    );
    lines.add(
      ReceiptLine.amount(
        'Change',
        _peso(receipt.effectiveChange ?? 0),
        amountStyle: ReceiptAmountStyle.muted,
      ),
    );
    lines.add(ReceiptLine.rule('-' * kThermalCols));
  }
  if (receipt.refunded) {
    lines.add(ReceiptLine.text(_center('** REFUNDED **')));
  }
  lines.add(const ReceiptLine.blank());
  lines.add(const ReceiptLine.footer(kThermalFooter));
  return lines;
}

String formatSaleReceiptText(SaleReceipt receipt, {DateTime? printedAt}) {
  return buildSaleReceiptLines(receipt, printedAt: printedAt).map((line) {
    switch (line.kind) {
      case ReceiptLineKind.blank:
        return '';
      case ReceiptLineKind.amount:
        return _padRow(line.left, line.right);
      case ReceiptLineKind.text:
      case ReceiptLineKind.rule:
      case ReceiptLineKind.footer:
        return line.left;
    }
  }).join('\n');
}

/// Prefer one row: label left, price right (same as web POS).
/// Only wrap the label when it is too long for the price column.
void _addLabeledAmount(List<ReceiptLine> lines, String label, String price) {
  const maxLeft = kThermalCols - 10;
  if (label.length <= maxLeft) {
    lines.add(ReceiptLine.amount(label, price));
    return;
  }
  lines.add(ReceiptLine.text(label.substring(0, kThermalCols)));
  final end = label.length < kThermalCols * 2 ? label.length : kThermalCols * 2;
  final rest = label.length > kThermalCols ? label.substring(kThermalCols, end) : '';
  lines.add(ReceiptLine.amount(rest, price));
}

String _itemLabel(SaleReceiptItem item) {
  final variant = (item.variant ?? '').trim();
  if (variant.isNotEmpty) {
    final size = _sizeLabel(item.sizeLabel ?? item.size ?? '');
    final qty = _qty(item.qty);
    final head = _variantLabel(variant);
    return size.isNotEmpty ? '$head · $size x$qty' : '$head x$qty';
  }
  final name = item.name.trim().isNotEmpty ? item.name.trim() : 'Item';
  return '$name x${_qty(item.qty)}';
}

String _variantLabel(String v) {
  if (v.isEmpty) return v;
  return v[0].toUpperCase() + v.substring(1);
}

String _sizeLabel(String size) {
  const map = {
    '250ml': '250ml',
    '350ml': '350ml',
    'liter': '1L',
    'gallon': 'Gallon',
  };
  return map[size] ?? size;
}

String _qty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  return qty.toStringAsFixed(2);
}

String _peso(double n) {
  final fixed = n.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final fromEnd = whole.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '₱${buf.toString()}.${parts[1]}';
}

String _padRow(String left, String right, [int width = kThermalCols]) {
  final space = width - left.length - right.length;
  if (space < 1) {
    final joined = '$left $right';
    return joined.length <= width ? joined : joined.substring(0, width);
  }
  return left + (' ' * space) + right;
}

String _center(String text, [int width = kThermalCols]) {
  if (text.length >= width) return text.substring(0, width);
  final left = ((width - text.length) / 2).floor();
  return (' ' * left) + text;
}

String _formatEnPh(DateTime dt) {
  final local = dt.toLocal();
  final m = local.month;
  final d = local.day;
  final y = local.year;
  var hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$m/$d/$y, $hour:$minute:$second $ampm';
}
