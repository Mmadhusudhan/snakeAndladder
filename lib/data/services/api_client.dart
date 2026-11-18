import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_record.dart';

/// Thin client for the Node backend (`backend/`). The base URL comes from
/// `--dart-define=API_BASE_URL=https://...`; when empty the client is
/// disabled and every call is a no-op that returns null.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required Future<String?> Function() tokenProvider,
    http.Client? client,
  })  : _token = tokenProvider,
        _http = client ?? http.Client();

  static const String configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String baseUrl;
  final Future<String?> Function() _token;
  final http.Client _http;

  bool get isEnabled => baseUrl.isNotEmpty;

  Future<Map<String, String>?> _headers() async {
    final token = await _token();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  /// Submits a finished match for server-side validation. The server
  /// updates stats and the leaderboard. Returns the server's response body
  /// or null when disabled / signed out.
  Future<Map<String, dynamic>?> submitMatch(MatchRecord match) async {
    if (!isEnabled) return null;
    final headers = await _headers();
    if (headers == null) return null;
    final res = await _http.post(
      _uri('/matches'),
      headers: headers,
      body: jsonEncode({'id': match.id, ...match.toMap()}),
    );
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _message(res.body));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> me() async {
    if (!isEnabled) return null;
    final headers = await _headers();
    if (headers == null) return null;
    final res = await _http.get(_uri('/me'), headers: headers);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _message(res.body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Generic authenticated calls used by the online room service.
  Future<Map<String, dynamic>> postJson(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);
  Future<Map<String, dynamic>> getJson(String path) => _send('GET', path, null);
  Future<Map<String, dynamic>> deleteJson(String path) => _send('DELETE', path, null);

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic>? body) async {
    if (!isEnabled) throw const ApiException(0, 'Backend URL is not configured');
    final headers = await _headers();
    if (headers == null) throw const ApiException(401, 'Sign in first');
    final req = http.Request(method, _uri(path))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _message(res.body));
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _message(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['error'] as String?) ?? body;
    } catch (_) {
      return body;
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'API $status: $message';
}
