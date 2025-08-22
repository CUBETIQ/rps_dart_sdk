# RPS Dart SDK

A modern, production-ready Dart SDK for Remote Printing Service (RPS) with comprehensive offline support, intelligent retry mechanisms, and real-time monitoring.

[![Pub Version](https://img.shields.io/pub/v/rps_dart_sdk.svg)](https://pub.dev/packages/rps_dart_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

🚀 **Modern Architecture**

- Clean, modular design with dependency injection
- Event-driven architecture for real-time monitoring
- Comprehensive error handling and recovery

🔄 **Intelligent Retry Logic**

- Exponential backoff with jitter
- Configurable retry policies
- Circuit breaker pattern for fault tolerance

📱 **Offline Support**

- Local request caching
- Automatic queue synchronization when online
- Offline-first architecture options

🔐 **Authentication**

- Pluggable authentication providers
- Token management with automatic refresh
- Support for API keys, OAuth, and custom auth

⚡ **Performance**

- HTTP/2 connection pooling
- Request/response caching
- Optimistic updates

  **Developer Experience**

- Fluent API with builder pattern
- Comprehensive validation
- Detailed logging and debugging

## Getting Started

Add the RPS Dart SDK to your `pubspec.yaml`:

```yaml
dependencies:
  rps_dart_sdk:
    git:
      url: https://code.cubetiqs.com/cubetiq/rps_dart_sdk.git
      ref: main
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() async {
  // Create a basic client
  final client = RpsClientBuilder.basic(
    baseUrl: 'https://api.rps.example.com',
    apiKey: 'your-api-key',
  );

  try {
    // Send a simple message
    final response = await client.sendMessage({
      'type': 'print',
      'content': 'Hello, World!',
      'printer': 'office-printer-01'
    });

    print('Message sent successfully: ${response.messageId}');
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.dispose();
  }
}
```

### Enterprise Configuration

```dart
final client = RpsClientBuilder.enterprise(
  baseUrl: 'https://enterprise.rps.example.com',
  apiKey: 'enterprise-key',
)
  .withTimeout(Duration(seconds: 30))
  .withRetryPolicy(ExponentialBackoffRetryPolicy(
    maxAttempts: 5,
    baseDelay: Duration(seconds: 1),
  ))
  .withCaching(enabled: true, ttl: Duration(minutes: 15))
  .build();
```

### Offline-First Architecture

```dart
final client = RpsClientBuilder.offlineFirst(
  baseUrl: 'https://api.rps.example.com',
  apiKey: 'your-api-key',
);

// Requests are automatically queued when offline
// and synchronized when connection is restored
await client.sendMessage({
  'type': 'print',
  'content': 'This works offline!',
});
```

## Advanced Usage

### Custom Authentication

```dart
class CustomAuthProvider extends AuthenticationProvider {
  @override
  Future<Map<String, String>> getHeaders() async {
    // Implement your custom authentication logic
    return {
      'Authorization': 'Bearer ${await getToken()}',
      'X-Client-Version': '1.0.0',
    };
  }
}

final client = RpsClientBuilder()
  .baseUrl('https://api.rps.example.com')
  .authProvider(CustomAuthProvider())
  .build();
```

### Handling Different Response Types

```dart
// Send with custom request options
final response = await client.sendRequest(
  endpoint: '/api/v1/print',
  method: 'POST',
  data: {
    'document': 'base64-encoded-pdf',
    'printer': 'laser-printer-02',
    'copies': 3,
  },
  options: RpsRequestOptions(
    timeout: Duration(minutes: 5),
    retryPolicy: NoRetryPolicy(),
    priority: RequestPriority.high,
  ),
);

// Access detailed response information
print('Status: ${response.statusCode}');
print('Headers: ${response.headers}');
print('Data: ${response.data}');
```

## Migration Guide

### From Legacy RpsClient

The SDK maintains backward compatibility through `LegacyRpsClient`:

```dart
// Old way (still works with deprecation warnings)
import 'package:rps_dart_sdk/legacy.dart';

final legacyClient = LegacyRpsClient(
  baseUrl: 'https://api.rps.example.com',
  apiKey: 'your-api-key',
);

// New way (recommended)
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

final client = RpsClientBuilder.basic(
  baseUrl: 'https://api.rps.example.com',
  apiKey: 'your-api-key',
);
```

### Key Improvements

- **Better Error Handling**: Structured error types with recovery suggestions
- **Offline Support**: Automatic request queuing and synchronization
- **Flexible Configuration**: Builder pattern for easy customization
- **Enhanced Security**: Pluggable authentication with token refresh

## Configuration Options

### Cache Configuration

```dart
final client = RpsClientBuilder()
  .baseUrl('https://api.rps.example.com')
  .apiKey('your-api-key')
  .withCaching(
    enabled: true,
    ttl: Duration(minutes: 30),
    maxSize: 100, // Maximum cached items
  )
  .build();
```

### Retry Policies

```dart
// Exponential backoff (default)
final exponentialRetry = ExponentialBackoffRetryPolicy(
  maxAttempts: 3,
  baseDelay: Duration(seconds: 1),
  maxDelay: Duration(seconds: 30),
);

// Linear backoff
final linearRetry = LinearRetryPolicy(
  maxAttempts: 5,
  delay: Duration(seconds: 2),
);

// No retry
final noRetry = NoRetryPolicy();
```

### Logging Configuration

```dart
// Enable debug logging
final client = RpsClientBuilder.basic(
  baseUrl: 'https://api.rps.example.com',
  apiKey: 'your-api-key',
)
  .withLogging(LogLevel.debug)
  .build();
```

## Error Handling

The SDK provides structured error handling:

```dart
try {
  await client.sendMessage(messageData);
} on RpsNetworkError catch (e) {
  // Handle network-related errors
  print('Network error: ${e.message}');
  if (e.isRetriable) {
    // Error can be retried
  }
} on RpsValidationError catch (e) {
  // Handle validation errors
  print('Validation failed: ${e.violations}');
} on RpsAuthenticationError catch (e) {
  // Handle authentication errors
  print('Auth error: ${e.message}');
} on RpsError catch (e) {
  // Handle any other RPS errors
  print('RPS error: ${e.message}');
}
```

## Testing

The SDK includes comprehensive test utilities:

```dart
import 'package:rps_dart_sdk/testing.dart';

void main() {
  test('should send message successfully', () async {
    final mockClient = MockRpsClient();

    when(mockClient.sendMessage(any))
      .thenAnswer((_) async => RpsResponse(
        messageId: 'test-123',
        statusCode: 200,
      ));

    final response = await mockClient.sendMessage({'test': 'data'});
    expect(response.messageId, equals('test-123'));
  });
}
```

## Examples

Check out the comprehensive examples in the `/example` directory:

- `example/comprehensive_example.dart` - Complete feature demonstration
- `example/validation_example.dart` - Request validation examples

## Performance Considerations

- **Connection Pooling**: HTTP connections are automatically pooled and reused
- **Caching**: Responses are cached based on configured TTL
- **Offline Queue**: Requests are efficiently stored and synchronized
- **Memory Management**: Automatic cleanup of expired cache entries

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## Support

- **Documentation**: [API Reference](https://pub.dev/documentation/rps_dart_sdk)
- **Issues**: [GitHub Issues](https://github.com/yourusername/rps_dart_sdk/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/rps_dart_sdk/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and migration notes for each version.
