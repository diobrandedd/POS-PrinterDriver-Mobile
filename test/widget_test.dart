import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';
import 'package:thermal_print/src/api/rts_models.dart';

void main() {
  test('receipt formatter includes total', () {
    final text = formatSaleReceiptText(
      SaleReceipt(
        saleId: 1,
        receiptNo: 'RCP-TEST',
        total: 120,
        buyerName: 'Walk-in',
        sellerName: 'Cashier',
        items: [
          SaleReceiptItem(name: 'Honey 350ml', qty: 1, unitPrice: 120, lineTotal: 120),
        ],
      ),
    );
    expect(text.contains('RCP-TEST'), isTrue);
    expect(text.contains('120.00'), isTrue);
  });
}
