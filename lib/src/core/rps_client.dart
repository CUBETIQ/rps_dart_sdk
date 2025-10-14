/// Modern RPS client with request orchestration
///
/// This file implements the main SDK client that orchestrates all components
/// including validation, authentication, retry logic, caching, and HTTP transport.
library;

import 'dart:async';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

class RpsClient {
  final RpsConfiguration _config;
  final HttpTransport _transport;
  final RequestValidator _validator;
  final CacheManager? _cacheManager;
  final LoggingManager? _logger;
  final RpsEventBus? _eventBus;

  bool _initialized = false;
  bool _disposed = false;
  Timer? _cachedRequestsTimer;

  RpsClient._({
    required RpsConfiguration config,
    required HttpTransport transport,
    required RequestValidator validator,
    CacheManager? cacheManager,
    LoggingManager? logger,
    RpsEventBus? eventBus,
  }) : _config = config,
       _transport = transport,
       _validator = validator,
       _cacheManager = cacheManager,
       _logger = logger,
       _eventBus = eventBus;

  /// Factory constructor for creating instances via the builder
  factory RpsClient.create({
    required RpsConfiguration config,
    required HttpTransport transport,
    required RequestValidator validator,
    CacheManager? cacheManager,
    LoggingManager? logger,
    RpsEventBus? eventBus,
  }) {
    return RpsClient._(
      config: config,
      transport: transport,
      validator: validator,
      cacheManager: cacheManager,
      logger: logger,
      eventBus: eventBus,
    );
  }

  /// Initialize the client and all its components
  Future<void> initialize() async {
    if (_initialized) return;
    if (_disposed)
      throw RpsError.configuration(
        message: 'Cannot initialize disposed client',
      );

    try {
      _logger?.info('Initializing Modern RPS Client');

      if (_cacheManager != null) {
        await _cacheManager.initialize();
        _logger?.debug('Cache manager initialized');
      }

      _initialized = true;
      _logger?.info('Modern RPS Client initialized successfully');

      // Emit initialization event
      _eventBus?.publish(
        RequestStartedEvent(
          requestId: 'client_init',
          requestType: 'initialization',
          requestData: {'version': '1.0.0'},
        ),
      );

      if (_cacheManager != null) {
        _processCachedRequestsAsync();
      }
    } catch (e) {
      _logger?.error('Failed to initialize Modern RPS Client', error: e);
      rethrow;
    }
  }

  /// Send a message with full request orchestration
  Future<RpsResponse> sendMessage({
    required String type,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    int priority = 0,
    Map<String, dynamic>? customMetadata,
  }) async {
    await _ensureInitialized();

    final request = RpsRequest.create(
      type: type,
      data: data,
      headers: headers,
      priority: priority,
      customMetadata: customMetadata,
    );

    return await sendRequest(request);
  }

  /// Send a request through the full lifecycle
  Future<RpsResponse> sendRequest(RpsRequest request) async {
    await _ensureInitialized();

    _logger?.info('Processing request: ${request.id}');

    _eventBus?.publish(
      RequestStartedEvent(
        requestId: request.id,
        requestType: request.type,
        requestData: request.data,
      ),
    );

    try {
      final validationResult = await _validateRequest(request);
      if (!validationResult.isValid) {
        final error = RpsError.validation(
          message: 'Request validation failed',
          validationErrors: validationResult.errors,
        );
        throw error;
      }

      final response = await _executeWithRetry(request);

      if (_cacheManager != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        await _cacheManager.cacheResponse(request.id, response);
        _logger?.debug('Cached successful response for: ${request.id}');
      }

      _eventBus?.publish(
        RequestCompletedEvent(
          requestId: request.id,
          statusCode: response.statusCode,
          responseTime: response.responseTime,
          fromCache: false,
          retryCount: 0,
        ),
      );

      return response;
    } catch (e) {
      _logger?.error('Request failed: ${request.id}', error: e);

      if (_cacheManager != null && _config.cachePolicy.enableOfflineCache) {
        await _cacheManager.cacheRequest(request);
        _logger?.debug(
          'Cached failed request for offline retry: ${request.id}',
        );
      }

      rethrow;
    }
  }

  /// Validate request using the configured validator
  Future<ValidationResult> _validateRequest(RpsRequest request) async {
    try {
      final result = _validator.validate(request.data, request.type);
      return result;
    } catch (e) {
      _logger?.error('Validation error for request: ${request.id}', error: e);
      return ValidationResult.failure(
        errors: ['Validation failed: ${e.toString()}'],
      );
    }
  }

  /// Execute request with retry logic
  Future<RpsResponse> _executeWithRetry(RpsRequest request) async {
    final retryPolicy = _config.retryPolicy;
    int attempt = 0;
    RpsError? lastError;

    while (attempt <= retryPolicy.maxAttempts) {
      try {
        final response = await _transport.sendRequest(request);

        if (attempt > 0) {
          _logger?.info(
            'Request succeeded on retry attempt ${attempt + 1}: ${request.id}',
          );
        }

        return response;
      } catch (e) {
        final error = e is RpsError
            ? e
            : RpsError.network(message: e.toString());
        lastError = error;

        _logger?.warning(
          'Request attempt ${attempt + 1} failed: ${request.id}',
        );

        // Check if we should retry
        if (attempt >= retryPolicy.maxAttempts ||
            !retryPolicy.shouldRetry(attempt, error)) {
          break;
        }

        final delay = retryPolicy.getDelay(attempt, error);
        _logger?.debug(
          'Retrying request ${request.id} in ${delay.inMilliseconds}ms',
        );

        await Future.delayed(delay);
        attempt++;
      }
    }

    // Cache ALL retryable errors (including server errors)
    if (lastError != null && _cacheManager != null && lastError.isRetryable) {
      try {
        await _cacheManager.cacheRequest(request);
        _logger?.info(
          'Cached failed request for offline retry: ${request.id} (${lastError.type})',
        );
      } catch (e) {
        _logger?.error(
          'Failed to cache request for offline retry: ${request.id}',
          error: e,
        );
      }
    }

    throw lastError ?? RpsError.network(message: 'Unknown error occurred');
  }

  /// Process cached requests asynchronously
  void _processCachedRequestsAsync({
    Duration interval = const Duration(minutes: 5),
  }) {
    if (_cacheManager == null) return;

    _cachedRequestsTimer?.cancel();

    _cachedRequestsTimer = Timer.periodic(interval, (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }

      try {
        // Clean up stale requests first
        await _cacheManager.cleanupStaleRequests();

        final cachedRequests = await _cacheManager.getCachedRequests();
        if (cachedRequests.isNotEmpty) {
          _logger?.info('Processing ${cachedRequests.length} cached requests');

          for (final cachedRequest in cachedRequests) {
            try {
              await sendRequest(cachedRequest.request);
              await _cacheManager.removeCachedRequest(cachedRequest.id);
              _logger?.debug(
                'Successfully processed cached request: ${cachedRequest.id}',
              );
            } catch (e) {
              _logger?.warning(
                'Failed to process cached request: ${cachedRequest.id}',
              );
              // Update retry count for failed attempts
              await _cacheManager.processCachedRequests();
            }
          }
        }
      } catch (e) {
        _logger?.error('Error processing cached requests', error: e);
      }
    });
  }

  /// Manually trigger processing of cached requests (call this when network is restored)
  Future<void> processCachedRequests() async {
    if (_cacheManager == null) return;

    try {
      final cachedRequests = await _cacheManager.getCachedRequests();
      if (cachedRequests.isNotEmpty) {
        _logger?.info(
          'Manually processing ${cachedRequests.length} cached requests',
        );

        for (final cachedRequest in cachedRequests) {
          try {
            await sendRequest(cachedRequest.request);
            await _cacheManager.removeCachedRequest(cachedRequest.id);
            _logger?.debug(
              'Successfully processed cached request: ${cachedRequest.id}',
            );
          } catch (e) {
            _logger?.warning(
              'Failed to process cached request: ${cachedRequest.id}',
            );
          }
        }
      }
    } catch (e) {
      _logger?.error('Error manually processing cached requests', error: e);
    }
  }

  /// Configure the interval for processing cached requests
  void setCachedRequestProcessingInterval(Duration interval) {
    if (_cacheManager != null && _initialized) {
      _logger?.info(
        'Updating cached request processing interval to: ${interval.inSeconds} seconds',
      );
      _processCachedRequestsAsync(interval: interval);
    }
  }

  /// Get client statistics
  Future<Map<String, dynamic>> getStatistics() async {
    await _ensureInitialized();

    final stats = <String, dynamic>{
      'transport': {
        'activeRequests': _transport.activeRequestCount,
        'stats': _transport.stats.toString(),
      },
    };

    if (_cacheManager != null) {
      stats['cache'] = await _cacheManager.getStatistics();
    }

    return stats;
  }

  /// Cancel a specific request
  Future<void> cancelRequest(String requestId) async {
    await _ensureInitialized();
    await _transport.cancelRequest(requestId);
  }

  /// Cancel all pending requests
  Future<void> cancelAllRequests() async {
    await _ensureInitialized();
    await _transport.cancelAllRequests();
  }

  /// Dispose of the client and clean up resources
  Future<void> dispose() async {
    if (_disposed) return;

    _logger?.info('Disposing Modern RPS Client');

    try {
      _cachedRequestsTimer?.cancel();

      await _transport.dispose();

      _disposed = true;
      _initialized = false;

      _logger?.info('Modern RPS Client disposed successfully');
    } catch (e) {
      _logger?.error('Error during client disposal', error: e);
    }
  }

  /// Ensure the client is initialized
  Future<void> _ensureInitialized() async {
    if (_disposed)
      throw RpsError.configuration(message: 'Client has been disposed');
    if (!_initialized) await initialize();
  }

  /// Check if the client is initialized
  bool get isInitialized => _initialized;

  /// Check if the client is disposed
  bool get isDisposed => _disposed;

  /// Get the current configuration
  RpsConfiguration get configuration => _config;

  /// Get the event stream for monitoring
  Stream<RpsEvent>? get events => _eventBus?.events;
}
