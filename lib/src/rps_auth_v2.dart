/// Authentication providers for RPS SDK v2
///
/// Simplified authentication system focused on RPS API requirements.
library;

/// Simple authentication interface for RPS SDK v2
abstract class RpsAuth {
  /// Get authentication headers for HTTP requests
  Map<String, String> getHeaders();

  /// Authentication method name for debugging
  String get method;
}

/// API Key authentication for RPS API
class RpsApiKeyAuth implements RpsAuth {
  final String _apiKey;
  final String _headerName;
  final String? _prefix;

  /// Create API key authentication
  ///
  /// Common header formats:
  /// - 'Authorization: Api-Key xxx' (default with prefix)
  /// - 'X-API-Key: xxx' (headerName: 'X-API-Key', prefix: null)
  /// - 'Authorization: Bearer xxx' (use RpsBearerAuth instead)
  /// - Custom header names as required by API
  const RpsApiKeyAuth(
    this._apiKey, {
    String headerName = 'Authorization',
    String? prefix = 'Api-Key',
  }) : _headerName = headerName,
       _prefix = prefix;

  @override
  Map<String, String> getHeaders() {
    final value = _prefix != null ? '$_prefix $_apiKey' : _apiKey;
    return {_headerName: value};
  }

  @override
  String get method => _prefix != null
      ? 'api_key($_headerName: $_prefix)'
      : 'api_key($_headerName)';

  @override
  String toString() => 'RpsApiKeyAuth(header: $_headerName, prefix: $_prefix)';
}

/// Bearer token authentication for RPS API
class RpsBearerAuth implements RpsAuth {
  final String _token;

  /// Create Bearer token authentication
  const RpsBearerAuth(this._token);

  @override
  Map<String, String> getHeaders() {
    return {'Authorization': 'Bearer $_token'};
  }

  @override
  String get method => 'bearer_token';

  @override
  String toString() => 'RpsBearerAuth()';
}

/// Custom authentication for special RPS API requirements
class RpsCustomAuth implements RpsAuth {
  final Map<String, String> _headers;
  final String _methodName;

  /// Create custom authentication with specific headers
  const RpsCustomAuth(this._headers, {String methodName = 'custom'})
    : _methodName = methodName;

  @override
  Map<String, String> getHeaders() {
    return Map.from(_headers);
  }

  @override
  String get method => _methodName;

  @override
  String toString() => 'RpsCustomAuth($_methodName)';
}

/// Utility class for creating common RPS authentication methods
class RpsAuthUtils {
  /// Create API key authentication with Authorization: Api-Key header (default)
  static RpsAuth apiKey(String key) => RpsApiKeyAuth(key);

  /// Create API key authentication with X-API-Key header (no prefix)
  static RpsAuth xApiKey(String key) =>
      RpsApiKeyAuth(key, headerName: 'X-API-Key', prefix: null);

  /// Create API key authentication with Authorization header (no prefix)
  static RpsAuth authHeader(String key) =>
      RpsApiKeyAuth(key, headerName: 'Authorization', prefix: null);

  /// Create Bearer token authentication
  static RpsAuth bearer(String token) => RpsBearerAuth(token);

  /// Create custom authentication for specific requirements
  static RpsAuth custom(
    Map<String, String> headers, {
    String name = 'custom',
  }) => RpsCustomAuth(headers, methodName: name);

  /// Create authentication for query parameter (embedded in URL)
  static RpsAuth queryParam(String paramName, String value) =>
      RpsCustomAuth({}, methodName: 'query_param($paramName=$value)');

  /// Create authentication for request body (API key in payload)
  static RpsAuth bodyParam(String fieldName, String value) =>
      RpsCustomAuth({}, methodName: 'body_param($fieldName=$value)');
}
