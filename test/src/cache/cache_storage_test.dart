import 'package:rps_dart_sdk/src/cache/cache_storage.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    test('should create entry with current timestamp', () {
      final data = {'key': 'value'};
      final entry = CacheEntry.create(data);

      expect(entry.data, equals(data));
      expect(entry.accessCount, equals(1));
      expect(entry.createdAt, isA<DateTime>());
      expect(entry.lastAccessedAt, isA<DateTime>());
      expect(entry.expiresAt, isNull);
    });

    test('should create entry with custom expiration', () {
      final data = {'key': 'value'};
      final expiresAt = DateTime.now().add(Duration(hours: 1));
      final entry = CacheEntry.create(data, expiresAt: expiresAt);

      expect(entry.expiresAt, equals(expiresAt));
    });

    test('should update access information', () {
      final entry = CacheEntry.create({'key': 'value'});
      final updatedEntry = entry.withAccess();

      expect(updatedEntry.accessCount, equals(2));
      expect(updatedEntry.lastAccessedAt.isAfter(entry.lastAccessedAt), isTrue);
      expect(updatedEntry.data, equals(entry.data));
      expect(updatedEntry.createdAt, equals(entry.createdAt));
    });

    test('should detect expiration by age', () {
      final pastTime = DateTime.now().subtract(Duration(hours: 2));
      final entry = CacheEntry(
        data: {'key': 'value'},
        createdAt: pastTime,
        lastAccessedAt: pastTime,
      );

      expect(entry.isExpired(Duration(hours: 1)), isTrue);
      expect(entry.isExpired(Duration(hours: 3)), isFalse);
    });

    test('should detect expiration by specific time', () {
      final pastTime = DateTime.now().subtract(Duration(minutes: 1));
      final entry = CacheEntry.create({'key': 'value'}, expiresAt: pastTime);

      expect(entry.isExpired(Duration(hours: 1)), isTrue);
    });

    test('should serialize to and from JSON', () {
      final originalEntry = CacheEntry.create({
        'key': 'value',
        'number': 42,
      }, expiresAt: DateTime.now().add(Duration(hours: 1)));

      final json = originalEntry.toJson();
      final deserializedEntry = CacheEntry.fromJson(json);

      expect(deserializedEntry.data, equals(originalEntry.data));
      expect(deserializedEntry.createdAt, equals(originalEntry.createdAt));
      expect(
        deserializedEntry.lastAccessedAt,
        equals(originalEntry.lastAccessedAt),
      );
      expect(deserializedEntry.accessCount, equals(originalEntry.accessCount));
      expect(deserializedEntry.expiresAt, equals(originalEntry.expiresAt));
    });

    test('should handle JSON without optional fields', () {
      final json = {
        'data': {'key': 'value'},
        'createdAt': DateTime.now().toIso8601String(),
        'lastAccessedAt': DateTime.now().toIso8601String(),
      };

      final entry = CacheEntry.fromJson(json);

      expect(entry.data, equals({'key': 'value'}));
      expect(entry.accessCount, equals(1));
      expect(entry.expiresAt, isNull);
    });
  });

  group('CacheStorageException', () {
    test('should create exception with message', () {
      final exception = CacheStorageException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(exception.toString(), equals('CacheStorageException: Test error'));
    });

    test('should create exception with cause', () {
      final cause = Exception('Root cause');
      final exception = CacheStorageException('Test error', cause);

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
    });
  });
}
