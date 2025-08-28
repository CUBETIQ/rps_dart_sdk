import 'package:test/test.dart';
import 'package:rps_dart_sdk/rps_dart_sdk.dart';

void main() {
  group('iOS Compatibility Tests', () {
    test(
      'IOSUtils.createIOSOptimizedCache should work with valid paths',
      () async {
        final cache = await IOSUtils.createIOSOptimizedCache(
          cachePath: './test_cache',
          boxName: 'test_ios_box',
          verbose: true,
        );

        expect(cache, isNotNull);

        // Should be able to perform basic cache operations
        await cache.store('test-key', {'test': 'data'});
        final result = await cache.retrieve('test-key');
        expect(result, isNotNull);
        expect(result!['test'], equals('data'));

        await cache.dispose();
      },
    );

    test('IOSUtils.getIOSCachePaths should return valid paths', () {
      final paths = IOSUtils.getIOSCachePaths();
      expect(paths, isList);
      expect(paths.isNotEmpty, isTrue);
    });

    test('IOSUtils.detectIOSDevice should return appropriate device type', () {
      final deviceType = IOSUtils.detectIOSDevice();
      expect(deviceType, isNotNull);
      // On non-iOS platforms, it should return unknown
      expect(deviceType, equals(IOSDeviceType.unknown));
    });

    test('IOSUtils.getIOSOptimizedCacheConfig should provide config', () {
      final config = IOSUtils.getIOSOptimizedCacheConfig();
      expect(config, isMap);
      expect(config['maxAge'], isNotNull);
      expect(config['maxSize'], isNotNull);
      expect(config['preferredStorage'], isNotNull);
    });

    test(
      'IOSUtils.diagnoseIOSCacheIssues should provide useful information',
      () async {
        final diagnosis = await IOSUtils.diagnoseIOSCacheIssues(
          attemptedPath: './test_path',
        );

        expect(diagnosis, isMap);
        expect(diagnosis['platform'], isNotNull);
        expect(diagnosis['deviceType'], isNotNull);
        expect(diagnosis['recommendations'], isList);
        expect(diagnosis['canUseHive'], isA<bool>());
        expect(diagnosis['shouldUseInMemory'], isA<bool>());
        expect(diagnosis['iosSpecificTips'], isList);
      },
    );

    test('IOSDeviceTypeExtension should provide display names', () {
      expect(IOSDeviceType.iphone.displayName, equals('iPhone'));
      expect(IOSDeviceType.ipad.displayName, equals('iPad'));
      expect(IOSDeviceType.ios.displayName, equals('iOS Device'));
      expect(IOSDeviceType.unknown.displayName, equals('Unknown Device'));
    });

    test('IOSUtils.createIOSClientConfig should generate config', () async {
      final config = await IOSUtils.createIOSClientConfig();
      expect(config, isMap);
      expect(config['cacheConfig'], isNotNull);
      expect(config['connectTimeout'], isNotNull);
      expect(config['iosOptimizations'], isNotNull);
    });
  });
}
