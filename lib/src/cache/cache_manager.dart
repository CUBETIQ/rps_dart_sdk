/// Cache manager for the RPS SDK
///
/// This file provides the main cache management functionality including
/// eviction policies, capacity management, and request caching.
library;

import 'dart:async';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

/// Main cache manager that orchestrates caching operations
class CacheManager {
  final CacheStorage _storage;
  final CachePolicy _policy;
  final LoggingManager? _logger;

  bool _initialized = false;

  CacheManager({
    required CacheStorage storage,
    required CachePolicy policy,
    LoggingManager? logger,
  }) : _storage = storage,
       _policy = policy,
       _logger = logger {
    _policy.validate();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _storage.initialize();
      await _cleanupExpiredEntries();
      _initialized = true;
      _logger?.debug('Cache manager initialized successfully');
    } catch (e) {
      _logger?.error('Failed to initialize cache manager', error: e);
      rethrow;
    }
  }

  Future<void> cacheRequest(RpsRequest request) async {
    await _ensureInitialized();

    if (!_policy.cacheFailedRequests) {
      _logger?.debug('Request caching is disabled by policy');
      return;
    }

    try {
      // Check if request with same business ID already exists
      final existingRequests = await getCachedRequests();
      final businessId = _extractBusinessId(request);

      if (businessId != null) {
        final duplicateExists = existingRequests.any(
          (cached) => _extractBusinessId(cached.request) == businessId,
        );

        if (duplicateExists) {
          _logger?.debug(
            'Request with business ID $businessId already cached, skipping duplicate: ${request.id}',
          );
          return;
        }
      }

      await _enforceCapacityLimits();

      final cachedRequest = CachedRequest(
        id: request.id,
        request: request,
        cachedAt: DateTime.now(),
        retryCount: 0,
      );

      final key = _getRequestKey(request.id);
      await _storage.store(key, cachedRequest.toJson());

      _logger?.debug('Cached request for offline retry: ${request.id}');
    } catch (e) {
      _logger?.error('Failed to cache request: ${request.id}', error: e);
      rethrow;
    }
  }

  Future<List<CachedRequest>> getCachedRequests() async {
    await _ensureInitialized();

    try {
      final keys = await _storage.getAllKeys();
      final requestKeys = keys.where((key) => key.startsWith('request_'));
      final cachedRequests = <CachedRequest>[];

      for (final key in requestKeys) {
        try {
          final data = await _storage.retrieve(key);
          if (data != null) {
            final cachedRequest = CachedRequest.fromJson(data);
            cachedRequests.add(cachedRequest);
          }
        } catch (e) {
          _logger?.error('Failed to parse cached request: $key', error: e);
          // Remove corrupted entry
          await _storage.remove(key);
        }
      }

      cachedRequests.sort((a, b) => a.cachedAt.compareTo(b.cachedAt));

      _logger?.debug(
        'Retrieved ${cachedRequests.length} cached requests (sorted oldest to newest)',
      );
      return cachedRequests;
    } catch (e) {
      _logger?.error('Failed to get cached requests', error: e);
      return [];
    }
  }

  Future<void> removeCachedRequest(String requestId) async {
    await _ensureInitialized();

    try {
      final key = _getRequestKey(requestId);
      await _storage.remove(key);
      _logger?.debug('Removed cached request: $requestId');
    } catch (e) {
      _logger?.error('Failed to remove cached request: $requestId', error: e);
    }
  }

  Future<void> processCachedRequests() async {
    await _ensureInitialized();

    if (!_policy.enableOfflineCache) {
      _logger?.debug('Offline cache processing is disabled by policy');
      return;
    }

    try {
      final cachedRequests = await getCachedRequests();
      _logger?.info('Processing ${cachedRequests.length} cached requests');

      for (final cachedRequest in cachedRequests) {
        _logger?.debug('Request ready for retry: ${cachedRequest.id}');

        // Update the retry count and last retry timestamp
        try {
          final updatedRequest = CachedRequest(
            id: cachedRequest.id,
            request: cachedRequest.request,
            cachedAt: cachedRequest.cachedAt,
            retryCount: cachedRequest.retryCount + 1,
            lastRetryAt: DateTime.now(),
          );

          final key = _getRequestKey(cachedRequest.id);
          await _storage.store(key, updatedRequest.toJson());
          _logger?.debug(
            'Updated retry metadata for request: ${cachedRequest.id}',
          );
        } catch (e) {
          _logger?.error(
            'Failed to update retry metadata for request: ${cachedRequest.id}',
            error: e,
          );
        }
      }
    } catch (e) {
      _logger?.error('Failed to process cached requests', error: e);
    }
  }

  /// Remove cached requests that have exceeded retry limits or are too old
  Future<void> cleanupStaleRequests() async {
    await _ensureInitialized();

    try {
      final cachedRequests = await getCachedRequests();
      final maxRetries = 5; // Maximum retry attempts
      final maxAge = const Duration(days: 7); // Maximum age for cached requests

      int removedCount = 0;

      for (final cachedRequest in cachedRequests) {
        bool shouldRemove = false;
        String reason = '';

        // Remove if too many retries
        if (cachedRequest.retryCount >= maxRetries) {
          shouldRemove = true;
          reason = 'exceeded max retries (${cachedRequest.retryCount})';
        }

        // Remove if too old
        if (DateTime.now().difference(cachedRequest.cachedAt) > maxAge) {
          shouldRemove = true;
          reason =
              'expired (age: ${DateTime.now().difference(cachedRequest.cachedAt).inDays} days)';
        }

        if (shouldRemove) {
          await removeCachedRequest(cachedRequest.id);
          removedCount++;
          _logger?.debug(
            'Removed stale cached request ${cachedRequest.id}: $reason',
          );
        }
      }

      if (removedCount > 0) {
        _logger?.info('Cleaned up $removedCount stale cached requests');
      }
    } catch (e) {
      _logger?.error('Failed to cleanup stale requests', error: e);
    }
  }

  Future<void> cacheResponse(String key, RpsResponse response) async {
    await _ensureInitialized();

    if (!_policy.cacheSuccessfulResponses) {
      _logger?.debug('Response caching is disabled by policy');
      return;
    }

    try {
      await _enforceCapacityLimits();

      final responseData = {
        'statusCode': response.statusCode,
        'data': response.data,
        'headers': response.headers,
        'responseTime': response.responseTime.inMilliseconds,
        'fromCache': false,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      final cacheKey = _getResponseKey(key);
      await _storage.store(cacheKey, responseData);

      _logger?.debug('Cached response for key: $key');
    } catch (e) {
      _logger?.error('Failed to cache response for key: $key', error: e);
    }
  }

  Future<RpsResponse?> getCachedResponse(String key) async {
    await _ensureInitialized();

    if (!_policy.cacheSuccessfulResponses) {
      return null;
    }

    try {
      final cacheKey = _getResponseKey(key);
      final data = await _storage.retrieve(cacheKey);

      if (data == null) return null;

      // Check if the cached response has expired
      final cachedAt = DateTime.parse(data['cachedAt']);
      if (DateTime.now().difference(cachedAt) > _policy.maxAge) {
        await _storage.remove(cacheKey);
        return null;
      }

      return RpsResponse(
        statusCode: data['statusCode'],
        data: Map<String, dynamic>.from(data['data']),
        headers: Map<String, String>.from(data['headers']),
        responseTime: Duration(milliseconds: data['responseTime']),
        fromCache: true,
      );
    } catch (e) {
      _logger?.error('Failed to get cached response for key: $key', error: e);
      return null;
    }
  }

  Future<void> clearCache() async {
    await _ensureInitialized();

    try {
      await _storage.clear();
      _logger?.info('Cache cleared successfully');
    } catch (e) {
      _logger?.error('Failed to clear cache', error: e);
      rethrow;
    }
  }

  Future<CacheStatistics> getStatistics() async {
    await _ensureInitialized();

    try {
      final size = await _storage.size();
      final keys = await _storage.getAllKeys();

      int requestCount = 0;
      int responseCount = 0;

      for (final key in keys) {
        if (key.startsWith('request_')) {
          requestCount++;
        } else if (key.startsWith('response_')) {
          responseCount++;
        }
      }

      return CacheStatistics(
        totalEntries: size,
        cachedRequests: requestCount,
        cachedResponses: responseCount,
        maxCapacity: _policy.maxSize,
      );
    } catch (e) {
      _logger?.error('Failed to get cache statistics', error: e);
      return CacheStatistics(
        totalEntries: 0,
        cachedRequests: 0,
        cachedResponses: 0,
        maxCapacity: _policy.maxSize,
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _storage.dispose();
      _initialized = false;
      _logger?.debug('Cache manager disposed');
    } catch (e) {
      _logger?.error('Error disposing cache manager', error: e);
    }
  }

  Future<void> _enforceCapacityLimits() async {
    if (_policy.maxSize <= 0) return;

    final currentSize = await _storage.size();
    if (currentSize < _policy.maxSize) return;

    _logger?.debug(
      'Cache at capacity ($currentSize/${_policy.maxSize}), applying eviction policy',
    );

    switch (_policy.evictionPolicy) {
      case EvictionPolicy.fifo:
        await _evictFifo();
        break;
      case EvictionPolicy.lru:
        await _evictLru();
        break;
      case EvictionPolicy.lfu:
        await _evictLfu();
        break;
    }
  }

  Future<void> _evictFifo() async {
    final keys = await _storage.getAllKeys();
    if (keys.isNotEmpty) {
      await _storage.remove(keys.first);
      _logger?.debug('Evicted oldest entry: ${keys.first}');
    }
  }

  Future<void> _evictLru() async {
    await _evictFifo();
  }

  Future<void> _evictLfu() async {
    await _evictFifo();
  }

  Future<void> _cleanupExpiredEntries() async {
    if (_policy.maxAge == Duration.zero) return;

    try {
      final keys = await _storage.getAllKeys();
      for (final key in keys) {
        final data = await _storage.retrieve(key);
        if (data == null) {
          _logger?.debug('Removed expired entry: $key');
        }
      }
    } catch (e) {
      _logger?.error('Error during expired entry cleanup', error: e);
    }
  }

  String _getRequestKey(String requestId) => 'request_$requestId';
  String _getResponseKey(String key) => 'response_$key';

  /// Extract business ID from request data to prevent duplicate business transactions
  /// Specifically handles InvoiceModel structure from frontend
  String? _extractBusinessId(RpsRequest request) {
    try {
      final data = request.data;

      // Primary business ID fields - prioritize these for invoice deduplication
      final primaryFields = [
        'orderNumber', // Most important for your InvoiceModel
        'id', // Invoice ID
        'queueNumber', // Queue number for orders
      ];

      // Secondary business ID fields
      final secondaryFields = [
        'orderId',
        'order_id',
        'invoiceId',
        'invoice_id',
        'transactionId',
        'transaction_id',
        'businessId',
        'business_id',
        'referenceId',
        'reference_id',
      ];

      // Check primary fields first (these are most important for your use case)
      for (final field in primaryFields) {
        final value = data[field];
        if (value != null) {
          return value.toString();
        }
      }

      // Check secondary fields
      for (final field in secondaryFields) {
        final value = data[field];
        if (value != null) {
          return value.toString();
        }
      }

      // Look nested in 'data' field
      final nestedDataValue = data['data'];
      if (nestedDataValue is Map<String, dynamic>) {
        // Check primary fields in nested data
        for (final field in primaryFields) {
          final value = nestedDataValue[field];
          if (value != null) {
            return value.toString();
          }
        }

        // Check secondary fields in nested data
        for (final field in secondaryFields) {
          final value = nestedDataValue[field];
          if (value != null) {
            return value.toString();
          }
        }
      }

      // For InvoiceModel, create composite key from multiple fields if individual fields not found
      final orderNumber =
          data['orderNumber'] ?? nestedDataValue?['orderNumber'];
      final queueNumber =
          data['queueNumber'] ?? nestedDataValue?['queueNumber'];
      final orderDate = data['orderDate'] ?? nestedDataValue?['orderDate'];

      if (orderNumber != null && orderDate != null) {
        return '${orderNumber}_${orderDate}';
      }

      if (queueNumber != null && orderDate != null) {
        return 'queue_${queueNumber}_${orderDate}';
      }

      return null;
    } catch (e) {
      _logger?.debug(
        'Failed to extract business ID from request: ${request.id}',
        error: e,
      );
      return null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}

/// Statistics about cache usage
class CacheStatistics {
  final int totalEntries;
  final int cachedRequests;
  final int cachedResponses;
  final int maxCapacity;

  const CacheStatistics({
    required this.totalEntries,
    required this.cachedRequests,
    required this.cachedResponses,
    required this.maxCapacity,
  });

  double get utilizationPercentage =>
      maxCapacity > 0 ? (totalEntries / maxCapacity) * 100 : 0;

  @override
  String toString() {
    return 'CacheStatistics(total: $totalEntries, requests: $cachedRequests, '
        'responses: $cachedResponses, capacity: $maxCapacity, '
        'utilization: ${utilizationPercentage.toStringAsFixed(1)}%)';
  }
}

/// Model for cached requests that failed and need retry
class CachedRequest {
  final String id;
  final RpsRequest request;
  final DateTime cachedAt;
  final int retryCount;
  final DateTime? lastRetryAt;
  final String? lastError;

  const CachedRequest({
    required this.id,
    required this.request,
    required this.cachedAt,
    this.retryCount = 0,
    this.lastRetryAt,
    this.lastError,
  });

  /// Create a copy with updated retry information
  CachedRequest withRetry({
    int? retryCount,
    DateTime? lastRetryAt,
    String? lastError,
  }) {
    return CachedRequest(
      id: id,
      request: request,
      cachedAt: cachedAt,
      retryCount: retryCount ?? this.retryCount + 1,
      lastRetryAt: lastRetryAt ?? DateTime.now(),
      lastError: lastError ?? this.lastError,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request': request.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
      'retryCount': retryCount,
      'lastRetryAt': lastRetryAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  /// Create from JSON
  factory CachedRequest.fromJson(Map<String, dynamic> json) {
    return CachedRequest(
      id: json['id'],
      request: RpsRequest.fromJson(json['request']),
      cachedAt: DateTime.parse(json['cachedAt']),
      retryCount: json['retryCount'] ?? 0,
      lastRetryAt: json['lastRetryAt'] != null
          ? DateTime.parse(json['lastRetryAt'])
          : null,
      lastError: json['lastError'],
    );
  }
}
