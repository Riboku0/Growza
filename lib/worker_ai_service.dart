import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_models.dart';
import 'secure_storage.dart';

/// An installation credential is independent of the device's email accounts.
/// Only document headings and page count are sent after the existing consent UI.
class WorkerAiService {
  WorkerAiService({
    required this.client,
    required this.base,
    required this.vault,
  });
  final http.Client client;
  final Uri? base;
  final SessionVault vault;
  String? _token;
  Future<String>? _connecting;
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, Object> data, {
    String? token,
  }) async {
    final endpoint = base;
    if (endpoint == null) throw const AccountException('unavailable');
    try {
      final request =
          http.Request(
              'POST',
              endpoint.replace(
                path: '${endpoint.path.replaceAll(RegExp(r'/$'), '')}$path',
              ),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            })
            ..body = jsonEncode(data);
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(
        const Duration(seconds: 45),
      )) {
        if (bytes.length + chunk.length > 256 * 1024) {
          throw const AccountException('invalid_response');
        }
        bytes.addAll(chunk);
      }
      if (streamed.statusCode == 401) throw const AccountException('sign_in');
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw AccountException(
          value['code'] is String ? value['code'] as String : 'unavailable',
        );
      }
      return value;
    } on AccountException {
      rethrow;
    } on FormatException {
      throw const AccountException('invalid_response');
    } catch (_) {
      throw const AccountException('network');
    }
  }

  Future<String> _credential() {
    if (_token case final token?) return Future.value(token);
    return _connecting ??= _connect();
  }

  Future<String> _connect() async {
    try {
      // Scope the saved credential to the exact Worker endpoint.
      final raw = await vault.read();
      if (raw != null) {
        try {
          final saved = jsonDecode(raw);
          if (saved is Map &&
              saved['endpoint'] == base.toString() &&
              saved['token'] is String &&
              _tokenPattern.hasMatch(saved['token'] as String)) {
            return _token = saved['token'] as String;
          }
        } on FormatException {
          /* Replace a corrupt or obsolete credential. */
        }
      }
      final result = await _request('/installations', {});
      final token = result['token'];
      if (token is! String || !_tokenPattern.hasMatch(token)) {
        throw const AccountException('invalid_response');
      }
      await vault.write(
        jsonEncode({'endpoint': base.toString(), 'token': token}),
      );
      return _token = token;
    } finally {
      _connecting = null;
    }
  }

  Future<List<dynamic>> suggest({
    required String text,
    required int pageCount,
  }) async {
    if (base == null) throw const AccountException('unavailable');
    if (text.trim().isEmpty ||
        text.length > 12000 ||
        pageCount < 1 ||
        pageCount > 2000) {
      throw const AccountException('invalid_request');
    }
    var token = await _credential();
    final data = <String, Object>{'text': text, 'pageCount': pageCount};
    Map<String, dynamic> result;
    try {
      result = await _request('/ai/topics', data, token: token);
    } on AccountException catch (error) {
      if (error.code != 'sign_in') rethrow;
      if (_token == token) {
        _token = null;
        await vault.clear();
      }
      token = await _credential();
      result = await _request('/ai/topics', data, token: token);
    }
    if (result['topics'] is! List) {
      throw const AccountException('invalid_response');
    }
    return result['topics'] as List;
  }
}
