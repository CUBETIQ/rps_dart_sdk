/// Offline cache for failed webhook requests in RPS SDK v2
/// 
/// Lightweight local storage system to cache failed requests for later retry.
library;

import 'dart:convert';
import 'dart:io';

import 'rps_models_v2.dart';
import 'rps_exceptions_v2.dart';

/// Cached request data for offline storage
class CachedWebhookRequest {
  /// Unique cache entry ID
  final String id;
  
  /// Original webhook request
  final WebhookRequest request;
  
  /// When the request was first cached
  final DateTime cachedAt;
  
  /// Number of retry attempts made
  final int retryCount;
  
  /// Last retry attempt timestamp
  final DateTime? lastRetryAt;
  
  /// Last error message
  final String? lastError;
  
  /// Request priority (higher = retry sooner)
  final int priority;
  
  /// Maximum number of retries allowed
  final int maxRetries;

  const CachedWebhookRequest({
    required this.id,
    required this.request,
    required this.cachedAt,
    this.retryCount = 0,
    this.lastRetryAt,
    this.lastError,
    this.priority = 0,
    this.maxRetries = 5,
  });

  /// Create a copy with updated retry information
  CachedWebhookRequest withRetry({
    int? retryCount,
    DateTime? lastRetryAt,
    String? lastError,
  }) {
    return CachedWebhookRequest(
      id: id,
      request: request,
      cachedAt: cachedAt,
      retryCount: retryCount ?? this.retryCount + 1,
      lastRetryAt: lastRetryAt ?? DateTime.now(),
      lastError: lastError ?? this.lastError,
      priority: priority,
      maxRetries: maxRetries,
    );
  }

  /// Whether this request should be retried
  bool get shouldRetry {
    if (retryCount >= maxRetries) return false;
    
    // Don't retry if too old (7 days)
    final age = DateTime.now().difference(cachedAt);
    if (age.inDays > 7) return false;
    
    return true;
  }

  /// Calculate next retry delay based on attempt count
  Duration get nextRetryDelay {
    if (retryCount == 0) return Duration.zero;
    
    // Exponential backoff: 1min, 5min, 15min, 1hr, 4hr
    final delays = [
      const Duration(minutes: 1),
      const Duration(minutes: 5),
      const Duration(minutes: 15),
      const Duration(hours: 1),
      const Duration(hours: 4),
    ];
    
    final index = (retryCount - 1).clamp(0, delays.length - 1);
    return delays[index];
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
      'priority': priority,
      'maxRetries': maxRetries,
    };
  }

  /// Create from JSON
  factory CachedWebhookRequest.fromJson(Map<String, dynamic> json) {
    return CachedWebhookRequest(
      id: json['id'] as String,
      request: WebhookRequest.fromJson(json['request'] as Map<String, dynamic>),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastRetryAt: json['lastRetryAt'] != null 
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
      priority: json['priority'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 5,
    );
  }

  @override
  String toString() => 'CachedWebhookRequest(id: $id, retries: $retryCount/$maxRetries)';
}

/// Lightweight file-based cache for offline webhook requests
class OfflineWebhookCache {
  final String _cacheDir;
  final String _fileName;
  late final File _cacheFile;
  
  /// Maximum number of cached requests to keep
  final int maxCacheSize;
  
  /// Whether the cache has been initialized
  bool _initialized = false;

  OfflineWebhookCache({
    String? cacheDirectory,
    String fileName = 'rps_offline_cache.json',
    this.maxCacheSize = 100,
  }) : _cacheDir = cacheDirectory ?? _getDefaultCacheDir(),
       _fileName = fileName {
    _cacheFile = File('$_cacheDir/$_fileName');
  }

  /// Initialize the cache directory and file
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Create cache directory if it doesn't exist
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create cache file if it doesn't exist
      if (!await _cacheFile.exists()) {
        await _cacheFile.writeAsString('[]');
      }

      _initialized = true;
    } catch (e) {
      throw RpsConfigException(
        'Failed to initialize offline cache: $e',
        details: {'cacheDir': _cacheDir, 'fileName': _fileName},
      );
    }
  }

  /// Cache a failed webhook request for later retry
  Future<void> cacheRequest(
    WebhookRequest request, {
    String? error,
    int priority = 0,
    int maxRetries = 5,
  }) async {
    await _ensureInitialized();

    try {
      final cached = CachedWebhookRequest(
        id: request.id,
        request: request,
        cachedAt: DateTime.now(),
        lastError: error,
        priority: priority,
        maxRetries: maxRetries,
      );

      final requests = await _loadCachedRequests();
      
      // Remove any existing request with same ID
      requests.removeWhere((r) => r.id == request.id);
      
      // Add new request
      requests.add(cached);
      
      // Sort by priority (higher first) then by cache time
      requests.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.cachedAt.compareTo(b.cachedAt);
      });
      
      // Limit cache size
      if (requests.length > maxCacheSize) {
        requests.removeRange(maxCacheSize, requests.length);
      }

      await _saveCachedRequests(requests);
    } catch (e) {
      throw RpsConfigException(
        'Failed to cache request: $e',
        details: {'requestId': request.id},
      );
    }
  }

  /// Get all cached requests that should be retried
  Future<List<CachedWebhookRequest>> getRetryableRequests() async {
    await _ensureInitialized();

    try {
      final requests = await _loadCachedRequests();
      final now = DateTime.now();
      
      // Filter requests that should be retried
      final retryable = requests.where((request) {
        if (!request.shouldRetry) return false;
        
        // Check if enough time has passed since last retry
        if (request.lastRetryAt != null) {
          final timeSinceLastRetry = now.difference(request.lastRetryAt!);
          if (timeSinceLastRetry < request.nextRetryDelay) {
            return false;
          }
        }
        
        return true;
      }).toList();

      // Sort by priority and age
      retryable.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.cachedAt.compareTo(b.cachedAt);
      });

      return retryable;
    } catch (e) {
      throw RpsConfigException('Failed to get retryable requests: $e');
    }
  }

  /// Update a cached request after retry attempt
  Future<void> updateRequestAfterRetry(
    String requestId, {
    required bool success,
    String? error,
  }) async {
    await _ensureInitialized();

    try {
      final requests = await _loadCachedRequests();
      final index = requests.indexWhere((r) => r.id == requestId);
      
      if (index >= 0) {
        if (success) {
          // Remove successful request from cache
          requests.removeAt(index);
        } else {
          // Update failed request with retry info
          requests[index] = requests[index].withRetry(lastError: error);
        }
        
        await _saveCachedRequests(requests);
      }
    } catch (e) {
      throw RpsConfigException(
        'Failed to update cached request: $e',
        details: {'requestId': requestId},
      );
    }
  }

  /// Remove a request from cache
  Future<void> removeRequest(String requestId) async {
    await _ensureInitialized();

    try {
      final requests = await _loadCachedRequests();
      requests.removeWhere((r) => r.id == requestId);
      await _saveCachedRequests(requests);
    } catch (e) {
      throw RpsConfigException(
        'Failed to remove cached request: $e',
        details: {'requestId': requestId},
      );
    }
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    await _ensureInitialized();

    try {
      final requests = await _loadCachedRequests();
      final now = DateTime.now();
      
      final retryable = requests.where((r) => r.shouldRetry).length;
      final expired = requests.where((r) => !r.shouldRetry).length;
      final oldestAge = requests.isEmpty 
          ? Duration.zero 
          : now.difference(requests.map((r) => r.cachedAt).reduce((a, b) => a.isBefore(b) ? a : b));
      
      return CacheStats(
        totalRequests: requests.length,
        retryableRequests: retryable,
        expiredRequests: expired,
        oldestRequestAge: oldestAge,
      );
    } catch (e) {
      return const CacheStats(
        totalRequests: 0,
        retryableRequests: 0,
        expiredRequests: 0,
        oldestRequestAge: Duration.zero,
      );
    }
  }

  /// Clean up expired requests
  Future<int> cleanupExpiredRequests() async {
    await _ensureInitialized();

    try {
      final requests = await _loadCachedRequests();
      final initialCount = requests.length;
      
      // Remove requests that shouldn't be retried anymore
      requests.removeWhere((r) => !r.shouldRetry);
      
      await _saveCachedRequests(requests);
      return initialCount - requests.length;
    } catch (e) {
      throw RpsConfigException('Failed to cleanup expired requests: $e');
    }
  }

  /// Clear all cached requests
  Future<void> clear() async {
    await _ensureInitialized();
    await _saveCachedRequests([]);
  }

  /// Load cached requests from file
  Future<List<CachedWebhookRequest>> _loadCachedRequests() async {
    try {
      final content = await _cacheFile.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      
      return jsonList
          .map((json) => CachedWebhookRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list if file is corrupted or doesn't exist
      return [];
    }
  }

  /// Save cached requests to file
  Future<void> _saveCachedRequests(List<CachedWebhookRequest> requests) async {
    try {
      final jsonList = requests.map((r) => r.toJson()).toList();
      final content = jsonEncode(jsonList);
      await _cacheFile.writeAsString(content);
    } catch (e) {
      throw RpsConfigException('Failed to save cached requests: $e');
    }
  }

  /// Ensure cache is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Get default cache directory based on platform
  static String _getDefaultCacheDir() {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'];
        return '$appData/RPS_SDK_v2';
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        return '$home/Library/Caches/RPS_SDK_v2';
      } else {
        // Linux and others
        final home = Platform.environment['HOME'];
        return '$home/.cache/rps_sdk_v2';
      }
    } catch (e) {
      // Fallback to current directory
      return './rps_cache';
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _initialized = false;
  }
}

/// Cache statistics
class CacheStats {
  final int totalRequests;
  final int retryableRequests;
  final int expiredRequests;
  final Duration oldestRequestAge;

  const CacheStats({
    required this.totalRequests,
    required this.retryableRequests,
    required this.expiredRequests,
    required this.oldestRequestAge,
  });

  @override
  String toString() {
    return 'CacheStats(total: $totalRequests, retryable: $retryableRequests, '
           'expired: $expiredRequests, oldest: ${oldestRequestAge.inHours}h)';
  }
}