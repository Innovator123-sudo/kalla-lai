import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failure returned by, or while reaching, the Kalla-Lai API.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code = 'NETWORK_ERROR',
    this.statusCode,
  });

  final String message;
  final String code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code): $message';
}

/// Thin JSON client for the Kalla-Lai API.
///
/// Authentication tokens are held in memory only. A future auth feature should
/// replace [setAccessToken] with a secure platform store.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  String baseUrl;
  final http.Client _http;
  String? _accessToken;

  /// Lets the settings screen point the app at a different API without a
  /// rebuild. Pass an empty string to go back to same-origin requests.
  void updateBaseUrl(String value) => baseUrl = value.trim();

  void setAccessToken(String? token) => _accessToken = token;

  String? get accessToken => _accessToken;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    return _send(() => _http.get(uri, headers: _headers()));
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = _uri(path);
    return _send(
      () => _http.post(
        uri,
        headers: {..._headers(), ...?headers},
        body: body == null ? null : jsonEncode(body),
      ),
      timeout: timeout,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Object body,
  }) async {
    final uri = _uri(path);
    return _send(
      () => _http.patch(uri, headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = _uri(path);
    return _send(() => _http.delete(uri, headers: _headers()));
  }

  /// Uploads showcase media (promo video, CV, image) to the demo file store and
  /// returns its metadata, including a servable [url]. Media is sent as base64
  /// JSON, so this uses a longer timeout than ordinary calls.
  Future<Map<String, dynamic>> uploadFile({
    required String kind,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    return postJson(
      '/v1/uploads',
      body: {
        'kind': kind,
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
      timeout: const Duration(seconds: 120),
    );
  }

  /// An empty [baseUrl] means "same origin as this client" — used by the
  /// container image where nginx proxies `/v1` to the API.
  Uri _uri(String path) =>
      baseUrl.trim().isEmpty
          ? Uri.base.resolve(path)
          : Uri.parse('$baseUrl$path');

  Map<String, String> _headers() => {
    'accept': 'application/json',
    'content-type': 'application/json',
    if (_accessToken != null) 'authorization': 'Bearer $_accessToken',
  };

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool retryOnUnauthorized = true,
  }) async {
    late http.Response response;
    try {
      response = await request().timeout(timeout ?? const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(
        'Could not reach the Kalla-Lai API at $baseUrl. '
        'Check that the server is running and try again.',
      );
    }

    // On startup a saved session is restored in the background. The refresh
    // rotates the token (and revokes the old session) while the first data
    // requests are already in flight, so a transient 401 is expected. Wait
    // briefly for the new token and retry with fresh headers.
    if (response.statusCode == 401 && _accessToken != null && retryOnUnauthorized) {
      for (var attempt = 0; attempt < 3 && response.statusCode == 401; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          response = await request().timeout(
            timeout ?? const Duration(seconds: 15),
          );
        } catch (_) {
          break;
        }
      }
    }

    Map<String, dynamic>? decoded;
    if (response.body.isNotEmpty) {
      try {
        final value = jsonDecode(response.body);
        if (value is Map<String, dynamic>) decoded = value;
      } catch (_) {
        // Fall through to the generic error below.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }

    final error = decoded?['error'];
    final message =
        error is Map<String, dynamic> ? error['message'] as String? : null;
    final code =
        error is Map<String, dynamic> ? error['code'] as String? : null;
    throw ApiException(
      message ?? 'The server returned an error (${response.statusCode}).',
      code: code ?? 'HTTP_${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  void close() => _http.close();
}
