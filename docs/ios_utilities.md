# iOS Utilities for RPS Dart SDK

This document explains the iOS-specific utilities provided by the RPS Dart SDK to help optimize performance and compatibility on iPhone and iPad devices.

## Overview

The RPS Dart SDK includes iOS-specific utilities in the `IOSUtils` class to help developers:

- Optimize cache storage for iOS file system characteristics
- Handle iOS-specific file system paths and permissions
- Detect iOS device types (iPhone vs iPad)
- Get device-optimized configurations
- Diagnose and resolve cache-related issues

## Key Features

### 1. iOS-Optimized Cache Storage

iOS generally has more reliable file system access than Android, so the SDK provides optimized cache storage:

```dart
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

// Create iOS-optimized cache storage
final cache = await IOSUtils.createIOSOptimizedCache(
  cachePath: './Library/Caches/my_app_cache',
  boxName: 'my_app_box',
  maxAge: Duration(days: 7),
  verbose: true, // Enable logging
);
```

### 2. iOS-Specific Cache Paths

iOS has specific directories that work best for different types of data:

```dart
// Get recommended iOS cache paths
final paths = IOSUtils.getIOSCachePaths();
// Returns: [
//   './Library/Application Support/rps_cache',
//   './Library/Caches/rps_cache',
//   './Documents/rps_cache',
//   './tmp/rps_cache',
//   './cache',
//   './data'
// ]

// Find the best writable path for your app
final bestPath = await IOSUtils.getBestIOSCachePath(verbose: true);
```

### 3. Device Type Detection

Detect whether your app is running on iPhone or iPad to optimize accordingly:

```dart
// Detect iOS device type
final deviceType = IOSUtils.detectIOSDevice();

switch (deviceType) {
  case IOSDeviceType.iphone:
    // Optimize for iPhone constraints
    print('Running on iPhone');
    break;
  case IOSDeviceType.ipad:
    // Take advantage of iPad capabilities
    print('Running on iPad');
    break;
  default:
    print('Running on unknown iOS device');
}
```

### 4. Device-Optimized Configurations

Get cache configurations optimized for specific iOS devices:

```dart
// Get optimized cache configuration
final config = IOSUtils.getIOSOptimizedCacheConfig(
  deviceType: IOSDeviceType.ipad, // or IOSDeviceType.iphone
  isLowMemoryDevice: false,
);

print('Max cache age: ${config['maxAge']}');
print('Max cache size: ${config['maxSize']}');
print('Preferred storage: ${config['preferredStorage']}');
```

### 5. iOS-Specific Diagnostics

Diagnose cache issues and get iOS-specific recommendations:

```dart
// Diagnose cache issues
final diagnosis = await IOSUtils.diagnoseIOSCacheIssues(
  attemptedPath: './my/custom/path',
);

print('Platform: ${diagnosis['platform']}');
print('Device type: ${diagnosis['deviceType']}');
print('Writable paths: ${diagnosis['writablePaths']}');
print('Recommendations: ${diagnosis['recommendations']}');
print('iOS-specific tips: ${diagnosis['iosSpecificTips']}');
```

## Using Proper Application Directories with path_provider

The RPS Dart SDK works best when you use proper application directories provided by the `path_provider` package. This ensures your app follows iOS best practices and works reliably across different iOS versions.

### 1. Add path_provider to your pubspec.yaml

```yaml
dependencies:
  rps_dart_sdk:
    git:
      url: https://code.cubetiqs.com/cubetiq/rps_dart_sdk.git
      ref: main
  path_provider: ^2.1.1
```

### 2. Use path_provider to get proper iOS directories

```dart
import 'package:path_provider/path_provider.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

// Get proper iOS directories
Future<String> getRpsCachePath() async {
  try {
    // For persistent cache data that should not be backed up
    final supportDir = await getApplicationSupportDirectory();
    return '${supportDir.path}/rps_cache';
  } catch (e) {
    // Fallback if path_provider is not available
    final fallbackPath = await IOSUtils.getBestIOSCachePath();
    return fallbackPath ?? './cache/rps_cache';
  }
}

// Create iOS-optimized cache with proper path
Future<CacheStorage> createOptimizedCache() async {
  final cachePath = await getRpsCachePath();

  return await IOSUtils.createIOSOptimizedCache(
    cachePath: cachePath,
    boxName: 'rps_ios_cache',
  );
}
```

### 3. iOS Directory Recommendations

- **Application Support Directory**: Best for persistent cache data that should not be backed up (recommended)
- **Caches Directory**: Good for temporary cache data that can be regenerated
- **Documents Directory**: Only for user-visible documents (gets backed up by default)

## Using Custom Path Providers

The RPS SDK also allows you to provide your own custom path provider functions for maximum flexibility:

```dart
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

// Custom path provider function
Future<String> myCustomPathProvider() async {
  // Your custom logic here
  // For example, you might read from environment variables,
  // configuration files, or use your own directory logic
  return '/my/custom/path';
}

// Use with RPS SDK
Future<CacheStorage> createCacheWithCustomProvider() async {
  final cachePath = await IOSUtils.createIOSCachePathWithProvider(
    pathProvider: myCustomPathProvider,
    subdirectory: 'my_app_cache',
  );

  return await IOSUtils.createIOSOptimizedCache(
    cachePath: cachePath ?? await IOSUtils.getBestIOSCachePath(),
    boxName: 'my_app_cache',
  );
}
```

## Specifying Custom Paths for Hive Cache Storage

You can also specify custom paths directly when configuring Hive cache storage:

```dart
// Using RpsConfigurationBuilder with custom path
final config = RpsConfigurationBuilder()
    .setBaseUrl('https://api.example.com/webhook')
    .setApiKey('your-api-key')
    .useHiveCacheWithPath(
      path: '/path/to/your/cache/directory',  // Custom path for Hive storage
      maxAge: const Duration(days: 30),
      boxName: 'my_ios_cache_box',
      autoCompact: true,
    )
    .build();

// Or directly using CacheStorageFactory
final storage = await CacheStorageFactory.create(
  type: CacheStorageType.hive,
  config: {
    'path': '/path/to/your/cache/directory',  // Custom path
    'boxName': 'my_ios_cache_box',
    'maxAge': const Duration(days: 30),
  },
);
```

## iOS-Specific Recommendations

### Cache Directory Best Practices

1. **Use Library/Application Support** for important cache data that should persist (recommended)
2. **Use Library/Caches** for data that can be regenerated
3. **Avoid Documents directory** for cache data (gets backed up by default)
4. **Use tmp directory** for very temporary data

### Device-Specific Optimizations

- **iPhone**: Consider memory constraints when setting cache size limits
- **iPad**: Can typically use larger cache sizes and longer retention periods
- **All iOS devices**: Respect Low Power Mode settings in your app

### Background Processing

iOS has specific background processing capabilities:

```dart
// Create iOS-optimized client configuration
final iosConfig = await IOSUtils.createIOSClientConfig(
  deviceType: IOSDeviceType.ipad,
  enableBackgroundSync: true,
  optimizeForBatteryLife: true,
);

print('iOS optimizations: ${iosConfig['iosOptimizations']}');
```

## Integration with RPS Client

You can use iOS utilities when creating RPS clients:

```dart
// Create an iOS-optimized RPS client
Future<RpsClient> createIOSOptimizedClient({
  required String webhookUrl,
  required String apiKey,
}) async {
  // Get proper iOS directory (requires path_provider)
  String? cachePath;
  try {
    final supportDir = await getApplicationSupportDirectory();
    cachePath = '${supportDir.path}/rps_cache';
  } catch (e) {
    // Fallback to auto-detection
    cachePath = await IOSUtils.getBestIOSCachePath();
  }

  // Create configuration with iOS optimizations
  final config = RpsConfigurationBuilder()
      .setBaseUrl(webhookUrl)
      .setApiKey(apiKey)
      .useHiveCache(
        maxAge: const Duration(days: 7),
        boxName: 'rps_ios_cache',
      )
      .build();

  // Create cache storage with iOS-optimized path
  final storage = await IOSUtils.createIOSOptimizedCache(
    cachePath: cachePath,
    boxName: 'rps_ios_cache',
  );

  // Create cache manager
  final cacheManager = CacheManager(
    storage: storage,
    policy: config.cachePolicy,
  );
  await cacheManager.initialize();

  return RpsClientBuilder()
      .withConfiguration(config)
      .withCacheManager(cacheManager)
      .build();
}
```

## Troubleshooting

### Common iOS Issues

1. **Permission Issues**: iOS has strict sandboxing. Use recommended paths.
2. **Backup Concerns**: Cache data in Documents directory gets backed up.
3. **Memory Constraints**: Older devices may need smaller cache sizes.
4. **Background App Refresh**: Consider iOS background processing limits.

### Diagnostic Tool

Use the built-in diagnostic tool to troubleshoot issues:

```dart
// Run diagnostics
final diagnosis = await IOSUtils.diagnoseIOSCacheIssues();

// Check if Hive is supported
if (diagnosis['canUseHive']) {
  print('✅ Hive cache is supported on this iOS device');
} else {
  print('⚠️  Falling back to in-memory cache');
}

// Follow iOS-specific recommendations
for (final tip in diagnosis['iosSpecificTips']) {
  print('💡 iOS Tip: $tip');
}
```

## Best Practices

1. **Always use iOS-recommended paths** for cache storage
2. **Detect device type** to optimize cache size and behavior
3. **Handle fallbacks gracefully** when file system access fails
4. **Respect iOS system settings** like Low Power Mode
5. **Test on both iPhone and iPad** if your app supports both
6. **Use verbose logging during development** to understand cache behavior
7. **Use path_provider package** for proper application directories (recommended)
8. **Provide custom path providers** when you need specific directory logic

## API Reference

### IOSUtils Class

Main utility class for iOS-specific functionality.

#### Methods

- `createIOSOptimizedCache()` - Create cache storage optimized for iOS
- `getIOSCachePaths()` - Get recommended iOS cache paths
- `isPathWritable()` - Check if a path is writable on iOS
- `getBestIOSCachePath()` - Find the best cache path for iOS
- `detectIOSDevice()` - Detect iOS device type
- `getIOSOptimizedCacheConfig()` - Get device-optimized cache configuration
- `diagnoseIOSCacheIssues()` - Diagnose iOS-specific cache issues
- `createIOSClientConfig()` - Create iOS-optimized client configuration
- `getIOSCachePathWithPathProvider()` - Get iOS cache path using path_provider (returns null if not available)
- `getIOSApplicationSupportDirectoryPath()` - Get iOS application support directory path
- `getIOSCachesDirectoryPath()` - Get iOS caches directory path
- `createIOSCachePathWithProvider()` - Create iOS cache path with custom provider function
- `createIOSCachePath()` - Helper method to create iOS cache path

### IOSDeviceType Enum

Enumeration of iOS device types:

- `iphone` - iPhone devices
- `ipad` - iPad devices
- `ios` - Generic iOS when specific type cannot be determined
- `unknown` - Unknown device type

## Conclusion

The iOS utilities in the RPS Dart SDK provide comprehensive tools to optimize your app's performance and compatibility on iPhone and iPad devices. By using these utilities and following iOS best practices with proper application directories from path_provider or custom path providers, you can ensure your app follows iOS best practices while taking advantage of device-specific capabilities.
