import 'package:test/test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() {
  group('Android Compatibility Tests', () {
    test(
      'createAndroidOfflineFirst should handle file system errors gracefully',
      () async {
        // This test simulates what happens on Android with read-only file system
        try {
          final client = await RpsClientBuilder.createAndroidOfflineFirst(
            webhookUrl: 'https://example.com/webhook',
            apiKey: 'test-api-key',
            cachePath: '/invalid/readonly/path', // This should fail
          );

          // Client should be created successfully even if Hive fails
          expect(client, isNotNull);

          // Should be able to dispose without errors
          await client.dispose();
        } catch (e) {
          // Should not throw errors, should gracefully fall back
          fail('createAndroidOfflineFirst should not throw errors: $e');
        }
      },
    );

    test(
      'AndroidUtils.createAndroidCompatibleCache should fall back gracefully',
      () async {
        try {
          final cache = await AndroidUtils.createAndroidCompatibleCache(
            cachePath: '/invalid/readonly/path',
            verbose: true,
          );

          expect(cache, isNotNull);

          // Should be able to perform basic cache operations
          await cache.store('test-key', {'test': 'data'});
          final result = await cache.retrieve('test-key');
          expect(result, isNotNull);
          expect(result!['test'], equals('data'));

          await cache.dispose();
        } catch (e) {
          fail('Android compatible cache should not throw errors: $e');
        }
      },
    );

    test(
      'AndroidUtils.diagnoseCacheIssues should provide useful information',
      () async {
        final diagnosis = await AndroidUtils.diagnoseCacheIssues(
          attemptedPath: '/invalid/path',
        );

        expect(diagnosis, isMap);
        expect(diagnosis['platform'], isNotNull);
        expect(diagnosis['recommendations'], isList);
        expect(diagnosis['canUseHive'], isA<bool>());
        expect(diagnosis['shouldUseInMemory'], isA<bool>());
      },
    );

    test(
      'HiveCacheStorage with custom path should handle invalid paths',
      () async {
        final storage = HiveCacheStorage(
          path: '/invalid/readonly/path',
          boxName: 'test_box',
        );

        try {
          await storage.initialize();
          // If we get here, the fallback worked
          await storage.dispose();
        } catch (e) {
          // This is expected for invalid paths
          expect(e, isA<CacheStorageException>());
          expect(
            e.toString(),
            contains('All Hive initialization paths failed'),
          );
        }
      },
    );

    test('Configuration with custom Hive path should work', () {
      final builder = RpsConfigurationBuilder()
          .setBaseUrl('https://example.com')
          .setApiKey('test-key')
          .useHiveCacheWithPath(
            path: '/some/path',
            boxName: 'custom_box',
            maxAge: const Duration(hours: 12),
          );

      // Test builder's cache configuration
      expect(builder.cacheConfig?['path'], equals('/some/path'));
      expect(builder.cacheConfig?['boxName'], equals('custom_box'));

      // Test that the configuration can be built successfully
      final config = builder.build();
      expect(config, isNotNull);
      expect(config.baseUrl, equals('https://example.com'));
      expect(config.apiKey, equals('test-key'));
    });
  });
}
