/// Connection manager for HTTP transport layer
///
/// This file implements connection pooling, resource management, and
/// concurrent request handling for the RPS SDK HTTP transport.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/simple_logger.dart';

/// Configuration for connection management
class ConnectionConfig {
  /// Maximum number of connections per host
  final int maxConnectionsPerHost;

  /// Maximum number of idle connections to keep alive
  final int maxIdleConnections;

  /// Timeout for idle connections
  final Duration idleTimeout;

  /// Connection timeout
  final Duration connectionTimeout;

  /// Maximum number of concurrent requests
  final int maxConcurrentRequests;

  /// Request queue timeout
  final Duration queueTimeout;

  const ConnectionConfig({
    this.maxConnectionsPerHost = 10,
    this.maxIdleConnections = 5,
    this.idleTimeout = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 30),
    this.maxConcurrentRequests = 50,
    this.queueTimeout = const Duration(minutes: 1),
  });

  /// Creates a development-optimized configuration
  factory ConnectionConfig.development() {
    return const ConnectionConfig(
      maxConnectionsPerHost: 5,
      maxIdleConnections: 2,
      idleTimeout: Duration(seconds: 15),
      connectionTimeout: Duration(seconds: 10),
      maxConcurrentRequests: 20,
      queueTimeout: Duration(seconds: 30),
    );
  }

  /// Creates a production-optimized configuration
  factory ConnectionConfig.production() {
    return const ConnectionConfig(
      maxConnectionsPerHost: 15,
      maxIdleConnections: 8,
      idleTimeout: Duration(minutes: 2),
      connectionTimeout: Duration(seconds: 30),
      maxConcurrentRequests: 100,
      queueTimeout: Duration(minutes: 2),
    );
  }
}

/// Statistics for connection management
class ConnectionStats {
  final int activeConnections;
  final int idleConnections;
  final int queuedRequests;
  final int totalConnectionsCreated;
  final int totalConnectionsReused;
  final int totalConnectionsTimedOut;
  final Duration averageConnectionTime;

  const ConnectionStats({
    required this.activeConnections,
    required this.idleConnections,
    required this.queuedRequests,
    required this.totalConnectionsCreated,
    required this.totalConnectionsReused,
    required this.totalConnectionsTimedOut,
    required this.averageConnectionTime,
  });

  double get connectionReuseRate {
    final total = totalConnectionsCreated + totalConnectionsReused;
    if (total == 0) return 0.0;
    return totalConnectionsReused / total;
  }

  @override
  String toString() {
    return 'ConnectionStats('
        'active: $activeConnections, '
        'idle: $idleConnections, '
        'queued: $queuedRequests, '
        'created: $totalConnectionsCreated, '
        'reused: $totalConnectionsReused, '
        'timedOut: $totalConnectionsTimedOut, '
        'avgTime: ${averageConnectionTime.inMilliseconds}ms, '
        'reuseRate: ${(connectionReuseRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Request queue entry for managing concurrent requests
class QueuedRequest {
  final String id;
  final RequestOptions options;
  final Completer<Response> completer;
  final DateTime queuedAt;
  final CancelToken? cancelToken;

  QueuedRequest({
    required this.id,
    required this.options,
    required this.completer,
    DateTime? queuedAt,
    this.cancelToken,
  }) : queuedAt = queuedAt ?? DateTime.now();

  bool get isExpired {
    return DateTime.now().difference(queuedAt) > const Duration(minutes: 1);
  }

  bool get isCancelled {
    return cancelToken?.isCancelled ?? false;
  }
}

/// Connection manager that handles connection pooling and request queuing
class ConnectionManager {
  final ConnectionConfig _config;
  final LoggingManager? _logger;
  final Dio _dio;

  // Request management
  final Queue<QueuedRequest> _requestQueue = Queue<QueuedRequest>();
  final Set<String> _activeRequests = <String>{};
  final Map<String, Timer> _requestTimeouts = <String, Timer>{};

  // Connection statistics
  final int _totalConnectionsCreated = 0;
  int _totalConnectionsReused = 0;
  int _totalConnectionsTimedOut = 0;
  final List<Duration> _connectionTimes = <Duration>[];

  // Cleanup timer
  Timer? _cleanupTimer;

  ConnectionManager({
    required ConnectionConfig config,
    required Dio dio,
    LoggingManager? logger,
  }) : _config = config,
       _dio = dio,
       _logger = logger {
    _setupConnectionPooling();
    _startCleanupTimer();
  }

  /// Sets up connection pooling configuration
  void _setupConnectionPooling() {
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      final adapter = _dio.httpClientAdapter as IOHttpClientAdapter;

      adapter.createHttpClient = () {
        final client = HttpClient();
        client.maxConnectionsPerHost = _config.maxConnectionsPerHost;
        client.idleTimeout = _config.idleTimeout;
        client.connectionTimeout = _config.connectionTimeout;

        _logger?.debug(
          'Configured HTTP client - maxConnectionsPerHost: ${_config.maxConnectionsPerHost}, idleTimeout: ${_config.idleTimeout.inSeconds}s, connectionTimeout: ${_config.connectionTimeout.inSeconds}s',
        );

        return client;
      };
    }
  }

  /// Executes a request with connection management and queuing
  Future<Response> executeRequest(RequestOptions options) async {
    final requestId =
        options.extra['requestId'] as String? ?? _generateRequestId();
    options.extra['requestId'] = requestId;

    // Check if we can execute immediately
    if (_activeRequests.length < _config.maxConcurrentRequests) {
      return _executeRequestDirectly(requestId, options);
    }

    // Queue the request
    return _queueRequest(requestId, options);
  }

  /// Executes a request directly without queuing
  Future<Response> _executeRequestDirectly(
    String requestId,
    RequestOptions options,
  ) async {
    _activeRequests.add(requestId);
    final startTime = DateTime.now();

    try {
      _logger?.debug('Executing request directly: $requestId');

      // Set up request timeout
      _setupRequestTimeout(requestId, options);

      final response = await _dio.fetch(options);

      final connectionTime = DateTime.now().difference(startTime);
      _connectionTimes.add(connectionTime);
      _totalConnectionsReused++; // Assume reuse for successful connections

      _logger?.debug(
        'Request completed: $requestId - Status: ${response.statusCode}, Time: ${connectionTime.inMilliseconds}ms',
      );

      return response;
    } catch (e) {
      _logger?.error('Request failed: $requestId', error: e);
      rethrow;
    } finally {
      _activeRequests.remove(requestId);
      _requestTimeouts.remove(requestId)?.cancel();
      _processQueue();
    }
  }

  /// Queues a request for later execution
  Future<Response> _queueRequest(
    String requestId,
    RequestOptions options,
  ) async {
    final completer = Completer<Response>();
    final cancelToken = options.cancelToken;

    final queuedRequest = QueuedRequest(
      id: requestId,
      options: options,
      completer: completer,
      cancelToken: cancelToken,
    );

    _requestQueue.add(queuedRequest);

    _logger?.debug(
      'Queued request: $requestId - Queue size: ${_requestQueue.length}, Active: ${_activeRequests.length}',
    );

    // Set up queue timeout
    Timer(_config.queueTimeout, () {
      if (!completer.isCompleted) {
        _requestQueue.remove(queuedRequest);
        completer.completeError(
          DioException(
            requestOptions: options,
            error: 'Request timed out in queue',
            type: DioExceptionType.connectionTimeout,
          ),
        );
      }
    });

    // Handle cancellation
    if (cancelToken != null) {
      cancelToken.whenCancel.then((_) {
        if (!completer.isCompleted) {
          _requestQueue.remove(queuedRequest);
          completer.completeError(
            DioException(
              requestOptions: options,
              error: 'Request cancelled while queued',
              type: DioExceptionType.cancel,
            ),
          );
        }
      });
    }

    return completer.future;
  }

  /// Processes the request queue when capacity becomes available
  void _processQueue() {
    while (_requestQueue.isNotEmpty &&
        _activeRequests.length < _config.maxConcurrentRequests) {
      final queuedRequest = _requestQueue.removeFirst();

      // Skip expired or cancelled requests
      if (queuedRequest.isExpired || queuedRequest.isCancelled) {
        if (!queuedRequest.completer.isCompleted) {
          final error = queuedRequest.isExpired
              ? 'Request expired in queue'
              : 'Request cancelled while queued';

          queuedRequest.completer.completeError(
            DioException(
              requestOptions: queuedRequest.options,
              error: error,
              type: queuedRequest.isExpired
                  ? DioExceptionType.connectionTimeout
                  : DioExceptionType.cancel,
            ),
          );
        }
        continue;
      }

      // Execute the queued request
      _executeRequestDirectly(queuedRequest.id, queuedRequest.options)
          .then((response) {
            if (!queuedRequest.completer.isCompleted) {
              queuedRequest.completer.complete(response);
            }
          })
          .catchError((error) {
            if (!queuedRequest.completer.isCompleted) {
              queuedRequest.completer.completeError(error);
            }
          });
    }
  }

  /// Sets up timeout for individual requests
  void _setupRequestTimeout(String requestId, RequestOptions options) {
    final timeout = options.receiveTimeout ?? _config.connectionTimeout;

    _requestTimeouts[requestId] = Timer(timeout, () {
      _logger?.warning('Request timeout: $requestId');
      _totalConnectionsTimedOut++;

      // The actual timeout handling is done by Dio
      // This is just for statistics and logging
    });
  }

  /// Starts the cleanup timer for expired requests and connections
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanupExpiredRequests();
    });
  }

  /// Cleans up expired requests from the queue
  void _cleanupExpiredRequests() {
    final expiredRequests = <QueuedRequest>[];

    for (final request in _requestQueue) {
      if (request.isExpired || request.isCancelled) {
        expiredRequests.add(request);
      }
    }

    for (final request in expiredRequests) {
      _requestQueue.remove(request);

      if (!request.completer.isCompleted) {
        final error = request.isExpired
            ? 'Request expired in queue'
            : 'Request cancelled while queued';

        request.completer.completeError(
          DioException(
            requestOptions: request.options,
            error: error,
            type: request.isExpired
                ? DioExceptionType.connectionTimeout
                : DioExceptionType.cancel,
          ),
        );
      }
    }

    if (expiredRequests.isNotEmpty) {
      _logger?.debug('Cleaned up ${expiredRequests.length} expired requests');
    }
  }

  /// Cancels a specific request
  Future<void> cancelRequest(String requestId) async {
    // Remove from active requests
    _activeRequests.remove(requestId);
    _requestTimeouts.remove(requestId)?.cancel();

    // Remove from queue
    final queuedRequest = _requestQueue.cast<QueuedRequest?>().firstWhere(
      (r) => r?.id == requestId,
      orElse: () => null,
    );

    if (queuedRequest != null) {
      _requestQueue.remove(queuedRequest);

      if (!queuedRequest.completer.isCompleted) {
        queuedRequest.completer.completeError(
          DioException(
            requestOptions: queuedRequest.options,
            error: 'Request cancelled',
            type: DioExceptionType.cancel,
          ),
        );
      }
    }

    _processQueue();
  }

  /// Cancels all pending requests
  Future<void> cancelAllRequests() async {
    // Cancel active requests
    final activeRequestIds = List<String>.from(_activeRequests);
    for (final requestId in activeRequestIds) {
      await cancelRequest(requestId);
    }

    // Cancel queued requests
    final queuedRequests = List<QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();

    for (final request in queuedRequests) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(
          DioException(
            requestOptions: request.options,
            error: 'Request cancelled during shutdown',
            type: DioExceptionType.cancel,
          ),
        );
      }
    }

    _logger?.debug(
      'Cancelled ${activeRequestIds.length} active and ${queuedRequests.length} queued requests',
    );
  }

  /// Gets current connection statistics
  ConnectionStats get stats {
    final avgConnectionTime = _connectionTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                _connectionTimes
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) ~/
                _connectionTimes.length,
          );

    return ConnectionStats(
      activeConnections: _activeRequests.length,
      idleConnections: 0, // This would require deeper Dio integration to track
      queuedRequests: _requestQueue.length,
      totalConnectionsCreated: _totalConnectionsCreated,
      totalConnectionsReused: _totalConnectionsReused,
      totalConnectionsTimedOut: _totalConnectionsTimedOut,
      averageConnectionTime: avgConnectionTime,
    );
  }

  /// Disposes of the connection manager and cleans up resources
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    await cancelAllRequests();

    // Clear all timeouts
    for (final timer in _requestTimeouts.values) {
      timer.cancel();
    }
    _requestTimeouts.clear();

    _logger?.debug('Connection manager disposed');
  }

  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'conn_${timestamp}_${timestamp.hashCode.abs()}';
  }
}
