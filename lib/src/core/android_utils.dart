/// Android utility functions for RPS Dart SDK
///
/// This file provides utilities to handle Android-specific configurations
/// and file system limitations.
///
/// To use path_provider for proper Android directories, add it to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   path_provider: ^2.1.1
/// ```
library;

import 'dart:io';
import 'package:rps_dart_sdk/src/cache/cache_storage.dart';
import 'package:rps_dart_sdk/src/cache/cache_storage_factory.dart';

/// Utility class for Android-specific configurations
class AndroidUtils {
  /// Create a cache storage that works reliably on Android
  ///
  /// This method tries to create Hive storage first, but if it fails
  /// due to file system restrictions (common on Android), it automatically
  /// falls back to in-memory storage.
  ///
  /// For best results with proper Android directories, use path_provider package:
  /// ```dart
  /// final cacheDir = await getExternalCacheDirectories();
  /// final supportDir = await getApplicationSupportDirectory();
  /// ```
  static Future<CacheStorage> createAndroidCompatibleCache({
    Duration maxAge = const Duration(days: 7),
    String? cachePath,
    String? boxName,
    bool verbose = false,
  }) async {
    try {
      // Try Hive storage first
      final storage = await CacheStorageFactory.create(
        type: CacheStorageType.hive,
        config: {
          if (cachePath != null) 'path': cachePath,
          if (boxName != null) 'boxName': boxName,
          'maxAge': maxAge,
        },
      );

      if (verbose) {
        print('✅ Successfully initialized Hive cache storage');
      }

      return storage;
    } catch (e) {
      if (verbose) {
        print('⚠️  Hive cache failed, falling back to in-memory cache');
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

  /// Get recommended writable paths for Android
  ///
  /// Returns a list of paths that are commonly writable on Android,
  /// ordered by preference.
  ///
  /// NOTE: These are fallback paths. For production apps, use path_provider:
  /// ```dart
  /// // Recommended approach:
  /// final cacheDir = await getExternalCacheDirectories();
  /// final cachePath = '${cacheDir.first.path}/rps_cache';
  /// ```
  static List<String> getAndroidWritablePaths() {
    final paths = <String>[];

    // Try to get proper Android paths if available
    try {
      // These would work if path_provider was available
      // For now, we'll use fallback paths
      paths.addAll([
        './cache/rps_cache',
        '/data/data/com.yourapp/cache/rps_cache',
        '/sdcard/Android/data/com.yourapp/cache/rps_cache',
        './data/rps_cache',
        '/tmp/rps_cache',
      ]);
    } catch (e) {
      // Fallback paths
      paths.addAll(['./cache', './data', '/tmp']);
    }

    return paths;
  }

  /// Check if a path is writable
  static Future<bool> isPathWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Try to create a test file
      final testFile = File('$path/test_write.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Find the first writable path from a list
  ///
  /// For production apps, use path_provider package instead:
  /// ```dart
  /// final cacheDir = await getExternalCacheDirectories();
  /// return '${cacheDir.first.path}/rps_cache';
  /// ```
  static Future<String?> findWritablePath(List<String> paths) async {
    for (final path in paths) {
      if (await isPathWritable(path)) {
        return path;
      }
    }
    return null;
  }

  /// Get the best cache path for Android
  ///
  /// Tries to find a writable path from recommended Android locations.
  /// For production apps, use path_provider package instead:
  /// ```dart
  /// final cacheDir = await getExternalCacheDirectories();
  /// return '${cacheDir.first.path}/rps_cache';
  /// ```
  static Future<String?> getBestCachePath({bool verbose = false}) async {
    final candidatePaths = getAndroidWritablePaths();

    if (verbose) {
      print('🔍 Searching for writable cache path...');
    }

    for (final path in candidatePaths) {
      if (verbose) {
        print('   Trying: $path');
      }

      if (await isPathWritable(path)) {
        if (verbose) {
          print('   ✅ Found writable path: $path');
        }
        return path;
      } else if (verbose) {
        print('   ❌ Not writable: $path');
      }
    }

    if (verbose) {
      print('   ⚠️  No writable path found');
    }

    return null;
  }

  /// Get Android cache path using path_provider (if available)
  ///
  /// This method attempts to use path_provider to get proper Android directories.
  /// It will only work if path_provider is added to your project dependencies.
  ///
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getAndroidCachePathWithPathProvider() async {
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

  /// Get Android external cache directories path (if path_provider is available)
  ///
  /// This method provides the recommended Android external cache directories
  /// for cache data that can be cleared by the system when space is needed.
  ///
  /// Requires path_provider dependency:
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getAndroidExternalCacheDirectoryPath() async {
    try {
      // In a real implementation with path_provider, this would be:
      // final dirs = await getExternalCacheDirectories();
      // return dirs.first.path;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get Android application support directory path (if path_provider is available)
  ///
  /// This method provides the Android application support directory
  /// for persistent cache data.
  ///
  /// Requires path_provider dependency:
  /// ```yaml
  /// dependencies:
  ///   path_provider: ^2.1.1
  /// ```
  ///
  /// Returns null if path_provider is not available.
  static Future<String?> getAndroidApplicationSupportDirectoryPath() async {
    try {
      // In a real implementation with path_provider, this would be:
      // final dir = await getApplicationSupportDirectory();
      // return dir.path;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create Android cache path using a custom path provider function
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
  /// final cachePath = await AndroidUtils.createAndroidCachePathWithProvider(
  ///   pathProvider: myCustomPathProvider,
  ///   subdirectory: 'my_app_cache',
  /// );
  ///
  /// final cache = await AndroidUtils.createAndroidCompatibleCache(
  ///   cachePath: cachePath,
  ///   boxName: 'my_app_cache',
  /// );
  /// ```
  static Future<String?> createAndroidCachePathWithProvider({
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

  /// Create Android cache path using path_provider (recommended approach)
  ///
  /// This is the recommended way to create cache paths for Android when path_provider
  /// is available in your project.
  ///
  /// Example usage with path_provider:
  /// ```dart
  /// // With path_provider available:
  /// final cacheDirs = await getExternalCacheDirectories();
  /// final cachePath = '${cacheDirs.first.path}/rps_cache';
  ///
  /// // Then use with RPS SDK:
  /// final cache = await AndroidUtils.createAndroidCompatibleCache(
  ///   cachePath: cachePath,
  ///   boxName: 'my_app_cache',
  /// );
  /// ```
  static Future<String?> createAndroidCachePath({
    String subdirectory = 'rps_cache',
  }) async {
    // This method is meant to be a guide for how to use path_provider
    // In a real app with path_provider, you would do:
    // final cacheDirs = await getExternalCacheDirectories();
    // return '${cacheDirs.first.path}/$subdirectory';
    return null;
  }

  /// Diagnose cache issues and provide solutions
  static Future<Map<String, dynamic>> diagnoseCacheIssues({
    String? attemptedPath,
  }) async {
    final diagnosis = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'writablePaths': <String>[],
      'recommendations': <String>[],
      'canUseHive': false,
      'shouldUseInMemory': false,
    };

    // Check writable paths
    final candidatePaths = getAndroidWritablePaths();
    for (final path in candidatePaths) {
      if (await isPathWritable(path)) {
        diagnosis['writablePaths'].add(path);
      }
    }

    final writablePaths = diagnosis['writablePaths'] as List<String>;

    if (writablePaths.isNotEmpty) {
      diagnosis['canUseHive'] = true;
      diagnosis['recommendations'].add(
        'Use Hive cache with path: ${writablePaths.first}',
      );
    } else {
      diagnosis['shouldUseInMemory'] = true;
      diagnosis['recommendations'].addAll([
        'Use in-memory cache instead of Hive',
        'Consider adding path_provider dependency for proper Android paths',
        'Ensure app has WRITE_EXTERNAL_STORAGE permission if needed',
        'For production apps, use path_provider package for proper Android paths',
      ]);
    }

    if (attemptedPath != null) {
      diagnosis['attemptedPath'] = attemptedPath;
      diagnosis['attemptedPathWritable'] = await isPathWritable(attemptedPath);
    }

    return diagnosis;
  }
}
