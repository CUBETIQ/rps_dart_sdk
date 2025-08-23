/// Cache storage abstraction for the RPS SDK
///
/// This file defines the cache storage interface and implementations for
/// different storage backends including SharedPreferences.
library;

/// Abstract interface for cache storage backends
abstract class CacheStorage {
  Future<void> store(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> retrieve(String key);
  Future<void> remove(String key);
  Future<void> clear();
  Future<List<String>> getAllKeys();
  Future<int> size();
  Future<bool> containsKey(String key);
  Future<void> initialize();
  Future<void> dispose();
}

/// Cache entry model that wraps stored data with metadata
class CacheEntry {
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final int accessCount;
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

    if (expiresAt != null && now.isAfter(expiresAt!)) {
      return true;
    }

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
