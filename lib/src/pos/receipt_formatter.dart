import 'package:thermal_print/src/api/rts_models.dart';

String formatSaleReceiptText(SaleReceipt receipt) {
  final buf = StringBuffer();
  buf.writeln(receipt.isAr ? 'AR CREDIT SALE' : 'WALK-IN SALE');
  buf.writeln(receipt.receiptNo);
  if (receipt.soldAt != null && receipt.soldAt!.isNotEmpty) {
    buf.writeln(receipt.soldAt);
  }
  buf.writeln('--------------------------------');
  buf.writeln('Buyer : ${receipt.buyerName}');
  buf.writeln('Seller: ${receipt.sellerName}');
  if (receipt.debtorMobile != null && receipt.debtorMobile!.isNotEmpty) {
    buf.writeln('Mobile: ${receipt.debtorMobile}');
  }
  buf.writeln('--------------------------------');
  for (final item in receipt.items) {
    final qty = item.qty == item.qty.roundToDouble()
        ? item.qty.toInt().toString()
        : item.qty.toStringAsFixed(2);
    buf.writeln(item.name);
    buf.writeln('  $qty x ${_money(item.unitPrice)} = ${_money(item.lineTotal)}');
  }
  buf.writeln('--------------------------------');
  if (receipt.subtotal != null) {
    buf.writeln('Subtotal: ${_money(receipt.subtotal!)}');
  }
  if (receipt.discountPercent != null && receipt.discountPercent! > 0) {
    buf.writeln('Discount ${receipt.discountPercent}%: -${_money(receipt.discountAmount ?? 0)}');
  }
  buf.writeln('TOTAL   : ${_money(receipt.total)}');
  if (receipt.refunded) {
    buf.writeln('** REFUNDED **');
  }
  buf.writeln('--------------------------------');
  buf.writeln('Thank you');
  return buf.toString();
}

String _money(double v) => 'PHP ${v.toStringAsFixed(2)}';
