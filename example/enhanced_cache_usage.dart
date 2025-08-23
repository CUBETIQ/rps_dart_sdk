/// RPS SDK Usage Examples with Multi-Storage Cache
///
/// This file demonstrates how to use the RPS SDK with different
/// cache storage backends using the integrated RpsClientBuilder.
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

/// Example 1: Simple client with in-memory cache (fastest, not persistent)
Future<void> createSimpleClient() async {
  final client = await RpsClientBuilder.createSimple(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
  );

  // Send data
  final response = await client.sendMessage(
    type: 'simple_message',
    data: {
      'message': 'Hello from simple client!',
      'timestamp': DateTime.now().toIso8601String(),
    },
  );

  print('Response: ${response.statusCode}');

  await client.dispose();
}

/// Example 2: Production client with SharedPreferences cache (persistent, small data)
Future<void> createProductionClient() async {
  final client = await RpsClientBuilder.createProduction(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
    storageType: CacheStorageType.hive,
    cacheMaxAge: const Duration(hours: 24),
    logLevel: RpsLogLevel.warning,
  );

  // Send data
  final response = await client.sendMessage(
    type: 'production_order',
    data: {
      'order_id': '12345',
      'items': ['item1', 'item2'],
      'total': 99.99,
    },
  );

  print('Production response: ${response.statusCode}');

  await client.dispose();
}

/// Example 3: High-performance client with Hive CE cache (persistent, high-performance)
Future<void> createHighPerformanceClient() async {
  final client = await RpsClientBuilder.createHighPerformance(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
    hiveBoxName: 'rps_production_cache',
    cacheMaxAge: const Duration(days: 7),
    logLevel: RpsLogLevel.info,
  );

  // Send large dataset
  final response = await client.sendMessage(
    type: 'batch_upload',
    data: {
      'batch_id': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'records': List.generate(
        1000,
        (i) => {
          'id': i,
          'data': 'record_$i',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    },
  );

  print('High-performance response: ${response.statusCode}');

  await client.dispose();
}

/// Example 4: Custom configuration with configuration builder
Future<void> createCustomClient() async {
  final config = RpsConfigurationBuilder()
      .setBaseUrl('https://rps.service.ctdn.net/third-party/rps/webhook')
      .setApiKey('6057c8d2-3b11-4e0b-8bb8-649d9510904d')
      .useHiveCache(
        maxAge: const Duration(days: 30),
        boxName: 'custom_rps_cache',
        autoCompact: true,
      )
      .setConnectTimeout(const Duration(seconds: 30))
      .setReceiveTimeout(const Duration(seconds: 60))
      .build();

  // Create cache manager with Hive CE storage
  final storage = await CacheStorageFactory.create(
    type: CacheStorageType.hive,
    config: {'boxName': 'custom_rps_cache', 'autoCompact': true},
  );
  final cacheManager = CacheManager(
    storage: storage,
    policy: config.cachePolicy,
  );
  await cacheManager.initialize();

  final client = await RpsClientBuilder()
      .withConfiguration(config)
      .withCacheManager(cacheManager)
      .withLogger(SimpleLoggingManager(level: RpsLogLevel.debug))
      .build();

  // Configure retry intervals for cached requests
  client.setCachedRequestProcessingInterval(const Duration(seconds: 30));

  // Send data
  final response = await client.sendMessage(
    type: 'custom_message',
    data: {
      'custom_config': true,
      'message': 'Hello from custom client!',
      'features': ['hive_cache', 'custom_logging', 'retry_intervals'],
    },
  );

  print('Custom response: ${response.statusCode}');

  await client.dispose();
}

/// Example 5: Auto-select cache storage based on requirements
Future<void> createAutoSelectedClient() async {
  final client = await RpsClientBuilder.forWebhook(
    url: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
    needsPersistence: true,
    isHighFrequency: true,
    isLargeData: false,
    cacheMaxAge: const Duration(hours: 12),
    logLevel: RpsLogLevel.info,
  );

  // The SDK automatically selected the best storage type based on requirements
  // (In this case: SharedPreferences for persistent, high-frequency, small data)

  final response = await client.sendMessage(
    type: 'auto_selected',
    data: {'auto_selected': true, 'storage_type': 'auto_determined'},
  );

  print('Auto-selected response: ${response.statusCode}');

  await client.dispose();
}

/// Example 6: Offline-first client for unreliable network environments
Future<void> createOfflineFirstClient() async {
  final client = await RpsClientBuilder.createOfflineFirst(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
    storageType: CacheStorageType.hive,
    cacheMaxAge: const Duration(days: 30),
  );

  // This client will cache all requests and retry them automatically
  // even if the network is unreliable

  final response = await client.sendMessage(
    type: 'offline_message',
    data: {
      'offline_first': true,
      'cached_for_retry': true,
      'network_resilient': true,
    },
  );

  print('Offline-first response: ${response.statusCode}');

  // Process cached requests manually if needed
  await client.processCachedRequests();

  await client.dispose();
}

/// Example 7: Storage comparison and performance testing
Future<void> compareStoragePerformance() async {
  final stopwatch = Stopwatch();

  print('Testing different storage backends...\n');

  // Test in-memory storage
  stopwatch.start();
  final memoryClient = await RpsClientBuilder.createSimple(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
  );
  stopwatch.stop();
  print('In-Memory client creation: ${stopwatch.elapsedMilliseconds}ms');

  // Test SharedPreferences storage
  stopwatch.reset();
  stopwatch.start();
  final prefsClient = await RpsClientBuilder.createProduction(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
    storageType: CacheStorageType.hive,
  );
  stopwatch.stop();
  print(
    'SharedPreferences client creation: ${stopwatch.elapsedMilliseconds}ms',
  );

  // Test Hive CE storage
  stopwatch.reset();
  stopwatch.start();
  final hiveClient = await RpsClientBuilder.createHighPerformance(
    webhookUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    apiKey: '6057c8d2-3b11-4e0b-8bb8-649d9510904d',
  );
  stopwatch.stop();
  print('Hive CE client creation: ${stopwatch.elapsedMilliseconds}ms');

  // Clean up
  await memoryClient.dispose();
  await prefsClient.dispose();
  await hiveClient.dispose();
}

/// Main function to run all examples
Future<void> main() async {
  print('RPS SDK Multi-Storage Cache Examples\n');

  try {
    await createSimpleClient();
    print('✅ Simple client example completed\n');

    await createProductionClient();
    print('✅ Production client example completed\n');

    await createHighPerformanceClient();
    print('✅ High-performance client example completed\n');

    await createCustomClient();
    print('✅ Custom client example completed\n');

    await createAutoSelectedClient();
    print('✅ Auto-selected client example completed\n');

    await createOfflineFirstClient();
    print('✅ Offline-first client example completed\n');

    await compareStoragePerformance();
    print('✅ Storage performance comparison completed\n');
  } catch (e) {
    print('❌ Error: $e');
  }

  print('All examples completed!');
}
