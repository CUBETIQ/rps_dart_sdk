import 'package:rps_dart_sdk/src/cache/cache_manager.dart';
import 'package:rps_dart_sdk/src/cache/cache_policy.dart';
import 'package:rps_dart_sdk/src/cache/cache_storage.dart';
import 'package:rps_dart_sdk/src/core/models.dart';
import 'package:test/test.dart';

// Mock storage for testing
class MockCacheStorage implements CacheStorage {
  final Map<String, Map<String, dynamic>> _storage = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> store(String key, Map<String, dynamic> data) async {
    _ensureInitialized();
    _storage[key] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> retrieve(String key) async {
    _ensureInitialized();
    return _storage[key] != null
        ? Map<String, dynamic>.from(_storage[key]!)
        : null;
  }

  @override
  Future<void> remove(String key) async {
    _ensureInitialized();
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    _storage.clear();
  }

  @override
  Future<List<String>> getAllKeys() async {
    _ensureInitialized();
    return _storage.keys.toList();
  }

  @override
  Future<int> size() async {
    _ensureInitialized();
    return _storage.length;
  }

  @override
  Future<bool> containsKey(String key) async {
    _ensureInitialized();
    return _storage.containsKey(key);
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _storage.clear();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Storage not initialized');
    }
  }
}

void main() {
  group('CacheManager', () {
    late MockCacheStorage mockStorage;
    late CachePolicy policy;
    late CacheManager cacheManager;

    setUp(() async {
      mockStorage = MockCacheStorage();
      policy = const CachePolicy(
        maxAge: Duration(hours: 1),
        maxSize: 3,
        enableOfflineCache: true,
        evictionPolicy: EvictionPolicy.fifo,
      );
      cacheManager = CacheManager(storage: mockStorage, policy: policy);
      await cacheManager.initialize();
    });

    tearDown(() async {
      await cacheManager.dispose();
    });

    test('should initialize successfully', () async {
      final newManager = CacheManager(
        storage: MockCacheStorage(),
        policy: policy,
      );

      await newManager.initialize();
      expect(newManager, isNotNull);
      await newManager.dispose();
    });

    test('should cache and retrieve requests', () async {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );

      await cacheManager.cacheRequest(request);
      final cachedRequests = await cacheManager.getCachedRequests();

      expect(cachedRequests, hasLength(1));
      expect(cachedRequests.first.id, equals('test_request'));
      expect(cachedRequests.first.request.data, equals({'amount': 100}));
    });

    test('should remove cached requests', () async {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );

      await cacheManager.cacheRequest(request);
      expect(await cacheManager.getCachedRequests(), hasLength(1));

      await cacheManager.removeCachedRequest('test_request');
      expect(await cacheManager.getCachedRequests(), isEmpty);
    });

    test('should cache and retrieve responses', () async {
      final response = RpsResponse(
        statusCode: 200,
        data: {'result': 'success'},
        headers: {'content-type': 'application/json'},
        responseTime: Duration(milliseconds: 100),
        fromCache: false,
      );

      await cacheManager.cacheResponse('test_key', response);
      final cachedResponse = await cacheManager.getCachedResponse('test_key');

      expect(cachedResponse, isNotNull);
      expect(cachedResponse!.statusCode, equals(200));
      expect(cachedResponse.data, equals({'result': 'success'}));
      expect(cachedResponse.fromCache, isTrue);
    });

    test('should return null for expired cached responses', () async {
      // Create a policy with very short max age
      final shortPolicy = CachePolicy(
        maxAge: Duration(milliseconds: 1),
        maxSize: 10,
      );
      final shortCacheManager = CacheManager(
        storage: MockCacheStorage(),
        policy: shortPolicy,
      );
      await shortCacheManager.initialize();

      final response = RpsResponse(
        statusCode: 200,
        data: {'result': 'success'},
        headers: {},
        responseTime: Duration(milliseconds: 100),
        fromCache: false,
      );

      await shortCacheManager.cacheResponse('test_key', response);

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      final cachedResponse = await shortCacheManager.getCachedResponse(
        'test_key',
      );
      expect(cachedResponse, isNull);

      await shortCacheManager.dispose();
    });

    test('should enforce capacity limits with FIFO eviction', () async {
      // Fill cache to capacity
      for (int i = 0; i < 3; i++) {
        final request = RpsRequest(
          id: 'request_$i',
          type: 'invoice',
          data: {'amount': i},
        );
        await cacheManager.cacheRequest(request);
      }

      expect(await mockStorage.size(), equals(3));

      // Add one more to trigger eviction
      final newRequest = RpsRequest(
        id: 'request_new',
        type: 'invoice',
        data: {'amount': 999},
      );
      await cacheManager.cacheRequest(newRequest);

      // Should still be at capacity
      expect(await mockStorage.size(), equals(3));

      // The oldest entry should be evicted
      final keys = await mockStorage.getAllKeys();
      expect(keys, isNot(contains('request_request_0')));
      expect(keys, contains('request_request_new'));
    });

    test('should get cache statistics', () async {
      // Add some requests and responses
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );
      await cacheManager.cacheRequest(request);

      final response = RpsResponse(
        statusCode: 200,
        data: {'result': 'success'},
        headers: {},
        responseTime: Duration(milliseconds: 100),
        fromCache: false,
      );
      await cacheManager.cacheResponse('test_response', response);

      final stats = await cacheManager.getStatistics();

      expect(stats.totalEntries, equals(2));
      expect(stats.cachedRequests, equals(1));
      expect(stats.cachedResponses, equals(1));
      expect(stats.maxCapacity, equals(3));
      expect(stats.utilizationPercentage, closeTo(66.7, 0.1));
    });

    test('should clear all cache', () async {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );
      await cacheManager.cacheRequest(request);

      expect(await mockStorage.size(), equals(1));

      await cacheManager.clearCache();

      expect(await mockStorage.size(), equals(0));
    });

    test('should respect cache policy for request caching', () async {
      final disabledPolicy = CachePolicy(
        cacheFailedRequests: false,
        maxSize: 10,
      );
      final disabledManager = CacheManager(
        storage: MockCacheStorage(),
        policy: disabledPolicy,
      );
      await disabledManager.initialize();

      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );

      await disabledManager.cacheRequest(request);
      final cachedRequests = await disabledManager.getCachedRequests();

      expect(cachedRequests, isEmpty);
      await disabledManager.dispose();
    });

    test('should respect cache policy for response caching', () async {
      final disabledPolicy = CachePolicy(
        cacheSuccessfulResponses: false,
        maxSize: 10,
      );
      final disabledManager = CacheManager(
        storage: MockCacheStorage(),
        policy: disabledPolicy,
      );
      await disabledManager.initialize();

      final response = RpsResponse(
        statusCode: 200,
        data: {'result': 'success'},
        headers: {},
        responseTime: Duration(milliseconds: 100),
        fromCache: false,
      );

      await disabledManager.cacheResponse('test_key', response);
      final cachedResponse = await disabledManager.getCachedResponse(
        'test_key',
      );

      expect(cachedResponse, isNull);
      await disabledManager.dispose();
    });

    test('should handle corrupted cached requests gracefully', () async {
      // Manually insert corrupted data
      await mockStorage.store('request_corrupted', {'invalid': 'data'});

      final cachedRequests = await cacheManager.getCachedRequests();

      // Should skip corrupted entries and clean them up
      expect(cachedRequests, isEmpty);
      expect(await mockStorage.containsKey('request_corrupted'), isFalse);
    });

    test('should process cached requests', () async {
      final request1 = RpsRequest(
        id: 'request_1',
        type: 'invoice',
        data: {'amount': 100},
      );
      final request2 = RpsRequest(
        id: 'request_2',
        type: 'invoice',
        data: {'amount': 200},
      );

      await cacheManager.cacheRequest(request1);
      await cacheManager.cacheRequest(request2);

      // This should not throw and should process all cached requests
      await cacheManager.processCachedRequests();

      // Requests should still be cached (they would be removed after successful retry)
      final cachedRequests = await cacheManager.getCachedRequests();
      expect(cachedRequests, hasLength(2));
    });

    test('should handle disabled offline cache processing', () async {
      final disabledPolicy = CachePolicy(
        enableOfflineCache: false,
        maxSize: 10,
      );
      final disabledManager = CacheManager(
        storage: MockCacheStorage(),
        policy: disabledPolicy,
      );
      await disabledManager.initialize();

      // Should not throw even with disabled offline cache
      await disabledManager.processCachedRequests();

      await disabledManager.dispose();
    });
  });

  group('CachedRequest', () {
    test('should create cached request', () {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );
      final cachedRequest = CachedRequest(
        id: 'cached_1',
        request: request,
        cachedAt: DateTime.now(),
      );

      expect(cachedRequest.id, equals('cached_1'));
      expect(cachedRequest.request, equals(request));
      expect(cachedRequest.retryCount, equals(0));
      expect(cachedRequest.lastRetryAt, isNull);
      expect(cachedRequest.lastError, isNull);
    });

    test('should update retry information', () {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );
      final cachedRequest = CachedRequest(
        id: 'cached_1',
        request: request,
        cachedAt: DateTime.now(),
      );

      final updatedRequest = cachedRequest.withRetry(
        lastError: 'Network error',
      );

      expect(updatedRequest.retryCount, equals(1));
      expect(updatedRequest.lastError, equals('Network error'));
      expect(updatedRequest.lastRetryAt, isA<DateTime>());
      expect(updatedRequest.id, equals(cachedRequest.id));
      expect(updatedRequest.request, equals(cachedRequest.request));
    });

    test('should serialize to and from JSON', () {
      final request = RpsRequest(
        id: 'test_request',
        type: 'invoice',
        data: {'amount': 100},
      );
      final cachedRequest = CachedRequest(
        id: 'cached_1',
        request: request,
        cachedAt: DateTime.now(),
        retryCount: 2,
        lastRetryAt: DateTime.now(),
        lastError: 'Network timeout',
      );

      final json = cachedRequest.toJson();
      final deserializedRequest = CachedRequest.fromJson(json);

      expect(deserializedRequest.id, equals(cachedRequest.id));
      expect(deserializedRequest.request.id, equals(cachedRequest.request.id));
      expect(deserializedRequest.retryCount, equals(cachedRequest.retryCount));
      expect(deserializedRequest.lastError, equals(cachedRequest.lastError));
    });
  });

  group('CacheStatistics', () {
    test('should calculate utilization percentage', () {
      final stats = CacheStatistics(
        totalEntries: 75,
        cachedRequests: 50,
        cachedResponses: 25,
        maxCapacity: 100,
      );

      expect(stats.utilizationPercentage, equals(75.0));
    });

    test('should handle zero capacity', () {
      final stats = CacheStatistics(
        totalEntries: 10,
        cachedRequests: 5,
        cachedResponses: 5,
        maxCapacity: 0,
      );

      expect(stats.utilizationPercentage, equals(0.0));
    });

    test('should provide string representation', () {
      final stats = CacheStatistics(
        totalEntries: 75,
        cachedRequests: 50,
        cachedResponses: 25,
        maxCapacity: 100,
      );

      final string = stats.toString();
      expect(string, contains('total: 75'));
      expect(string, contains('requests: 50'));
      expect(string, contains('responses: 25'));
      expect(string, contains('capacity: 100'));
      expect(string, contains('utilization: 75.0%'));
    });
  });
}
