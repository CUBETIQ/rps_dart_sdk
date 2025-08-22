import 'package:rps_dart_sdk/src/core/error.dart';
import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/core/configuration.dart';
import 'package:rps_dart_sdk/src/cache/cache_policy.dart';
import 'package:rps_dart_sdk/src/retry/retry_policy.dart';

void main() {
  group('RpsConfigurationBuilder', () {
    late RpsConfigurationBuilder builder;

    setUp(() {
      builder = RpsConfigurationBuilder();
    });

    group('setBaseUrl', () {
      test('should set valid base URL', () {
        final config = builder.setBaseUrl('https://api.example.com').build();

        expect(config.baseUrl, equals('https://api.example.com'));
      });

      test('should throw RpsError for empty URL', () {
        expect(() => builder.setBaseUrl(''), throwsA(isA<RpsError>()));
      });

      test('should use default URL when not set', () {
        final config = builder.build();
        expect(config.baseUrl, equals('https://api.rps.com'));
      });
    });

    group('setApiKey', () {
      test('should set API key', () {
        final config = builder.setApiKey('test-api-key-12345').build();

        expect(config.apiKey, equals('test-api-key-12345'));
      });

      test('should allow empty API key', () {
        final config = builder.setApiKey('').build();

        expect(config.apiKey, equals(''));
      });

      test('should use empty string as default', () {
        final config = builder.build();
        expect(config.apiKey, equals(''));
      });
    });

    group('timeout configuration', () {
      test('should set individual timeouts', () {
        final config = builder
            .setConnectTimeout(const Duration(seconds: 10))
            .setReceiveTimeout(const Duration(seconds: 20))
            .build();

        expect(config.connectTimeout, equals(const Duration(seconds: 10)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 20)));
      });

      test('should set both timeouts together', () {
        final config = builder
            .setTimeouts(
              const Duration(seconds: 15),
              const Duration(seconds: 45),
            )
            .build();

        expect(config.connectTimeout, equals(const Duration(seconds: 15)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 45)));
      });

      test('should throw for negative connect timeout', () {
        expect(
          () => builder.setConnectTimeout(const Duration(seconds: -1)),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw for zero connect timeout', () {
        expect(
          () => builder.setConnectTimeout(Duration.zero),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw for negative receive timeout', () {
        expect(
          () => builder.setReceiveTimeout(const Duration(seconds: -1)),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw for zero receive timeout', () {
        expect(
          () => builder.setReceiveTimeout(Duration.zero),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw when connect timeout > receive timeout', () {
        expect(
          () => builder.setTimeouts(
            const Duration(seconds: 30),
            const Duration(seconds: 20),
          ),
          throwsA(isA<RpsError>()),
        );
      });

      test('should use default timeouts when not set', () {
        final config = builder.build();
        expect(config.connectTimeout, equals(const Duration(seconds: 30)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 60)));
      });
    });

    group('policy configuration', () {
      test('should set retry policy', () {
        final customPolicy = _TestRetryPolicy();
        final config = builder.setRetryPolicy(customPolicy).build();

        expect(config.retryPolicy, equals(customPolicy));
      });

      test('should set cache policy', () {
        final customPolicy = const CachePolicy(maxSize: 500);
        final config = builder.setCachePolicy(customPolicy).build();

        expect(config.cachePolicy, equals(customPolicy));
      });

      test('should use default policies when not set', () {
        final config = builder.build();
        expect(config.retryPolicy, isA<RetryPolicy>());
        expect(config.cachePolicy, isA<CachePolicy>());
      });
    });

    group('custom headers', () {
      test('should add single custom header', () {
        final config = builder
            .addCustomHeader('X-Custom-Header', 'custom-value')
            .build();

        expect(config.customHeaders['X-Custom-Header'], equals('custom-value'));
      });

      test('should add multiple custom headers', () {
        final headers = {'X-Header-1': 'value-1', 'X-Header-2': 'value-2'};

        final config = builder.addCustomHeaders(headers).build();

        expect(config.customHeaders['X-Header-1'], equals('value-1'));
        expect(config.customHeaders['X-Header-2'], equals('value-2'));
      });

      test('should remove custom header', () {
        final config = builder
            .addCustomHeader('X-Remove-Me', 'value')
            .addCustomHeader('X-Keep-Me', 'value')
            .removeCustomHeader('X-Remove-Me')
            .build();

        expect(config.customHeaders.containsKey('X-Remove-Me'), isFalse);
        expect(config.customHeaders['X-Keep-Me'], equals('value'));
      });

      test('should clear all custom headers', () {
        final config = builder
            .addCustomHeader('X-Header-1', 'value-1')
            .addCustomHeader('X-Header-2', 'value-2')
            .clearCustomHeaders()
            .build();

        expect(config.customHeaders, isEmpty);
      });

      test('should throw for empty header key', () {
        expect(
          () => builder.addCustomHeader('', 'value'),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw for header key with spaces', () {
        expect(
          () => builder.addCustomHeader('Invalid Key', 'value'),
          throwsA(isA<RpsError>()),
        );
      });

      test('should throw for header key with newlines', () {
        expect(
          () => builder.addCustomHeader('Invalid\nKey', 'value'),
          throwsA(isA<RpsError>()),
        );
      });

      test('should return immutable headers map', () {
        final config = builder.addCustomHeader('X-Test', 'value').build();

        expect(
          () => config.customHeaders['X-New'] = 'new-value',
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('preset configurations', () {
      test('should create development configuration', () {
        final config = builder.development().build();

        expect(config.connectTimeout, equals(const Duration(seconds: 10)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 30)));
        expect(config.cachePolicy.maxSize, equals(0)); // disabled cache
      });

      test('should create production configuration', () {
        final config = builder.production().build();

        expect(config.connectTimeout, equals(const Duration(seconds: 30)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 60)));
        expect(config.cachePolicy.maxSize, equals(500)); // performance cache
      });

      test('should create offline-first configuration', () {
        final config = builder.offlineFirst().build();

        expect(config.connectTimeout, equals(const Duration(seconds: 15)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 30)));
        expect(config.cachePolicy.maxSize, equals(5000)); // offline-first cache
      });
    });

    group('fluent API', () {
      test('should support method chaining', () {
        final config = builder
            .setBaseUrl('https://api.test.com')
            .setApiKey('test-key')
            .setTimeouts(
              const Duration(seconds: 5),
              const Duration(seconds: 15),
            )
            .addCustomHeader('X-Test', 'test')
            .build();

        expect(config.baseUrl, equals('https://api.test.com'));
        expect(config.apiKey, equals('test-key'));
        expect(config.connectTimeout, equals(const Duration(seconds: 5)));
        expect(config.receiveTimeout, equals(const Duration(seconds: 15)));

        expect(config.customHeaders['X-Test'], equals('test'));
      });
    });
  });

  group('RpsConfiguration validation', () {
    late RpsConfigurationBuilder builder;

    setUp(() {
      builder = RpsConfigurationBuilder();
    });

    test('should validate successfully with valid configuration', () {
      expect(
        () => builder
            .setBaseUrl('https://api.example.com')
            .setApiKey('valid-api-key-12345')
            .build(),
        returnsNormally,
      );
    });

    test('should throw for invalid base URL', () {
      expect(
        () => builder.setBaseUrl('not-a-url').build(),
        throwsA(isA<RpsConfigurationException>()),
      );
    });

    test('should throw for non-HTTP URL', () {
      expect(
        () => builder.setBaseUrl('ftp://example.com').build(),
        throwsA(isA<RpsConfigurationException>()),
      );
    });

    test('should throw for URL without host', () {
      expect(
        () => builder.setBaseUrl('https://').build(),
        throwsA(isA<RpsConfigurationException>()),
      );
    });

    test('should throw for short API key', () {
      expect(
        () => builder.setApiKey('short').build(),
        throwsA(isA<RpsConfigurationException>()),
      );
    });

    test('should throw for invalid cache policy', () {
      expect(
        () => builder.setCachePolicy(const CachePolicy(maxSize: -1)).build(),
        throwsA(isA<RpsConfigurationException>()),
      );
    });

    test('should provide detailed error messages', () {
      try {
        builder.setBaseUrl('invalid-url').setApiKey('short').build();
        fail('Expected RpsConfigurationException');
      } catch (e) {
        expect(e, isA<RpsConfigurationException>());
        final exception = e as RpsConfigurationException;
        expect(exception.errors.length, greaterThan(1));
        expect(exception.toString(), contains('Base URL'));
        expect(exception.toString(), contains('API key'));
      }
    });
  });

  group('RpsConfigurationException', () {
    test('should format single error correctly', () {
      final exception = RpsConfigurationException('Test error', [
        'Single error message',
      ]);

      final message = exception.toString();
      expect(message, contains('Test error'));
      expect(message, contains('1. Single error message'));
    });

    test('should format multiple errors correctly', () {
      final exception = RpsConfigurationException('Multiple errors', [
        'First error',
        'Second error',
        'Third error',
      ]);

      final message = exception.toString();
      expect(message, contains('Multiple errors'));
      expect(message, contains('1. First error'));
      expect(message, contains('2. Second error'));
      expect(message, contains('3. Third error'));
    });

    test('should handle empty error list', () {
      final exception = RpsConfigurationException('No specific errors', []);

      final message = exception.toString();
      expect(message, equals('No specific errors'));
    });
  });
}

/// Test implementation of RetryPolicy for testing
class _TestRetryPolicy implements RetryPolicy {
  @override
  int get maxAttempts => 5;

  @override
  bool shouldRetry(int attemptCount, RpsError error) =>
      attemptCount < maxAttempts;

  @override
  Duration getDelay(int attemptCount, RpsError error) =>
      Duration(seconds: attemptCount);

  @override
  Duration get baseDelay => throw UnimplementedError();

  @override
  Duration get maxDelay => throw UnimplementedError();
}
