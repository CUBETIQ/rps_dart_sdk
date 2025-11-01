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

  /// Create API key authentication
  /// 
  /// Common header names:
  /// - 'X-API-Key' (default)
  /// - 'Authorization' (for direct auth header)
  /// - Custom header names as required by API
  const RpsApiKeyAuth(
    this._apiKey, {
    String headerName = 'X-API-Key',
  }) : _headerName = headerName;

  @override
  Map<String, String> getHeaders() {
    return {_headerName: _apiKey};
  }

  @override
  String get method => 'api_key($_headerName)';

  @override
  String toString() => 'RpsApiKeyAuth(header: $_headerName)';
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
  const RpsCustomAuth(
    this._headers, {
    String methodName = 'custom',
  }) : _methodName = methodName;

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
  /// Create API key authentication with X-API-Key header
  static RpsAuth apiKey(String key) => RpsApiKeyAuth(key);

  /// Create API key authentication with Authorization header (no Bearer prefix)
  static RpsAuth authHeader(String key) => RpsApiKeyAuth(key, headerName: 'Authorization');

  /// Create Bearer token authentication
  static RpsAuth bearer(String token) => RpsBearerAuth(token);

  /// Create custom authentication for specific requirements
  static RpsAuth custom(Map<String, String> headers, {String name = 'custom'}) =>
      RpsCustomAuth(headers, methodName: name);

  /// Create authentication for query parameter (embedded in URL)
  static RpsAuth queryParam(String paramName, String value) =>
      RpsCustomAuth({}, methodName: 'query_param($paramName=$value)');

  /// Create authentication for request body (API key in payload)
  static RpsAuth bodyParam(String fieldName, String value) =>
      RpsCustomAuth({}, methodName: 'body_param($fieldName=$value)');
}