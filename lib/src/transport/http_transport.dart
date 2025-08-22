/// HTTP transport layer with connection management for the RPS SDK
///
/// This file implements the HTTP transport wrapper around Dio with connection
/// pooling, request/response interceptors, concurrent request handling, and
/// cancellation support for long-running operations.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:rps_dart_sdk/src/core/core.dart';
import '../auth/authentication_provider.dart';

/// Abstract interface for HTTP transport operations
abstract class HttpTransport {
  /// Sends an HTTP request and returns the response
  Future<RpsResponse> sendRequest(RpsRequest request);

  /// Cancels a request by its ID
  Future<void> cancelRequest(String requestId);

  /// Cancels all pending requests
  Future<void> cancelAllRequests();

  /// Disposes of the transport and cleans up resources
  Future<void> dispose();

  /// Gets the number of active requests
  int get activeRequestCount;

  /// Gets transport statistics
  HttpTransportStats get stats;
}

/// Statistics for HTTP transport operations
class HttpTransportStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int cancelledRequests;
  final int activeConnections;
  final Duration averageResponseTime;

  const HttpTransportStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.cancelledRequests,
    required this.activeConnections,
    required this.averageResponseTime,
  });

  double get successRate {
    if (totalRequests == 0) return 0.0;
    return successfulRequests / totalRequests;
  }

  @override
  String toString() {
    return 'HttpTransportStats('
        'total: $totalRequests, '
        'success: $successfulRequests, '
        'failed: $failedRequests, '
        'cancelled: $cancelledRequests, '
        'active: $activeConnections, '
        'avgTime: ${averageResponseTime.inMilliseconds}ms, '
        'successRate: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Dio-based HTTP transport implementation with connection pooling and interceptors
class DioHttpTransport implements HttpTransport {
  final Dio _dio;
  final AuthenticationProvider? _authProvider;
  final LoggingManager? _logger;

  // Request tracking
  final Map<String, CancelToken> _activeRequests = {};
  final Map<String, DateTime> _requestStartTimes = {};

  // Statistics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  int _cancelledRequests = 0;
  final List<Duration> _responseTimes = [];

  DioHttpTransport._({
    required Dio dio,
    required RpsConfiguration config,
    AuthenticationProvider? authProvider,
    LoggingManager? logger,
  }) : _dio = dio,
       _authProvider = authProvider,
       _logger = logger;

  /// Factory constructor that creates and configures the Dio instance
  static Future<DioHttpTransport> create({
    required RpsConfiguration config,
    AuthenticationProvider? authProvider,
    LoggingManager? logger,

    Dio? customDio,
  }) async {
    final dio = customDio ?? Dio();

    // Configure Dio with connection pooling and timeouts
    dio.options = BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...config.customHeaders,
      },
      // Enable connection pooling
      persistentConnection: true,
      // Set reasonable limits for concurrent connections
      extra: {'connectionPoolSize': 10, 'maxIdleConnections': 5},
    );

    // Configure HTTP adapter for connection pooling
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.maxConnectionsPerHost = 10;
        client.idleTimeout = const Duration(seconds: 30);
        client.connectionTimeout = config.connectTimeout;
        return client;
      };
    }

    final transport = DioHttpTransport._(
      dio: dio,
      config: config,
      authProvider: authProvider,
      logger: logger,
    );

    // Add interceptors
    await transport._setupInterceptors();

    return transport;
  }

  /// Sets up request/response interceptors
  Future<void> _setupInterceptors() async {
    // Authentication interceptor
    if (_authProvider != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              final authHeaders = await _authProvider.getAuthHeaders();
              options.headers.addAll(authHeaders);
              handler.next(options);
            } catch (e) {
              _logger?.error('Authentication failed', error: e);
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: RpsError.authentication(
                    message: 'Authentication failed: ${e.toString()}',
                    details: {'provider': _authProvider.providerType},
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // Logging interceptor
    if (_logger != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            _logger.debug(
              'HTTP Request: ${options.method} ${options.uri} - Headers: ${_sanitizeHeaders(options.headers)}, Data: ${options.data}',
            );
            handler.next(options);
          },
          onResponse: (response, handler) {
            _logger.debug(
              'HTTP Response: ${response.statusCode} ${response.requestOptions.uri} - Status: ${response.statusCode}, Time: ${DateTime.now().difference(_requestStartTimes[response.requestOptions.extra['requestId']] ?? DateTime.now()).inMilliseconds}ms',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            _logger.error(
              'HTTP Error: ${error.requestOptions.method} ${error.requestOptions.uri} - Status: ${error.response?.statusCode}, Type: ${error.type.toString()}',
              error: error,
            );
            handler.next(error);
          },
        ),
      );
    }
  }

  @override
  Future<RpsResponse> sendRequest(RpsRequest request) async {
    final cancelToken = CancelToken();
    final startTime = DateTime.now();

    _activeRequests[request.id] = cancelToken;
    _requestStartTimes[request.id] = startTime;
    _totalRequests++;

    try {
      final response = await _dio.post(
        '/post', // Use httpbin.org's /post endpoint for testing
        data: {
          'type': request.type,
          'data': request.data,
          'metadata': request.metadata.toJson(),
        },
        options: Options(
          headers: request.headers,
          extra: {'requestId': request.id, 'priority': request.priority},
        ),
        cancelToken: cancelToken,
      );

      final responseTime = DateTime.now().difference(startTime);
      _responseTimes.add(responseTime);
      _successfulRequests++;

      final rpsResponse = RpsResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {'response': response.data},
        headers: _convertHeaders(response.headers.map),
        responseTime: responseTime,
        fromCache: false,
        requestId: request.id,
      );

      return rpsResponse;
    } on DioException catch (e) {
      _failedRequests++;

      if (e.type == DioExceptionType.cancel) {
        _cancelledRequests++;
        throw RpsError.network(
          message: 'Request was cancelled',
          details: {'requestId': request.id},
        );
      }

      // Convert Dio exceptions to RPS errors
      final rpsError = _convertDioException(e, request.id);
      throw rpsError;
    } catch (e) {
      _failedRequests++;
      throw RpsError.network(
        message: 'Unexpected error during request: ${e.toString()}',
        details: {'requestId': request.id},
      );
    } finally {
      _activeRequests.remove(request.id);
      _requestStartTimes.remove(request.id);
    }
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    final cancelToken = _activeRequests[requestId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Request cancelled by user');
      _logger?.debug('Cancelled request: $requestId');
    }
  }

  @override
  Future<void> cancelAllRequests() async {
    final requestIds = List<String>.from(_activeRequests.keys);
    for (final requestId in requestIds) {
      await cancelRequest(requestId);
    }
    _logger?.debug('Cancelled ${requestIds.length} active requests');
  }

  @override
  Future<void> dispose() async {
    await cancelAllRequests();
    _dio.close();
    _activeRequests.clear();
    _requestStartTimes.clear();
    _logger?.debug('HTTP transport disposed');
  }

  @override
  int get activeRequestCount => _activeRequests.length;

  @override
  HttpTransportStats get stats {
    final avgResponseTime = _responseTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                _responseTimes
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) ~/
                _responseTimes.length,
          );

    return HttpTransportStats(
      totalRequests: _totalRequests,
      successfulRequests: _successfulRequests,
      failedRequests: _failedRequests,
      cancelledRequests: _cancelledRequests,
      activeConnections: _activeRequests.length,
      averageResponseTime: avgResponseTime,
    );
  }

  /// Converts Dio exceptions to RPS errors
  RpsError _convertDioException(DioException e, String requestId) {
    // Check if the DioException contains an RpsError from an interceptor
    if (e.error is RpsError) {
      return e.error as RpsError;
    }

    final details = <String, dynamic>{
      'requestId': requestId,
      'dioType': e.type.toString(),
    };

    if (e.response != null) {
      details['statusCode'] = e.response!.statusCode;
      details['responseData'] = e.response!.data;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RpsError.timeout(message: 'Request timeout: ${e.message}');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode >= 400 && statusCode < 500) {
          return RpsError.clientError(
            message: 'Client error ($statusCode): ${e.message}',
            details: details,
            statusCode: statusCode,
          );
        } else if (statusCode >= 500) {
          return RpsError.serverError(
            message: 'Server error ($statusCode): ${e.message}',
            details: details,
            statusCode: statusCode,
          );
        }
        return RpsError.network(
          message: 'Bad response: ${e.message}',
          details: details,
        );

      case DioExceptionType.connectionError:
        return RpsError.network(
          details: details,
          message: 'Connection error: ${e.message}',
        );

      case DioExceptionType.badCertificate:
        return RpsError.network(
          message: 'SSL certificate error: ${e.message}',
          details: details,
        );

      case DioExceptionType.cancel:
        return RpsError.network(
          message: 'Request cancelled: ${e.message}',
          details: details,
        );

      case DioExceptionType.unknown:
        return RpsError.network(
          message: 'Unknown error: ${e.message}',
          details: details,
        );
    }
  }

  /// Converts Dio headers to string map
  Map<String, String> _convertHeaders(Map<String, List<String>> headers) {
    return headers.map((key, value) => MapEntry(key, value.join(', ')));
  }

  /// Sanitizes headers for logging (removes sensitive information)
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);

    // List of header names that should be sanitized
    const sensitiveHeaders = {
      'authorization',
      'x-api-key',
      'api-key',
      'auth-token',
      'bearer',
      'cookie',
      'set-cookie',
    };

    for (final key in sanitized.keys.toList()) {
      if (sensitiveHeaders.contains(key.toLowerCase())) {
        sanitized[key] = '[REDACTED]';
      }
    }

    return sanitized;
  }
}
