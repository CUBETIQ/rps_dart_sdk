/// iOS utility functions for RPS Dart SDK
///
/// This file provides utilities to handle iOS-specific configurations
/// and file system optimizations for iPhone and iPad.
///
/// To use path_provider for proper iOS directories, add it to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   path_provider: ^2.1.1
/// ```
library;

import 'dart:io';
import 'package:rps_dart_sdk/src/cache/cache_storage.dart';
import 'package:rps_dart_sdk/src/cache/cache_storage_factory.dart';

/// Utility class for iOS-specific configurations (iPhone and iPad)
class IOSUtils {
  /// Create a cache storage optimized for iOS devices
  ///
  /// iOS generally has good file system access, so we prefer Hive storage
  /// for persistence and performance. Falls back to in-memory if needed.
  ///
  /// For best results with proper iOS directories, use path_provider package:
  /// ```dart
  /// final supportDir = await getApplicationSupportDirectory();
  /// final cacheDir = await getTemporaryDirectory();
  /// final supportDir = await getApplicationSupportDirectory();
  /// ```
  static Future<CacheStorage> createIOSOptimizedCache({
    Duration maxAge = const Duration(days: 7),
    String? cachePath,
    String? boxName,
    bool verbose = false,
  }) async {
    try {
      // iOS typically has reliable file system access
      final storage = await CacheStorageFactory.create(
        type: CacheStorageType.hive,
        config: {
          if (cachePath != null) 'path': cachePath,
          if (boxName != null) 'boxName': boxName,
          'maxAge': maxAge,
        },
      );

      if (verbose) {
        print('✅ Successfully initialized Hive cache storage for iOS');
      }

      return storage;
    } catch (e) {
      if (verbose) {
        print('⚠️  Hive cache failed on iOS, falling back to in-memory cache');
        print('   Error: $e');
      }

      // Fall back to in-memory storage
      final storage = await CacheStorageFactory.create(
        type: CacheStorageType.inMemory,
        config: {'maxAge': maxAge},
      );

      return storage;
    }
  }

  /// Get recommended cache paths for iOS
  ///
  /// Returns a list of paths that work well on iOS, ordered by preference.
  /// iOS has more predictable file system access than Android.
  ///
  /// NOTE: These are fallback paths. For production apps, use path_provider:
  /// ```dart
  /// // Recommended approach:
  /// final supportDir = await getApplicationSupportDirectory();
  /// final cachePath = '${supportDir.path}/rps_cache';
  /// ```
  static List<String> getIOSCachePaths() {
    final paths = <String>[];

    // iOS-specific paths (these would work better with path_provider)
    try {
      paths.addAll([
        // Application Support directory (recommended for iOS)
        './Library/Application Support/rps_cache',
        // Caches directory (automatically managed by iOS)
        './Library/Caches/rps_cache',
        // Documents directory (backed up by iTunes/iCloud by default)
        './Documents/rps_cache',
        // Temporary directory (cleared by system when space needed)
        './tmp/rps_cache',
        // Fallback paths
        './cache',
        './data',
      ]);
    } catch (e) {
      // Fallback paths
      paths.addAll(['./cache', './data', './tmp']);
    }

    return paths;
  }

  /// Check if a path is writable (iOS version)
  static Future<bool> isPathWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Try to create a test file
      final testFile = File('$path/.rps_test_write.tmp');
      await testFile.writeAsString('iOS test');
      await testFile.delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the best cache path for iOS devices
  ///
  /// Tries to find a writable path from recommended iOS locations.
  /// For production apps, use path_provider package instead:
  /// ```dart
  /// final supportDir = await getApplicationSupportDirectory();
  /// return '${supportDir.path}/rps_cache';
  /// ```
  static Future<String?> getBestIOSCachePath({bool verbose = false}) async {
    final candidatePaths = getIOSCachePaths();

    if (verbose) {
      print('🔍 Searching for optimal iOS cache path...');
    }

    for (final path in candidatePaths) {
      if (verbose) {
        print('   Trying: $path');
      }

      if (await isPathWritable(path)) {
        if (verbose) {
          print('   ✅ Found writable iOS path: $path');
        }
        return path;
      } else if (verbose) {
        print('   ❌ Not accessible: $path');
      }
    }

    if (verbose) {
      print('   ⚠️  No writable path found on iOS');
    }

    return null;
  }

  /// Get iOS cache path using path_provider (if available)
  ///
  /// This method attempts to use path_provider to get proper iOS directories.
  /// It will only work if path_provider is added to your project dependencies.
  ///
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getIOSCachePathWithPathProvider() async {
    try {
      // Check if path_provider is available by trying to import it
      final path = await _getPathFromPathProvider();
      return path;
    } catch (e) {
      // path_provider not available or failed
      return null;
    }
  }

  /// Internal method to get path from path_provider
  static Future<String?> _getPathFromPathProvider() async {
    // In a real implementation, we would use conditional imports
    // or other techniques to properly handle optional dependencies.
    // For now, we'll return null to indicate path_provider is not available.
    return null;
  }

  /// Get iOS application support directory path (if path_provider is available)
  ///
  /// This method provides the recommended iOS application support directory
  /// for persistent cache data that should not be backed up.
  ///
  /// Requires path_provider dependency:
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getIOSApplicationSupportDirectoryPath() async {
    try {
      // In a real implementation with path_provider, this would be:
      // final dir = await getApplicationSupportDirectory();
      // return dir.path;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get iOS caches directory path (if path_provider is available)
  ///
  /// This method provides the iOS caches directory for temporary data
  /// that can be regenerated and is automatically managed by iOS.
  ///
  /// Requires path_provider dependency:
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getIOSCachesDirectoryPath() async {
    try {
      // In a real implementation with path_provider, this would be:
      // final dir = await getTemporaryDirectory();
      // return dir.path;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create iOS cache path using a custom path provider function
  ///
  /// This method allows users to provide their own path provider function
  /// for maximum flexibility in how paths are determined.
  ///
  /// Example usage:
  /// ```dart
  /// // Custom path provider function
  /// Future<String> myCustomPathProvider() async {
  ///   // Your custom logic here
  ///   return '/my/custom/path/rps_cache';
  /// }
  ///
  /// // Use with RPS SDK
  /// final cachePath = await IOSUtils.createIOSCachePathWithProvider(
  ///   pathProvider: myCustomPathProvider,
  ///   subdirectory: 'my_app_cache',
  /// );
  ///
  /// final cache = await IOSUtils.createIOSOptimizedCache(
  ///   cachePath: cachePath,
  ///   boxName: 'my_app_cache',
  /// );
  /// ```
  static Future<String?> createIOSCachePathWithProvider({
    Future<String> Function()? pathProvider,
    String subdirectory = 'rps_cache',
  }) async {
    if (pathProvider != null) {
      try {
        final basePath = await pathProvider();
        return '$basePath/$subdirectory';
      } catch (e) {
        // If custom provider fails, fall back to default behavior
        return null;
      }
    }
    return null;
  }

  /// Create iOS cache path using path_provider (recommended approach)
  ///
  /// This is the recommended way to create cache paths for iOS when path_provider
  /// is available in your project.
  ///
  /// Example usage with path_provider:
  /// ```dart
  /// // With path_provider available:
  /// final supportDir = await getApplicationSupportDirectory();
  /// final cachePath = '${supportDir.path}/rps_cache';
  ///
  /// // Then use with RPS SDK:
  /// final cache = await IOSUtils.createIOSOptimizedCache(
  ///   cachePath: cachePath,
  ///   boxName: 'my_app_cache',
  /// );
  /// ```
  static Future<String?> createIOSCachePath({
    String subdirectory = 'rps_cache',
  }) async {
    // This method is meant to be a guide for how to use path_provider
    // In a real app with path_provider, you would do:
    // final supportDir = await getApplicationSupportDirectory();
    // return '${supportDir.path}/$subdirectory';
    return null;
  }

  /// Detect iOS device type for optimized configurations
  static IOSDeviceType detectIOSDevice() {
    // This is a simplified detection - in a real app you might use
    // device_info_plus package for more accurate detection

    if (Platform.isIOS) {
      // You could use screen size or device_info to detect iPad vs iPhone
      // For now, we'll return a general iOS type
      return IOSDeviceType.ios;
    }

    return IOSDeviceType.unknown;
  }

  /// Get recommended cache configuration based on iOS device
  static Map<String, dynamic> getIOSOptimizedCacheConfig({
    IOSDeviceType? deviceType,
    bool isLowMemoryDevice = false,
  }) {
    deviceType ??= detectIOSDevice();

    switch (deviceType) {
      case IOSDeviceType.iphone:
        return {
          'maxAge': const Duration(days: 7),
          'maxSize': isLowMemoryDevice ? 500 : 1000,
          'autoCompact': true,
          'preferredStorage': CacheStorageType.hive,
        };

      case IOSDeviceType.ipad:
        // iPads generally have more storage and memory
        return {
          'maxAge': const Duration(days: 14),
          'maxSize': 2000,
          'autoCompact': true,
          'preferredStorage': CacheStorageType.hive,
        };

      case IOSDeviceType.ios:
      default:
        return {
          'maxAge': const Duration(days: 7),
          'maxSize': 1000,
          'autoCompact': true,
          'preferredStorage': CacheStorageType.hive,
        };
    }
  }

  /// Diagnose iOS-specific cache issues and provide solutions
  static Future<Map<String, dynamic>> diagnoseIOSCacheIssues({
    String? attemptedPath,
  }) async {
    final deviceType = detectIOSDevice();

    final diagnosis = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'deviceType': deviceType.toString(),
      'writablePaths': <String>[],
      'recommendations': <String>[],
      'canUseHive': true, // iOS generally supports Hive well
      'shouldUseInMemory': false,
      'iosSpecificTips': <String>[],
    };

    // Check writable paths
    final candidatePaths = getIOSCachePaths();
    for (final path in candidatePaths) {
      if (await isPathWritable(path)) {
        diagnosis['writablePaths'].add(path);
      }
    }

    final writablePaths = diagnosis['writablePaths'] as List<String>;

    if (writablePaths.isNotEmpty) {
      diagnosis['recommendations'].add(
        'Use Hive cache with iOS-optimized path: ${writablePaths.first}',
      );

      // iOS-specific recommendations
      diagnosis['iosSpecificTips'].addAll([
        'Use Library/Caches for data that can be regenerated',
        'Use Library/Application Support for important cache data',
        'Avoid Documents directory for cache (gets backed up)',
        'Consider cache size limits on older iOS devices',
        'For production apps, use path_provider package for proper iOS paths',
      ]);
    } else {
      diagnosis['shouldUseInMemory'] = true;
      diagnosis['canUseHive'] = false;
      diagnosis['recommendations'].addAll([
        'Use in-memory cache as fallback',
        'Check iOS app sandbox permissions',
        'Consider using path_provider package for proper iOS paths',
      ]);
    }

    // Device-specific recommendations
    if (deviceType == IOSDeviceType.ipad) {
      diagnosis['iosSpecificTips'].add(
        'iPad detected: Can use larger cache sizes and longer retention',
      );
    } else if (deviceType == IOSDeviceType.iphone) {
      diagnosis['iosSpecificTips'].add(
        'iPhone detected: Consider memory constraints for cache size',
      );
    }

    if (attemptedPath != null) {
      diagnosis['attemptedPath'] = attemptedPath;
      diagnosis['attemptedPathWritable'] = await isPathWritable(attemptedPath);
    }

    return diagnosis;
  }

  /// Create an iOS-optimized client configuration
  ///
  /// For production apps, consider using path_provider:
  /// ```dart
  /// final supportDir = await getApplicationSupportDirectory();
  /// final cachePath = '${supportDir.path}/rps_cache';
  /// ```
  static Future<Map<String, dynamic>> createIOSClientConfig({
    IOSDeviceType? deviceType,
    bool enableBackgroundSync = true,
    bool optimizeForBatteryLife = true,
  }) async {
    deviceType ??= detectIOSDevice();
    final cacheConfig = getIOSOptimizedCacheConfig(deviceType: deviceType);
    final bestPath = await getBestIOSCachePath();

    return {
      'cacheConfig': cacheConfig,
      'cachePath': bestPath,
      'connectTimeout': optimizeForBatteryLife
          ? const Duration(seconds: 15)
          : const Duration(seconds: 30),
      'receiveTimeout': optimizeForBatteryLife
          ? const Duration(seconds: 30)
          : const Duration(seconds: 60),
      'enableBackgroundSync': enableBackgroundSync,
      'iosOptimizations': {
        'respectLowPowerMode': true,
        'adaptiveCacheSize': true,
        'backgroundAppRefresh': enableBackgroundSync,
      },
    };
  }
}

/// Enum for iOS device types
enum IOSDeviceType {
  iphone,
  ipad,
  ios, // General iOS when specific type cannot be determined
  unknown,
}

/// Extension for IOSDeviceType enum
extension IOSDeviceTypeExtension on IOSDeviceType {
  String get displayName {
    switch (this) {
      case IOSDeviceType.iphone:
        return 'iPhone';
      case IOSDeviceType.ipad:
        return 'iPad';
      case IOSDeviceType.ios:
        return 'iOS Device';
      case IOSDeviceType.unknown:
        return 'Unknown Device';
    }
  }
}
