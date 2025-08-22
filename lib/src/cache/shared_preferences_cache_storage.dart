/// SharedPreferences implementation of cache storage
///
/// This file provides a cache storage implementation using SharedPreferences
/// for simple key-value caching on mobile platforms.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_storage.dart';

/// Cache storage implementation using SharedPreferences
class SharedPreferencesCacheStorage implements CacheStorage {
  static const String _keyPrefix = 'rps_cache_';

  SharedPreferences? _prefs;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      throw CacheStorageException(
        'Failed to initialize SharedPreferences cache storage',
        e,
      );
    }
  }

  @override
  Future<void> store(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();

    try {
      final entry = CacheEntry.create(data);
      final entryJson = json.encode(entry.toJson());

      final success = await _prefs!.setString(_keyPrefix + key, entryJson);
      if (!success) {
        throw CacheStorageException('Failed to store data for key: $key');
      }
    } catch (e) {
      if (e is CacheStorageException) rethrow;
      throw CacheStorageException('Error storing cache entry for key: $key', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> retrieve(String key) async {
    await _ensureInitialized();

    try {
      final entryJson = _prefs!.getString(_keyPrefix + key);
      if (entryJson == null) return null;

      final entryData = json.decode(entryJson) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(entryData);

      // Update access information
      final updatedEntry = entry.withAccess();
      final updatedJson = json.encode(updatedEntry.toJson());
      await _prefs!.setString(_keyPrefix + key, updatedJson);

      return entry.data;
    } catch (e) {
      // If we can't parse the entry, remove it
      await _prefs!.remove(_keyPrefix + key);
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
      await _prefs!.remove(_keyPrefix + key);
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
      final keys = await getAllKeys();
      for (final key in keys) {
        await _prefs!.remove(_keyPrefix + key);
      }
    } catch (e) {
      throw CacheStorageException('Error clearing cache', e);
    }
  }

  @override
  Future<List<String>> getAllKeys() async {
    await _ensureInitialized();

    try {
      final allKeys = _prefs!.getKeys();
      return allKeys
          .where((key) => key.startsWith(_keyPrefix))
          .map((key) => key.substring(_keyPrefix.length))
          .toList();
    } catch (e) {
      throw CacheStorageException('Error getting cache keys', e);
    }
  }

  @override
  Future<int> size() async {
    final keys = await getAllKeys();
    return keys.length;
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();

    try {
      return _prefs!.containsKey(_keyPrefix + key);
    } catch (e) {
      throw CacheStorageException('Error checking key existence: $key', e);
    }
  }

  @override
  Future<void> dispose() async {
    // SharedPreferences doesn't need explicit disposal
    _initialized = false;
    _prefs = null;
  }

  /// Get cache entry metadata for a specific key
  Future<CacheEntry?> getEntry(String key) async {
    await _ensureInitialized();

    try {
      final entryJson = _prefs!.getString(_keyPrefix + key);
      if (entryJson == null) return null;

      final entryData = json.decode(entryJson) as Map<String, dynamic>;
      return CacheEntry.fromJson(entryData);
    } catch (e) {
      return null;
    }
  }

  /// Get all cache entries with their metadata
  Future<Map<String, CacheEntry>> getAllEntries() async {
    await _ensureInitialized();

    final entries = <String, CacheEntry>{};
    final keys = await getAllKeys();

    for (final key in keys) {
      final entry = await getEntry(key);
      if (entry != null) {
        entries[key] = entry;
      }
    }

    return entries;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
