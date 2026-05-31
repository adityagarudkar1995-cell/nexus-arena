import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String? _accessToken;

  const ApiClient({String? accessToken}) : _accessToken = accessToken; // ignore: prefer_initializing_formals

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool isFunction = false}) async {
    final base = isFunction ? AppConstants.functionsBaseUrl : AppConstants.insforgeBaseUrl;
    final resp = await http.post(
      Uri.parse('$base$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(resp);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final resp = await http.get(
      Uri.parse('${AppConstants.insforgeBaseUrl}$path'),
      headers: _headers,
    );
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? 'unknown_error', resp.statusCode);
    }
    return body;
  }
}
