import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/src/api/rts_models.dart';
import 'package:thermal_print/src/pos/receipt_formatter.dart';

void main() {
  test('receipt matches RTS web layout', () {
    final text = formatSaleReceiptText(
      SaleReceipt(
        saleId: 1,
        receiptNo: 'RCP-0193D2D6',
        total: 400,
        subtotal: 500,
        discountPercent: 20,
        discountAmount: 100,
        buyerName: 'Noli',
        sellerName: 'Brent',
        items: [
          SaleReceiptItem(
            name: 'Honey',
            qty: 1,
            unitPrice: 400,
            lineTotal: 400,
            variant: 'dark',
            size: 'liter',
          ),
        ],
      ),
      printedAt: DateTime(2026, 9, 12, 17, 32, 20),
    );

    expect(text.contains('Pyx Food Products'), isTrue);
    expect(text.contains('Walk-in Sales Receipt'), isTrue);
    expect(text.contains('RCP-0193D2D6'), isTrue);
    expect(text.contains('Buyer: Noli'), isTrue);
    expect(text.contains('Seller: Brent'), isTrue);
    expect(text.contains('Dark · 1L x1'), isTrue);
    expect(text.contains('Subtotal'), isTrue);
    expect(text.contains('Discount (20%)'), isTrue);
    expect(text.contains('TOTAL'), isTrue);
    expect(text.contains('This is not an Official Receipt'), isTrue);
    expect(text.contains('₱400.00'), isTrue);
    expect(text.contains('Thank you'), isFalse);
  });
}
