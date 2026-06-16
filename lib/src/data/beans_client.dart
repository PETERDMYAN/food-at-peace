import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bean_transaction.dart';

class BeansSyncException implements Exception {
  BeansSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// HTTP client for the server-side Beans ledger (`/beans`), authenticated with
/// the app session token. The ledger is append-only and idempotent by txn id, so
/// [push] (POST) both uploads new transactions and returns the account's full
/// merged ledger — one round-trip does pull+push. [pull] (GET) is a read-only
/// fetch. Isolated from the food/weight/profile sync (its own endpoint + table).
class BeansClient {
  BeansClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _headers(String token, {bool json = true}) => {
    if (json) 'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  /// Read the account's server-side ledger.
  Future<List<BeanTransaction>> pull(String token) async {
    final resp = await _http.get(
      Uri.parse('$_base/beans'),
      headers: _headers(token, json: false),
    );
    return _ledgerFrom(resp);
  }

  /// Append [txns] (idempotent by id; at most one signup grant per account is
  /// kept server-side) and return the resulting full ledger.
  Future<List<BeanTransaction>> push(
    String token,
    List<BeanTransaction> txns,
  ) async {
    final resp = await _http.post(
      Uri.parse('$_base/beans'),
      headers: _headers(token),
      body: jsonEncode({'txns': [for (final t in txns) t.toJson()]}),
    );
    return _ledgerFrom(resp);
  }

  /// Validate a StoreKit receipt server-side (`POST /iap/validate`). Returns the
  /// account's ledger when Apple confirms the purchase (Beans credited
  /// server-side, idempotent), or null when it couldn't validate
  /// (unconfigured / invalid / network error) so the caller can fall back to a
  /// local credit. Never throws.
  Future<List<BeanTransaction>?> validateIap(
    String token,
    String receipt,
    String productId,
  ) async {
    try {
      final resp = await _http.post(
        Uri.parse('$_base/iap/validate'),
        headers: _headers(token),
        body: jsonEncode({'receipt': receipt, 'productId': productId}),
      );
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (j['valid'] != true) return null;
      return [
        for (final t in (j['ledger'] as List? ?? const []))
          BeanTransaction.fromJson((t as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return null;
    }
  }

  List<BeanTransaction> _ledgerFrom(http.Response resp) {
    if (resp.statusCode != 200) throw BeansSyncException(_messageFrom(resp));
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final t in (j['ledger'] as List? ?? const []))
        BeanTransaction.fromJson((t as Map).cast<String, dynamic>()),
    ];
  }

  String _messageFrom(http.Response r) {
    try {
      final err = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
    } catch (_) {}
    return 'Beans sync failed. Please try again.';
  }
}
