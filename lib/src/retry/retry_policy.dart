/// Retry policy framework for the Modern RPS SDK
///
/// This file provides configurable retry strategies including exponential backoff,
/// intelligent retry decisions based on error types, and jitter support to prevent
/// thundering herd problems.
library;

import 'dart:math' as math;
import '../core/error.dart';

/// Abstract interface for retry policies that determine when and how to retry failed operations
abstract class RetryPolicy {
  bool shouldRetry(int attemptCount, RpsError error);
  Duration getDelay(int attemptCount, RpsError error);
  int get maxAttempts;
  Duration get baseDelay;
  Duration get maxDelay;
}

/// Exponential backoff retry policy with jitter support
///
/// This policy implements exponential backoff with configurable parameters
/// and optional jitter to prevent thundering herd problems.
class ExponentialBackoffRetryPolicy implements RetryPolicy {
  @override
  final int maxAttempts;

  @override
  final Duration baseDelay;

  final double multiplier;

  @override
  final Duration maxDelay;

  final bool jitterEnabled;

  final math.Random _random;

  /// Creates an exponential backoff retry policy
  ExponentialBackoffRetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.jitterEnabled = true,
    math.Random? random,
  }) : _random = random ?? math.Random();

  @override
  bool shouldRetry(int attemptCount, RpsError error) {
    if (attemptCount >= maxAttempts) {
      return false;
    }

    return _shouldRetryForErrorType(error);
  }

  @override
  Duration getDelay(int attemptCount, RpsError error) {
    final exponentialDelayMs =
        (baseDelay.inMilliseconds * math.pow(multiplier, attemptCount)).round();

    var delay = Duration(milliseconds: exponentialDelayMs);

    if (delay > maxDelay) {
      delay = maxDelay;
    }

    if (jitterEnabled) {
      delay = _addJitter(delay);
    }

    if (error.type == RpsErrorType.rateLimited) {
      delay = _adjustForRateLimit(delay, error);
    }

    return delay;
  }

  /// Determines if an error type should be retried
  bool _shouldRetryForErrorType(RpsError error) {
    switch (error.type) {
      case RpsErrorType.network:
      case RpsErrorType.timeout:
      case RpsErrorType.serverError:
      case RpsErrorType.rateLimited:
      case RpsErrorType.unknown:
      case RpsErrorType.clientError:
      case RpsErrorType.cache:
      case RpsErrorType.authentication:
        return true;

      case RpsErrorType.validation:
      case RpsErrorType.configuration:
        return false;
    }
  }

  /// Adds jitter to the delay to prevent thundering herd
  Duration _addJitter(Duration delay) {
    final jitterMs = (_random.nextDouble() * delay.inMilliseconds * 0.1)
        .round();
    return Duration(milliseconds: delay.inMilliseconds + jitterMs);
  }

  /// Adjusts delay for rate limiting scenarios
  Duration _adjustForRateLimit(Duration delay, RpsError error) {
    var adjustedDelay = Duration(
      milliseconds: (delay.inMilliseconds * 2).round(),
    );

    if (error.details != null && error.details!.containsKey('retry_after')) {
      final retryAfter = error.details!['retry_after'];
      if (retryAfter is int) {
        final retryAfterDelay = Duration(seconds: retryAfter);
        if (retryAfterDelay > adjustedDelay) {
          adjustedDelay = retryAfterDelay;
        }
      }
    }

    return adjustedDelay;
  }

  /// Creates a copy of this policy with modified parameters
  ExponentialBackoffRetryPolicy copyWith({
    int? maxAttempts,
    Duration? baseDelay,
    double? multiplier,
    Duration? maxDelay,
    bool? jitterEnabled,
  }) {
    return ExponentialBackoffRetryPolicy(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      baseDelay: baseDelay ?? this.baseDelay,
      multiplier: multiplier ?? this.multiplier,
      maxDelay: maxDelay ?? this.maxDelay,
      jitterEnabled: jitterEnabled ?? this.jitterEnabled,
      random: _random,
    );
  }

  @override
  String toString() {
    return 'ExponentialBackoffRetryPolicy('
        'maxAttempts: $maxAttempts, '
        'baseDelay: ${baseDelay.inMilliseconds}ms, '
        'multiplier: $multiplier, '
        'maxDelay: ${maxDelay.inMilliseconds}ms, '
        'jitterEnabled: $jitterEnabled)';
  }
}

class NoRetryPolicy implements RetryPolicy {
  @override
  final int maxAttempts = 0;

  @override
  final Duration baseDelay = Duration.zero;

  @override
  final Duration maxDelay = Duration.zero;

  @override
  bool shouldRetry(int attemptCount, RpsError error) => false;

  @override
  Duration getDelay(int attemptCount, RpsError error) => Duration.zero;

  @override
  String toString() => 'NoRetryPolicy()';
}

class FixedDelayRetryPolicy implements RetryPolicy {
  @override
  final int maxAttempts;

  @override
  final Duration baseDelay;

  @override
  Duration get maxDelay => baseDelay;

  final bool jitterEnabled;
  final math.Random _random;

  /// Creates a fixed delay retry policy
  FixedDelayRetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.jitterEnabled = true,
    math.Random? random,
  }) : _random = random ?? math.Random();

  @override
  bool shouldRetry(int attemptCount, RpsError error) {
    if (attemptCount >= maxAttempts) {
      return false;
    }

    return _shouldRetryForErrorType(error);
  }

  @override
  Duration getDelay(int attemptCount, RpsError error) {
    var delay = baseDelay;

    if (jitterEnabled) {
      final jitterMs = (_random.nextDouble() * delay.inMilliseconds * 0.1)
          .round();
      delay = Duration(milliseconds: delay.inMilliseconds + jitterMs);
    }

    return delay;
  }

  /// Determines if an error type should be retried
  bool _shouldRetryForErrorType(RpsError error) {
    switch (error.type) {
      case RpsErrorType.network:
      case RpsErrorType.timeout:
      case RpsErrorType.serverError:
      case RpsErrorType.rateLimited:
      case RpsErrorType.cache:
      case RpsErrorType.authentication:
      case RpsErrorType.clientError:
      case RpsErrorType.unknown:
        return true;

      case RpsErrorType.validation:
      case RpsErrorType.configuration:
        return false;
    }
  }

  @override
  String toString() {
    return 'FixedDelayRetryPolicy('
        'maxAttempts: $maxAttempts, '
        'delay: ${baseDelay.inMilliseconds}ms, '
        'jitterEnabled: $jitterEnabled)';
  }
}

class RetryManager {
  final RetryPolicy policy;

  /// Creates a retry manager with the specified policy
  const RetryManager(this.policy);

  /// Executes an operation with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    void Function(int attemptCount, RpsError error, Duration delay)? onRetry,
    String? requestId,
  }) async {
    int attemptCount = 0;

    while (true) {
      try {
        return await operation();
      } catch (exception, stackTrace) {
        // Classify the error
        final error = exception is RpsError
            ? exception
            : RpsErrorHandler.classifyError(
                exception,
                requestId: requestId,
                stackTrace: stackTrace,
              );

        if (!policy.shouldRetry(attemptCount, error)) {
          throw error;
        }

        // Calculate delay and wait
        final delay = policy.getDelay(attemptCount, error);

        // Increment attempt count after checking if we should retry
        attemptCount++;

        // Call retry callback if provided
        onRetry?.call(attemptCount, error, delay);

        // Wait before retrying
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }
  }

  /// Executes an operation with retry logic and returns a result that includes retry information
  Future<RetryResult<T>> executeWithRetryResult<T>(
    Future<T> Function() operation, {
    void Function(int attemptCount, RpsError error, Duration delay)? onRetry,
    String? requestId,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attemptCount = 0;
    final List<RetryAttempt> attempts = [];

    while (true) {
      final attemptStopwatch = Stopwatch()..start();

      try {
        // Execute the operation
        final result = await operation();
        attemptStopwatch.stop();

        attempts.add(
          RetryAttempt(
            attemptNumber: attemptCount + 1,
            duration: attemptStopwatch.elapsed,
            success: true,
          ),
        );

        stopwatch.stop();

        return RetryResult<T>(
          result: result,
          totalDuration: stopwatch.elapsed,
          totalAttempts: attemptCount + 1,
          attempts: attempts,
          success: true,
        );
      } catch (exception, stackTrace) {
        attemptStopwatch.stop();

        // Classify the error
        final error = exception is RpsError
            ? exception
            : RpsErrorHandler.classifyError(
                exception,
                requestId: requestId,
                stackTrace: stackTrace,
              );

        attempts.add(
          RetryAttempt(
            attemptNumber: attemptCount + 1,
            duration: attemptStopwatch.elapsed,
            success: false,
            error: error,
          ),
        );

        // Check if we should retry (pass current attempt count before incrementing)
        if (!policy.shouldRetry(attemptCount, error)) {
          stopwatch.stop();

          // No more retries, return failure result
          return RetryResult<T>(
            error: error,
            totalDuration: stopwatch.elapsed,
            totalAttempts: attemptCount + 1,
            attempts: attempts,
            success: false,
          );
        }

        // Calculate delay and wait
        final delay = policy.getDelay(attemptCount, error);

        // Increment attempt count after checking if we should retry
        attemptCount++;

        // Call retry callback if provided
        onRetry?.call(attemptCount, error, delay);

        // Wait before retrying
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }
  }

  @override
  String toString() => 'RetryManager(policy: $policy)';
}

/// Result of a retry operation containing detailed information about the execution
class RetryResult<T> {
  /// The successful result (null if operation failed)
  final T? result;

  /// The final error (null if operation succeeded)
  final RpsError? error;

  /// Total duration of all retry attempts
  final Duration totalDuration;

  /// Total number of attempts made
  final int totalAttempts;

  /// List of individual retry attempts
  final List<RetryAttempt> attempts;

  /// Whether the operation ultimately succeeded
  final bool success;

  const RetryResult({
    this.result,
    this.error,
    required this.totalDuration,
    required this.totalAttempts,
    required this.attempts,
    required this.success,
  });

  /// Whether the operation was retried (more than one attempt)
  bool get wasRetried => totalAttempts > 1;

  /// Number of failed attempts
  int get failedAttempts => attempts.where((a) => !a.success).length;

  @override
  String toString() {
    return 'RetryResult('
        'success: $success, '
        'attempts: $totalAttempts, '
        'duration: ${totalDuration.inMilliseconds}ms'
        ')';
  }
}

/// Information about a single retry attempt
class RetryAttempt {
  /// The attempt number (1-based)
  final int attemptNumber;

  /// Duration of this specific attempt
  final Duration duration;

  /// Whether this attempt succeeded
  final bool success;

  /// Error that occurred during this attempt (null if successful)
  final RpsError? error;

  const RetryAttempt({
    required this.attemptNumber,
    required this.duration,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    return 'RetryAttempt('
        'attempt: $attemptNumber, '
        'success: $success, '
        'duration: ${duration.inMilliseconds}ms'
        ')';
  }
}
