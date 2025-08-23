/// HTTP interceptors for the RPS SDK transport layer
///
/// This file contains specialized interceptors for authentication, logging,
/// metrics collection, and other cross-cutting concerns in HTTP requests.
library;

import 'package:dio/dio.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

class AuthenticationInterceptor extends Interceptor {
  final AuthenticationProvider _authProvider;
  final LoggingManager? _logger;

  AuthenticationInterceptor(this._authProvider, {LoggingManager? logger})
    : _logger = logger;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (_authProvider.requiresRefresh && _authProvider.supportsRefresh) {
        final refreshed = await _authProvider.refreshCredentials();
        if (!refreshed) {
          _logger?.warning(
            'Failed to refresh credentials, proceeding with existing credentials',
          );
        }
      }

      final authHeaders = await _authProvider.getAuthHeaders();
      options.headers.addAll(authHeaders);

      _logger?.debug(
        'Added authentication headers: provider=${_authProvider.providerType}, headerCount=${authHeaders.length}',
      );

      handler.next(options);
    } catch (e) {
      _logger?.error('Authentication failed', error: e);

      final rpsError = e is AuthenticationException
          ? RpsError.authentication(
              message: e.message,
              details: {'provider': _authProvider.providerType},
            )
          : RpsError.authentication(
              message: 'Authentication failed: ${e.toString()}',
            );

      handler.reject(
        DioException(
          requestOptions: options,
          error: rpsError,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _logger?.warning('Received 401 Unauthorized response');

      if (_authProvider.supportsRefresh) {
        _logger?.info('Attempting credential refresh due to 401 response');
        // Note: In a real implementation, you might want to retry the request
      }
    }

    handler.next(err);
  }
}

class LoggingInterceptor extends Interceptor {
  final LoggingManager _logger;
  final bool _logRequestBody;
  final bool _logResponseBody;
  final Set<String> _sensitiveHeaders;

  LoggingInterceptor(
    this._logger, {
    bool logRequestBody = true,
    bool logResponseBody = true,
    Set<String>? sensitiveHeaders,
  }) : _logRequestBody = logRequestBody,
       _logResponseBody = logResponseBody,
       _sensitiveHeaders = sensitiveHeaders ?? _defaultSensitiveHeaders;

  static const Set<String> _defaultSensitiveHeaders = {
    'authorization',
    'x-api-key',
    'api-key',
    'auth-token',
    'bearer',
    'cookie',
    'set-cookie',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['requestId'] as String? ?? 'unknown';

    _logger.debug(
      'HTTP Request: ${options.method.toUpperCase()} ${options.uri} [requestId: $requestId, headers: ${_sanitizeHeaders(options.headers)}, timeout: connect=${options.connectTimeout?.inMilliseconds}ms/receive=${options.receiveTimeout?.inMilliseconds}ms/send=${options.sendTimeout?.inMilliseconds}ms${_logRequestBody && options.data != null ? ', body: ${options.data}' : ''}]',
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId =
        response.requestOptions.extra['requestId'] as String? ?? 'unknown';
    final startTime = response.requestOptions.extra['startTime'] as DateTime?;
    final responseTime = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    _logger.debug(
      'HTTP Response: ${response.statusCode} ${response.requestOptions.uri} [requestId: $requestId, statusMessage: ${response.statusMessage}, headers: ${_sanitizeHeaders(response.headers.map)}, redirects: ${response.redirects.length}${responseTime != null ? ', responseTime: ${responseTime.inMilliseconds}ms' : ''}${_logResponseBody && response.data != null ? ', body: ${response.data}' : ''}]',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId =
        err.requestOptions.extra['requestId'] as String? ?? 'unknown';
    final startTime = err.requestOptions.extra['startTime'] as DateTime?;
    final responseTime = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    _logger.error(
      'HTTP Error: ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri} [requestId: $requestId, type: ${err.type.toString()}, message: ${err.message}, statusCode: ${err.response?.statusCode}, statusMessage: ${err.response?.statusMessage}${responseTime != null ? ', responseTime: ${responseTime.inMilliseconds}ms' : ''}${_logResponseBody && err.response?.data != null ? ', responseBody: ${err.response!.data}' : ''}]',
      error: err,
    );

    handler.next(err);
  }

  /// Sanitizes headers by redacting sensitive information
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (_sensitiveHeaders.contains(key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }
}

class TimingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['startTime'] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra['startTime'] as DateTime?;
    if (startTime != null) {
      final responseTime = DateTime.now().difference(startTime);
      response.extra['responseTime'] = responseTime;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra['startTime'] as DateTime?;
    if (startTime != null) {
      final responseTime = DateTime.now().difference(startTime);
      err.requestOptions.extra['responseTime'] = responseTime;
    }
    handler.next(err);
  }
}

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration baseDelay;
  final Set<DioExceptionType> retryableTypes;
  final Set<int> retryableStatusCodes;
  final LoggingManager? _logger;

  RetryInterceptor({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    Set<DioExceptionType>? retryableTypes,
    Set<int>? retryableStatusCodes,
    LoggingManager? logger,
  }) : retryableTypes = retryableTypes ?? _defaultRetryableTypes,
       retryableStatusCodes =
           retryableStatusCodes ?? _defaultRetryableStatusCodes,
       _logger = logger;

  static const Set<DioExceptionType> _defaultRetryableTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  static const Set<int> _defaultRetryableStatusCodes = {
    429, // Too Many Requests
    500, // Internal Server Error
    502, // Bad Gateway
    503, // Service Unavailable
    504, // Gateway Timeout
  };

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (retryCount >= maxRetries || !_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final delay = _calculateDelay(retryCount);
    _logger?.debug(
      'Retrying request after ${delay.inMilliseconds}ms [requestId: ${err.requestOptions.extra['requestId']}, retryCount: ${retryCount + 1}, maxRetries: $maxRetries, errorType: ${err.type.toString()}]',
    );

    await Future.delayed(delay);

    err.requestOptions.extra['retryCount'] = retryCount + 1;

    try {
      final response = await Dio().fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }

  bool _shouldRetry(DioException err) {
    if (retryableTypes.contains(err.type)) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null && retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    return false;
  }

  Duration _calculateDelay(int retryCount) {
    final multiplier = 1 << retryCount;
    return Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
  }
}
