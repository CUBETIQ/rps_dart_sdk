import 'package:test/test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() {
  group('Custom Path Tests', () {
    test('useHiveCacheWithPath should store path in configuration', () {
      final builder = RpsConfigurationBuilder()
          .setBaseUrl('https://example.com')
          .setApiKey('test-key')
          .useHiveCacheWithPath(
            path: '/custom/cache/path',
            boxName: 'test_box',
            maxAge: const Duration(hours: 12),
          );

      // Test that the path is stored in the configuration
      expect(builder.cacheConfig?['path'], equals('/custom/cache/path'));
      expect(builder.cacheConfig?['boxName'], equals('test_box'));
      
      // Test that the configuration can be built successfully
      final config = builder.build();
      expect(config, isNotNull);
      expect(config.baseUrl, equals('https://example.com'));
      expect(config.apiKey, equals('test-key'));
    });

    test('CacheStorageFactory should create Hive storage with custom path', () async {
      final storage = await CacheStorageFactory.create(
        type: CacheStorageType.hive,
        config: {
          'path': './test_cache_path',
          'boxName': 'test_box',
        },
      );

      expect(storage, isNotNull);
      expect(storage, isA<HiveCacheStorage>());
      
      // Clean up
      await storage.dispose();
    });

    test('HiveCacheStorage should accept custom path in constructor', () async {
      final storage = HiveCacheStorage(
        path: './test_constructor_path',
        boxName: 'constructor_test_box',
      );

      expect(storage, isNotNull);
      
      // Note: We're not initializing the storage here to avoid file system operations
      // in tests, but we're verifying the constructor accepts the parameters
    });
  });
}