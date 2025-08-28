/// Cache storage factory for creating different storage backends
///
/// This file provides a factory for creating cache storage instances
/// with different backends like in-memory, SharedPreferences, and Hive.
library;

import 'cache_storage.dart';
import 'in_memory_cache_storage.dart';
import 'hive_cache_storage.dart';

/// Enum for different cache storage types
enum CacheStorageType { inMemory, hive }

/// Factory class for creating cache storage instances
class CacheStorageFactory {
  /// Create a cache storage instance based on the specified type
  static Future<CacheStorage> create({
    required CacheStorageType type,
    Duration defaultMaxAge = const Duration(hours: 24),
    Map<String, dynamic>? config,
  }) async {
    switch (type) {
      case CacheStorageType.inMemory:
        return _createInMemoryStorage(defaultMaxAge, config);

      case CacheStorageType.hive:
        return _createHiveStorage(defaultMaxAge, config);
    }
  }

  /// Create in-memory cache storage
  static Future<CacheStorage> _createInMemoryStorage(
    Duration defaultMaxAge,
    Map<String, dynamic>? config,
  ) async {
    final storage = InMemoryCacheStorage();
    await storage.initialize();
    return storage;
  }

  /// Create Hive cache storage
  static Future<CacheStorage> _createHiveStorage(
    Duration defaultMaxAge,
    Map<String, dynamic>? config,
  ) async {
    final path = config?['path'] as String?;
    final boxName = config?['boxName'] as String?;

    final storage = HiveCacheStorage(
      defaultMaxAge: defaultMaxAge,
      path: path,
      boxName: boxName,
    );
    await storage.initialize();
    return storage;
  }

  /// Get recommended storage type based on use case
  static CacheStorageType getRecommendedStorageType({
    required bool needsPersistence,
    required bool isHighFrequency,
    required bool isLargeData,
  }) {
    if (!needsPersistence) {
      return CacheStorageType.inMemory;
    }

    return CacheStorageType.hive;
  }

  /// Get storage type from string name
  static CacheStorageType? fromString(String name) {
    switch (name.toLowerCase()) {
      case 'memory':
      case 'inmemory':
      case 'in_memory':
        return CacheStorageType.inMemory;

      case 'hive':
        return CacheStorageType.hive;

      default:
        return null;
    }
  }

  /// Get storage type capabilities
  static Map<String, bool> getCapabilities(CacheStorageType type) {
    switch (type) {
      case CacheStorageType.inMemory:
        return {
          'persistent': false,
          'fast': true,
          'largeData': true,
          'concurrent': true,
          'crossSession': false,
        };

      case CacheStorageType.hive:
        return {
          'persistent': true,
          'fast': true,
          'largeData': true,
          'concurrent': true,
          'crossSession': true,
        };
    }
  }
}
