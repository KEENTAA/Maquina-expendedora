import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_exception.dart';

class _NgrokHeaderClient extends http.BaseClient {
  final http.Client _inner;
  _NgrokHeaderClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['ngrok-skip-browser-warning'] = '1';
    return _inner.send(request);
  }
}

class HttpApiClient {
  final http.Client _client;

  HttpApiClient({http.Client? client}) : _client = _NgrokHeaderClient(client ?? http.Client());

  Map<String, String> _mergeHeaders([Map<String, String>? headers]) {
    return {
      'ngrok-skip-browser-warning': '1',
      ...?headers,
    };
  }

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    final response = await _withRetry(
      () => _client.get(uri, headers: _mergeHeaders(headers)),
      retries: retries,
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    Uri uri, {
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    final response = await _withRetry(
      () => _client.get(uri, headers: _mergeHeaders(headers)),
      retries: retries,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int retries = 2,
  }) async {
    final response = await _withRetry(
      () => _client.post(
        uri,
        headers: _mergeHeaders({'Content-Type': 'application/json', ...?headers}),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retries: retries,
    );
    return _decodeObject(response);
  }

  
  Future<Map<String, dynamic>> putJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int retries = 2,
  }) async {
    final response = await _withRetry(
      () => _client.put(
        uri,
        headers: _mergeHeaders({'Content-Type': 'application/json', ...?headers}),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retries: retries,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int retries = 2,
  }) async {
    final response = await _withRetry(
      () => _client.patch(
        uri,
        headers: _mergeHeaders({'Content-Type': 'application/json', ...?headers}),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retries: retries,
    );
    return _decodeObject(response);
  }

  Future<http.Response> _withRetry(
    Future<http.Response> Function() call, {
    required int retries,
  }) async {
    var attempts = 0;
    while (true) {
      try {
        final res = await call().timeout(const Duration(seconds: 20));
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
        throw _exceptionFromResponse(res);
      } on SocketException catch (_) {
        if (attempts >= retries) {
          throw const AppException(
            'No se pudo conectar con el servidor. Verifica tu conexión a internet.',
          );
        }
      } on TimeoutException catch (_) {
        if (attempts >= retries) {
          throw const AppException(
            'La conexión ha expirado. El servidor tarda demasiado en responder.',
          );
        }
      } on AppException catch (e) {
        if (e.statusCode != null && e.statusCode! < 500) rethrow;
        if (attempts >= retries) rethrow;
      }
      attempts += 1;
      await Future.delayed(Duration(milliseconds: 400 * attempts));
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const AppException('Respuesta inválida del servidor.');
    } on FormatException {
      throw const AppException('No se pudo parsear la respuesta del servidor.');
    }
  }

  List<dynamic> _decodeList(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) return decoded;
      throw const AppException('Respuesta inválida del servidor (se esperaba una lista).');
    } on FormatException {
      throw const AppException('No se pudo parsear la respuesta del servidor.');
    }
  }

  AppException _exceptionFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return AppException(
          decoded['detail'].toString(),
          statusCode: response.statusCode,
        );
      }
    } catch (_) {
      // ignore parse issues and fallback to raw body
    }
    return AppException(
      'HTTP ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }
}
