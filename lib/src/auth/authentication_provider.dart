/// Authentication provider interfaces for the RPS SDK
///
/// This file defines the authentication system that supports multiple
/// authentication methods including API keys, bearer tokens, and custom
/// authentication schemes with secure credential handling.
library;

/// Abstract interface for authentication providers that supply
/// authentication headers and handle credential refresh
abstract class AuthenticationProvider {
  /// Gets authentication headers to include with requests
  Future<Map<String, String>> getAuthHeaders();

  /// Refreshes credentials if supported and needed
  Future<bool> refreshCredentials();

  /// Whether this provider requires credential refresh
  bool get requiresRefresh;

  /// Whether this provider supports credential refresh
  bool get supportsRefresh;

  /// Authentication provider type identifier
  String get providerType;
}

/// Exception thrown when authentication operations fail
class AuthenticationException implements Exception {
  final String message;
  final String? providerType;
  final Exception? cause;

  const AuthenticationException(this.message, {this.providerType, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('AuthenticationException: $message');
    if (providerType != null) {
      buffer.write(' (Provider: $providerType)');
    }
    if (cause != null) {
      buffer.write(' (Cause: $cause)');
    }
    return buffer.toString();
  }
}

/// API Key authentication provider for simple API key-based authentication
class ApiKeyAuthProvider implements AuthenticationProvider {
  final String _apiKey;
  final String _headerName;

  /// Creates an API key authentication provider
  ///
  /// [apiKey] The API key to use for authentication
  /// [headerName] The header name to use (defaults to 'X-API-Key')
  ApiKeyAuthProvider(String apiKey, {String headerName = 'X-API-Key'})
    : _apiKey = apiKey,
      _headerName = headerName {
    if (apiKey.isEmpty) {
      throw AuthenticationException(
        'API key cannot be empty',
        providerType: providerType,
      );
    }
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    return {_headerName: _apiKey};
  }

  @override
  Future<bool> refreshCredentials() async {
    // API keys don't support refresh
    return false;
  }

  @override
  bool get requiresRefresh => false;

  @override
  bool get supportsRefresh => false;

  @override
  String get providerType => 'api_key';

  @override
  String toString() => 'ApiKeyAuthProvider(headerName: $_headerName)';
}

/// Bearer token authentication provider with optional token refresh capability
class BearerTokenAuthProvider implements AuthenticationProvider {
  String _token;
  final Future<String> Function()? _tokenRefreshCallback;
  DateTime? _tokenExpiry;
  final Duration? _refreshBuffer;

  /// Creates a bearer token authentication provider
  ///
  /// [token] The initial bearer token
  /// [tokenRefreshCallback] Optional callback to refresh the token
  /// [tokenExpiry] Optional token expiry time
  /// [refreshBuffer] Buffer time before expiry to refresh token (defaults to 5 minutes)
  BearerTokenAuthProvider(
    String token, {
    Future<String> Function()? tokenRefreshCallback,
    DateTime? tokenExpiry,
    Duration? refreshBuffer,
  }) : _token = token,
       _tokenRefreshCallback = tokenRefreshCallback,
       _tokenExpiry = tokenExpiry,
       _refreshBuffer = refreshBuffer ?? const Duration(minutes: 5) {
    if (token.isEmpty) {
      throw AuthenticationException(
        'Bearer token cannot be empty',
        providerType: providerType,
      );
    }
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    // Check if token needs refresh before returning headers
    if (requiresRefresh && supportsRefresh) {
      await refreshCredentials();
    }

    return {'Authorization': 'Bearer $_token'};
  }

  @override
  Future<bool> refreshCredentials() async {
    if (_tokenRefreshCallback == null) {
      return false;
    }

    try {
      final newToken = await _tokenRefreshCallback();
      if (newToken.isEmpty) {
        throw AuthenticationException(
          'Token refresh returned empty token',
          providerType: providerType,
        );
      }

      _token = newToken;
      // Reset expiry if we don't have a new one
      _tokenExpiry = null;
      return true;
    } catch (e) {
      if (e is AuthenticationException) {
        rethrow;
      }
      throw AuthenticationException(
        'Failed to refresh token: ${e.toString()}',
        providerType: providerType,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  @override
  bool get requiresRefresh {
    if (_tokenExpiry == null || _refreshBuffer == null) {
      return false;
    }

    final now = DateTime.now();
    final refreshTime = _tokenExpiry!.subtract(_refreshBuffer);
    return now.isAfter(refreshTime);
  }

  @override
  bool get supportsRefresh => _tokenRefreshCallback != null;

  @override
  String get providerType => 'bearer_token';

  /// Updates the token expiry time
  void setTokenExpiry(DateTime expiry) {
    _tokenExpiry = expiry;
  }

  /// Gets the current token (for testing purposes)
  String get currentToken => _token;

  @override
  String toString() =>
      'BearerTokenAuthProvider(supportsRefresh: $supportsRefresh)';
}

/// Custom authentication provider for implementing custom authentication schemes
class CustomAuthProvider implements AuthenticationProvider {
  final Future<Map<String, String>> Function() _headerProvider;
  final Future<bool> Function()? _refreshCallback;
  final String _providerType;

  /// Creates a custom authentication provider
  ///
  /// [headerProvider] Function that returns authentication headers
  /// [refreshCallback] Optional function to refresh credentials
  /// [providerType] Type identifier for this provider
  CustomAuthProvider({
    required Future<Map<String, String>> Function() headerProvider,
    Future<bool> Function()? refreshCallback,
    String providerType = 'custom',
  }) : _headerProvider = headerProvider,
       _refreshCallback = refreshCallback,
       _providerType = providerType;

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    try {
      return await _headerProvider();
    } catch (e) {
      throw AuthenticationException(
        'Failed to get authentication headers: ${e.toString()}',
        providerType: providerType,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  @override
  Future<bool> refreshCredentials() async {
    if (_refreshCallback == null) {
      return false;
    }

    try {
      return await _refreshCallback();
    } catch (e) {
      throw AuthenticationException(
        'Failed to refresh credentials: ${e.toString()}',
        providerType: providerType,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  @override
  bool get requiresRefresh => false; // Custom providers manage their own refresh logic

  @override
  bool get supportsRefresh => _refreshCallback != null;

  @override
  String get providerType => _providerType;

  @override
  String toString() =>
      'CustomAuthProvider(type: $_providerType, supportsRefresh: $supportsRefresh)';
}
