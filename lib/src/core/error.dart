/// Error handling and classification system for the Modern RPS SDK
///
/// This file provides comprehensive error handling capabilities including
/// error classification, recovery strategies, and retryability determination.
library;

/// Enumeration of different error types that can occur in the SDK
enum RpsErrorType {
  /// Network connectivity issues (DNS resolution, connection refused, etc.)
  network,

  /// Authentication and authorization failures
  authentication,

  /// Request validation errors (invalid data, missing fields, etc.)
  validation,

  /// Server errors (5xx HTTP status codes)
  serverError,

  /// Client errors (4xx HTTP status codes)
  clientError,

  /// Request timeout errors
  timeout,

  /// Cache operation failures
  cache,

  /// SDK configuration errors
  configuration,

  /// Rate limiting errors (429 status code)
  rateLimited,

  /// Unknown or unclassified errors
  unknown,
}

/// Comprehensive error class for the RPS SDK with detailed context and metadata
class RpsError extends Error {
  /// Unique error code for programmatic handling
  final String code;

  /// Human-readable error message
  final String message;

  /// Error type classification for handling logic
  final RpsErrorType type;

  /// Additional error details and context
  final Map<String, dynamic>? details;

  /// Original exception that caused this error (if any)
  final Exception? originalException;

  /// Stack trace when the error occurred
  @override
  final StackTrace? stackTrace;

  /// Timestamp when the error occurred
  final DateTime timestamp;

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// Whether this error is potentially retryable
  final bool isRetryable;

  /// Request ID associated with this error (if applicable)
  final String? requestId;

  RpsError({
    required this.code,
    required this.message,
    required this.type,
    this.details,
    this.originalException,
    this.stackTrace,
    DateTime? timestamp,
    this.statusCode,
    bool? isRetryable,
    this.requestId,
  }) : timestamp = timestamp ?? DateTime.now(),
       isRetryable = isRetryable ?? _determineRetryability(type, statusCode);

  /// Factory constructor for network-related errors
  factory RpsError.network({
    required String message,
    String? code,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? 'NETWORK_ERROR',
      message: message,
      type: RpsErrorType.network,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
      requestId: requestId,
    );
  }

  /// Factory constructor for authentication errors
  factory RpsError.authentication({
    required String message,
    String? code,
    int? statusCode,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? 'AUTH_ERROR',
      message: message,
      type: RpsErrorType.authentication,
      statusCode: statusCode,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
      requestId: requestId,
    );
  }

  /// Factory constructor for validation errors
  factory RpsError.validation({
    required String message,
    String? code,
    List<String>? validationErrors,
    Exception? originalException,
    StackTrace? stackTrace,
    String? requestId,
  }) {
    final details = <String, dynamic>{};
    if (validationErrors != null) {
      details['validation_errors'] = validationErrors;
    }

    return RpsError(
      code: code ?? 'VALIDATION_ERROR',
      message: message,
      type: RpsErrorType.validation,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details.isNotEmpty ? details : null,
      requestId: requestId,
    );
  }

  /// Factory constructor for server errors (5xx)
  factory RpsError.serverError({
    required String message,
    required int statusCode,
    String? code,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? 'SERVER_ERROR',
      message: message,
      type: RpsErrorType.serverError,
      statusCode: statusCode,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
      requestId: requestId,
    );
  }

  /// Factory constructor for client errors (4xx)
  factory RpsError.clientError({
    required String message,
    required int statusCode,
    String? code,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? 'CLIENT_ERROR',
      message: message,
      type: statusCode == 429
          ? RpsErrorType.rateLimited
          : RpsErrorType.clientError,
      statusCode: statusCode,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
      requestId: requestId,
    );
  }

  /// Factory constructor for timeout errors
  factory RpsError.timeout({
    required String message,
    String? code,
    Duration? timeoutDuration,
    Exception? originalException,
    StackTrace? stackTrace,
    String? requestId,
  }) {
    final details = <String, dynamic>{};
    if (timeoutDuration != null) {
      details['timeout_duration_ms'] = timeoutDuration.inMilliseconds;
    }

    return RpsError(
      code: code ?? 'TIMEOUT_ERROR',
      message: message,
      type: RpsErrorType.timeout,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details.isNotEmpty ? details : null,
      requestId: requestId,
    );
  }

  /// Factory constructor for cache errors
  factory RpsError.cache({
    required String message,
    String? code,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? 'CACHE_ERROR',
      message: message,
      type: RpsErrorType.cache,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
      requestId: requestId,
    );
  }

  /// Factory constructor for configuration errors
  factory RpsError.configuration({
    required String message,
    String? code,
    Exception? originalException,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
  }) {
    return RpsError(
      code: code ?? 'CONFIG_ERROR',
      message: message,
      type: RpsErrorType.configuration,
      originalException: originalException,
      stackTrace: stackTrace,
      details: details,
    );
  }

  /// Determines if an error type is generally retryable
  static bool _determineRetryability(RpsErrorType type, int? statusCode) {
    switch (type) {
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

  /// Creates a copy of this error with updated properties
  RpsError copyWith({
    String? code,
    String? message,
    RpsErrorType? type,
    Map<String, dynamic>? details,
    Exception? originalException,
    StackTrace? stackTrace,
    DateTime? timestamp,
    int? statusCode,
    bool? isRetryable,
    String? requestId,
  }) {
    return RpsError(
      code: code ?? this.code,
      message: message ?? this.message,
      type: type ?? this.type,
      details: details ?? this.details,
      originalException: originalException ?? this.originalException,
      stackTrace: stackTrace ?? this.stackTrace,
      timestamp: timestamp ?? this.timestamp,
      statusCode: statusCode ?? this.statusCode,
      isRetryable: isRetryable ?? this.isRetryable,
      requestId: requestId ?? this.requestId,
    );
  }

  /// Converts the error to a JSON representation
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'is_retryable': isRetryable,
      if (statusCode != null) 'status_code': statusCode,
      if (requestId != null) 'request_id': requestId,
      if (details != null) 'details': details,
      if (originalException != null)
        'original_exception': originalException.toString(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('RpsError(');
    buffer.write('code: $code, ');
    buffer.write('type: ${type.name}, ');
    buffer.write('message: $message');

    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }

    if (requestId != null) {
      buffer.write(', requestId: $requestId');
    }

    buffer.write(', retryable: $isRetryable');
    buffer.write(')');

    return buffer.toString();
  }
}

/// Error handler that provides classification, recovery strategies, and retry logic
class RpsErrorHandler {
  /// Classifies an exception into an RpsError with appropriate type and metadata
  static RpsError classifyError(
    Object exception, {
    String? requestId,
    StackTrace? stackTrace,
  }) {
    stackTrace ??= StackTrace.current;

    // Handle different types of exceptions
    if (exception is RpsError) {
      return exception;
    }

    // Convert to Exception if it's not already
    Exception actualException;
    if (exception is Exception) {
      actualException = exception;
    } else {
      actualException = Exception(exception.toString());
    }

    // Classify based on exception type and message
    final exceptionString = actualException.toString().toLowerCase();

    // Network-related errors
    if (_isNetworkError(actualException, exceptionString)) {
      return RpsError.network(
        message: _extractErrorMessage(actualException),
        originalException: actualException,
        stackTrace: stackTrace,
        requestId: requestId,
      );
    }

    // Timeout errors
    if (_isTimeoutError(actualException, exceptionString)) {
      return RpsError.timeout(
        message: _extractErrorMessage(actualException),
        originalException: actualException,
        stackTrace: stackTrace,
        requestId: requestId,
      );
    }

    // Authentication errors
    if (_isAuthenticationError(actualException, exceptionString)) {
      return RpsError.authentication(
        message: _extractErrorMessage(actualException),
        originalException: actualException,
        stackTrace: stackTrace,
        requestId: requestId,
      );
    }

    // Configuration errors
    if (_isConfigurationError(actualException, exceptionString)) {
      return RpsError.configuration(
        message: _extractErrorMessage(actualException),
        originalException: actualException,
        stackTrace: stackTrace,
      );
    }

    // Default to unknown error type
    return RpsError(
      code: 'UNKNOWN_ERROR',
      message: _extractErrorMessage(actualException),
      type: RpsErrorType.unknown,
      originalException: actualException,
      stackTrace: stackTrace,
      requestId: requestId,
    );
  }

  /// Classifies an HTTP response error based on status code
  static RpsError classifyHttpError(
    int statusCode,
    String responseBody, {
    String? requestId,
    StackTrace? stackTrace,
    Map<String, String>? responseHeaders,
  }) {
    stackTrace ??= StackTrace.current;

    final details = <String, dynamic>{
      'response_body': responseBody,
      if (responseHeaders != null) 'response_headers': responseHeaders,
    };

    if (statusCode >= 500) {
      return RpsError.serverError(
        message: 'Server error: HTTP $statusCode',
        statusCode: statusCode,
        details: details,
        requestId: requestId,
        stackTrace: stackTrace,
      );
    } else if (statusCode == 429) {
      return RpsError.clientError(
        message: 'Rate limited: Too many requests',
        statusCode: statusCode,
        details: details,
        requestId: requestId,
        stackTrace: stackTrace,
      );
    } else if (statusCode == 401 || statusCode == 403) {
      return RpsError.authentication(
        message: statusCode == 401 ? 'Unauthorized' : 'Forbidden',
        statusCode: statusCode,
        details: details,
        requestId: requestId,
        stackTrace: stackTrace,
      );
    } else if (statusCode >= 400) {
      return RpsError.clientError(
        message: 'Client error: HTTP $statusCode',
        statusCode: statusCode,
        details: details,
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }

    // Shouldn't reach here for error status codes, but handle gracefully
    return RpsError(
      code: 'HTTP_ERROR',
      message: 'HTTP error: $statusCode',
      type: RpsErrorType.unknown,
      statusCode: statusCode,
      details: details,
      requestId: requestId,
      stackTrace: stackTrace,
    );
  }

  /// Determines if an error should be retried based on its type and context
  static bool shouldRetry(RpsError error, int attemptCount, int maxAttempts) {
    // Don't retry if we've exceeded max attempts
    if (attemptCount >= maxAttempts) {
      return false;
    }

    // Use the error's built-in retryability determination
    return error.isRetryable;
  }

  /// Calculates the delay before the next retry attempt
  static Duration getRetryDelay(
    RpsError error,
    int attemptCount, {
    Duration baseDelay = const Duration(seconds: 1),
    double multiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool jitterEnabled = true,
  }) {
    // Calculate exponential backoff
    final exponentialDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * (multiplier * attemptCount))
          .round(),
    );

    // Cap at maximum delay
    var delay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

    // Add jitter to prevent thundering herd
    if (jitterEnabled) {
      final jitterMs =
          (delay.inMilliseconds *
                  0.1 *
                  (DateTime.now().millisecondsSinceEpoch % 100) /
                  100)
              .round();
      delay = Duration(milliseconds: delay.inMilliseconds + jitterMs);
    }

    // Special handling for rate limiting - use longer delays
    if (error.type == RpsErrorType.rateLimited) {
      delay = Duration(milliseconds: (delay.inMilliseconds * 2).round());
    }

    return delay;
  }

  /// Gets a recovery strategy for the given error
  static ErrorRecoveryStrategy getRecoveryStrategy(RpsError error) {
    switch (error.type) {
      case RpsErrorType.network:
      case RpsErrorType.timeout:
      case RpsErrorType.serverError:
        return ErrorRecoveryStrategy.retry;

      case RpsErrorType.rateLimited:
        return ErrorRecoveryStrategy.retryWithBackoff;

      case RpsErrorType.authentication:
        return ErrorRecoveryStrategy.refreshCredentials;

      case RpsErrorType.validation:
      case RpsErrorType.clientError:
      case RpsErrorType.configuration:
        return ErrorRecoveryStrategy.fail;

      case RpsErrorType.cache:
        return ErrorRecoveryStrategy.fallbackToNetwork;

      case RpsErrorType.unknown:
        return ErrorRecoveryStrategy.retry;
    }
  }

  /// Checks if an exception is network-related
  static bool _isNetworkError(Exception exception, String exceptionString) {
    return exceptionString.contains('socketexception') ||
        exceptionString.contains('connection') ||
        exceptionString.contains('network') ||
        exceptionString.contains('dns') ||
        exceptionString.contains('host') ||
        exceptionString.contains('unreachable');
  }

  /// Checks if an exception is timeout-related
  static bool _isTimeoutError(Exception exception, String exceptionString) {
    return exceptionString.contains('timeout') ||
        exceptionString.contains('timeoutexception');
  }

  /// Checks if an exception is authentication-related
  static bool _isAuthenticationError(
    Exception exception,
    String exceptionString,
  ) {
    return exceptionString.contains('unauthorized') ||
        exceptionString.contains('authentication') ||
        exceptionString.contains('auth') ||
        exceptionString.contains('forbidden') ||
        exceptionString.contains('401') ||
        exceptionString.contains('403');
  }

  /// Checks if an exception is configuration-related
  static bool _isConfigurationError(
    Exception exception,
    String exceptionString,
  ) {
    return exception is ArgumentError ||
        exception is StateError ||
        exceptionString.contains('configuration') ||
        exceptionString.contains('config') ||
        exceptionString.contains('invalid') &&
            exceptionString.contains('parameter');
  }

  /// Extracts a meaningful error message from an exception
  static String _extractErrorMessage(Exception exception) {
    final message = exception.toString();

    // Clean up common exception prefixes
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    if (message.startsWith('SocketException: ')) {
      return message.substring(16);
    }

    if (message.startsWith('TimeoutException: ')) {
      return message.substring(17);
    }

    return message;
  }
}

/// Enumeration of error recovery strategies
enum ErrorRecoveryStrategy {
  /// Retry the operation immediately or with minimal delay
  retry,

  /// Retry with exponential backoff
  retryWithBackoff,

  /// Attempt to refresh credentials and retry
  refreshCredentials,

  /// Fail immediately without retry
  fail,

  /// Fall back to network request (for cache errors)
  fallbackToNetwork,

  /// Fall back to cached data (for network errors)
  fallbackToCache,
}

/// Exception thrown when error recovery fails
class ErrorRecoveryException implements Exception {
  final String message;
  final RpsError originalError;
  final ErrorRecoveryStrategy attemptedStrategy;

  const ErrorRecoveryException({
    required this.message,
    required this.originalError,
    required this.attemptedStrategy,
  });

  @override
  String toString() {
    return 'ErrorRecoveryException: $message (attempted: ${attemptedStrategy.name}, original: ${originalError.code})';
  }
}
