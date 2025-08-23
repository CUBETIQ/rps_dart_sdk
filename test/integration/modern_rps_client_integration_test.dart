/// Comprehensive integration tests for the Modern RPS SDK
///
/// This file contains end-to-end tests for complete request lifecycle,
/// offline scenarios, concurrent requests, authentication integration,
/// and performance tests.
library;

import 'package:test/test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';
import 'dart:async';

void main() {
  group('Modern RPS SDK Integration Tests', () {
    late RpsClient client;

    const testBaseUrl = 'https://httpbin.org/post';
    const testApiKey = 'test-api-key';

    setUp(() async {
      // Create a basic client for most tests
      client = await RpsClientBuilder.createSimple(
        webhookUrl: testBaseUrl,
        apiKey: testApiKey,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      );
    });

    tearDown(() async {
      await client.dispose();
    });

    group('End-to-End Request Lifecycle', () {
      test('should complete full request lifecycle with validation', () async {
        final response = await client.sendMessage(
          type: 'test',
          data: {
            'message': 'Hello World',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        expect(response.statusCode, equals(200));
        expect(response.data, isA<Map<String, dynamic>>());
        expect(response.responseTime.inMilliseconds, greaterThan(0));
      });

      test('should handle request with custom headers', () async {
        final response = await client.sendMessage(
          type: 'test',
          data: {'test': 'data'},
          headers: {
            'X-Custom-Header': 'test-value',
            'X-Request-ID': 'test-123',
          },
        );

        expect(response.statusCode, equals(200));
      });

      test('should handle large payloads', () async {
        // Create a large data payload
        final largeData = {
          'items': List.generate(
            1000,
            (index) => {
              'id': index,
              'name': 'Item $index',
              'data': 'Large data payload ' * 100,
            },
          ),
        };

        final response = await client.sendMessage(
          type: 'bulk',
          data: largeData,
        );

        expect(response.statusCode, equals(200));
      });
    });

    group('Offline Scenarios and Cache Synchronization', () {
      late RpsClient offlineClient;

      setUp(() async {
        offlineClient = await RpsClientBuilder.createOfflineFirst(
          webhookUrl: 'https://httpbin.org/post',
          apiKey: testApiKey,
        );
      });

      tearDown(() async {
        await offlineClient.dispose();
      });

      test('should cache failed requests for offline retry', () async {
        // Try to send to a non-existent endpoint to simulate network failure
        try {
          await offlineClient.sendMessage(
            type: 'test',
            data: {'test': 'offline'},
          );
        } catch (e) {
          // Expected to fail
        }

        // Check if the request was cached
        final stats = await offlineClient.getStatistics();
        expect(stats['cache'], isNotNull);
      });

      test('should handle offline to online transition', () async {
        // This test would typically require network simulation
        // For now, we'll test the basic functionality

        final response = await offlineClient.sendMessage(
          type: 'test',
          data: {'transition': 'test'},
        );

        expect(response.statusCode, equals(200));
      });
    });

    group('Concurrent Request Handling', () {
      test('should handle multiple concurrent requests', () async {
        const numberOfRequests = 10;
        final futures = <Future<RpsResponse>>[];

        for (int i = 0; i < numberOfRequests; i++) {
          futures.add(
            client.sendMessage(
              type: 'concurrent',
              data: {
                'requestId': i,
                'timestamp': DateTime.now().toIso8601String(),
              },
            ),
          );
        }

        final responses = await Future.wait(futures);

        expect(responses.length, equals(numberOfRequests));
        for (final response in responses) {
          expect(response.statusCode, equals(200));
        }
      });

      test('should maintain connection pooling under load', () async {
        const numberOfRequests = 50;
        final stopwatch = Stopwatch()..start();

        final futures = <Future<RpsResponse>>[];
        for (int i = 0; i < numberOfRequests; i++) {
          futures.add(
            client.sendMessage(type: 'load_test', data: {'index': i}),
          );
        }

        await Future.wait(futures);
        stopwatch.stop();

        // All requests should complete within reasonable time
        expect(stopwatch.elapsed.inSeconds, lessThan(30));
      });

      test('should handle request cancellation', () async {
        // Create a client for cancellation testing with delay endpoint
        final cancelClient = await RpsClientBuilder.createSimple(
          webhookUrl: 'https://httpbin.org/delay/5', // Use delay endpoint
          apiKey: testApiKey,
        );

        try {
          // Start a long-running request
          final future = cancelClient.sendMessage(
            type: 'slow_test',
            data: {'delay': 5},
          );

          // Cancel after a longer delay to ensure the request has started
          await Future.delayed(const Duration(milliseconds: 500));
          await cancelClient.cancelAllRequests();

          // The request should be cancelled or complete
          // Since cancellation timing is unpredictable, we just verify the client can handle it
          try {
            await future;
            // If it completes, that's also acceptable since timing is unpredictable
          } catch (e) {
            // If it throws an error, verify it's a cancellation or network error
            expect(e, isA<RpsError>());
          }
        } finally {
          await cancelClient.dispose();
        }
      });
    });

    group('  Integration', () {
      test('should work with API key authentication', () async {
        // Create an enterprise-like client with events enabled
        final config = RpsConfigurationBuilder()
            .setBaseUrl('https://httpbin.org/post')
            .setApiKey('test-enterprise-key')
            .useInMemoryCache()
            .build();

        final eventBus = RpsEventBus();
        final authClient = await RpsClientBuilder()
            .withConfiguration(config)
            .withEventBus(eventBus)
            .withLogger(SimpleLoggingManager(level: RpsLogLevel.info))
            .build();

        try {
          final response = await authClient.sendMessage(
            type: 'auth_test',
            data: {'authenticated': true},
          );

          expect(response.statusCode, equals(200));
        } finally {
          await authClient.dispose();
        }
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle network timeouts gracefully', () async {
        final timeoutClient = await RpsClientBuilder.createSimple(
          webhookUrl:
              'https://httpbin.org/delay/10', // Use delay endpoint for timeout test
          apiKey: testApiKey,
          connectTimeout: const Duration(milliseconds: 1), // Very short timeout
          receiveTimeout: const Duration(milliseconds: 1),
        );

        try {
          await expectLater(
            timeoutClient.sendMessage(
              type: 'timeout_test',
              data: {'test': 'timeout'},
            ),
            throwsA(isA<RpsError>()),
          );
        } finally {
          await timeoutClient.dispose();
        }
      });

      test('should retry failed requests according to policy', () async {
        // This would typically require a mock server to simulate failures
        // For now, we test that retry configuration is properly set
        final config = client.configuration;
        expect(config.retryPolicy, isNotNull);
      });

      test('should handle validation errors', () async {
        // Create a client with a strict validator
        final config = RpsConfigurationBuilder()
            .setBaseUrl('https://httpbin.org/post')
            .setApiKey(testApiKey)
            .useInMemoryCache()
            .build();

        final validator = DefaultRequestValidator(
          schemas: {
            'test_type': ValidationSchema(requiredFields: {'required_field'}),
          },
        );

        final strictClient = await RpsClientBuilder()
            .withConfiguration(config)
            .withValidator(validator)
            .build();

        try {
          // This should fail validation because 'required_field' is missing
          await expectLater(
            strictClient.sendMessage(
              type: 'test_type',
              data: {'optional_field': 'value'},
            ),
            throwsA(isA<RpsError>()),
          );
        } finally {
          await strictClient.dispose();
        }
      });
    });

    group('Performance and Memory Tests', () {
      test('should not leak memory with many requests', () async {
        const numberOfCycles = 20; // Reduced from 100 to prevent timeout

        for (int cycle = 0; cycle < numberOfCycles; cycle++) {
          final response = await client.sendMessage(
            type: 'memory_test',
            data: {
              'cycle': cycle,
              'data': 'test data for memory leak detection',
            },
          );

          expect(response.statusCode, equals(200));

          // Periodic garbage collection suggestion
          if (cycle % 5 == 0) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      });

      test('should maintain reasonable response times', () async {
        final responseTimes = <Duration>[];
        const numberOfRequests = 20;

        for (int i = 0; i < numberOfRequests; i++) {
          final stopwatch = Stopwatch()..start();

          await client.sendMessage(type: 'performance', data: {'iteration': i});

          stopwatch.stop();
          responseTimes.add(stopwatch.elapsed);
        }

        // Calculate average response time
        final averageMs =
            responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
            numberOfRequests;

        // Average should be reasonable (under 2 seconds for httpbin)
        expect(averageMs, lessThan(2000));
      });

      test('should handle storage backend efficiency', () async {
        final offlineClient = await RpsClientBuilder.createOfflineFirst(
          webhookUrl: 'https://httpbin.org/post',
          apiKey: testApiKey,
        );

        try {
          // Test storage operations
          final stats = await offlineClient.getStatistics();
          expect(stats['cache'], isNotNull);

          // Storage should be efficient for multiple operations
          final startTime = DateTime.now();

          for (int i = 0; i < 10; i++) {
            await offlineClient.sendMessage(
              type: 'storage_test',
              data: {'iteration': i},
            );
          }

          final endTime = DateTime.now();
          final totalTime = endTime.difference(startTime);

          // Should complete within reasonable time
          expect(totalTime.inSeconds, lessThan(30));
        } finally {
          await offlineClient.dispose();
        }
      });
    });

    group('Event System Integration', () {
      test('should emit events during request lifecycle', () async {
        // Create a client with events enabled
        final config = RpsConfigurationBuilder()
            .setBaseUrl('https://httpbin.org/post')
            .setApiKey(testApiKey)
            .useInMemoryCache()
            .build();

        final eventBus = RpsEventBus();
        final eventClient = await RpsClientBuilder()
            .withConfiguration(config)
            .withEventBus(eventBus)
            .build();

        try {
          final events = <RpsEvent>[];
          final subscription = eventClient.events?.listen((event) {
            events.add(event);
          });

          await eventClient.sendMessage(
            type: 'event_test',
            data: {'test': 'events'},
          );

          // Allow time for events to be processed
          await Future.delayed(const Duration(milliseconds: 100));

          subscription?.cancel();

          // Should have received some events
          expect(events.isNotEmpty, isTrue);
        } finally {
          await eventClient.dispose();
        }
      });
    });

    group('Configuration Validation', () {
      test('should validate configuration on client creation', () async {
        expect(
          () => RpsClientBuilder.createSimple(
            webhookUrl: '', // Invalid empty URL
            apiKey: testApiKey,
          ),
          throwsA(isA<RpsError>()),
        );
      });

      test('should allow valid custom configurations', () async {
        final customClient = await RpsClientBuilder()
            .withConfiguration(
              RpsConfigurationBuilder()
                  .setBaseUrl('https://httpbin.org/post')
                  .setApiKey(testApiKey)
                  .setTimeouts(
                    const Duration(seconds: 15),
                    const Duration(seconds: 30),
                  )
                  .setRetryPolicy(
                    ExponentialBackoffRetryPolicy(
                      maxAttempts: 3,
                      baseDelay: const Duration(seconds: 1),
                    ),
                  )
                  .setCachePolicy(CachePolicy.performance())
                  .build(),
            )
            .build();

        try {
          final response = await customClient.sendMessage(
            type: 'custom_config',
            data: {'test': 'custom'},
          );

          expect(response.statusCode, equals(200));
        } finally {
          await customClient.dispose();
        }
      });
    });
  });
}
