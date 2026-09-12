class RtsException implements Exception {
  RtsException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PosUser {
  const PosUser({required this.name, required this.role});
  final String name;
  final String role;

  factory PosUser.fromMap(Map<dynamic, dynamic>? map) {
    return PosUser(
      name: map?['name'] as String? ?? 'POS',
      role: map?['role'] as String? ?? 'pos',
    );
  }
}

class LookupItem {
  LookupItem({
    required this.kind,
    required this.lookupKind,
    required this.label,
    required this.productId,
    required this.productName,
    required this.suggestedPrice,
    required this.requiresQty,
    this.variant,
    this.size,
    this.sizeLabel,
    this.productKey,
    this.unitId,
    this.skuId,
    this.code,
    this.pool,
  });

  final String kind;
  final String lookupKind;
  final String label;
  final int productId;
  final String productName;
  final double suggestedPrice;
  final bool requiresQty;
  final String? variant;
  final String? size;
  final String? sizeLabel;
  final String? productKey;
  final int? unitId;
  final int? skuId;
  final String? code;
  final String? pool;

  factory LookupItem.fromMap(Map<dynamic, dynamic> map) {
    return LookupItem(
      kind: map['kind'] as String? ?? 'honey',
      lookupKind: map['lookup_kind'] as String? ?? 'sku',
      label: map['label'] as String? ?? map['product_name'] as String? ?? 'Item',
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] as String? ?? map['label'] as String? ?? 'Item',
      suggestedPrice: (map['suggested_price'] as num?)?.toDouble() ?? 0,
      requiresQty: map['requires_qty'] == true,
      variant: map['variant'] as String?,
      size: map['size'] as String?,
      sizeLabel: map['size_label'] as String?,
      productKey: map['product_key'] as String?,
      unitId: (map['unit_id'] as num?)?.toInt(),
      skuId: (map['sku_id'] as num?)?.toInt(),
      code: map['code'] as String?,
      pool: map['pool'] as String?,
    );
  }

  Map<String, dynamic> toCheckoutLine({required int qty, required double listUnitPrice}) {
    final line = <String, dynamic>{
      'kind': kind,
      'product_id': productId,
      'list_unit_price': listUnitPrice,
      'qty': qty,
      'lookup_kind': lookupKind,
    };
    if (variant != null) line['variant'] = variant;
    if (size != null) line['size'] = size;
    if (productKey != null) line['product_key'] = productKey;
    if (skuId != null) line['sku_id'] = skuId;
    if (code != null) line['code'] = code;
    if (pool != null) line['pool'] = pool;
    if (lookupKind == 'unique_honey' && unitId != null) {
      line['bottle_unit_ids'] = [unitId];
      line['qty'] = 1;
    }
    if (lookupKind == 'unique_dept' && unitId != null) {
      line['pouch_unit_ids'] = [unitId];
      line['qty'] = 1;
    }
    return line;
  }
}

class CartLine {
  CartLine({
    required this.lookup,
    required this.qty,
    required this.unitPrice,
  });

  final LookupItem lookup;
  int qty;
  double unitPrice;

  double get lineTotal => double.parse((unitPrice * qty).toStringAsFixed(2));
  String get title => lookup.label;
}

class StaffMember {
  const StaffMember({required this.id, required this.name, this.deptName});
  final int id;
  final String name;
  final String? deptName;

  factory StaffMember.fromMap(Map<dynamic, dynamic> map) => StaffMember(
        id: (map['id'] as num?)?.toInt() ?? 0,
        name: map['name'] as String? ?? '',
        deptName: map['dept_name'] as String?,
      );
}

class SaleReceipt {
  SaleReceipt({
    required this.saleId,
    required this.receiptNo,
    required this.total,
    required this.buyerName,
    required this.sellerName,
    required this.items,
    this.subtotal,
    this.discountPercent,
    this.discountAmount,
    this.isAr = false,
    this.debtorMobile,
    this.soldAt,
    this.refunded = false,
  });

  final int saleId;
  final String receiptNo;
  final double total;
  final String buyerName;
  final String sellerName;
  final List<SaleReceiptItem> items;
  final double? subtotal;
  final int? discountPercent;
  final double? discountAmount;
  final bool isAr;
  final String? debtorMobile;
  final String? soldAt;
  final bool refunded;

  factory SaleReceipt.fromCheckout(Map<dynamic, dynamic> map) {
    final itemsRaw = (map['items'] as List?) ?? const [];
    return SaleReceipt(
      saleId: (map['sale_id'] as num?)?.toInt() ?? 0,
      receiptNo: map['receipt_no'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? (map['total_amount'] as num?)?.toDouble() ?? 0,
      buyerName: map['buyer_name'] as String? ?? map['debtor_name'] as String? ?? '',
      sellerName: map['seller_name'] as String? ?? map['sold_by_name'] as String? ?? 'POS',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? (map['subtotal_amount'] as num?)?.toDouble(),
      discountPercent: (map['discount_percent'] as num?)?.toInt(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      isAr: map['is_ar'] == true || (map['receipt_no'] as String? ?? '').startsWith('AR-'),
      debtorMobile: map['debtor_mobile'] as String?,
      soldAt: map['sold_at'] as String?,
      refunded: map['refunded'] == true,
      items: itemsRaw
          .map((e) => SaleReceiptItem.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory SaleReceipt.fromHistoryRow(Map<dynamic, dynamic> map) {
    final itemsRaw = (map['items'] as List?) ?? const [];
    return SaleReceipt(
      saleId: (map['sale_id'] as num?)?.toInt() ?? 0,
      receiptNo: map['receipt_no'] as String? ?? '',
      total: (map['total_amount'] as num?)?.toDouble() ?? 0,
      buyerName: map['buyer_name'] as String? ?? '',
      sellerName: map['sold_by_name'] as String? ?? 'POS',
      subtotal: (map['subtotal_amount'] as num?)?.toDouble(),
      discountPercent: (map['discount_percent'] as num?)?.toInt(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      isAr: map['is_ar'] == true,
      soldAt: map['sold_at'] as String?,
      refunded: map['refunded'] == true,
      items: itemsRaw
          .map((e) => SaleReceiptItem.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class SaleReceiptItem {
  SaleReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final double qty;
  final double unitPrice;
  final double lineTotal;

  factory SaleReceiptItem.fromMap(Map<dynamic, dynamic> map) {
    final label = map['label'] as String? ??
        map['name'] as String? ??
        map['product_name'] as String? ??
        'Item';
    return SaleReceiptItem(
      name: label,
      qty: (map['qty'] as num?)?.toDouble() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (map['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}
