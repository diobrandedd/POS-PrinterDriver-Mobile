import 'package:thermal_print/src/api/rts_models.dart';

/// Matches RTS web POS receipt layout ([posThermalPrint.ts]).
const int kThermalCols = 28;
const String kThermalFooter = 'This is not an Official Receipt';

String formatSaleReceiptText(SaleReceipt receipt, {DateTime? printedAt}) {
  final when = printedAt ?? DateTime.now();
  final lines = <String>[];

  lines.add(_center('Pyx Food Products'));
  lines.add(_center(receipt.isAr ? 'AR Credit Receipt' : 'Walk-in Sales Receipt'));
  lines.add(_center(receipt.receiptNo));
  lines.add(_center(_formatEnPh(when)));
  lines.add('-' * kThermalCols);
  lines.add('Buyer: ${receipt.buyerName}');
  final seller = receipt.sellerName.trim();
  if (seller.isNotEmpty) {
    lines.add('Seller: $seller');
  }
  if (receipt.debtorMobile != null && receipt.debtorMobile!.trim().isNotEmpty) {
    lines.add('Mobile: ${receipt.debtorMobile!.trim()}');
  }
  lines.add('');

  for (final item in receipt.items) {
    final label = _itemLabel(item);
    final price = _peso(item.lineTotal);
    const maxLeft = kThermalCols - 10;
    if (label.length <= maxLeft) {
      lines.add(_padRow(label, price));
    } else {
      lines.add(label.substring(0, label.length < kThermalCols ? label.length : kThermalCols));
      final end = label.length < kThermalCols * 2 ? label.length : kThermalCols * 2;
      final rest = label.length > kThermalCols ? label.substring(kThermalCols, end) : '';
      lines.add(_padRow(rest, price));
    }
  }

  if (receipt.discountPercent != null && receipt.discountPercent! > 0) {
    lines.add('-' * kThermalCols);
    lines.add(_padRow('Subtotal', _peso(receipt.subtotal ?? receipt.total)));
    lines.add(
      _padRow(
        'Discount (${receipt.discountPercent}%)',
        '-${_peso(receipt.discountAmount ?? 0)}',
      ),
    );
  }

  lines.add('=' * kThermalCols);
  lines.add(_padRow('TOTAL', _peso(receipt.total)));
  if (receipt.refunded) {
    lines.add(_center('** REFUNDED **'));
  }
  lines.add('');
  // Footer is not COLS-truncated (matches RTS web CSS footer).
  lines.add(kThermalFooter);

  return lines.join('\n');
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

/// en-PH-ish locale string similar to JS toLocaleString("en-PH")
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
