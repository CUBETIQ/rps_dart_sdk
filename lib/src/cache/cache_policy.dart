/// Cache policy interfaces for the RPS SDK
///
/// This file defines the cache policy system that controls caching behavior
/// including cache duration, size limits, and eviction strategies.
library;

/// Eviction policies for cache management when capacity limits are reached
enum EvictionPolicy { fifo, lru, lfu }

/// Cache policy configuration that controls all aspects of caching behavior
class CachePolicy {
  /// Maximum age for cached entries before they expire
  final Duration maxAge;

  /// Maximum number of entries to store in cache
  final int maxSize;

  /// Whether to enable offline request caching
  final bool enableOfflineCache;

  /// Eviction policy when cache reaches capacity
  final EvictionPolicy evictionPolicy;

  /// Whether to cache successful responses
  final bool cacheSuccessfulResponses;

  /// Whether to cache failed requests for offline retry
  final bool cacheFailedRequests;

  const CachePolicy({
    this.maxAge = const Duration(hours: 1),
    this.maxSize = 1000,
    this.enableOfflineCache = true,
    this.evictionPolicy = EvictionPolicy.fifo,
    this.cacheSuccessfulResponses = true,
    this.cacheFailedRequests = true,
  });

  /// Creates a cache policy optimized for offline-first applications
  factory CachePolicy.offlineFirst() {
    return const CachePolicy(
      maxAge: Duration(days: 7),
      maxSize: 5000,
      enableOfflineCache: true,
      evictionPolicy: EvictionPolicy.lru,
      cacheSuccessfulResponses: true,
      cacheFailedRequests: true,
    );
  }

  /// Creates a cache policy optimized for performance with minimal storage
  factory CachePolicy.performance() {
    return const CachePolicy(
      maxAge: Duration(minutes: 15),
      maxSize: 500,
      enableOfflineCache: false,
      evictionPolicy: EvictionPolicy.lfu,
      cacheSuccessfulResponses: true,
      cacheFailedRequests: false,
    );
  }

  /// Creates a cache policy with no caching
  factory CachePolicy.disabled() {
    return const CachePolicy(
      maxAge: Duration.zero,
      maxSize: 0,
      enableOfflineCache: false,
      evictionPolicy: EvictionPolicy.fifo,
      cacheSuccessfulResponses: false,
      cacheFailedRequests: false,
    );
  }

  /// Validates the cache policy configuration
  void validate() {
    if (maxAge.isNegative) {
      throw ArgumentError('Max age cannot be negative');
    }

    if (maxSize < 0) {
      throw ArgumentError('Max size cannot be negative');
    }

    if (maxSize == 0 && (cacheSuccessfulResponses || cacheFailedRequests)) {
      throw ArgumentError('Cannot enable caching with zero max size');
    }
  }

  /// Creates a copy with modified properties
  CachePolicy copyWith({
    Duration? maxAge,
    int? maxSize,
    bool? enableOfflineCache,
    EvictionPolicy? evictionPolicy,
    bool? cacheSuccessfulResponses,
    bool? cacheFailedRequests,
  }) {
    return CachePolicy(
      maxAge: maxAge ?? this.maxAge,
      maxSize: maxSize ?? this.maxSize,
      enableOfflineCache: enableOfflineCache ?? this.enableOfflineCache,
      evictionPolicy: evictionPolicy ?? this.evictionPolicy,
      cacheSuccessfulResponses:
          cacheSuccessfulResponses ?? this.cacheSuccessfulResponses,
      cacheFailedRequests: cacheFailedRequests ?? this.cacheFailedRequests,
    );
  }
}
