/// Retry policy implementation for RPS SDK v2
///
/// Simple, configurable retry logic with exponential backoff and jitter.
library;

import 'dart:async';
import 'dart:math';

import 'rps_exceptions_v2.dart';
import 'rps_models_v2.dart';

/// Retry policy for handling failed requests
class RetryPolicy {
  final RetryConfig _config;
  final Set<String> _processedRequests = <String>{};

  RetryPolicy(this._config);

  /// Execute a function with retry logic
  Future<T> execute<T>(
    String requestId,
    Future<T> Function() operation, {
    bool enableIdempotency = true,
  }) async {
    // Check for idempotency violations
    if (enableIdempotency && _processedRequests.contains(requestId)) {
      throw RpsIdempotencyException(
        'Request already processed',
        duplicateId: requestId,
        requestId: requestId,
      );
    }

    RpsException? lastException;

    for (int attempt = 1; attempt <= _config.maxAttempts + 1; attempt++) {
      try {
        final result = await operation();

        // Mark as processed on success
        if (enableIdempotency) {
          _processedRequests.add(requestId);
        }

        return result;
      } catch (e) {
        final exception = _normalizeException(e, requestId);
        lastException = exception;

        // Don't retry on the last attempt or for non-retryable errors
        if (attempt > _config.maxAttempts || !exception.isRetryable) {
          break;
        }

        // Calculate and wait for retry delay
        final delay = _config.getDelay(attempt);
        await Future.delayed(delay);
      }
    }

    // All retries exhausted, throw the last exception
    throw lastException!;
  }

  /// Check if a request has been processed (for idempotency)
  bool hasBeenProcessed(String requestId) {
    return _processedRequests.contains(requestId);
  }

  /// Clear processed requests (useful for testing or cleanup)
  void clearProcessedRequests() {
    _processedRequests.clear();
  }

  /// Get current retry configuration
  RetryConfig get config => _config;

  /// Convert any exception to an RpsException
  RpsException _normalizeException(dynamic error, String requestId) {
    if (error is RpsException) {
      return error;
    }

    // Handle common Dart exceptions
    if (error is TimeoutException) {
      return RpsTimeoutException(
        error.message ?? 'Operation timed out',
        timeout: error.duration ?? const Duration(seconds: 30),
        requestId: requestId,
      );
    }

    if (error is FormatException) {
      return RpsConfigException(
        'Invalid format: ${error.message}',
        requestId: requestId,
      );
    }

    // Default to network exception for unknown errors
    return RpsNetworkException(
      'Unexpected error: ${error.toString()}',
      requestId: requestId,
      details: {'originalError': error.runtimeType.toString()},
    );
  }
}

/// Utility functions for retry policies
class RetryUtils {
  /// Create a simple retry policy with exponential backoff
  static RetryPolicy simple({
    int maxAttempts = 3,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
  }) {
    return RetryPolicy(
      RetryConfig(
        maxAttempts: maxAttempts,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
        useExponentialBackoff: true,
        useJitter: true,
      ),
    );
  }

  /// Create a retry policy for aggressive retries (more attempts, shorter delays)
  static RetryPolicy aggressive({
    int maxAttempts = 5,
    Duration baseDelay = const Duration(milliseconds: 500),
    Duration maxDelay = const Duration(seconds: 10),
  }) {
    return RetryPolicy(
      RetryConfig(
        maxAttempts: maxAttempts,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
        useExponentialBackoff: true,
        useJitter: true,
      ),
    );
  }

  /// Create a retry policy for conservative retries (fewer attempts, longer delays)
  static RetryPolicy conservative({
    int maxAttempts = 2,
    Duration baseDelay = const Duration(seconds: 2),
    Duration maxDelay = const Duration(minutes: 1),
  }) {
    return RetryPolicy(
      RetryConfig(
        maxAttempts: maxAttempts,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
        useExponentialBackoff: true,
        useJitter: false, // More predictable timing
      ),
    );
  }

  /// Create a retry policy with no retries (for testing or specific use cases)
  static RetryPolicy noRetry() {
    return RetryPolicy(
      const RetryConfig(
        maxAttempts: 0,
        baseDelay: Duration.zero,
        maxDelay: Duration.zero,
        useExponentialBackoff: false,
        useJitter: false,
      ),
    );
  }

  /// Calculate total maximum time for all retry attempts
  static Duration calculateMaxRetryTime(RetryConfig config) {
    Duration totalTime = Duration.zero;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      totalTime += config.getDelay(attempt);
    }

    return totalTime;
  }

  /// Check if an error should be retried based on common patterns
  static bool shouldRetryError(dynamic error) {
    if (error is RpsException) {
      return error.isRetryable;
    }

    // Retry timeouts and network issues
    if (error is TimeoutException) {
      return true;
    }

    // Don't retry format/validation errors
    if (error is FormatException || error is ArgumentError) {
      return false;
    }

    // Default to retry for unknown errors (be conservative)
    return true;
  }
}

/// Backoff calculator for custom retry strategies
class BackoffCalculator {
  /// Calculate exponential backoff with jitter
  static Duration exponentialBackoff(
    int attempt,
    Duration baseDelay,
    Duration maxDelay, {
    bool useJitter = true,
    double jitterFactor = 0.25,
  }) {
    if (attempt <= 0) return Duration.zero;

    // Calculate exponential delay: baseDelay * 2^(attempt-1)
    final multiplier = pow(2, attempt - 1).toDouble();
    var delayMs = (baseDelay.inMilliseconds * multiplier).round();

    // Cap at maximum delay
    if (delayMs > maxDelay.inMilliseconds) {
      delayMs = maxDelay.inMilliseconds;
    }

    // Add jitter to prevent thundering herd
    if (useJitter && delayMs > 0) {
      final jitterMs = (delayMs * jitterFactor * Random().nextDouble()).round();
      delayMs += jitterMs;
    }

    return Duration(milliseconds: delayMs);
  }

  /// Calculate linear backoff
  static Duration linearBackoff(
    int attempt,
    Duration baseDelay,
    Duration maxDelay, {
    bool useJitter = true,
  }) {
    if (attempt <= 0) return Duration.zero;

    var delayMs = baseDelay.inMilliseconds * attempt;

    // Cap at maximum delay
    if (delayMs > maxDelay.inMilliseconds) {
      delayMs = maxDelay.inMilliseconds;
    }

    // Add small amount of jitter
    if (useJitter && delayMs > 0) {
      final jitterMs = Random().nextInt(delayMs ~/ 10);
      delayMs += jitterMs;
    }

    return Duration(milliseconds: delayMs);
  }

  /// Calculate fixed delay (no backoff)
  static Duration fixedDelay(
    int attempt,
    Duration delay, {
    bool useJitter = false,
  }) {
    if (attempt <= 0) return Duration.zero;

    var delayMs = delay.inMilliseconds;

    // Add minimal jitter if requested
    if (useJitter && delayMs > 0) {
      final jitterMs = Random().nextInt(delayMs ~/ 20);
      delayMs += jitterMs;
    }

    return Duration(milliseconds: delayMs);
  }
}
