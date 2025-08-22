/// Cache storage abstraction for the RPS SDK
///
/// This file defines the cache storage interface and implementations for
/// different storage backends including SharedPreferences.
library;

/// Abstract interface for cache storage backends
abstract class CacheStorage {
  /// Store data in the cache with the given key
  Future<void> store(String key, Map<String, dynamic> data);

  /// Retrieve data from the cache by key
  /// Returns null if the key doesn't exist or data is expired
  Future<Map<String, dynamic>?> retrieve(String key);

  /// Remove a specific entry from the cache
  Future<void> remove(String key);

  /// Clear all entries from the cache
  Future<void> clear();

  /// Get all keys currently stored in the cache
  Future<List<String>> getAllKeys();

  /// Get the current size of the cache (number of entries)
  Future<int> size();

  /// Check if a key exists in the cache
  Future<bool> containsKey(String key);

  /// Initialize the storage backend
  Future<void> initialize();

  /// Dispose of resources and cleanup
  Future<void> dispose();
}

/// Cache entry model that wraps stored data with metadata
class CacheEntry {
  /// The actual cached data
  final Map<String, dynamic> data;

  /// When this entry was created
  final DateTime createdAt;

  /// When this entry was last accessed
  final DateTime lastAccessedAt;

  /// How many times this entry has been accessed
  final int accessCount;

  /// Optional expiration time for this specific entry
  final DateTime? expiresAt;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.lastAccessedAt,
    this.accessCount = 1,
    this.expiresAt,
  });

  /// Create a new cache entry with current timestamp
  factory CacheEntry.create(Map<String, dynamic> data, {DateTime? expiresAt}) {
    final now = DateTime.now();
    return CacheEntry(
      data: data,
      createdAt: now,
      lastAccessedAt: now,
      accessCount: 1,
      expiresAt: expiresAt,
    );
  }

  /// Create a copy with updated access information
  CacheEntry withAccess() {
    return CacheEntry(
      data: data,
      createdAt: createdAt,
      lastAccessedAt: DateTime.now(),
      accessCount: accessCount + 1,
      expiresAt: expiresAt,
    );
  }

  /// Check if this entry has expired
  bool isExpired(Duration maxAge) {
    final now = DateTime.now();

    // Check specific expiration time first
    if (expiresAt != null && now.isAfter(expiresAt!)) {
      return true;
    }

    // Check age-based expiration
    return now.difference(createdAt) > maxAge;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'accessCount': accessCount,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt']),
      accessCount: json['accessCount'] ?? 1,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
    );
  }
}

/// Exception thrown when cache operations fail
class CacheStorageException implements Exception {
  final String message;
  final Object? cause;

  const CacheStorageException(this.message, [this.cause]);

  @override
  String toString() => 'CacheStorageException: $message';
}
