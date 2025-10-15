import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/core/error.dart';

void main() {
  group('RpsError', () {
    test('should create basic error with required fields', () {
      final error = RpsError(
        code: 'TEST_ERROR',
        message: 'Test error message',
        type: RpsErrorType.network,
      );

      expect(error.code, equals('TEST_ERROR'));
      expect(error.message, equals('Test error message'));
      expect(error.type, equals(RpsErrorType.network));
      expect(error.isRetryable, isTrue); // Network errors are retryable
      expect(error.timestamp, isA<DateTime>());
    });

    test('should create network error with factory constructor', () {
      final originalException = Exception('Connection failed');
      final error = RpsError.network(
        message: 'Network connection failed',
        code: 'NET_001',
        originalException: originalException,
        requestId: 'req-123',
      );

      expect(error.code, equals('NET_001'));
      expect(error.message, equals('Network connection failed'));
      expect(error.type, equals(RpsErrorType.network));
      expect(error.isRetryable, isTrue);
      expect(error.originalException, equals(originalException));
      expect(error.requestId, equals('req-123'));
    });

    test('should create authentication error with factory constructor', () {
      final error = RpsError.authentication(
        message: 'Invalid API key',
        statusCode: 401,
        requestId: 'req-456',
      );

      expect(error.code, equals('AUTH_ERROR'));
      expect(error.message, equals('Invalid API key'));
      expect(error.type, equals(RpsErrorType.authentication));
      expect(error.statusCode, equals(401));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
      expect(error.requestId, equals('req-456'));
    });

    test('should create validation error with validation details', () {
      final validationErrors = [
        'Field "name" is required',
        'Invalid email format',
      ];
      final error = RpsError.validation(
        message: 'Request validation failed',
        validationErrors: validationErrors,
        requestId: 'req-789',
      );

      expect(error.code, equals('VALIDATION_ERROR'));
      expect(error.message, equals('Request validation failed'));
      expect(error.type, equals(RpsErrorType.validation));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
      expect(error.details?['validation_errors'], equals(validationErrors));
      expect(error.requestId, equals('req-789'));
    });

    test('should create server error with status code', () {
      final error = RpsError.serverError(
        message: 'Internal server error',
        statusCode: 500,
        details: {'server_id': 'srv-001'},
      );

      expect(error.code, equals('SERVER_ERROR'));
      expect(error.type, equals(RpsErrorType.serverError));
      expect(error.statusCode, equals(500));
      expect(error.isRetryable, isTrue); // Server errors are retryable
      expect(error.details?['server_id'], equals('srv-001'));
    });

    test('should create client error and detect rate limiting', () {
      final rateLimitError = RpsError.clientError(
        message: 'Too many requests',
        statusCode: 429,
      );

      final regularClientError = RpsError.clientError(
        message: 'Bad request',
        statusCode: 400,
      );

      expect(rateLimitError.type, equals(RpsErrorType.rateLimited));
      expect(
        rateLimitError.isRetryable,
        isTrue,
      ); // Rate limit errors are retryable

      expect(regularClientError.type, equals(RpsErrorType.clientError));
      expect(
        regularClientError.isRetryable,
        isTrue, // ✅ ULTRA AGGRESSIVE: Now retryable!
      );
    });

    test('should create timeout error with duration details', () {
      final timeoutDuration = Duration(seconds: 30);
      final error = RpsError.timeout(
        message: 'Request timed out',
        timeoutDuration: timeoutDuration,
      );

      expect(error.code, equals('TIMEOUT_ERROR'));
      expect(error.type, equals(RpsErrorType.timeout));
      expect(error.isRetryable, isTrue);
      expect(error.details?['timeout_duration_ms'], equals(30000));
    });

    test('should create cache error', () {
      final error = RpsError.cache(
        message: 'Cache write failed',
        details: {'cache_type': 'shared_preferences'},
      );

      expect(error.code, equals('CACHE_ERROR'));
      expect(error.type, equals(RpsErrorType.cache));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
      expect(error.details?['cache_type'], equals('shared_preferences'));
    });

    test('should create configuration error', () {
      final error = RpsError.configuration(
        message: 'Invalid base URL',
        code: 'CONFIG_001',
      );

      expect(error.code, equals('CONFIG_001'));
      expect(error.type, equals(RpsErrorType.configuration));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should copy error with updated properties', () {
      final originalError = RpsError.network(
        message: 'Original message',
        requestId: 'req-001',
      );

      final copiedError = originalError.copyWith(
        message: 'Updated message',
        code: 'NEW_CODE',
      );

      expect(copiedError.message, equals('Updated message'));
      expect(copiedError.code, equals('NEW_CODE'));
      expect(copiedError.type, equals(originalError.type));
      expect(copiedError.requestId, equals('req-001')); // Unchanged
    });

    test('should convert to JSON representation', () {
      final error = RpsError.authentication(
        message: 'Auth failed',
        statusCode: 401,
        requestId: 'req-123',
      );

      final json = error.toJson();

      expect(json['code'], equals('AUTH_ERROR'));
      expect(json['message'], equals('Auth failed'));
      expect(json['type'], equals('authentication'));
      expect(json['status_code'], equals(401));
      expect(json['request_id'], equals('req-123'));
      expect(
        json['is_retryable'],
        isTrue,
      ); // ✅ ULTRA AGGRESSIVE: Now retryable!
      expect(json['timestamp'], isA<String>());
    });

    test('should have meaningful toString representation', () {
      final error = RpsError.serverError(
        message: 'Server error',
        statusCode: 500,
        requestId: 'req-456',
      );

      final errorString = error.toString();

      expect(errorString, contains('RpsError'));
      expect(errorString, contains('code: SERVER_ERROR'));
      expect(errorString, contains('type: serverError'));
      expect(errorString, contains('message: Server error'));
      expect(errorString, contains('statusCode: 500'));
      expect(errorString, contains('requestId: req-456'));
      expect(errorString, contains('retryable: true'));
    });
  });

  group('RpsErrorHandler', () {
    test('should classify network exceptions', () {
      final networkException = Exception('SocketException: Connection refused');
      final error = RpsErrorHandler.classifyError(
        networkException,
        requestId: 'req-001',
      );

      expect(error.type, equals(RpsErrorType.network));
      expect(error.code, equals('NETWORK_ERROR'));
      expect(error.isRetryable, isTrue);
      expect(error.originalException, equals(networkException));
      expect(error.requestId, equals('req-001'));
    });

    test('should classify timeout exceptions', () {
      final timeoutException = Exception('TimeoutException: Request timeout');
      final error = RpsErrorHandler.classifyError(timeoutException);

      expect(error.type, equals(RpsErrorType.timeout));
      expect(error.code, equals('TIMEOUT_ERROR'));
      expect(error.isRetryable, isTrue);
      expect(error.originalException, equals(timeoutException));
    });

    test('should classify authentication exceptions', () {
      final authException = Exception('Unauthorized access');
      final error = RpsErrorHandler.classifyError(authException);

      expect(error.type, equals(RpsErrorType.authentication));
      expect(error.code, equals('AUTH_ERROR'));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should classify configuration exceptions', () {
      final configException = ArgumentError('Invalid parameter value');
      final error = RpsErrorHandler.classifyError(configException);

      expect(error.type, equals(RpsErrorType.configuration));
      expect(error.code, equals('CONFIG_ERROR'));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should classify unknown exceptions', () {
      final unknownException = Exception('Some unknown error');
      final error = RpsErrorHandler.classifyError(unknownException);

      expect(error.type, equals(RpsErrorType.unknown));
      expect(error.code, equals('UNKNOWN_ERROR'));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should return existing RpsError unchanged', () {
      final originalError = RpsError.network(message: 'Network error');
      final classifiedError = RpsErrorHandler.classifyError(originalError);

      expect(classifiedError, same(originalError));
    });

    test('should classify HTTP server errors', () {
      final error = RpsErrorHandler.classifyHttpError(
        500,
        'Internal Server Error',
        requestId: 'req-123',
      );

      expect(error.type, equals(RpsErrorType.serverError));
      expect(error.statusCode, equals(500));
      expect(error.isRetryable, isTrue);
      expect(error.requestId, equals('req-123'));
      expect(error.details?['response_body'], equals('Internal Server Error'));
    });

    test('should classify HTTP rate limiting errors', () {
      final error = RpsErrorHandler.classifyHttpError(
        429,
        'Too Many Requests',
        responseHeaders: {'Retry-After': '60'},
      );

      expect(error.type, equals(RpsErrorType.rateLimited));
      expect(error.statusCode, equals(429));
      expect(error.isRetryable, isTrue);
      expect(error.details?['response_headers'], contains('Retry-After'));
    });

    test('should classify HTTP authentication errors', () {
      final unauthorizedError = RpsErrorHandler.classifyHttpError(
        401,
        'Unauthorized',
      );
      final forbiddenError = RpsErrorHandler.classifyHttpError(
        403,
        'Forbidden',
      );

      expect(unauthorizedError.type, equals(RpsErrorType.authentication));
      expect(unauthorizedError.statusCode, equals(401));
      expect(
        unauthorizedError.isRetryable,
        isTrue,
      ); // ✅ ULTRA AGGRESSIVE: Now retryable!

      expect(forbiddenError.type, equals(RpsErrorType.authentication));
      expect(forbiddenError.statusCode, equals(403));
      expect(
        forbiddenError.isRetryable,
        isTrue,
      ); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should classify HTTP client errors', () {
      final error = RpsErrorHandler.classifyHttpError(400, 'Bad Request');

      expect(error.type, equals(RpsErrorType.clientError));
      expect(error.statusCode, equals(400));
      expect(error.isRetryable, isTrue); // ✅ ULTRA AGGRESSIVE: Now retryable!
    });

    test('should determine retry eligibility correctly', () {
      final retryableError = RpsError.network(message: 'Network error');
      final validationError = RpsError.validation(message: 'Validation error');

      expect(RpsErrorHandler.shouldRetry(retryableError, 1, 3), isTrue);
      expect(
        RpsErrorHandler.shouldRetry(validationError, 1, 3),
        isTrue,
      ); // ✅ ULTRA AGGRESSIVE: Now retryable!
      expect(
        RpsErrorHandler.shouldRetry(retryableError, 3, 3),
        isFalse,
      ); // Max attempts reached
    });

    test('should calculate exponential backoff delay', () {
      final error = RpsError.network(message: 'Network error');

      final delay1 = RpsErrorHandler.getRetryDelay(error, 1);
      final delay2 = RpsErrorHandler.getRetryDelay(error, 2);

      expect(delay1.inMilliseconds, greaterThan(0));
      expect(delay2.inMilliseconds, greaterThan(delay1.inMilliseconds));
    });

    test('should apply jitter to retry delays', () {
      final error = RpsError.network(message: 'Network error');

      final delay1 = RpsErrorHandler.getRetryDelay(
        error,
        1,
        jitterEnabled: true,
      );
      final delay2 = RpsErrorHandler.getRetryDelay(
        error,
        1,
        jitterEnabled: true,
      );

      // With jitter, delays should potentially be different
      // (though they might occasionally be the same due to randomness)
      expect(delay1.inMilliseconds, greaterThan(0));
      expect(delay2.inMilliseconds, greaterThan(0));
    });

    test('should cap retry delay at maximum', () {
      final error = RpsError.network(message: 'Network error');
      const maxDelay = Duration(seconds: 5);

      final delay = RpsErrorHandler.getRetryDelay(
        error,
        10, // High attempt count
        maxDelay: maxDelay,
      );

      expect(
        delay.inMilliseconds,
        lessThanOrEqualTo(maxDelay.inMilliseconds * 1.1),
      ); // Allow for jitter
    });

    test('should apply longer delays for rate limiting', () {
      final networkError = RpsError.network(message: 'Network error');
      final rateLimitError = RpsError.clientError(
        message: 'Rate limited',
        statusCode: 429,
      );

      final networkDelay = RpsErrorHandler.getRetryDelay(
        networkError,
        1,
        jitterEnabled: false,
      );
      final rateLimitDelay = RpsErrorHandler.getRetryDelay(
        rateLimitError,
        1,
        jitterEnabled: false,
      );

      expect(
        rateLimitDelay.inMilliseconds,
        greaterThan(networkDelay.inMilliseconds),
      );
    });

    test('should provide appropriate recovery strategies', () {
      expect(
        RpsErrorHandler.getRecoveryStrategy(
          RpsError.network(message: 'Network error'),
        ),
        equals(ErrorRecoveryStrategy.retry),
      );

      expect(
        RpsErrorHandler.getRecoveryStrategy(
          RpsError.clientError(message: 'Rate limited', statusCode: 429),
        ),
        equals(ErrorRecoveryStrategy.retryWithBackoff),
      );

      expect(
        RpsErrorHandler.getRecoveryStrategy(
          RpsError.authentication(message: 'Auth error'),
        ),
        equals(ErrorRecoveryStrategy.refreshCredentials),
      );

      expect(
        RpsErrorHandler.getRecoveryStrategy(
          RpsError.validation(message: 'Validation error'),
        ),
        equals(ErrorRecoveryStrategy.fail),
      );

      expect(
        RpsErrorHandler.getRecoveryStrategy(
          RpsError.cache(message: 'Cache error'),
        ),
        equals(ErrorRecoveryStrategy.fallbackToNetwork),
      );
    });
  });

  group('ErrorRecoveryException', () {
    test('should create recovery exception with details', () {
      final originalError = RpsError.network(message: 'Network error');
      final recoveryException = ErrorRecoveryException(
        message: 'Recovery failed after 3 attempts',
        originalError: originalError,
        attemptedStrategy: ErrorRecoveryStrategy.retry,
      );

      expect(
        recoveryException.message,
        equals('Recovery failed after 3 attempts'),
      );
      expect(recoveryException.originalError, equals(originalError));
      expect(
        recoveryException.attemptedStrategy,
        equals(ErrorRecoveryStrategy.retry),
      );
    });

    test('should have meaningful toString representation', () {
      final originalError = RpsError.authentication(message: 'Auth failed');
      final recoveryException = ErrorRecoveryException(
        message: 'Credential refresh failed',
        originalError: originalError,
        attemptedStrategy: ErrorRecoveryStrategy.refreshCredentials,
      );

      final exceptionString = recoveryException.toString();

      expect(exceptionString, contains('ErrorRecoveryException'));
      expect(exceptionString, contains('Credential refresh failed'));
      expect(exceptionString, contains('attempted: refreshCredentials'));
      expect(exceptionString, contains('original: AUTH_ERROR'));
    });
  });
}
