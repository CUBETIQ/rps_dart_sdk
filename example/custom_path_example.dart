/// Example showing how to use custom paths with Hive cache storage in RPS SDK
///
/// This example demonstrates various ways to specify custom paths for Hive
/// cache storage, which is especially useful for Android apps with file
/// system restrictions.

import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() async {
  // Example 1: Using RpsConfigurationBuilder with custom path
  print('=== Example 1: RpsConfigurationBuilder with custom path ===');
  final config1 = RpsConfigurationBuilder()
      .setBaseUrl('https://api.example.com/webhook')
      .setApiKey('your-api-key')
      .useHiveCacheWithPath(
        path: './custom_cache_directory', // Custom path for Hive storage
        maxAge: const Duration(days: 30),
        boxName: 'my_custom_cache_box',
        autoCompact: true,
      )
      .build();

  print('Configuration created with custom path: ${config1.cachePolicy}');

  // Example 2: Directly using CacheStorageFactory with custom path
  print('\n=== Example 2: CacheStorageFactory with custom path ===');
  try {
    final storage = await CacheStorageFactory.create(
      type: CacheStorageType.hive,
      config: {
        'path': './custom_cache_directory', // Custom path
        'boxName': 'my_direct_cache_box',
        'maxAge': const Duration(days: 30),
      },
    );

    print('Hive storage created with custom path');
    await storage.dispose();
  } catch (e) {
    print('Error creating storage with custom path: $e');
  }

  // Example 3: Using AndroidUtils with custom path
  print('\n=== Example 3: AndroidUtils with custom path ===');
  try {
    final androidCache = await AndroidUtils.createAndroidCompatibleCache(
      cachePath: './android_custom_cache',
      boxName: 'android_custom_box',
      maxAge: const Duration(days: 7),
      verbose: true,
    );

    print('Android-compatible cache created with custom path');
    await androidCache.dispose();
  } catch (e) {
    print('Error creating Android cache with custom path: $e');
  }

  // Example 4: Using IOSUtils with custom path
  print('\n=== Example 4: IOSUtils with custom path ===');
  try {
    final iosCache = await IOSUtils.createIOSOptimizedCache(
      cachePath: './ios_custom_cache',
      boxName: 'ios_custom_box',
      maxAge: const Duration(days: 7),
      verbose: true,
    );

    print('iOS-optimized cache created with custom path');
    await iosCache.dispose();
  } catch (e) {
    print('Error creating iOS cache with custom path: $e');
  }

  // Example 5: Using createOfflineFirst with custom path
  print('\n=== Example 5: createOfflineFirst with custom path ===');
  try {
    final offlineClient = await RpsClientBuilder.createOfflineFirst(
      webhookUrl: 'https://api.example.com/webhook',
      apiKey: 'your-api-key',
      cachePath: './offline_custom_cache', // Custom path for offline cache
      cacheMaxAge: const Duration(days: 30),
    );

    print('Offline-first client created with custom cache path');
    await offlineClient.dispose();
  } catch (e) {
    print('Error creating offline-first client with custom path: $e');
  }

  // Example 6: Using custom path provider functions
  print('\n=== Example 6: Custom path provider functions ===');

  // Custom path provider function
  Future<String> myCustomPathProvider() async {
    // Your custom logic here
    // For example, you might read from environment variables,
    // configuration files, or use your own directory logic
    return './my/custom/app/path';
  }

  try {
    // Use with AndroidUtils
    final androidPath = await AndroidUtils.createAndroidCachePathWithProvider(
      pathProvider: myCustomPathProvider,
      subdirectory: 'my_android_cache',
    );

    final androidCache2 = await AndroidUtils.createAndroidCompatibleCache(
      cachePath: androidPath ?? await AndroidUtils.getBestCachePath(),
      boxName: 'android_provider_box',
    );

    print('Android cache created with custom path provider: $androidPath');
    await androidCache2.dispose();

    // Use with IOSUtils
    final iosPath = await IOSUtils.createIOSCachePathWithProvider(
      pathProvider: myCustomPathProvider,
      subdirectory: 'my_ios_cache',
    );

    final iosCache2 = await IOSUtils.createIOSOptimizedCache(
      cachePath: iosPath ?? await IOSUtils.getBestIOSCachePath(),
      boxName: 'ios_provider_box',
    );

    print('iOS cache created with custom path provider: $iosPath');
    await iosCache2.dispose();
  } catch (e) {
    print('Error using custom path providers: $e');
  }

  print('\n=== All examples completed ===');
}
