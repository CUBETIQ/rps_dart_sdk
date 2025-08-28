/// Hive implementation of cache storage
///
/// This file provides a cache storage implementation using Hive CE
/// for high-performance, local database storage.
library;

import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'cache_storage.dart';

/// Cache storage implementation using Hive
class HiveCacheStorage implements CacheStorage {
  static const String _boxName = 'rps_cache';

  Box<String>? _box;
  bool _initialized = false;
  final Duration _defaultMaxAge;
  final String? _customPath;
  final String? _customBoxName;

  HiveCacheStorage({
    Duration defaultMaxAge = const Duration(hours: 24),
    String? path,
    String? boxName,
  }) : _defaultMaxAge = defaultMaxAge,
       _customPath = path,
       _customBoxName = boxName;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _initializeHive();
      _initialized = true;
    } catch (e) {
      throw CacheStorageException('Failed to initialize Hive cache storage', e);
    }
  }

  /// Initialize Hive with fallback path handling for Android
  Future<void> _initializeHive() async {
    String? initPath = _customPath;
    final boxName = _customBoxName ?? _boxName;

    // If no custom path provided, try different locations
    if (initPath == null) {
      final fallbackPaths = _getFallbackPaths();

      for (final path in fallbackPaths) {
        try {
          Hive.init(path);

          if (!Hive.isBoxOpen(boxName)) {
            _box = await Hive.openBox<String>(boxName);
          } else {
            _box = Hive.box<String>(boxName);
          }
          return; // Success!
        } catch (e) {
          // Try next path
          continue;
        }
      }

      // If all paths failed, throw the last error
      throw CacheStorageException(
        'All Hive initialization paths failed. Consider using in-memory cache for Android apps.',
        null,
      );
    } else {
      // Use custom path
      Hive.init(initPath);

      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox<String>(boxName);
      } else {
        _box = Hive.box<String>(boxName);
      }
    }
  }

  /// Get fallback paths for different platforms
  List<String> _getFallbackPaths() {
    final paths = <String>[];

    // Try current directory first (works on desktop)
    paths.add('.');

    // Try system temp directory
    try {
      // For mobile platforms, try common writable directories
      paths.add('/tmp');
      paths.add('./cache');
      paths.add('./data');
    } catch (e) {
      // Ignore path errors
    }

    return paths;
  }

  @override
  Future<void> store(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();

    try {
      final entry = CacheEntry.create(data);
      final entryJson = json.encode(entry.toJson());
      await _box!.put(key, entryJson);
    } catch (e) {
      if (e is CacheStorageException) rethrow;
      throw CacheStorageException('Error storing cache entry for key: $key', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> retrieve(String key) async {
    await _ensureInitialized();

    try {
      final entryJson = _box!.get(key);
      if (entryJson == null) return null;

      final entryData = json.decode(entryJson) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(entryData);

      if (entry.isExpired(_defaultMaxAge)) {
        await remove(key);
        return null;
      }

      final updatedEntry = entry.withAccess();
      final updatedJson = json.encode(updatedEntry.toJson());
      await _box!.put(key, updatedJson);

      return entry.data;
    } catch (e) {
      if (e is CacheStorageException) rethrow;
      throw CacheStorageException(
        'Error retrieving cache entry for key: $key',
        e,
      );
    }
  }

  @override
  Future<void> remove(String key) async {
    await _ensureInitialized();

    try {
      await _box!.delete(key);
    } catch (e) {
      throw CacheStorageException(
        'Error removing cache entry for key: $key',
        e,
      );
    }
  }

  @override
  Future<void> clear() async {
    await _ensureInitialized();

    try {
      await _box!.clear();
    } catch (e) {
      throw CacheStorageException('Error clearing cache storage', e);
    }
  }

  @override
  Future<List<String>> getAllKeys() async {
    await _ensureInitialized();

    try {
      return _box!.keys.cast<String>().toList();
    } catch (e) {
      throw CacheStorageException('Error getting all cache keys', e);
    }
  }

  @override
  Future<int> size() async {
    await _ensureInitialized();
    return _box!.length;
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _box!.containsKey(key);
  }

  @override
  Future<void> dispose() async {
    if (_initialized && _box != null) {
      try {
        await _box!.close();
        _initialized = false;
        _box = null;
      } catch (e) {
        throw CacheStorageException('Error disposing Hive cache storage', e);
      }
    }
  }

  /// Compact the Hive database to reclaim space
  Future<void> compact() async {
    await _ensureInitialized();

    try {
      await _box!.compact();
    } catch (e) {
      throw CacheStorageException('Error compacting Hive cache storage', e);
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();

    try {
      final keys = await getAllKeys();
      int expiredCount = 0;
      int totalSize = 0;

      for (final key in keys) {
        final entryJson = _box!.get(key);
        if (entryJson != null) {
          totalSize += entryJson.length;

          try {
            final entryData = json.decode(entryJson) as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(entryData);
            if (entry.isExpired(_defaultMaxAge)) {
              expiredCount++;
            }
          } catch (e) {
            expiredCount++;
          }
        }
      }

      return {
        'totalEntries': keys.length,
        'expiredEntries': expiredCount,
        'validEntries': keys.length - expiredCount,
        'totalSizeBytes': totalSize,
        'averageSizeBytes': keys.isNotEmpty ? totalSize / keys.length : 0,
      };
    } catch (e) {
      throw CacheStorageException('Error getting cache statistics', e);
    }
  }

  /// Clean up expired entries
  Future<int> cleanupExpired() async {
    await _ensureInitialized();

    try {
      final keys = await getAllKeys();
      int removedCount = 0;

      for (final key in keys) {
        final entryJson = _box!.get(key);
        if (entryJson != null) {
          try {
            final entryData = json.decode(entryJson) as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(entryData);
            if (entry.isExpired(_defaultMaxAge)) {
              await _box!.delete(key);
              removedCount++;
            }
          } catch (e) {
            await _box!.delete(key);
            removedCount++;
          }
        }
      }

      return removedCount;
    } catch (e) {
      throw CacheStorageException('Error cleaning up expired entries', e);
    }
  }

  /// Ensure the storage is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
