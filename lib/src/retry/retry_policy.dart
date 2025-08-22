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
  /// Determines if an operation should be retried based on the attempt count and error
  bool shouldRetry(int attemptCount, RpsError error);

  /// Calculates the delay before the next retry attempt
  Duration getDelay(int attemptCount, RpsError error);

  /// Maximum number of retry attempts allowed
  int get maxAttempts;

  /// Base delay for the first retry attempt
  Duration get baseDelay;

  /// Maximum delay between retry attempts
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

  /// Multiplier for exponential backoff calculation
  final double multiplier;

  @override
  final Duration maxDelay;

  /// Whether to add jitter to prevent thundering herd
  final bool jitterEnabled;

  /// Random number generator for jitter calculation
  final math.Random _random;

  /// Creates an exponential backoff retry policy
  ///
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [baseDelay] - Base delay for the first retry (default: 1 second)
  /// [multiplier] - Exponential multiplier (default: 2.0)
  /// [maxDelay] - Maximum delay between retries (default: 30 seconds)
  /// [jitterEnabled] - Whether to add jitter (default: true)
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
    // Don't retry if we've exceeded max attempts
    if (attemptCount >= maxAttempts) {
      return false;
    }

    // Use intelligent retry decisions based on error type
    return _shouldRetryForErrorType(error);
  }

  @override
  Duration getDelay(int attemptCount, RpsError error) {
    // Calculate exponential backoff: baseDelay * (multiplier ^ attemptCount)
    final exponentialDelayMs =
        (baseDelay.inMilliseconds * math.pow(multiplier, attemptCount)).round();

    var delay = Duration(milliseconds: exponentialDelayMs);

    // Cap at maximum delay
    if (delay > maxDelay) {
      delay = maxDelay;
    }

    // Add jitter if enabled
    if (jitterEnabled) {
      delay = _addJitter(delay);
    }

    // Special handling for rate limiting - use longer delays
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
        return true;

      case RpsErrorType.authentication:
      case RpsErrorType.validation:
      case RpsErrorType.clientError:
      case RpsErrorType.cache:
      case RpsErrorType.configuration:
      case RpsErrorType.unknown:
        return false;
    }
  }

  /// Adds jitter to the delay to prevent thundering herd
  Duration _addJitter(Duration delay) {
    // Add up to 10% jitter
    final jitterMs = (_random.nextDouble() * delay.inMilliseconds * 0.1)
        .round();
    return Duration(milliseconds: delay.inMilliseconds + jitterMs);
  }

  /// Adjusts delay for rate limiting scenarios
  Duration _adjustForRateLimit(Duration delay, RpsError error) {
    // For rate limiting, use longer delays
    var adjustedDelay = Duration(
      milliseconds: (delay.inMilliseconds * 2).round(),
    );

    // Check if the error contains retry-after header information
    if (error.details != null && error.details!.containsKey('retry_after')) {
      final retryAfter = error.details!['retry_after'];
      if (retryAfter is int) {
        final retryAfterDelay = Duration(seconds: retryAfter);
        // Use the longer of the two delays
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

/// No-retry policy that never retries operations
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

/// Fixed delay retry policy that uses the same delay for all retry attempts
class FixedDelayRetryPolicy implements RetryPolicy {
  @override
  final int maxAttempts;

  @override
  final Duration baseDelay;

  @override
  Duration get maxDelay => baseDelay;

  /// Whether to add jitter to prevent thundering herd
  final bool jitterEnabled;

  /// Random number generator for jitter calculation
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

    // Use the same retry logic as exponential backoff
    return _shouldRetryForErrorType(error);
  }

  @override
  Duration getDelay(int attemptCount, RpsError error) {
    var delay = baseDelay;

    // Add jitter if enabled
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
        return true;

      case RpsErrorType.authentication:
      case RpsErrorType.validation:
      case RpsErrorType.clientError:
      case RpsErrorType.cache:
      case RpsErrorType.configuration:
      case RpsErrorType.unknown:
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

/// Retry manager that executes operations with retry logic
class RetryManager {
  /// The retry policy to use for operations
  final RetryPolicy policy;

  /// Creates a retry manager with the specified policy
  const RetryManager(this.policy);

  /// Executes an operation with retry logic
  ///
  /// [operation] - The operation to execute
  /// [onRetry] - Optional callback called before each retry attempt
  /// [requestId] - Optional request ID for error tracking
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    void Function(int attemptCount, RpsError error, Duration delay)? onRetry,
    String? requestId,
  }) async {
    int attemptCount = 0;

    while (true) {
      try {
        // Execute the operation
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
          // No more retries, throw the last error
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
