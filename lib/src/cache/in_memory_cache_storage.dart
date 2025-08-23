/// In-memory implementation of cache storage
///
/// This file provides a simple in-memory cache storage implementation
/// suitable for testing and development. For production use, consider
/// implementing persistent storage.
library;

import 'dart:convert';
import 'cache_storage.dart';

/// Simple in-memory cache storage implementation
class InMemoryCacheStorage implements CacheStorage {
  final Map<String, String> _storage = {};
  final Duration _defaultMaxAge = Duration(hours: 1);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> store(String key, Map<String, dynamic> data) async {
    try {
      final entry = CacheEntry.create(data);
      final entryJson = json.encode(entry.toJson());
      _storage[key] = entryJson;
    } catch (e) {
      throw CacheStorageException('Error storing cache entry for key: $key', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> retrieve(String key) async {
    try {
      final entryJson = _storage[key];
      if (entryJson == null) return null;

      final entryData = json.decode(entryJson) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(entryData);

      if (entry.isExpired(_defaultMaxAge)) {
        await remove(key);
        return null;
      }

      final updatedEntry = entry.withAccess();
      final updatedJson = json.encode(updatedEntry.toJson());
      _storage[key] = updatedJson;

      return updatedEntry.data;
    } catch (e) {
      throw CacheStorageException(
        'Error retrieving cache entry for key: $key',
        e,
      );
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    final entryJson = _storage[key];
    if (entryJson == null) return false;

    try {
      final entryData = json.decode(entryJson) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(entryData);

      if (entry.isExpired(_defaultMaxAge)) {
        await remove(key);
        return false;
      }

      return true;
    } catch (e) {
      await remove(key);
      return false;
    }
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<List<String>> getAllKeys() async {
    // Remove expired entries first
    await _removeExpired();
    return _storage.keys.toList();
  }

  @override
  Future<int> size() async {
    // Remove expired entries first
    await _removeExpired();
    return _storage.length;
  }

  Future<void> _removeExpired() async {
    final keysToRemove = <String>[];

    for (final key in _storage.keys) {
      try {
        final entryJson = _storage[key];
        if (entryJson == null) continue;

        final entryData = json.decode(entryJson) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(entryData);

        if (entry.isExpired(_defaultMaxAge)) {
          keysToRemove.add(key);
        }
      } catch (e) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _storage.remove(key);
    }
  }

  @override
  Future<void> dispose() async {
    _storage.clear();
  }
}
