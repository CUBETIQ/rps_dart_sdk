# RPS Dart SDK

A modern, production-ready Dart SDK for Remote Printing Service (RPS) with comprehensive offline support, intelligent retry mechanisms, and high-performance cache storage using Hive CE.

[![Pub Version](https://img.shields.io/pub/v/rps_dart_sdk.svg)](https://pub.dev/packages/rps_dart_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

🚀 **Modern Architecture**

- Clean, modular design with dependency injection
- Event-driven architecture for real-time monitoring
- Comprehensive error handling and recovery

� **Multi-Storage Cache System**

- **In-Memory Cache**: Lightning-fast, perfect for development
- **Hive CE**: High-performance storage with isolate support for production

�🔄 **Intelligent Retry Logic**

- Exponential backoff with jitter
- Configurable retry policies
- Circuit breaker pattern for fault tolerance

📱 **Offline-First Support**

- Local request caching with multiple storage backends
- Automatic queue synchronization when online
- Configurable retry intervals for cached requests

🔐 **Authentication**

- Pluggable authentication providers
- Token management with automatic refresh
- Support for API keys, OAuth, and custom auth

⚡ **Performance**

- HTTP/2 connection pooling
- Request/response caching
- Optimistic updates
- Auto-selection of best storage backend

🛠️ **Developer Experience**

- Fluent API with builder pattern
- Factory methods for common use cases
- Comprehensive validation and detailed logging

## Getting Started

Add the RPS Dart SDK to your `pubspec.yaml`:

```yaml
dependencies:
  rps_dart_sdk:
    git:
      url: https://code.cubetiqs.com/cubetiq/rps_dart_sdk.git
      ref: main

  # Cache storage dependencies (add based on your needs)
  hive_ce: ^2.11.3 # For high-performance Hive CE cache
  hive_ce_flutter: ^2.3.1 # Flutter integration for Hive CE

dev_dependencies:
  # For Hive CE code generation (if using Hive CE)
  hive_ce_generator: ^1.9.3
  build_runner: ^2.4.7
```

Then run:

```bash
dart pub get
```

## Quick Start

### 🚀 Instant Setup (Recommended)

Choose the right factory method for your use case:

```dart
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

// 1. Simple client with in-memory cache (perfect for development/testing)
final client = await RpsClientBuilder.createSimple(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
);

// 2. Production client with persistent cache
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive, // or .hive
  cacheMaxAge: const Duration(hours: 24),
  logLevel: RpsLogLevel.warning,
);

// 3. High-performance client with Hive CE (best for heavy usage)
final client = await RpsClientBuilder.createHighPerformance(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  hiveBoxName: 'rps_cache', // optional custom box name
  cacheMaxAge: const Duration(days: 7),
);

// 4. Offline-first client (automatically handles network issues)
final client = await RpsClientBuilder.createOfflineFirst(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive, // persistent storage required
  cacheMaxAge: const Duration(days: 30),
);

// Send your data
final response = await client.sendMessage(
  type: 'print_job',
  data: {
    'document': 'Hello, World!',
    'printer': 'office-printer-01',
    'copies': 1,
  },
);

print('✅ Message sent: ${response.statusCode}');
await client.dispose(); // Clean up resources
```

### 🔧 Smart Auto-Selection

Let the SDK choose the best storage for you:

```dart
final client = await RpsClientBuilder.forWebhook(
  url: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  needsPersistence: true,     // true = Hive
  isHighFrequency: true,
  isLargeData: false,         // true = prefers Hive CE for capacity
  cacheMaxAge: const Duration(hours: 12),
);
```

## Cache Storage Guide

### 📊 Storage Comparison

| Storage Type  | Best For                | Persistence | Performance | Data Size |
| ------------- | ----------------------- | ----------- | ----------- | --------- |
| **In-Memory** | Development, Testing    | ❌ No       | ⚡ Fastest  | Small     |
| **Hive CE**   | Production, Heavy Usage | ✅ Yes      | 🔥 Fastest  | Large     |

### 💡 When to Use Each Storage

**Choose In-Memory when:**

- Developing and testing your app
- You don't need data to persist across app restarts
- You want the fastest possible performance

**Choose Hive CE when:**

- You need high-performance persistent storage
- Your app sends > 100 requests per day
- You handle large data or many cached requests
- You want the best performance for production apps

### 🔧 Custom Configuration

For advanced use cases, build your own configuration:

```dart
// Method 1: Using RpsConfigurationBuilder
final config = RpsConfigurationBuilder()
    .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
    .setApiKey('your-api-key')
    .useHiveCache(
      maxAge: const Duration(days: 30),
      boxName: 'my_custom_cache',
      autoCompact: true,
    )
    .setConnectTimeout(const Duration(seconds: 30))
    .setReceiveTimeout(const Duration(seconds: 60))
    .build();

// Create storage and cache manager
final storage = await CacheStorageFactory.create(
  type: CacheStorageType.hive,
  config: {'boxName': 'my_custom_cache', 'autoCompact': true},
);
final cacheManager = CacheManager(storage: storage, policy: config.cachePolicy);
await cacheManager.initialize();

// Build the client
final client = await RpsClientBuilder()
    .withConfiguration(config)
    .withCacheManager(cacheManager)
    .withLogger(SimpleLoggingManager(level: RpsLogLevel.debug))
    .build();

// Method 2: Using individual cache storage methods
final config2 = RpsConfigurationBuilder()
    .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
    .setApiKey('your-api-key')
    // Choose one:
    .useInMemoryCache(maxAge: const Duration(hours: 1))
    // .useHiveCache(maxAge: const Duration(days: 30), boxName: 'cache')
    // .autoSelectCacheStorage(needsPersistence: true, isHighFrequency: false)
    .build();
```

## Advanced Features

### 🔄 Retry Intervals for Cached Requests

Configure how often cached (failed) requests are retried:

```dart
final client = await RpsClientBuilder.createOfflineFirst(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive,
);

// Set custom retry interval (default is 5 minutes)
client.setCachedRequestProcessingInterval(const Duration(seconds: 30));

// Manually process cached requests
await client.processCachedRequests();
```

### 🔐 Authentication Support

```dart
// API Key authentication (built-in)
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://api.example.com/webhook',
  apiKey: 'your-api-key',
);

// Custom authentication
class CustomAuthProvider extends AuthenticationProvider {
  @override
  Future<Map<String, String>> getHeaders() async {
    return {
      'Authorization': 'Bearer ${await getToken()}',
      'X-Client-Version': '1.0.0',
    };
  }
}

final customClient = await RpsClientBuilder()
    .withConfiguration(
      RpsConfigurationBuilder()
          .setBaseUrl('https://api.example.com/webhook')
          .build()
    )
    .withAuthProvider(CustomAuthProvider())
    .build();
```

### 📊 Real-time Monitoring

Listen to client events for monitoring and debugging:

```dart
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
);

// Listen to events
client.events.listen((event) {
  switch (event.type) {
    case RpsEventType.requestStarted:
      print('📤 Request started: ${event.data}');
      break;
    case RpsEventType.requestCompleted:
      print('✅ Request completed: ${event.data}');
      break;
    case RpsEventType.requestFailed:
      print('❌ Request failed: ${event.data}');
      break;
    case RpsEventType.connectionStatusChanged:
      print('🌐 Connection: ${event.data}');
      break;
    case RpsEventType.cacheOperation:
      print('💾 Cache: ${event.data}');
      break;
  }
});
```

### 🛠️ Error Handling

The SDK provides structured error handling:

```dart
try {
  await client.sendMessage(
    type: 'print_job',
    data: {'document': 'Hello, World!'},
  );
} on RpsNetworkError catch (e) {
  print('🌐 Network error: ${e.message}');
  if (e.isRetriable) {
    print('Will retry automatically');
  }
} on RpsValidationError catch (e) {
  print('❌ Validation failed: ${e.violations}');
} on RpsAuthenticationError catch (e) {
  print('🔐 Auth error: ${e.message}');
} on RpsError catch (e) {
  print('⚠️ RPS error: ${e.message}');
} catch (e) {
  print('💥 Unexpected error: $e');
}
```

## Migration Guide

### 📦 From Legacy RpsClient

If you're upgrading from an older version:

```dart
// ❌ Old way (deprecated)
import 'package:rps_dart_sdk/legacy.dart';

final legacyClient = LegacyRpsClient(
  baseUrl: 'https://api.rps.example.com',
  apiKey: 'your-api-key',
);

// ✅ New way (recommended)
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

final client = await RpsClientBuilder.createSimple(
  webhookUrl: 'https://api.rps.example.com/webhook',
  apiKey: 'your-api-key',
);
```

### 🔄 Key Improvements

- **Multi-Storage Cache**: Choose between in-memory or Hive CE
- **Better Offline Support**: Intelligent request queuing and automatic retry
- **Simpler API**: Factory methods for common use cases
- **Enhanced Performance**: Hive CE for high-performance storage
- **Better Error Handling**: Structured error types with recovery suggestions
- **Flexible Configuration**: Builder pattern with auto-selection capabilities

## Configuration Reference

### 📋 All Available Factory Methods

```dart
// 🚀 Simple Development Setup
final client = await RpsClientBuilder.createSimple(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
);

// 🏭 Production Setup
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive,
  cacheMaxAge: const Duration(hours: 24),
  logLevel: RpsLogLevel.warning,
);

// ⚡ High-Performance Setup
final client = await RpsClientBuilder.createHighPerformance(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  hiveBoxName: 'rps_cache', // optional
  cacheMaxAge: const Duration(days: 7),
  logLevel: RpsLogLevel.info,
);

// 📱 Offline-First Setup
final client = await RpsClientBuilder.createOfflineFirst(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive,
  cacheMaxAge: const Duration(days: 30),
);

// 🤖 Auto-Selection Setup
final client = await RpsClientBuilder.forWebhook(
  url: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  needsPersistence: true,
  isHighFrequency: true,
  isLargeData: false,
  cacheMaxAge: const Duration(hours: 12),
  logLevel: RpsLogLevel.info,
);
```

### ⚙️ Cache Storage Configuration Methods

```dart
final config = RpsConfigurationBuilder()
    .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
    .setApiKey('your-api-key')

    // Choose one of these cache storage methods:

    // 1. In-Memory Cache (fastest, not persistent)
    .useInMemoryCache(maxAge: const Duration(hours: 1))



    // 2. Hive CE Cache (high-performance persistence)
    .useHiveCache(
      maxAge: const Duration(days: 30),
      boxName: 'my_rps_cache', // optional custom box name
      autoCompact: true, // optional auto-compaction
    )

    // 3. Auto-Select Best Storage
    .autoSelectCacheStorage(
      needsPersistence: true,    // true = Hive
      isHighFrequency: false,
      isLargeData: true,         // true = prefers Hive
      maxAge: const Duration(hours: 12),
    )

    // 4. Manual Storage Type Selection
    .setCacheStorageType(
      type: CacheStorageType.hive,
      maxAge: const Duration(days: 7),
      config: {
        'boxName': 'custom_box',
        'autoCompact': true,
      },
    )

    .build();
```

### 🎯 Storage Selection Logic

The `autoSelectCacheStorage` method chooses storage based on your requirements:

| Persistence | High Frequency | Large Data | Selected Storage |
| ----------- | -------------- | ---------- | ---------------- |
| ❌ No       | Any            | Any        | **In-Memory**    |
| ✅ Yes      | ❌ No          | ✅ Yes     | **Hive CE**      |

### 🔧 Advanced Configuration Options

```dart
final config = RpsConfigurationBuilder()
    .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
    .setApiKey('your-api-key')
    .useHiveCache(maxAge: const Duration(days: 30))

    // Network timeouts
    .setConnectTimeout(const Duration(seconds: 30))
    .setReceiveTimeout(const Duration(seconds: 60))
    .setSendTimeout(const Duration(seconds: 30))

    // Retry configuration
    .setRetryPolicy(ExponentialBackoffRetryPolicy(
      maxAttempts: 3,
      baseDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 30),
    ))

    // Custom headers
    .addHeader('X-Client-Version', '1.0.0')
    .addHeader('X-Platform', 'Flutter')

    .build();
```

### 📊 Monitoring and Logging

```dart
// Enable different log levels
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  logLevel: RpsLogLevel.debug, // none, error, warning, info, debug
);

// Listen to all client events
client.events.listen((event) {
  print('📋 Event: ${event.type} - ${event.data}');
});

// Listen to specific event types
client.events.where((event) => event.type == RpsEventType.requestFailed)
    .listen((event) {
  print('❌ Request failed: ${event.data}');
});
```

## Examples & Tutorials

### 🎯 Complete Example

```dart
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

Future<void> main() async {
  // Create a production-ready client
  final client = await RpsClientBuilder.createProduction(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: 'your-api-key-here',
    storageType: CacheStorageType.hive,
    cacheMaxAge: const Duration(hours: 24),
    logLevel: RpsLogLevel.info,
  );

  try {
    // Send a print job
    final response = await client.sendMessage(
      type: 'print_job',
      data: {
        'document': 'Hello from RPS SDK!',
        'printer_id': 'office-printer-01',
        'copies': 2,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    print('✅ Print job sent successfully!');
    print('📋 Response: ${response.statusCode}');

  } catch (e) {
    print('❌ Error sending print job: $e');
  } finally {
    // Always clean up resources
    await client.dispose();
  }
}
```

### 📂 More Examples

Check out comprehensive examples in the `/example` directory:

- **`example/enhanced_cache_usage.dart`** - Multi-storage cache examples
- **`example/comprehensive_example.dart`** - Complete feature demonstration
- **`example/validation_example.dart`** - Request validation examples

### 🧪 Testing Your Implementation

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() {
  group('RPS Client Tests', () {
    late RpsClient client;

    setUp(() async {
      // Use in-memory cache for testing
      client = await RpsClientBuilder.createSimple(
        webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
        apiKey: 'test-api-key',
      );
    });

    tearDown(() async {
      await client.dispose();
    });

    test('should send message successfully', () async {
      final response = await client.sendMessage(
        type: 'test_message',
        data: {'test': 'data'},
      );

      expect(response.statusCode, equals(200));
    });
  });
}
```

## ⚡ Performance Tips

### 🎯 Choose the Right Storage

```dart
// ✅ Good for development/testing
final devClient = await RpsClientBuilder.createSimple(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
);

// ✅ Good for simple production apps
final simpleClient = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  storageType: CacheStorageType.hive,
);

// ✅ Best for high-volume production apps
final highPerfClient = await RpsClientBuilder.createHighPerformance(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
);
```

### 🔧 Optimization Settings

```dart
final config = RpsConfigurationBuilder()
    .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
    .setApiKey('your-api-key')
    .useHiveCache(
      maxAge: const Duration(days: 7),
      autoCompact: true, // Keeps storage optimized
    )
    .setConnectTimeout(const Duration(seconds: 10)) // Faster timeout
    .build();
```

### 📊 Memory Management

```dart
// Always dispose clients when done
await client.dispose();

// Monitor cache size in development
client.events.where((e) => e.type == RpsEventType.cacheOperation)
    .listen((event) {
  print('💾 Cache operation: ${event.data}');
});
```

## 🔧 Troubleshooting

### Common Issues

**❌ Problem**: "Package not found" error

```bash
# ✅ Solution: Make sure you're using the correct git URL
dependencies:
  rps_dart_sdk:
    git:
      url: https://code.cubetiqs.com/cubetiq/rps_dart_sdk.git
      ref: main
```

**❌ Problem**: Hive CE storage errors

```dart
// ✅ Solution: Make sure you have the required dependencies
dependencies:
  hive_ce: ^2.11.3
  hive_ce_flutter: ^2.3.1

dev_dependencies:
  hive_ce_generator: ^1.9.3
  build_runner: ^2.4.7
```

**❌ Problem**: Network timeouts

```dart
// ✅ Solution: Increase timeout values
final client = await RpsClientBuilder.createProduction(
  webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
  apiKey: 'your-api-key',
  // Custom configuration with longer timeouts
);
```

**❌ Problem**: High memory usage

```dart
// ✅ Solution: Use appropriate cache settings
final config = RpsConfigurationBuilder()
    .useInMemoryCache(maxAge: const Duration(minutes: 5)) // Shorter TTL
    .build();
```

### 📞 Getting Help

- **📚 Examples**: Check `/example` directory for sample code
- **🐛 Issues**: [GitHub Issues](https://github.com/yourusername/rps_dart_sdk/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/yourusername/rps_dart_sdk/discussions)
- **📖 API Docs**: [pub.dev documentation](https://pub.dev/documentation/rps_dart_sdk)

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add** tests for your changes
4. **Ensure** all tests pass (`dart test`)
5. **Commit** your changes (`git commit -m 'Add amazing feature'`)
6. **Push** to the branch (`git push origin feature/amazing-feature`)
7. **Open** a Pull Request

### Development Setup

```bash
# Clone the repository
git clone https://code.cubetiqs.com/cubetiq/rps_dart_sdk.git
cd rps_dart_sdk

# Install dependencies
dart pub get

# Run tests
dart test

# Run tests with coverage
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and migration notes for each version.

### Recent Updates

- ✅ **v2.0.0**: Integrated multi-storage cache system with Hive CE support
- ✅ **Enhanced Builder**: Simplified factory methods for common use cases
- ✅ **Auto-Selection**: Smart cache storage selection based on requirements
- ✅ **Performance**: Significant improvements with Hive CE storage backend
- ✅ **Developer Experience**: Comprehensive documentation and examples

---

## 🚀 Quick Reference

### Factory Methods

```dart
// Development
RpsClientBuilder.createSimple(webhookUrl, apiKey)

// Production
RpsClientBuilder.createProduction(webhookUrl, apiKey, storageType, cacheMaxAge)

// High Performance
RpsClientBuilder.createHighPerformance(webhookUrl, apiKey, hiveBoxName)

// Offline First
RpsClientBuilder.createOfflineFirst(webhookUrl, apiKey, storageType)

// Auto Selection
RpsClientBuilder.forWebhook(url, apiKey, needsPersistence, isHighFrequency, isLargeData)
```

### Storage Types

- `CacheStorageType.inMemory` - Fastest, not persistent
- `CacheStorageType.hive` - High-performance persistence

### Configuration Methods

- `.useInMemoryCache(maxAge)` - In-memory cache
- `.useHiveCache(maxAge, boxName, autoCompact)` - Hive CE cache
- `.autoSelectCacheStorage(needsPersistence, isHighFrequency, isLargeData)` - Auto-select

Happy coding! 🎉
