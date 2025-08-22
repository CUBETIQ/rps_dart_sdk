import 'package:test/test.dart';
import 'package:rps_dart_sdk/src/auth/authentication_provider.dart';

void main() {
  group('AuthenticationException', () {
    test('should create exception with message only', () {
      const exception = AuthenticationException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.providerType, isNull);
      expect(exception.cause, isNull);
      expect(
        exception.toString(),
        equals('AuthenticationException: Test error'),
      );
    });

    test('should create exception with provider type', () {
      const exception = AuthenticationException(
        'Test error',
        providerType: 'test_provider',
      );

      expect(exception.message, equals('Test error'));
      expect(exception.providerType, equals('test_provider'));
      expect(
        exception.toString(),
        equals('AuthenticationException: Test error (Provider: test_provider)'),
      );
    });

    test('should create exception with cause', () {
      final cause = Exception('Original error');
      final exception = AuthenticationException('Test error', cause: cause);

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(
        exception.toString(),
        contains(
          'AuthenticationException: Test error (Cause: Exception: Original error)',
        ),
      );
    });
  });

  group('ApiKeyAuthProvider', () {
    test('should create provider with default header name', () {
      final provider = ApiKeyAuthProvider('test-api-key');

      expect(provider.providerType, equals('api_key'));
      expect(provider.requiresRefresh, isFalse);
      expect(provider.supportsRefresh, isFalse);
    });

    test('should create provider with custom header name', () {
      final provider = ApiKeyAuthProvider(
        'test-api-key',
        headerName: 'X-Custom-Key',
      );

      expect(provider.providerType, equals('api_key'));
    });

    test('should throw exception for empty API key', () {
      expect(
        () => ApiKeyAuthProvider(''),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.message, 'message', 'API key cannot be empty')
              .having((e) => e.providerType, 'providerType', 'api_key'),
        ),
      );
    });

    test(
      'should return correct auth headers with default header name',
      () async {
        final provider = ApiKeyAuthProvider('test-api-key');
        final headers = await provider.getAuthHeaders();

        expect(headers, equals({'X-API-Key': 'test-api-key'}));
      },
    );

    test(
      'should return correct auth headers with custom header name',
      () async {
        final provider = ApiKeyAuthProvider(
          'test-api-key',
          headerName: 'X-Custom-Key',
        );
        final headers = await provider.getAuthHeaders();

        expect(headers, equals({'X-Custom-Key': 'test-api-key'}));
      },
    );

    test('should not support credential refresh', () async {
      final provider = ApiKeyAuthProvider('test-api-key');
      final refreshed = await provider.refreshCredentials();

      expect(refreshed, isFalse);
      expect(provider.supportsRefresh, isFalse);
      expect(provider.requiresRefresh, isFalse);
    });

    test('should have meaningful toString', () {
      final provider = ApiKeyAuthProvider('test-key');
      expect(
        provider.toString(),
        equals('ApiKeyAuthProvider(headerName: X-API-Key)'),
      );
    });
  });

  group('BearerTokenAuthProvider', () {
    test('should create provider with token only', () {
      final provider = BearerTokenAuthProvider('test-token');

      expect(provider.providerType, equals('bearer_token'));
      expect(provider.supportsRefresh, isFalse);
      expect(provider.requiresRefresh, isFalse);
      expect(provider.currentToken, equals('test-token'));
    });

    test('should throw exception for empty token', () {
      expect(
        () => BearerTokenAuthProvider(''),
        throwsA(
          isA<AuthenticationException>()
              .having(
                (e) => e.message,
                'message',
                'Bearer token cannot be empty',
              )
              .having((e) => e.providerType, 'providerType', 'bearer_token'),
        ),
      );
    });

    test('should return correct auth headers', () async {
      final provider = BearerTokenAuthProvider('test-token');
      final headers = await provider.getAuthHeaders();

      expect(headers, equals({'Authorization': 'Bearer test-token'}));
    });

    test('should support refresh when callback provided', () {
      final provider = BearerTokenAuthProvider(
        'initial-token',
        tokenRefreshCallback: () async => 'new-token',
      );

      expect(provider.supportsRefresh, isTrue);
    });

    test('should refresh token successfully', () async {
      final provider = BearerTokenAuthProvider(
        'initial-token',
        tokenRefreshCallback: () async => 'new-token',
      );

      final refreshed = await provider.refreshCredentials();

      expect(refreshed, isTrue);
      expect(provider.currentToken, equals('new-token'));
    });

    test('should return false when refresh not supported', () async {
      final provider = BearerTokenAuthProvider('test-token');
      final refreshed = await provider.refreshCredentials();

      expect(refreshed, isFalse);
    });

    test('should throw exception when refresh returns empty token', () async {
      final provider = BearerTokenAuthProvider(
        'initial-token',
        tokenRefreshCallback: () async => '',
      );

      expect(
        () => provider.refreshCredentials(),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            'Token refresh returned empty token',
          ),
        ),
      );
    });

    test('should throw exception when refresh callback fails', () async {
      final provider = BearerTokenAuthProvider(
        'initial-token',
        tokenRefreshCallback: () async => throw Exception('Network error'),
      );

      expect(
        () => provider.refreshCredentials(),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Failed to refresh token'),
          ),
        ),
      );
    });

    test('should require refresh when token is near expiry', () {
      final now = DateTime.now();
      final expiry = now.add(
        const Duration(minutes: 3),
      ); // Less than 5 minute buffer

      final provider = BearerTokenAuthProvider(
        'test-token',
        tokenRefreshCallback: () async => 'new-token',
        tokenExpiry: expiry,
      );

      expect(provider.requiresRefresh, isTrue);
    });

    test('should not require refresh when token is not near expiry', () {
      final now = DateTime.now();
      final expiry = now.add(
        const Duration(minutes: 10),
      ); // More than 5 minute buffer

      final provider = BearerTokenAuthProvider(
        'test-token',
        tokenRefreshCallback: () async => 'new-token',
        tokenExpiry: expiry,
      );

      expect(provider.requiresRefresh, isFalse);
    });

    test('should use custom refresh buffer', () {
      final now = DateTime.now();
      final expiry = now.add(
        const Duration(minutes: 8),
      ); // Less than 10 minute buffer

      final provider = BearerTokenAuthProvider(
        'test-token',
        tokenRefreshCallback: () async => 'new-token',
        tokenExpiry: expiry,
        refreshBuffer: const Duration(minutes: 10),
      );

      expect(provider.requiresRefresh, isTrue);
    });

    test(
      'should automatically refresh token when getting headers if needed',
      () async {
        final now = DateTime.now();
        final expiry = now.add(const Duration(minutes: 3));

        final provider = BearerTokenAuthProvider(
          'initial-token',
          tokenRefreshCallback: () async => 'refreshed-token',
          tokenExpiry: expiry,
        );

        final headers = await provider.getAuthHeaders();

        expect(headers, equals({'Authorization': 'Bearer refreshed-token'}));
        expect(provider.currentToken, equals('refreshed-token'));
      },
    );

    test('should update token expiry', () {
      final provider = BearerTokenAuthProvider('test-token');
      final expiry = DateTime.now().add(const Duration(hours: 1));

      provider.setTokenExpiry(expiry);

      expect(provider.requiresRefresh, isFalse); // No refresh callback
    });

    test('should have meaningful toString', () {
      final provider1 = BearerTokenAuthProvider('test-token');
      final provider2 = BearerTokenAuthProvider(
        'test-token',
        tokenRefreshCallback: () async => 'new-token',
      );

      expect(
        provider1.toString(),
        equals('BearerTokenAuthProvider(supportsRefresh: false)'),
      );
      expect(
        provider2.toString(),
        equals('BearerTokenAuthProvider(supportsRefresh: true)'),
      );
    });
  });

  group('CustomAuthProvider', () {
    test('should create provider with header function only', () {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
      );

      expect(provider.providerType, equals('custom'));
      expect(provider.supportsRefresh, isFalse);
      expect(provider.requiresRefresh, isFalse);
    });

    test('should create provider with custom type', () {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
        providerType: 'oauth2',
      );

      expect(provider.providerType, equals('oauth2'));
    });

    test('should return headers from provider function', () async {
      final expectedHeaders = {'X-Custom': 'value', 'X-Another': 'header'};
      final provider = CustomAuthProvider(
        headerProvider: () async => expectedHeaders,
      );

      final headers = await provider.getAuthHeaders();

      expect(headers, equals(expectedHeaders));
    });

    test('should throw exception when header provider fails', () async {
      final provider = CustomAuthProvider(
        headerProvider: () async => throw Exception('Provider error'),
      );

      expect(
        () => provider.getAuthHeaders(),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Failed to get authentication headers'),
          ),
        ),
      );
    });

    test('should support refresh when callback provided', () {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
        refreshCallback: () async => true,
      );

      expect(provider.supportsRefresh, isTrue);
    });

    test('should refresh successfully', () async {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
        refreshCallback: () async => true,
      );

      final refreshed = await provider.refreshCredentials();

      expect(refreshed, isTrue);
    });

    test('should return false when refresh not supported', () async {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
      );

      final refreshed = await provider.refreshCredentials();

      expect(refreshed, isFalse);
    });

    test('should throw exception when refresh callback fails', () async {
      final provider = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
        refreshCallback: () async => throw Exception('Refresh error'),
      );

      expect(
        () => provider.refreshCredentials(),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Failed to refresh credentials'),
          ),
        ),
      );
    });

    test('should have meaningful toString', () {
      final provider1 = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
      );
      final provider2 = CustomAuthProvider(
        headerProvider: () async => {'X-Custom': 'value'},
        refreshCallback: () async => true,
        providerType: 'oauth2',
      );

      expect(
        provider1.toString(),
        equals('CustomAuthProvider(type: custom, supportsRefresh: false)'),
      );
      expect(
        provider2.toString(),
        equals('CustomAuthProvider(type: oauth2, supportsRefresh: true)'),
      );
    });
  });

  group('Integration Tests', () {
    test(
      'should handle multiple providers with different capabilities',
      () async {
        final apiKeyProvider = ApiKeyAuthProvider('api-key');
        final bearerProvider = BearerTokenAuthProvider(
          'bearer-token',
          tokenRefreshCallback: () async => 'new-bearer-token',
        );
        final customProvider = CustomAuthProvider(
          headerProvider: () async => {'X-Custom': 'custom-value'},
          refreshCallback: () async => true,
        );

        // Test API key provider
        expect(apiKeyProvider.supportsRefresh, isFalse);
        final apiHeaders = await apiKeyProvider.getAuthHeaders();
        expect(apiHeaders, equals({'X-API-Key': 'api-key'}));

        // Test bearer token provider
        expect(bearerProvider.supportsRefresh, isTrue);
        final bearerHeaders = await bearerProvider.getAuthHeaders();
        expect(bearerHeaders, equals({'Authorization': 'Bearer bearer-token'}));

        await bearerProvider.refreshCredentials();
        final refreshedHeaders = await bearerProvider.getAuthHeaders();
        expect(
          refreshedHeaders,
          equals({'Authorization': 'Bearer new-bearer-token'}),
        );

        // Test custom provider
        expect(customProvider.supportsRefresh, isTrue);
        final customHeaders = await customProvider.getAuthHeaders();
        expect(customHeaders, equals({'X-Custom': 'custom-value'}));

        final refreshed = await customProvider.refreshCredentials();
        expect(refreshed, isTrue);
      },
    );

    test('should handle secure credential scenarios', () async {
      // Test that credentials are not exposed in toString methods
      final apiProvider = ApiKeyAuthProvider('secret-api-key');
      final bearerProvider = BearerTokenAuthProvider('secret-bearer-token');

      expect(apiProvider.toString(), isNot(contains('secret-api-key')));
      expect(bearerProvider.toString(), isNot(contains('secret-bearer-token')));

      // Test that headers contain the actual credentials
      final apiHeaders = await apiProvider.getAuthHeaders();
      final bearerHeaders = await bearerProvider.getAuthHeaders();

      expect(apiHeaders['X-API-Key'], equals('secret-api-key'));
      expect(
        bearerHeaders['Authorization'],
        equals('Bearer secret-bearer-token'),
      );
    });
  });
}
