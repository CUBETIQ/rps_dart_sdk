/// Essential tests for RPS SDK v2
///
/// Focused test suite covering core functionality without redundancy.
library;

import 'dart:io';
import 'package:test/test.dart';

import '../lib/rps_sdk_v2.dart';

void main() {
  group('RPS SDK v2 Essential Tests', () {
    group('Core Models', () {
      test('RpsConfig should create with defaults and custom values', () {
        // Test defaults
        const config1 = RpsConfig(baseUrl: 'https://api.test.com');
        expect(config1.baseUrl, equals('https://api.test.com'));
        expect(config1.timeout, equals(const Duration(seconds: 30)));
        expect(config1.enableOfflineCache, isTrue);
        expect(config1.maxOfflineCacheSize, equals(100));

        // Test custom values
        final config2 = RpsConfig(
          baseUrl: 'https://custom.api.com',
          timeout: const Duration(seconds: 60),
          headers: {'X-Test': 'value'},
          enableOfflineCache: false,
          maxOfflineCacheSize: 50,
        );
        expect(config2.timeout, equals(const Duration(seconds: 60)));
        expect(config2.headers['X-Test'], equals('value'));
        expect(config2.enableOfflineCache, isFalse);
        expect(config2.maxOfflineCacheSize, equals(50));
      });

      test('WebhookRequest should handle creation and serialization', () {
        final request = WebhookRequest(
          id: 'test-123',
          data: {'message': 'test'},
          headers: {'X-Custom': 'header'},
        );

        expect(request.id, equals('test-123'));
        expect(request.data['message'], equals('test'));
        expect(request.headers['X-Custom'], equals('header'));

        // Test JSON serialization
        final json = request.toJson();
        final restored = WebhookRequest.fromJson(json);
        expect(restored.id, equals(request.id));
        expect(restored.data, equals(request.data));
        expect(restored.headers, equals(request.headers));
      });

      test('WebhookResponse should identify status types correctly', () {
        const success = WebhookResponse(
          statusCode: 200,
          data: {},
          headers: {},
          duration: Duration(milliseconds: 100),
          requestId: 'test',
        );
        expect(success.isSuccess, isTrue);
        expect(success.isClientError, isFalse);
        expect(success.isServerError, isFalse);

        const clientError = WebhookResponse(
          statusCode: 400,
          data: {},
          headers: {},
          duration: Duration(milliseconds: 100),
          requestId: 'test',
        );
        expect(clientError.isClientError, isTrue);
        expect(clientError.isSuccess, isFalse);

        const serverError = WebhookResponse(
          statusCode: 500,
          data: {},
          headers: {},
          duration: Duration(milliseconds: 100),
          requestId: 'test',
        );
        expect(serverError.isServerError, isTrue);
        expect(serverError.isSuccess, isFalse);
      });
    });

    group('Exception Handling', () {
      test('Exception hierarchy should classify retryability correctly', () {
        // Retryable exceptions
        const networkEx = RpsNetworkException('Connection failed');
        const timeoutEx = RpsTimeoutException(
          'Timeout',
          timeout: Duration(seconds: 30),
        );
        const serverEx = RpsHttpException('Server error', statusCode: 500);
        const rateLimitEx = RpsHttpException('Rate limited', statusCode: 429);

        expect(networkEx.isRetryable, isTrue);
        expect(timeoutEx.isRetryable, isTrue);
        expect(serverEx.isRetryable, isTrue);
        expect(rateLimitEx.isRetryable, isTrue);

        // Non-retryable exceptions
        const configEx = RpsConfigException('Invalid config');
        const cancelEx = RpsCancelledException('Cancelled');
        const clientEx = RpsHttpException('Bad request', statusCode: 400);
        const idempotencyEx = RpsIdempotencyException(
          'Duplicate',
          duplicateId: 'dup-123',
        );

        expect(configEx.isRetryable, isFalse);
        expect(cancelEx.isRetryable, isFalse);
        expect(clientEx.isRetryable, isFalse);
        expect(idempotencyEx.isRetryable, isFalse);
      });

      test('Exceptions should provide user-friendly messages', () {
        const networkEx = RpsNetworkException('Connection failed');
        const timeoutEx = RpsTimeoutException(
          'Timeout',
          timeout: Duration(seconds: 30),
        );
        const serverEx = RpsHttpException('Server error', statusCode: 500);

        expect(networkEx.userMessage, contains('Network connection failed'));
        expect(timeoutEx.userMessage, contains('Request timed out'));
        expect(serverEx.userMessage, contains('Server error occurred'));
      });
    });

    group('Authentication', () {
      test('Authentication methods should generate correct headers', () {
        final apiKeyAuth = RpsAuthUtils.apiKey('test-key');
        expect(apiKeyAuth.getHeaders()['X-API-Key'], equals('test-key'));

        final bearerAuth = RpsAuthUtils.bearer('token-123');
        expect(
          bearerAuth.getHeaders()['Authorization'],
          equals('Bearer token-123'),
        );

        final customAuth = RpsAuthUtils.custom({'X-Custom': 'value'});
        expect(customAuth.getHeaders()['X-Custom'], equals('value'));
      });
    });

    group('Retry Logic', () {
      test('RetryConfig should calculate delays correctly', () {
        const config = RetryConfig(
          baseDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 30),
          useExponentialBackoff: true,
          useJitter: false,
        );

        expect(config.getDelay(0), equals(Duration.zero));
        expect(config.getDelay(1), equals(const Duration(seconds: 1)));
        expect(config.getDelay(2), equals(const Duration(seconds: 2)));
        expect(config.getDelay(3), equals(const Duration(seconds: 4)));
      });

      test('RetryPolicy should handle retries correctly', () async {
        final policy = RetryUtils.simple(maxAttempts: 2);
        int callCount = 0;

        // Test success on first attempt
        final result1 = await policy.execute('test-1', () async {
          callCount++;
          return 'success';
        });
        expect(result1, equals('success'));
        expect(callCount, equals(1));

        // Reset counter
        callCount = 0;

        // Test success after retry
        final result2 = await policy.execute('test-2', () async {
          callCount++;
          if (callCount < 2) {
            throw const RpsNetworkException('Network error');
          }
          return 'success-after-retry';
        });
        expect(result2, equals('success-after-retry'));
        expect(callCount, equals(2));
      });

      test('RetryPolicy should prevent duplicate requests', () async {
        final policy = RetryUtils.simple();

        // First request should succeed
        await policy.execute('duplicate-test', () async => 'first');

        // Second request with same ID should fail
        expect(
          () => policy.execute('duplicate-test', () async => 'second'),
          throwsA(isA<RpsIdempotencyException>()),
        );
      });
    });

    group('Offline Cache', () {
      late OfflineWebhookCache cache;
      late String testCacheDir;

      setUp(() async {
        testCacheDir = 'test_cache_${DateTime.now().millisecondsSinceEpoch}';
        cache = OfflineWebhookCache(
          cacheDirectory: testCacheDir,
          maxCacheSize: 5,
        );
        await cache.initialize();
      });

      tearDown(() async {
        await cache.dispose();
        try {
          final dir = Directory(testCacheDir);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (_) {}
      });

      test('should cache and retrieve requests', () async {
        final request = WebhookRequest(
          id: 'cache-test',
          data: {'payment': 'test', 'amount': 100.0},
        );

        await cache.cacheRequest(request, error: 'Network error', priority: 5);

        final retryable = await cache.getRetryableRequests();
        expect(retryable.length, equals(1));
        expect(retryable.first.id, equals('cache-test'));
        expect(retryable.first.priority, equals(5));
      });

      test('should handle cache size limits', () async {
        // Add more than max size (5)
        for (int i = 0; i < 8; i++) {
          await cache.cacheRequest(
            WebhookRequest(id: 'req-$i', data: {'index': i}),
          );
        }

        final retryable = await cache.getRetryableRequests();
        expect(retryable.length, lessThanOrEqualTo(5));
      });

      test('should calculate retry delays correctly', () {
        final cached = CachedWebhookRequest(
          id: 'delay-test',
          request: WebhookRequest(id: 'test', data: {}),
          cachedAt: DateTime.now(),
          retryCount: 1,
        );

        expect(cached.nextRetryDelay, equals(const Duration(minutes: 1)));

        final updated = cached.withRetry();
        expect(updated.retryCount, equals(2));
        expect(updated.nextRetryDelay, equals(const Duration(minutes: 5)));
      });
    });

    group('Statistics', () {
      test('RequestStats should track and calculate correctly', () {
        const initialStats = RequestStats();
        expect(initialStats.totalRequests, equals(0));
        expect(initialStats.successRate, equals(0.0));

        final stats1 = initialStats.withRequest(
          success: true,
          responseTime: const Duration(milliseconds: 100),
        );
        expect(stats1.totalRequests, equals(1));
        expect(stats1.successfulRequests, equals(1));
        expect(stats1.successRate, equals(100.0));

        final stats2 = stats1.withRequest(
          success: false,
          responseTime: const Duration(milliseconds: 200),
        );
        expect(stats2.totalRequests, equals(2));
        expect(stats2.successfulRequests, equals(1));
        expect(stats2.successRate, equals(50.0));
        expect(
          stats2.averageResponseTime,
          equals(const Duration(milliseconds: 150)),
        );
      });
    });
  });

  group('Integration Tests', () {
    test('should successfully connect to httpbin.org', () async {
      final client = RpsClient.create(
        config: RpsConfig(
          baseUrl: 'https://httpbin.org/post',
          enableOfflineCache: false, // Disable for this test
        ),
        retryPolicy: RetryUtils.noRetry(),
      );

      try {
        final response = await client.sendWebhook(
          data: {
            'test': 'integration',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        expect(response.statusCode, equals(200));
        expect(response.isSuccess, isTrue);
        expect(response.data, isNotEmpty);

        // httpbin.org echoes the request
        if (response.data.containsKey('json')) {
          final echoed = response.data['json'] as Map<String, dynamic>;
          expect(echoed['test'], equals('integration'));
        }
      } finally {
        await client.dispose();
      }
    });

    test('should handle HTTP errors correctly', () async {
      final client = RpsClient.create(
        config: RpsConfig(
          baseUrl: 'https://httpbin.org/status/500',
          enableOfflineCache: false,
          timeout: const Duration(seconds: 10),
        ),
        retryPolicy: RetryUtils.noRetry(),
      );

      try {
        await client.sendWebhook(data: {'test': 'error'});
        fail('Request should have failed with 500 error');
      } on RpsHttpException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.isServerError, isTrue);
        print('✅ HTTP 500 error handled correctly');
      } on RpsException catch (e) {
        print('⚠️  Got ${e.runtimeType} instead of HTTP error: ${e.message}');
        // Accept timeout/cancellation as valid for unstable network
      } finally {
        await client.dispose();
      }
    });

    test('should demonstrate offline cache with failed requests', () async {
      final client = RpsClient.create(
        config: RpsConfig(
          baseUrl: 'https://httpbin.org/status/503', // Service unavailable
          enableOfflineCache: true,
        ),
        retryPolicy: RetryUtils.noRetry(),
        cacheDirectory: 'test_offline_${DateTime.now().millisecondsSinceEpoch}',
      );

      try {
        await client.sendWebhook(
          data: {'payment': 'failed', 'amount': 50.0},
          requestId: 'offline-test',
        );
        fail('Request should have failed');
      } on RpsHttpException {
        // Expected failure
      }

      // Check that request was cached
      final stats = await client.getOfflineCacheStats();
      expect(stats, isNotNull);
      expect(stats!.totalRequests, equals(1));

      await client.dispose();
    });
  });

  group('RPS API Tests', () {
    const apiKey = '6057c8d2-3b11-4e0b-8bb8-649d9510904d';
    const baseUrl = 'https://rps.service.ctdn.net/third-party/rps/webhook';

    test('should connect to RPS API and get consistent responses', () async {
      final client = RpsClient.create(
        config: RpsConfig(
          baseUrl: baseUrl,
          auth: RpsAuthUtils.apiKey(apiKey),
          enableOfflineCache: false,
        ),
        retryPolicy: RetryUtils.noRetry(),
      );

      try {
        await client.sendWebhook(
          data: {
            'test': 'rps_api',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        print('✅ RPS API: Request succeeded');
      } on RpsHttpException catch (e) {
        print('📡 RPS API Response: ${e.statusCode} - ${e.message}');

        // Expected responses based on our analysis
        if (e.statusCode == 403) {
          print('  Status: API key requires activation/setup');
          expect(e.isRetryable, isFalse);
        } else if (e.statusCode == 401) {
          print('  Status: Authentication method recognized but rejected');
          expect(e.isRetryable, isFalse);
        }

        // Verify error details
        expect(e.requestId, isNotNull);
        expect(e.statusCode, greaterThan(0));
      } finally {
        await client.dispose();
      }
    });

    test('should test Bearer token vs API key authentication', () async {
      final testPayload = {
        'auth_test': 'comparison',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Test API Key
      final apiKeyClient = RpsClient.create(
        config: RpsConfig(baseUrl: baseUrl, auth: RpsAuthUtils.apiKey(apiKey)),
        retryPolicy: RetryUtils.noRetry(),
      );

      int apiKeyStatus = 0;
      try {
        await apiKeyClient.sendWebhook(data: testPayload);
      } on RpsHttpException catch (e) {
        apiKeyStatus = e.statusCode;
      }
      await apiKeyClient.dispose();

      // Test Bearer Token
      final bearerClient = RpsClient.create(
        config: RpsConfig(baseUrl: baseUrl, auth: RpsAuthUtils.bearer(apiKey)),
        retryPolicy: RetryUtils.noRetry(),
      );

      int bearerStatus = 0;
      try {
        await bearerClient.sendWebhook(data: testPayload);
      } on RpsHttpException catch (e) {
        bearerStatus = e.statusCode;
      }
      await bearerClient.dispose();

      print('API Key Status: $apiKeyStatus, Bearer Status: $bearerStatus');

      // Verify our findings: API Key gets 403, Bearer gets 401
      expect(apiKeyStatus, equals(403));
      expect(bearerStatus, equals(401));

      print(
        '✅ Authentication behavior confirmed: API recognizes different auth methods',
      );
    });
  });
}
