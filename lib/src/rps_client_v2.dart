/// RPS Client v2 - Lightweight Webhook API Client
///
/// Simple, reliable webhook client with retry logic and proper error handling.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'retry_policy_v2.dart';
import 'rps_exceptions_v2.dart';
import 'rps_models_v2.dart';
import 'rps_offline_cache_v2.dart';

/// Lightweight webhook API client
class RpsClient {
  final RpsConfig _config;
  final Dio _dio;
  final RetryPolicy _retryPolicy;
  final OfflineWebhookCache? _offlineCache;

  // Statistics tracking
  RequestStats _stats = const RequestStats();

  // Active request tracking for cancellation
  final Map<String, CancelToken> _activeRequests = {};

  bool _disposed = false;

  RpsClient._(this._config, this._dio, this._retryPolicy, this._offlineCache);

  /// Create a new RPS client instance
  ///
  /// Example:
  /// ```dart
  /// final client = RpsClient.create(
  ///   config: RpsConfig(
  ///     baseUrl: 'https://api.example.com/webhook',
  ///     timeout: Duration(seconds: 30),
  ///   ),
  /// );
  /// ```
  static RpsClient create({
    required RpsConfig config,
    RetryPolicy? retryPolicy,
    Dio? dio,
    String? cacheDirectory,
  }) {
    // Validate configuration
    _validateConfig(config);

    // Create Dio instance with configuration
    final dioInstance = dio ?? _createDio(config);

    // Create retry policy
    final policy =
        retryPolicy ??
        RetryUtils.simple(
          maxAttempts: config.retryConfig.maxAttempts,
          baseDelay: config.retryConfig.baseDelay,
          maxDelay: config.retryConfig.maxDelay,
        );

    // Create offline cache if enabled
    final offlineCache = config.enableOfflineCache
        ? OfflineWebhookCache(
            cacheDirectory: cacheDirectory,
            maxCacheSize: config.maxOfflineCacheSize,
          )
        : null;

    return RpsClient._(config, dioInstance, policy, offlineCache);
  }

  /// Send a webhook request
  ///
  /// Example:
  /// ```dart
  /// final response = await client.sendWebhook(
  ///   data: {'message': 'Hello, webhook!'},
  ///   headers: {'X-Custom-Header': 'value'},
  /// );
  /// ```
  Future<WebhookResponse> sendWebhook({
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    String? requestId,
    bool enableRetry = true,
  }) async {
    _ensureNotDisposed();

    final request = WebhookRequest(
      id: requestId,
      data: data,
      headers: headers ?? {},
    );

    if (enableRetry) {
      try {
        return await _retryPolicy.execute(
          request.id,
          () => _sendRequest(request),
        );
      } catch (e) {
        // Cache failed request for offline retry if enabled and retryable
        if (_offlineCache != null && e is RpsException && e.isRetryable) {
          await _cacheFailedRequest(request, e.message);
        }
        rethrow;
      }
    } else {
      return await _sendRequest(request);
    }
  }

  /// Send a webhook request with explicit request object
  Future<WebhookResponse> sendRequest(WebhookRequest request) async {
    _ensureNotDisposed();

    return await _retryPolicy.execute(request.id, () => _sendRequest(request));
  }

  /// Cancel a specific request by ID
  Future<void> cancelRequest(String requestId) async {
    final cancelToken = _activeRequests[requestId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Request cancelled by user');
      _activeRequests.remove(requestId);
    }
  }

  /// Cancel all active requests
  Future<void> cancelAllRequests() async {
    final tokens = List<CancelToken>.from(_activeRequests.values);
    _activeRequests.clear();

    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel('All requests cancelled');
      }
    }
  }

  /// Get current request statistics
  RequestStats get stats => _stats;

  /// Get current configuration
  RpsConfig get config => _config;

  /// Check if a request has been processed (idempotency check)
  bool hasRequestBeenProcessed(String requestId) {
    return _retryPolicy.hasBeenProcessed(requestId);
  }

  /// Get the number of active requests
  int get activeRequestCount => _activeRequests.length;

  /// Process cached requests that failed and retry them
  Future<void> processOfflineCache() async {
    if (_offlineCache == null) return;

    _ensureNotDisposed();

    try {
      await _offlineCache.initialize();
      final retryableRequests = await _offlineCache.getRetryableRequests();

      if (retryableRequests.isEmpty) return;

      print('Processing ${retryableRequests.length} cached requests...');

      for (final cachedRequest in retryableRequests) {
        try {
          // Attempt to send the cached request
          await _sendRequest(cachedRequest.request);

          // Success - remove from cache
          await _offlineCache.removeRequest(cachedRequest.id);
          print('✓ Successfully sent cached request: ${cachedRequest.id}');
        } catch (e) {
          // Failed again - update retry count
          final errorMessage = e is RpsException ? e.message : e.toString();
          await _offlineCache.updateRequestAfterRetry(
            cachedRequest.id,
            success: false,
            error: errorMessage,
          );
          print(
            '✗ Failed to send cached request: ${cachedRequest.id} - $errorMessage',
          );
        }
      }
    } catch (e) {
      print('Error processing offline cache: $e');
    }
  }

  /// Get offline cache statistics
  Future<CacheStats?> getOfflineCacheStats() async {
    if (_offlineCache == null) return null;

    try {
      await _offlineCache.initialize();
      return await _offlineCache.getStats();
    } catch (e) {
      return null;
    }
  }

  /// Clean up expired cached requests
  Future<int> cleanupOfflineCache() async {
    if (_offlineCache == null) return 0;

    try {
      await _offlineCache.initialize();
      return await _offlineCache.cleanupExpiredRequests();
    } catch (e) {
      return 0;
    }
  }

  /// Clear all offline cached requests
  Future<void> clearOfflineCache() async {
    if (_offlineCache == null) return;

    try {
      await _offlineCache.initialize();
      await _offlineCache.clear();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  /// Check if offline caching is enabled
  bool get hasOfflineCache => _offlineCache != null;

  /// Dispose the client and clean up resources
  Future<void> dispose() async {
    if (_disposed) return;

    await cancelAllRequests();
    _dio.close();
    _retryPolicy.clearProcessedRequests();

    if (_offlineCache != null) {
      await _offlineCache.dispose();
    }

    _disposed = true;
  }

  /// Internal method to send the actual HTTP request
  Future<WebhookResponse> _sendRequest(WebhookRequest request) async {
    final cancelToken = CancelToken();
    _activeRequests[request.id] = cancelToken;

    final stopwatch = Stopwatch()..start();

    try {
      // Prepare headers
      final requestHeaders = <String, String>{
        ..._config.headers,
        ...request.headers,
        'Content-Type': 'application/json',
      };

      // Add authentication headers if configured
      if (_config.auth != null) {
        requestHeaders.addAll(_config.auth!.getHeaders());
      }

      // Send request
      final response = await _dio.post(
        '',
        data: request.data,
        options: Options(
          headers: requestHeaders,
          receiveTimeout: _config.timeout,
          sendTimeout: _config.timeout,
        ),
        cancelToken: cancelToken,
      );

      stopwatch.stop();

      // Create response
      final webhookResponse = WebhookResponse(
        statusCode: response.statusCode ?? 200,
        data: _normalizeResponseData(response.data),
        headers: _extractHeaders(response.headers),
        duration: stopwatch.elapsed,
        requestId: request.id,
      );

      // Update statistics
      _stats = _stats.withRequest(
        success: webhookResponse.isSuccess,
        responseTime: stopwatch.elapsed,
      );

      if (!webhookResponse.isSuccess) {
        throw RpsHttpException(
          'HTTP ${webhookResponse.statusCode}: Request failed',
          statusCode: webhookResponse.statusCode,
          responseBody: webhookResponse.data,
          requestId: request.id,
        );
      }

      return webhookResponse;
    } on DioException catch (e) {
      stopwatch.stop();

      // Update statistics for failed request
      _stats = _stats.withRequest(
        success: false,
        responseTime: stopwatch.elapsed,
      );

      throw _convertDioException(e, request.id);
    } catch (e) {
      stopwatch.stop();

      // Update statistics for failed request
      _stats = _stats.withRequest(
        success: false,
        responseTime: stopwatch.elapsed,
      );

      rethrow;
    } finally {
      _activeRequests.remove(request.id);
    }
  }

  /// Convert Dio exceptions to RPS exceptions
  RpsException _convertDioException(DioException e, String requestId) {
    final details = <String, dynamic>{'dioType': e.type.toString()};

    if (e.response != null) {
      details.addAll({
        'statusCode': e.response!.statusCode,
        'responseData': e.response!.data,
      });
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RpsTimeoutException(
          'Request timeout: ${e.message}',
          timeout: _config.timeout,
          requestId: requestId,
          details: details,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        return RpsHttpException(
          'HTTP $statusCode: ${e.message}',
          statusCode: statusCode,
          responseBody: _normalizeResponseData(e.response?.data),
          requestId: requestId,
          details: details,
        );

      case DioExceptionType.connectionError:
        return RpsNetworkException(
          'Connection error: ${e.message}',
          requestId: requestId,
          details: details,
        );

      case DioExceptionType.cancel:
        return RpsCancelledException(
          'Request cancelled: ${e.message}',
          requestId: requestId,
          details: details,
        );

      case DioExceptionType.badCertificate:
        return RpsNetworkException(
          'SSL certificate error: ${e.message}',
          requestId: requestId,
          details: details,
        );

      case DioExceptionType.unknown:
        return RpsNetworkException(
          'Unknown network error: ${e.message}',
          requestId: requestId,
          details: details,
        );
    }
  }

  /// Normalize response data to Map<String, dynamic>
  Map<String, dynamic> _normalizeResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        // Fall through to default case
      }
      return {'response': data};
    } else {
      return {'response': data};
    }
  }

  /// Extract headers from Dio response
  Map<String, String> _extractHeaders(Headers headers) {
    final result = <String, String>{};
    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        result[name] = values.join(', ');
      }
    });
    return result;
  }

  /// Cache a failed request for offline retry
  Future<void> _cacheFailedRequest(WebhookRequest request, String error) async {
    if (_offlineCache == null) return;

    try {
      await _offlineCache.initialize();
      await _offlineCache.cacheRequest(
        request,
        error: error,
        priority: _determinePriority(request),
      );
    } catch (e) {
      // Log cache error but don't fail the original request
      print('Warning: Failed to cache request for offline retry: $e');
    }
  }

  /// Determine priority for cached requests
  int _determinePriority(WebhookRequest request) {
    // Check for priority indicators in the request
    final data = request.data;

    // High priority for payment-related requests
    if (data.containsKey('payment') ||
        data.containsKey('transaction') ||
        data.toString().toLowerCase().contains('payment')) {
      return 10;
    }

    // Medium priority for orders
    if (data.containsKey('order') ||
        data.containsKey('receipt') ||
        data.toString().toLowerCase().contains('order')) {
      return 5;
    }

    // Default priority
    return 0;
  }

  /// Ensure the client hasn't been disposed
  void _ensureNotDisposed() {
    if (_disposed) {
      throw RpsConfigException('Client has been disposed');
    }
  }

  /// Validate configuration
  static void _validateConfig(RpsConfig config) {
    if (config.baseUrl.isEmpty) {
      throw RpsConfigException('Base URL cannot be empty');
    }

    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null || !uri.hasScheme) {
      throw RpsConfigException('Invalid base URL: ${config.baseUrl}');
    }

    if (config.timeout.inMilliseconds <= 0) {
      throw RpsConfigException('Timeout must be positive');
    }

    if (config.retryConfig.maxAttempts < 0) {
      throw RpsConfigException('Max retry attempts cannot be negative');
    }
  }

  /// Create and configure Dio instance
  static Dio _createDio(RpsConfig config) {
    final dio = Dio();

    dio.options = BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.timeout,
      receiveTimeout: config.timeout,
      sendTimeout: config.timeout,
      headers: {'User-Agent': 'RPS-SDK-v2/1.0.0', ...config.headers},
      validateStatus: (status) {
        // Don't throw exceptions for any status code
        // We'll handle status codes manually
        return status != null;
      },
    );

    // Configure HTTP client for better connection handling
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.connectionTimeout = config.timeout;
        client.idleTimeout = const Duration(seconds: 30);
        return client;
      };
    }

    return dio;
  }
}

/// Extension methods for easier usage
extension RpsClientExtensions on RpsClient {
  /// Send a simple webhook with just data
  Future<WebhookResponse> send(Map<String, dynamic> data) async {
    return sendWebhook(data: data);
  }

  /// Send webhook and return only the response data
  Future<Map<String, dynamic>> sendAndGetData(Map<String, dynamic> data) async {
    final response = await sendWebhook(data: data);
    return response.data;
  }

  /// Check if the client is healthy (can make requests)
  Future<bool> isHealthy() async {
    try {
      await sendWebhook(data: {'healthCheck': true}, enableRetry: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}
