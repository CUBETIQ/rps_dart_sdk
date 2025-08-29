import 'package:test/test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() {
  group('Offline First Custom Path Tests', () {
    test('createOfflineFirst should accept custom cache path', () async {
      // This test verifies that we can pass a custom cache path to createOfflineFirst
      final client = await RpsClientBuilder.createOfflineFirst(
        webhookUrl: 'https://example.com/webhook',
        apiKey: 'test-api-key',
        cachePath: './test_custom_path',
        cacheMaxAge: const Duration(hours: 1),
      );

      expect(client, isNotNull);
      
      // Clean up
      await client.dispose();
    });

    test('createOfflineFirst should work without custom cache path', () async {
      // This test verifies that the method still works without a custom path
      final client = await RpsClientBuilder.createOfflineFirst(
        webhookUrl: 'https://example.com/webhook',
        apiKey: 'test-api-key',
        cacheMaxAge: const Duration(hours: 1),
      );

      expect(client, isNotNull);
      
      // Clean up
      await client.dispose();
    });

    test('createOfflineFirst should work with different storage types', () async {
      // Test with in-memory storage
      final client1 = await RpsClientBuilder.createOfflineFirst(
        webhookUrl: 'https://example.com/webhook',
        apiKey: 'test-api-key',
        storageType: CacheStorageType.inMemory,
        cachePath: './test_path_should_be_ignored_for_in_memory',
        cacheMaxAge: const Duration(hours: 1),
      );

      expect(client1, isNotNull);
      await client1.dispose();

      // Test with hive storage
      final client2 = await RpsClientBuilder.createOfflineFirst(
        webhookUrl: 'https://example.com/webhook',
        apiKey: 'test-api-key',
        storageType: CacheStorageType.hive,
        cachePath: './test_hive_path',
        cacheMaxAge: const Duration(hours: 1),
      );

      expect(client2, isNotNull);
      await client2.dispose();
    });
  });
}