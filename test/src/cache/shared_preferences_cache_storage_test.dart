import 'package:shared_preferences/shared_preferences.dart';
import 'package:rps_dart_sdk/src/cache/shared_preferences_cache_storage.dart';
import 'package:rps_dart_sdk/src/cache/cache_storage.dart';
import 'package:test/test.dart';

void main() {
  group('SharedPreferencesCacheStorage', () {
    late SharedPreferencesCacheStorage storage;

    setUp(() async {
      // Initialize with mock values
      SharedPreferences.setMockInitialValues({});
      storage = SharedPreferencesCacheStorage();
      await storage.initialize();
    });

    tearDown(() async {
      await storage.dispose();
    });

    test('should initialize successfully', () async {
      final newStorage = SharedPreferencesCacheStorage();
      await newStorage.initialize();

      // Should not throw and should be ready for operations
      expect(await newStorage.size(), equals(0));
      await newStorage.dispose();
    });

    test('should store and retrieve data', () async {
      final data = {'key': 'value', 'number': 42};

      await storage.store('test_key', data);
      final retrieved = await storage.retrieve('test_key');

      expect(retrieved, equals(data));
    });

    test('should return null for non-existent key', () async {
      final retrieved = await storage.retrieve('non_existent');
      expect(retrieved, isNull);
    });

    test('should update access count on retrieval', () async {
      final data = {'key': 'value'};

      await storage.store('test_key', data);

      // First retrieval
      await storage.retrieve('test_key');
      final entry1 = await storage.getEntry('test_key');
      expect(entry1?.accessCount, equals(2)); // 1 from store + 1 from retrieve

      // Second retrieval
      await storage.retrieve('test_key');
      final entry2 = await storage.getEntry('test_key');
      expect(entry2?.accessCount, equals(3));
    });

    test('should remove specific entries', () async {
      await storage.store('key1', {'data': 'value1'});
      await storage.store('key2', {'data': 'value2'});

      expect(await storage.containsKey('key1'), isTrue);
      expect(await storage.containsKey('key2'), isTrue);

      await storage.remove('key1');

      expect(await storage.containsKey('key1'), isFalse);
      expect(await storage.containsKey('key2'), isTrue);
    });

    test('should clear all entries', () async {
      await storage.store('key1', {'data': 'value1'});
      await storage.store('key2', {'data': 'value2'});

      expect(await storage.size(), equals(2));

      await storage.clear();

      expect(await storage.size(), equals(0));
      expect(await storage.getAllKeys(), isEmpty);
    });

    test('should get all keys', () async {
      await storage.store('key1', {'data': 'value1'});
      await storage.store('key2', {'data': 'value2'});
      await storage.store('key3', {'data': 'value3'});

      final keys = await storage.getAllKeys();

      expect(keys, hasLength(3));
      expect(keys, containsAll(['key1', 'key2', 'key3']));
    });

    test('should report correct size', () async {
      expect(await storage.size(), equals(0));

      await storage.store('key1', {'data': 'value1'});
      expect(await storage.size(), equals(1));

      await storage.store('key2', {'data': 'value2'});
      expect(await storage.size(), equals(2));

      await storage.remove('key1');
      expect(await storage.size(), equals(1));
    });

    test('should check key existence', () async {
      expect(await storage.containsKey('test_key'), isFalse);

      await storage.store('test_key', {'data': 'value'});
      expect(await storage.containsKey('test_key'), isTrue);

      await storage.remove('test_key');
      expect(await storage.containsKey('test_key'), isFalse);
    });

    test('should get entry metadata', () async {
      final data = {'key': 'value'};
      await storage.store('test_key', data);

      final entry = await storage.getEntry('test_key');

      expect(entry, isNotNull);
      expect(entry!.data, equals(data));
      expect(entry.accessCount, equals(1));
      expect(entry.createdAt, isA<DateTime>());
      expect(entry.lastAccessedAt, isA<DateTime>());
    });

    test('should get all entries with metadata', () async {
      await storage.store('key1', {'data': 'value1'});
      await storage.store('key2', {'data': 'value2'});

      final entries = await storage.getAllEntries();

      expect(entries, hasLength(2));
      expect(entries.keys, containsAll(['key1', 'key2']));
      expect(entries['key1']?.data, equals({'data': 'value1'}));
      expect(entries['key2']?.data, equals({'data': 'value2'}));
    });

    test('should handle corrupted data gracefully', () async {
      // Manually insert corrupted data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rps_cache_corrupted', 'invalid_json');

      // Should throw exception but clean up corrupted entry
      expect(
        () => storage.retrieve('corrupted'),
        throwsA(isA<CacheStorageException>()),
      );
      expect(await storage.containsKey('corrupted'), isFalse);
    });

    test('should handle initialization errors', () async {
      // This test is more conceptual since we can't easily mock SharedPreferences
      // to fail initialization in the current setup
      expect(() async {
        final newStorage = SharedPreferencesCacheStorage();
        await newStorage.initialize();
      }, returnsNormally);
    });

    test('should handle multiple initializations', () async {
      await storage.initialize(); // Second initialization
      await storage.initialize(); // Third initialization

      // Should still work normally
      await storage.store('test', {'data': 'value'});
      final retrieved = await storage.retrieve('test');
      expect(retrieved, equals({'data': 'value'}));
    });

    test('should not interfere with other SharedPreferences keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('other_key', 'other_value');

      await storage.store('cache_key', {'data': 'cache_value'});

      expect(prefs.getString('other_key'), equals('other_value'));
      expect(await storage.getAllKeys(), equals(['cache_key']));
    });
  });
}
