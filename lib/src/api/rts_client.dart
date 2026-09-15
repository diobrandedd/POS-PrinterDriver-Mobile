import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_print/src/api/rts_models.dart';

class RtsClient {
  RtsClient._();
  static final RtsClient instance = RtsClient._();

  static const _defaultBase = 'https://pyxtracker.pyxfood.com/rts/api/v1';
  static const _tokenKey = 'rts_bearer_token';
  static const _baseKey = 'rts_api_base';
  static const _sellerKey = 'rts_default_seller';

  final _storage = const FlutterSecureStorage();
  String? _token;
  String _baseUrl = _defaultBase;
  PosUser? user;

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseKey) ?? _defaultBase;
    // Shared POS terminal: always require staff sign-in on cold start
    // (do not restore a previous Bearer session).
    await logout(remote: false);
  }

  Future<void> setBaseUrl(String url) async {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) cleaned = cleaned.substring(0, cleaned.length - 1);
    _baseUrl = cleaned.isEmpty ? _defaultBase : cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, _baseUrl);
  }

  Future<String> getDefaultSeller() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sellerKey) ?? (user?.name ?? '');
  }

  Future<void> setDefaultSeller(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sellerKey, name.trim());
  }

  Future<Map<String, dynamic>> posLogin(String pin) async {
    final data = await _request(
      'POST',
      'auth.php',
      action: 'pos_login',
      body: {'pin': pin},
      auth: false,
    );
    return _acceptToken(data);
  }

  /// Staff assigned in RTS Settings → Mobile POS staff.
  Future<Map<String, dynamic>> posStaffLogin(String username, String password) async {
    final data = await _request(
      'POST',
      'auth.php',
      action: 'pos_staff_login',
      body: {'username': username.trim(), 'password': password},
      auth: false,
    );
    return _acceptToken(data);
  }

  Future<Map<String, dynamic>> _acceptToken(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw RtsException(data['token_error'] as String? ?? 'Server did not issue a mobile token.');
    }
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    user = PosUser.fromMap(data['user'] as Map?);
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final data = await _request('GET', 'auth.php', action: 'me');
    if (data['authenticated'] != true) {
      throw RtsException('Not authenticated', statusCode: 401);
    }
    user = PosUser.fromMap(data['user'] as Map?);
    return data;
  }

  Future<void> logout({bool remote = true}) async {
    if (remote && isLoggedIn) {
      try {
        await _request('POST', 'auth.php', action: 'logout', body: {});
      } catch (_) {}
    }
    _token = null;
    user = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<LookupItem> unifiedLookup(String code) async {
    final data = await _request(
      'GET',
      'pos.php',
      action: 'unified_lookup',
      query: {'code': code},
    );
    final barcode = data['barcode'];
    if (barcode is! Map) {
      throw RtsException('Barcode not found.');
    }
    return LookupItem.fromMap(Map<dynamic, dynamic>.from(barcode));
  }

  Future<SaleReceipt> unifiedCheckout({
    required String buyerName,
    required String sellerName,
    required List<Map<String, dynamic>> items,
    String buyerCredentials = '',
    int discountPercent = 0,
  }) async {
    final body = <String, dynamic>{
      'buyer_name': buyerName,
      'seller_name': sellerName,
      'buyer_credentials': buyerCredentials,
      'items': items,
    };
    if (discountPercent == 10 || discountPercent == 20) {
      body['discount_percent'] = discountPercent;
    }
    final data = await _request('POST', 'pos.php', action: 'unified_checkout', body: body);
    return SaleReceipt.fromCheckout(data);
  }

  Future<SaleReceipt> unifiedArCheckout({
    required String debtorName,
    required String sellerName,
    required List<Map<String, dynamic>> items,
    int? debtorUserId,
    String debtorMobile = '',
  }) async {
    final body = <String, dynamic>{
      'debtor_name': debtorName,
      'seller_name': sellerName,
      'debtor_mobile': debtorMobile,
      'items': items,
    };
    if (debtorUserId != null && debtorUserId > 0) {
      body['debtor_user_id'] = debtorUserId;
    }
    final data = await _request('POST', 'pos.php', action: 'unified_ar_checkout', body: body);
    return SaleReceipt.fromCheckout(data);
  }

  Future<List<StaffMember>> staffPicker() async {
    final data = await _request('GET', 'pos.php', action: 'staff_picker');
    final list = (data['staff'] as List?) ?? const [];
    return list
        .map((e) => StaffMember.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> salesHistory({
    String period = 'day',
    int page = 1,
    String? receipt,
    String saleType = 'all',
  }) async {
    final query = <String, String>{
      'period': period,
      'page': '$page',
      'sale_type': saleType,
    };
    if (receipt != null && receipt.trim().isNotEmpty) {
      query['receipt'] = receipt.trim();
    }
    return _request('GET', 'pos.php', action: 'sales_history', query: query);
  }

  Future<SaleReceipt> receiptGet(int saleId) async {
    final data = await _request(
      'GET',
      'pos.php',
      action: 'receipt_get',
      query: {'sale_id': '$saleId'},
    );
    final receipt = data['receipt'];
    if (receipt is! Map) {
      throw RtsException('Receipt not found.');
    }
    return SaleReceipt.fromHistoryRow(Map<dynamic, dynamic>.from(receipt));
  }

  Future<Map<String, dynamic>> saleRefund(int saleId, {String reason = ''}) async {
    return _request(
      'POST',
      'pos.php',
      action: 'sale_refund',
      body: {'sale_id': saleId, 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String file, {
    required String action,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final params = <String, String>{'action': action, ...?query};
    final uri = Uri.parse('$_baseUrl/$file').replace(queryParameters: params);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      headers['X-Pos-Token'] = _token!;
    }

    late http.Response response;
    try {
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      } else {
        response = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 45));
      }
    } catch (e) {
      throw RtsException('Network error: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw RtsException(
        'Bad response (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 401) {
      await logout(remote: false);
      throw RtsException(decoded['error'] as String? ?? 'Not authenticated.', statusCode: 401);
    }

    if (decoded['ok'] != true) {
      throw RtsException(
        decoded['error'] as String? ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'value': data};
  }
}
