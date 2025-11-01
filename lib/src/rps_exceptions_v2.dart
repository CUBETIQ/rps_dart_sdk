/// Custom exceptions for RPS SDK v2
/// 
/// Clean exception hierarchy for different error scenarios.
library;

/// Base exception for all RPS errors
abstract class RpsException implements Exception {
  /// Error message
  final String message;
  
  /// Additional error details
  final Map<String, dynamic> details;
  
  /// Request ID associated with the error
  final String? requestId;

  const RpsException(this.message, {this.details = const {}, this.requestId});

  /// Whether this error should trigger a retry
  bool get isRetryable;

  @override
  String toString() {
    final requestInfo = requestId != null ? ' (request: $requestId)' : '';
    return '${runtimeType}: $message$requestInfo';
  }
}

/// Network-related errors (connection issues, DNS, etc.)
class RpsNetworkException extends RpsException {
  const RpsNetworkException(
    super.message, {
    super.details,
    super.requestId,
  });

  @override
  bool get isRetryable => true;
}

/// Request timeout errors
class RpsTimeoutException extends RpsException {
  /// The timeout duration that was exceeded
  final Duration timeout;

  const RpsTimeoutException(
    super.message, {
    required this.timeout,
    super.details,
    super.requestId,
  });

  @override
  bool get isRetryable => true;

  @override
  String toString() {
    final requestInfo = requestId != null ? ' (request: $requestId)' : '';
    return 'RpsTimeoutException: $message after ${timeout.inSeconds}s$requestInfo';
  }
}

/// HTTP status code errors (4xx, 5xx responses)
class RpsHttpException extends RpsException {
  /// HTTP status code
  final int statusCode;
  
  /// Response body if available
  final Map<String, dynamic>? responseBody;

  const RpsHttpException(
    super.message, {
    required this.statusCode,
    this.responseBody,
    super.details,
    super.requestId,
  });

  /// Whether this is a client error (4xx)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether this is a server error (5xx)
  bool get isServerError => statusCode >= 500;

  @override
  bool get isRetryable {
    // Retry server errors and specific client errors
    if (isServerError) return true;
    
    // Retry specific 4xx errors that might be transient
    const retryableClientErrors = {
      408, // Request Timeout
      429, // Too Many Requests
      449, // Retry With (Microsoft extension)
    };
    
    return retryableClientErrors.contains(statusCode);
  }

  @override
  String toString() {
    final requestInfo = requestId != null ? ' (request: $requestId)' : '';
    return 'RpsHttpException($statusCode): $message$requestInfo';
  }
}

/// Configuration or validation errors
class RpsConfigException extends RpsException {
  const RpsConfigException(
    super.message, {
    super.details,
    super.requestId,
  });

  @override
  bool get isRetryable => false; // Config errors are not retryable
}

/// Request cancellation errors
class RpsCancelledException extends RpsException {
  const RpsCancelledException(
    super.message, {
    super.details,
    super.requestId,
  });

  @override
  bool get isRetryable => false; // Cancelled requests shouldn't be retried
}

/// Idempotency violation errors (duplicate requests)
class RpsIdempotencyException extends RpsException {
  /// The duplicate request identifier
  final String duplicateId;

  const RpsIdempotencyException(
    super.message, {
    required this.duplicateId,
    super.details,
    super.requestId,
  });

  @override
  bool get isRetryable => false; // Duplicates should not be retried

  @override
  String toString() {
    final requestInfo = requestId != null ? ' (request: $requestId)' : '';
    return 'RpsIdempotencyException: $message (duplicate: $duplicateId)$requestInfo';
  }
}

/// Extension methods for easier exception handling
extension RpsExceptionHandling on RpsException {
  /// Get a user-friendly error message
  String get userMessage {
    switch (runtimeType) {
      case RpsNetworkException:
        return 'Network connection failed. Please check your internet connection.';
      case RpsTimeoutException:
        return 'Request timed out. Please try again.';
      case RpsHttpException:
        final httpEx = this as RpsHttpException;
        if (httpEx.isServerError) {
          return 'Server error occurred. Please try again later.';
        } else if (httpEx.statusCode == 429) {
          return 'Too many requests. Please wait and try again.';
        } else {
          return 'Request failed. Please check your input and try again.';
        }
      case RpsConfigException:
        return 'Configuration error. Please contact support.';
      case RpsCancelledException:
        return 'Request was cancelled.';
      case RpsIdempotencyException:
        return 'Duplicate request detected.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get error severity level
  ErrorSeverity get severity {
    switch (runtimeType) {
      case RpsNetworkException:
      case RpsTimeoutException:
        return ErrorSeverity.warning;
      case RpsHttpException:
        final httpEx = this as RpsHttpException;
        return httpEx.isServerError ? ErrorSeverity.error : ErrorSeverity.warning;
      case RpsConfigException:
        return ErrorSeverity.critical;
      case RpsCancelledException:
        return ErrorSeverity.info;
      case RpsIdempotencyException:
        return ErrorSeverity.warning;
      default:
        return ErrorSeverity.error;
    }
  }
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}