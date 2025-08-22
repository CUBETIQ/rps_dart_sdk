import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/retry/retry_policy.dart';
import 'package:rps_dart_sdk/src/core/error.dart';

void main() {
  group('ExponentialBackoffRetryPolicy', () {
    late ExponentialBackoffRetryPolicy policy;

    setUp(() {
      policy = ExponentialBackoffRetryPolicy(
        maxAttempts: 3,
        baseDelay: const Duration(seconds: 1),
        multiplier: 2.0,
        maxDelay: const Duration(seconds: 30),
        jitterEnabled: false, // Disable jitter for predictable tests
      );
    });

    group('shouldRetry', () {
      test('should retry network errors within max attempts', () {
        final error = RpsError.network(message: 'Connection failed');

        expect(policy.shouldRetry(0, error), isTrue);
        expect(policy.shouldRetry(1, error), isTrue);
        expect(policy.shouldRetry(2, error), isTrue);
        expect(policy.shouldRetry(3, error), isFalse); // Exceeds max attempts
      });

      test('should retry timeout errors within max attempts', () {
        final error = RpsError.timeout(message: 'Request timed out');

        expect(policy.shouldRetry(0, error), isTrue);
        expect(policy.shouldRetry(1, error), isTrue);
        expect(policy.shouldRetry(2, error), isTrue);
        expect(policy.shouldRetry(3, error), isFalse);
      });

      test('should retry server errors (5xx) within max attempts', () {
        final error = RpsError.serverError(
          message: 'Internal server error',
          statusCode: 500,
        );

        expect(policy.shouldRetry(0, error), isTrue);
        expect(policy.shouldRetry(1, error), isTrue);
        expect(policy.shouldRetry(2, error), isTrue);
        expect(policy.shouldRetry(3, error), isFalse);
      });

      test('should retry rate limited errors (429) within max attempts', () {
        final error = RpsError.clientError(
          message: 'Too many requests',
          statusCode: 429,
        );

        expect(policy.shouldRetry(0, error), isTrue);
        expect(policy.shouldRetry(1, error), isTrue);
        expect(policy.shouldRetry(2, error), isTrue);
        expect(policy.shouldRetry(3, error), isFalse);
      });

      test('should not retry authentication errors', () {
        final error = RpsError.authentication(
          message: 'Unauthorized',
          statusCode: 401,
        );

        expect(policy.shouldRetry(0, error), isFalse);
        expect(policy.shouldRetry(1, error), isFalse);
      });

      test('should not retry validation errors', () {
        final error = RpsError.validation(message: 'Invalid request data');

        expect(policy.shouldRetry(0, error), isFalse);
        expect(policy.shouldRetry(1, error), isFalse);
      });

      test('should not retry client errors (4xx except 429)', () {
        final error = RpsError.clientError(
          message: 'Bad request',
          statusCode: 400,
        );

        expect(policy.shouldRetry(0, error), isFalse);
        expect(policy.shouldRetry(1, error), isFalse);
      });

      test('should not retry configuration errors', () {
        final error = RpsError.configuration(message: 'Invalid configuration');

        expect(policy.shouldRetry(0, error), isFalse);
        expect(policy.shouldRetry(1, error), isFalse);
      });

      test('should not retry cache errors', () {
        final error = RpsError.cache(message: 'Cache operation failed');

        expect(policy.shouldRetry(0, error), isFalse);
        expect(policy.shouldRetry(1, error), isFalse);
      });
    });

    group('getDelay', () {
      test('should calculate exponential backoff correctly', () {
        final error = RpsError.network(message: 'Connection failed');

        // Attempt 0: 1 * (2^0) = 1 second
        expect(policy.getDelay(0, error), equals(const Duration(seconds: 1)));

        // Attempt 1: 1 * (2^1) = 2 seconds
        expect(policy.getDelay(1, error), equals(const Duration(seconds: 2)));

        // Attempt 2: 1 * (2^2) = 4 seconds
        expect(policy.getDelay(2, error), equals(const Duration(seconds: 4)));

        // Attempt 3: 1 * (2^3) = 8 seconds
        expect(policy.getDelay(3, error), equals(const Duration(seconds: 8)));
      });

      test('should cap delay at maxDelay', () {
        final shortMaxPolicy = ExponentialBackoffRetryPolicy(
          baseDelay: const Duration(seconds: 1),
          multiplier: 2.0,
          maxDelay: const Duration(seconds: 3),
          jitterEnabled: false,
        );

        final error = RpsError.network(message: 'Connection failed');

        // Should be capped at 3 seconds
        expect(
          shortMaxPolicy.getDelay(5, error),
          equals(const Duration(seconds: 3)),
        );
      });

      test('should add jitter when enabled', () {
        final jitterPolicy = ExponentialBackoffRetryPolicy(
          baseDelay: const Duration(seconds: 1),
          multiplier: 2.0,
          jitterEnabled: true,
          random: math.Random(42), // Fixed seed for predictable tests
        );

        final error = RpsError.network(message: 'Connection failed');
        final delay1 = jitterPolicy.getDelay(0, error);
        final delay2 = jitterPolicy.getDelay(0, error);

        // With jitter, delays should be different
        expect(delay1, isNot(equals(delay2)));

        // But should be within reasonable bounds (base delay + up to 10% jitter)
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(1000));
        expect(delay1.inMilliseconds, lessThanOrEqualTo(1100));
      });

      test('should use longer delays for rate limiting', () {
        final error = RpsError.clientError(
          message: 'Too many requests',
          statusCode: 429,
        );

        final normalError = RpsError.network(message: 'Connection failed');

        final rateLimitDelay = policy.getDelay(1, error);
        final normalDelay = policy.getDelay(1, normalError);

        // Rate limit delay should be longer (2x)
        expect(
          rateLimitDelay.inMilliseconds,
          equals(normalDelay.inMilliseconds * 2),
        );
      });

      test('should respect retry-after header for rate limiting', () {
        final error = RpsError.clientError(
          message: 'Too many requests',
          statusCode: 429,
          details: {'retry_after': 10}, // 10 seconds
        );

        final delay = policy.getDelay(0, error);

        // Should use the longer of calculated delay or retry-after
        expect(delay.inSeconds, greaterThanOrEqualTo(10));
      });
    });

    group('copyWith', () {
      test('should create copy with modified parameters', () {
        final newPolicy = policy.copyWith(
          maxAttempts: 5,
          baseDelay: const Duration(seconds: 2),
        );

        expect(newPolicy.maxAttempts, equals(5));
        expect(newPolicy.baseDelay, equals(const Duration(seconds: 2)));
        expect(newPolicy.multiplier, equals(policy.multiplier));
        expect(newPolicy.maxDelay, equals(policy.maxDelay));
      });
    });
  });

  group('NoRetryPolicy', () {
    late NoRetryPolicy policy;

    setUp(() {
      policy = NoRetryPolicy();
    });

    test('should never retry', () {
      final error = RpsError.network(message: 'Connection failed');

      expect(policy.shouldRetry(0, error), isFalse);
      expect(policy.shouldRetry(1, error), isFalse);
    });

    test('should return zero delay', () {
      final error = RpsError.network(message: 'Connection failed');

      expect(policy.getDelay(0, error), equals(Duration.zero));
    });

    test('should have zero max attempts', () {
      expect(policy.maxAttempts, equals(0));
    });
  });

  group('FixedDelayRetryPolicy', () {
    late FixedDelayRetryPolicy policy;

    setUp(() {
      policy = FixedDelayRetryPolicy(
        maxAttempts: 3,
        baseDelay: const Duration(seconds: 2),
        jitterEnabled: false,
      );
    });

    test('should use same delay for all attempts', () {
      final error = RpsError.network(message: 'Connection failed');

      expect(policy.getDelay(0, error), equals(const Duration(seconds: 2)));
      expect(policy.getDelay(1, error), equals(const Duration(seconds: 2)));
      expect(policy.getDelay(2, error), equals(const Duration(seconds: 2)));
    });

    test('should follow same retry rules as exponential backoff', () {
      final networkError = RpsError.network(message: 'Connection failed');
      final authError = RpsError.authentication(message: 'Unauthorized');

      expect(policy.shouldRetry(0, networkError), isTrue);
      expect(policy.shouldRetry(0, authError), isFalse);
    });
  });

  group('RetryManager', () {
    late RetryManager retryManager;
    late ExponentialBackoffRetryPolicy policy;

    setUp(() {
      policy = ExponentialBackoffRetryPolicy(
        maxAttempts: 3,
        baseDelay: const Duration(milliseconds: 10), // Short delay for tests
        jitterEnabled: false,
      );
      retryManager = RetryManager(policy);
    });

    group('executeWithRetry', () {
      test('should succeed on first attempt', () async {
        var callCount = 0;

        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(1));
      });

      test('should retry on retryable errors and eventually succeed', () async {
        var callCount = 0;

        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 3) {
            throw RpsError.network(message: 'Connection failed');
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(3));
      });

      test('should fail after max attempts', () async {
        var callCount = 0;

        try {
          await retryManager.executeWithRetry(() async {
            callCount++;
            throw RpsError.network(message: 'Connection failed');
          });
        } catch (e) {
          expect(e, isA<RpsError>());
        }

        expect(callCount, equals(4)); // Initial attempt + 3 retries
      });

      test('should not retry non-retryable errors', () async {
        var callCount = 0;

        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw RpsError.authentication(message: 'Unauthorized');
          }),
          throwsA(isA<RpsError>()),
        );

        expect(callCount, equals(1)); // No retries
      });

      test('should call onRetry callback', () async {
        // ignore: unused_local_variable
        int callCount = 0;
        var retryCallCount = 0;
        final retryInfo = <Map<String, dynamic>>[];

        try {
          await retryManager.executeWithRetry(
            () async {
              callCount++;
              throw RpsError.network(message: 'Connection failed');
            },
            onRetry: (attemptCount, error, delay) {
              retryCallCount++;
              retryInfo.add({
                'attemptCount': attemptCount,
                'error': error,
                'delay': delay,
              });
            },
          );
        } catch (e) {
          // Expected to fail
        }

        expect(retryCallCount, equals(3)); // 3 retry attempts
        expect(retryInfo.length, equals(3));
        expect(retryInfo[0]['attemptCount'], equals(1));
        expect(retryInfo[1]['attemptCount'], equals(2));
        expect(retryInfo[2]['attemptCount'], equals(3));
      });

      test('should handle non-RpsError exceptions', () async {
        var callCount = 0;

        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw Exception('Generic error');
          }),
          throwsA(isA<RpsError>()),
        );

        // Should not retry because generic exceptions are classified as unknown errors
        // which are not retryable
        expect(callCount, equals(1));
      });
    });

    group('executeWithRetryResult', () {
      test('should return success result on first attempt', () async {
        final result = await retryManager.executeWithRetryResult(() async {
          return 'success';
        });

        expect(result.success, isTrue);
        expect(result.result, equals('success'));
        expect(result.error, isNull);
        expect(result.totalAttempts, equals(1));
        expect(result.wasRetried, isFalse);
        expect(result.attempts.length, equals(1));
        expect(result.attempts[0].success, isTrue);
      });

      test('should return success result after retries', () async {
        var callCount = 0;

        final result = await retryManager.executeWithRetryResult(() async {
          callCount++;
          if (callCount < 3) {
            throw RpsError.network(message: 'Connection failed');
          }
          return 'success';
        });

        expect(result.success, isTrue);
        expect(result.result, equals('success'));
        expect(result.error, isNull);
        expect(result.totalAttempts, equals(3));
        expect(result.wasRetried, isTrue);
        expect(result.failedAttempts, equals(2));
        expect(result.attempts.length, equals(3));
        expect(result.attempts[0].success, isFalse);
        expect(result.attempts[1].success, isFalse);
        expect(result.attempts[2].success, isTrue);
      });

      test('should return failure result after max attempts', () async {
        final result = await retryManager.executeWithRetryResult(() async {
          throw RpsError.network(message: 'Connection failed');
        });

        expect(result.success, isFalse);
        expect(result.result, isNull);
        expect(result.error, isA<RpsError>());
        expect(result.totalAttempts, equals(4)); // Initial + 3 retries
        expect(result.wasRetried, isTrue);
        expect(result.failedAttempts, equals(4));
        expect(result.attempts.length, equals(4));
        expect(result.attempts.every((a) => !a.success), isTrue);
      });

      test('should track timing information', () async {
        final result = await retryManager.executeWithRetryResult(() async {
          await Future.delayed(const Duration(milliseconds: 5));
          return 'success';
        });

        expect(result.totalDuration.inMilliseconds, greaterThan(0));
        expect(result.attempts[0].duration.inMilliseconds, greaterThan(0));
      });
    });
  });

  group('RetryResult', () {
    test('should correctly identify if operation was retried', () {
      final successResult = RetryResult<String>(
        result: 'success',
        totalDuration: const Duration(milliseconds: 100),
        totalAttempts: 1,
        attempts: [
          const RetryAttempt(
            attemptNumber: 1,
            duration: Duration(milliseconds: 100),
            success: true,
          ),
        ],
        success: true,
      );

      expect(successResult.wasRetried, isFalse);

      final retriedResult = RetryResult<String>(
        result: 'success',
        totalDuration: const Duration(milliseconds: 200),
        totalAttempts: 2,
        attempts: [
          RetryAttempt(
            attemptNumber: 1,
            duration: const Duration(milliseconds: 100),
            success: false,
            error: RpsError.network(message: 'Failed'),
          ),
          const RetryAttempt(
            attemptNumber: 2,
            duration: Duration(milliseconds: 100),
            success: true,
          ),
        ],
        success: true,
      );

      expect(retriedResult.wasRetried, isTrue);
    });

    test('should correctly count failed attempts', () {
      final result = RetryResult<String>(
        error: RpsError.network(message: 'Failed'),
        totalDuration: const Duration(milliseconds: 400),
        totalAttempts: 4,
        attempts: [
          RetryAttempt(
            attemptNumber: 1,
            duration: const Duration(milliseconds: 100),
            success: false,
            error: RpsError.network(message: 'Failed'),
          ),
          RetryAttempt(
            attemptNumber: 2,
            duration: const Duration(milliseconds: 100),
            success: false,
            error: RpsError.network(message: 'Failed'),
          ),
          RetryAttempt(
            attemptNumber: 3,
            duration: const Duration(milliseconds: 100),
            success: false,
            error: RpsError.network(message: 'Failed'),
          ),
          RetryAttempt(
            attemptNumber: 4,
            duration: const Duration(milliseconds: 100),
            success: false,
            error: RpsError.network(message: 'Failed'),
          ),
        ],
        success: false,
      );

      expect(result.failedAttempts, equals(4));
    });
  });
}
