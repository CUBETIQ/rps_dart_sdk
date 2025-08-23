/// Unit tests for HTTP transport layer
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/transport/http_transport.dart';
import 'package:rps_dart_sdk/src/core/configuration.dart';
import 'package:rps_dart_sdk/src/core/models.dart';
import 'package:rps_dart_sdk/src/core/error.dart';
import 'package:rps_dart_sdk/src/auth/authentication_provider.dart';
import 'package:rps_dart_sdk/src/core/simple_logger.dart';

/// Mock Dio client for testing HTTP transport
// Todo: Needed To Update This Due To Change Made In Transport Layer File
class MockDio implements Dio {
  final List<RequestOptions> capturedRequests = [];
  Response? mockResponse;
  DioException? mockError;
  Duration? mockDelay;

  @override
  BaseOptions options = BaseOptions();

  @override
  Interceptors interceptors = Interceptors();

  @override
  HttpClientAdapter httpClientAdapter = IOHttpClientAdapter();

  @override
  Transformer transformer = BackgroundTransformer();

  void reset() {
    capturedRequests.clear();
    mockResponse = null;
    mockError = null;
    mockDelay = null;
    // Set default response
    mockResponse = Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 200,
      data: {'result': 'success'},
    );
  }

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    capturedRequests.add(requestOptions);

    if (mockDelay != null) {
      // Check for cancellation during delay
      final cancelToken = requestOptions.cancelToken;
      for (int i = 0; i < mockDelay!.inMilliseconds; i += 10) {
        if (cancelToken != null && cancelToken.isCancelled) {
          throw DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.cancel,
          );
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    if (mockError != null) {
      throw mockError!;
    }

    return mockResponse as Response<T>? ??
        Response<T>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'success': true} as T,
        );
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: 'GET',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final requestOptions = RequestOptions(
      path: path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      headers: options?.headers,
    );
    if (cancelToken != null) {
      requestOptions.cancelToken = cancelToken;
    }
    return fetch<T>(requestOptions);
  }

  // Implement other required methods with minimal functionality
  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: 'PUT',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: 'PATCH',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: 'DELETE',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response<T>> head<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: 'HEAD',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response> download(
    String urlPath,
    savePath, {
    void Function(int, int)? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
    FileAccessMode fileAccessMode = FileAccessMode.write,
  }) async {
    return fetch(RequestOptions(path: urlPath, method: 'GET'));
  }

  @override
  Future<Response> downloadUri(
    Uri uri,
    savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
    FileAccessMode fileAccessMode = FileAccessMode.write,
  }) async {
    return fetch(RequestOptions(path: uri.toString(), method: 'GET'));
  }

  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    Object? data,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'GET', data: data),
    );
  }

  @override
  Future<Response<T>> postUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'POST', data: data),
    );
  }

  @override
  Future<Response<T>> putUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'PUT', data: data),
    );
  }

  @override
  Future<Response<T>> patchUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'PATCH', data: data),
    );
  }

  @override
  Future<Response<T>> deleteUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'DELETE', data: data),
    );
  }

  @override
  Future<Response<T>> headUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    Object? data,
  }) async {
    return fetch<T>(
      RequestOptions(path: uri.toString(), method: 'HEAD', data: data),
    );
  }

  @override
  Dio clone({
    BaseOptions? options,
    Transformer? transformer,
    HttpClientAdapter? httpClientAdapter,
    Interceptors? interceptors,
  }) {
    return MockDio();
  }

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: path,
        method: options?.method ?? 'GET',
        data: data,
        queryParameters: queryParameters,
      ).copyWith(cancelToken: cancelToken),
    );
  }

  @override
  Future<Response<T>> requestUri<T>(
    Uri uri, {
    Object? data,
    CancelToken? cancelToken,
    Options? options,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return fetch<T>(
      RequestOptions(
        path: uri.toString(),
        method: options?.method ?? 'GET',
        data: data,
      ).copyWith(cancelToken: cancelToken),
    );
  }
}

/// Mock authentication provider for testing
class MockAuthProvider implements AuthenticationProvider {
  final Map<String, String> _headers;
  bool _shouldFail;
  bool _requiresRefresh;
  bool _supportsRefresh;
  int _getAuthHeadersCallCount = 0;

  MockAuthProvider({
    Map<String, String>? headers,
    bool shouldFail = false,
    bool requiresRefresh = false,
    bool supportsRefresh = false,
  }) : _headers = headers ?? {'Authorization': 'Bearer test-token'},
       _shouldFail = shouldFail,
       _requiresRefresh = requiresRefresh,
       _supportsRefresh = supportsRefresh;

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    _getAuthHeadersCallCount++;
    if (_shouldFail) {
      throw AuthenticationException('Mock auth failure');
    }
    return _headers;
  }

  @override
  Future<bool> refreshCredentials() async {
    if (!_supportsRefresh) return false;
    _requiresRefresh = false;
    return true;
  }

  @override
  bool get requiresRefresh => _requiresRefresh;

  @override
  bool get supportsRefresh => _supportsRefresh;

  @override
  String get providerType => 'mock';

  void setRequiresRefresh(bool value) => _requiresRefresh = value;
  void setShouldFail(bool value) => _shouldFail = value;

  void clearCallHistory() => _getAuthHeadersCallCount = 0;
  int get getAuthHeadersCallCount => _getAuthHeadersCallCount;
}

/// Mock logger for testing
class MockLogger implements LoggingManager {
  final List<String> debugMessages = [];
  final List<String> infoMessages = [];
  final List<String> warnMessages = [];
  final List<String> errorMessages = [];
  final List<Object> capturedErrors = [];

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    debugMessages.add(message);
    if (error != null) {
      capturedErrors.add(error);
    }
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    infoMessages.add(message);
    if (error != null) {
      capturedErrors.add(error);
    }
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    warnMessages.add(message);
    if (error != null) {
      capturedErrors.add(error);
    }
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    errorMessages.add(message);
    if (error != null) {
      capturedErrors.add(error);
    }
  }

  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    errorMessages.add(message);
    if (error != null) {
      capturedErrors.add(error);
    }
  }

  @override
  void dispose() {
    // No cleanup needed for mock
  }

  void clear() {
    debugMessages.clear();
    infoMessages.clear();
    warnMessages.clear();
    errorMessages.clear();
    capturedErrors.clear();
  }
}

void main() {
  group('DioHttpTransport', () {
    late RpsConfiguration config;
    late MockDio mockDio;
    late MockAuthProvider mockAuth;
    late MockLogger mockLogger;

    setUp(() {
      config = RpsConfigurationBuilder()
          .setBaseUrl('https://api.test.com')
          .setApiKey('test-key')
          .setTimeouts(const Duration(seconds: 10), const Duration(seconds: 30))
          .build();

      mockDio = MockDio();
      mockAuth = MockAuthProvider();
      mockLogger = MockLogger();
    });

    tearDown(() {
      mockLogger.clear();
      mockDio.reset();
    });

    group('Creation and Configuration', () {
      test('creates transport with default configuration', () async {
        final transport = await DioHttpTransport.create(config: config);

        expect(transport, isA<DioHttpTransport>());
        expect(transport.activeRequestCount, equals(0));

        await transport.dispose();
      });

      test('creates transport with custom components', () async {
        final transport = await DioHttpTransport.create(
          config: config,
          authProvider: mockAuth,
          logger: mockLogger,

          customDio: mockDio,
        );

        expect(transport, isA<DioHttpTransport>());
        await transport.dispose();
      });

      test('configures Dio with correct options', () async {
        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        expect(mockDio.options.baseUrl, equals('https://api.test.com'));
        expect(
          mockDio.options.connectTimeout,
          equals(const Duration(seconds: 10)),
        );
        expect(
          mockDio.options.receiveTimeout,
          equals(const Duration(seconds: 30)),
        );
        expect(
          mockDio.options.headers['Content-Type'],
          equals('application/json'),
        );

        await transport.dispose();
      });
    });

    group('Request Sending', () {
      test('sends successful request', () async {
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
          logger: mockLogger,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        final response = await transport.sendRequest(request);

        expect(response.statusCode, equals(200));
        expect(response.data['result'], equals('success'));
        expect(response.isSuccess, isTrue);
        expect(response.requestId, equals(request.id));
        expect(response.fromCache, isFalse);

        await transport.dispose();
      });

      test('includes authentication headers', () async {
        // Mock successful response
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
          authProvider: mockAuth,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        final response = await transport.sendRequest(request);

        // Verify the call was successful and auth provider was used
        expect(response.statusCode, equals(200));
        expect(mockAuth.getAuthHeadersCallCount, greaterThan(0));

        // Verify headers were included in the request
        expect(mockDio.capturedRequests, hasLength(1));
        final capturedRequest = mockDio.capturedRequests.first;
        expect(
          capturedRequest.headers['Authorization'],
          equals('Bearer test-token'),
        );

        await transport.dispose();
      });

      test('includes custom headers from request', () async {
        // Mock successful response
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
          headers: {'X-Custom': 'custom-value'},
        );

        final response = await transport.sendRequest(request);

        // Verify the call was successful
        expect(response.statusCode, equals(200));
        expect(response.data, isNotNull);

        // Verify custom headers were included in the request
        expect(mockDio.capturedRequests, hasLength(1));
        final capturedRequest = mockDio.capturedRequests.first;
        expect(capturedRequest.headers['X-Custom'], equals('custom-value'));

        await transport.dispose();
      });

      test('sends correct request data', () async {
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'invoice',
          data: {'amount': 100, 'currency': 'USD'},
        );

        await transport.sendRequest(request);

        expect(mockDio.capturedRequests, hasLength(1));
        final capturedRequest = mockDio.capturedRequests.first;

        // Check that the request data structure is as expected
        expect(capturedRequest.data, isA<Map<String, dynamic>>());
        final requestData = capturedRequest.data as Map<String, dynamic>;

        expect(requestData['type'], equals('invoice'));
        expect(requestData['data'], isA<Map>());
        expect(requestData['data']['amount'], equals(100));
        expect(requestData['data']['currency'], equals('USD'));
        expect(requestData['metadata'], isA<Map>());

        await transport.dispose();
      });
    });

    group('Error Handling', () {
      test('handles network errors', () async {
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: 'Connection failed',
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        expect(
          () => transport.sendRequest(request),
          throwsA(
            isA<RpsError>().having((e) => e.type, 'type', RpsErrorType.network),
          ),
        );

        await transport.dispose();
      });

      test('handles timeout errors', () async {
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
          message: 'Request timeout',
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        expect(
          () => transport.sendRequest(request),
          throwsA(
            isA<RpsError>().having((e) => e.type, 'type', RpsErrorType.timeout),
          ),
        );

        await transport.dispose();
      });

      test('handles server errors', () async {
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
            data: {'error': 'Internal server error'},
          ),
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        expect(
          () => transport.sendRequest(request),
          throwsA(
            isA<RpsError>().having(
              (e) => e.type,
              'type',
              RpsErrorType.serverError,
            ),
          ),
        );

        await transport.dispose();
      });

      test('handles client errors', () async {
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
            data: {'error': 'Bad request'},
          ),
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        expect(
          () => transport.sendRequest(request),
          throwsA(
            isA<RpsError>().having(
              (e) => e.type,
              'type',
              RpsErrorType.clientError,
            ),
          ),
        );

        await transport.dispose();
      });

      test('handles authentication errors', () async {
        // This test verifies that authentication errors are properly converted
        // We'll test this by creating a DioException with an RpsError in it
        final authError = RpsError.authentication(
          message: 'Auth failed',
          details: {'provider': 'mock'},
        );

        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          error: authError,
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        expect(
          () => transport.sendRequest(request),
          throwsA(
            isA<RpsError>().having(
              (e) => e.type,
              'type',
              RpsErrorType.authentication,
            ),
          ),
        );

        await transport.dispose();
      });
    });

    group('Request Cancellation', () {
      test('cancels individual request', () async {
        mockDio.mockDelay = const Duration(seconds: 1);

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(
          type: 'test',
          data: {'message': 'hello'},
        );

        // Start request but don't await
        final responseFuture = transport.sendRequest(request);

        // Cancel the request
        await transport.cancelRequest(request.id);

        // The request should be cancelled
        expect(
          () => responseFuture,
          throwsA(
            isA<RpsError>().having((e) => e.type, 'type', RpsErrorType.network),
          ),
        );

        await transport.dispose();
      });

      test('cancels all requests', () async {
        mockDio.mockDelay = const Duration(seconds: 2);

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request1 = RpsRequest.create(type: 'test1', data: {});
        final request2 = RpsRequest.create(type: 'test2', data: {});

        // Start requests with proper timing
        final future1 = transport.sendRequest(request1);
        await Future.delayed(const Duration(milliseconds: 100));

        final future2 = transport.sendRequest(request2);
        await Future.delayed(const Duration(milliseconds: 100));

        // Give enough time for both requests to start
        expect(transport.activeRequestCount, greaterThan(0));

        // Cancel all requests
        await transport.cancelAllRequests();

        // Both requests should be cancelled
        expect(() => future1, throwsA(isA<RpsError>()));
        expect(() => future2, throwsA(isA<RpsError>()));

        await transport.dispose();
      });
    });

    group('Statistics', () {
      test('tracks request statistics', () async {
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        // Send successful request
        final request1 = RpsRequest.create(type: 'test1', data: {});
        await transport.sendRequest(request1);

        // Send failed request
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        );

        final request2 = RpsRequest.create(type: 'test2', data: {});
        try {
          await transport.sendRequest(request2);
        } catch (e) {
          // Expected to fail
        }

        final stats = transport.stats;
        expect(stats.totalRequests, equals(2));
        expect(stats.successfulRequests, equals(1));
        expect(stats.failedRequests, equals(1));
        expect(stats.successRate, equals(0.5));

        await transport.dispose();
      });

      test('tracks response times', () async {
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );
        mockDio.mockDelay = const Duration(milliseconds: 100);

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        final request = RpsRequest.create(type: 'test', data: {});
        final response = await transport.sendRequest(request);

        expect(response.responseTime.inMilliseconds, greaterThan(90));

        final stats = transport.stats;
        expect(stats.averageResponseTime.inMilliseconds, greaterThan(90));

        await transport.dispose();
      });
    });

    group('Logging Integration', () {
      test('logs request and response details', () async {
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
          logger: mockLogger,
        );

        final request = RpsRequest.create(type: 'test', data: {'test': 'data'});
        await transport.sendRequest(request);

        expect(mockLogger.debugMessages, isNotEmpty);
        expect(
          mockLogger.debugMessages.any((msg) => msg.contains('HTTP Request')),
          isTrue,
        );
        expect(
          mockLogger.debugMessages.any((msg) => msg.contains('HTTP Response')),
          isTrue,
        );

        await transport.dispose();
      });

      test('logs errors', () async {
        mockDio.mockError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
          message: 'Request timeout',
        );

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
          logger: mockLogger,
        );

        final request = RpsRequest.create(type: 'test', data: {});

        try {
          await transport.sendRequest(request);
        } catch (e) {
          // Expected to fail with timeout
        }

        // Should have some logs even on timeout
        expect(mockLogger.debugMessages, isNotEmpty);
        expect(
          mockLogger.debugMessages.any((msg) => msg.contains('HTTP Request')),
          isTrue,
        );

        await transport.dispose();
      });
    });

    group('Resource Management', () {
      test('cleans up resources on dispose', () async {
        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        expect(transport.activeRequestCount, equals(0));

        await transport.dispose();

        // After disposal, the transport should be in a clean state
        expect(transport.activeRequestCount, equals(0));
      });

      test('tracks active request count', () async {
        mockDio.mockDelay = const Duration(milliseconds: 500);
        mockDio.mockResponse = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'result': 'success'},
        );

        // Clear any previous errors
        mockDio.mockError = null;

        final transport = await DioHttpTransport.create(
          config: config,
          customDio: mockDio,
        );

        expect(transport.activeRequestCount, equals(0));

        // Start multiple requests
        final request1 = RpsRequest.create(type: 'test1', data: {});
        final request2 = RpsRequest.create(type: 'test2', data: {});

        final future1 = transport.sendRequest(request1);
        await Future.delayed(const Duration(milliseconds: 100));

        final future2 = transport.sendRequest(request2);
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have active requests (at least 1, possibly 2)
        expect(transport.activeRequestCount, greaterThan(0));

        await Future.wait([future1, future2]);

        // Should be back to zero
        expect(transport.activeRequestCount, equals(0));

        await transport.dispose();
      });
    });
  });
}
