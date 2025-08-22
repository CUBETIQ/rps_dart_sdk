import 'package:rps_dart_sdk/rps_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('RpsLogLevel', () {
    test('should have correct ordering', () {
      expect(RpsLogLevel.debug.index, lessThan(RpsLogLevel.info.index));
      expect(RpsLogLevel.info.index, lessThan(RpsLogLevel.warning.index));
      expect(RpsLogLevel.warning.index, lessThan(RpsLogLevel.error.index));
      expect(RpsLogLevel.error.index, lessThan(RpsLogLevel.fatal.index));
      expect(RpsLogLevel.fatal.index, lessThan(RpsLogLevel.off.index));
    });
  });

  group('SimpleLoggingManager', () {
    late SimpleLoggingManager logger;

    setUp(() {
      logger = const SimpleLoggingManager();
    });

    test('should initialize with default log level', () {
      expect(logger.level, equals(RpsLogLevel.info));
    });

    test('should initialize with custom log level', () {
      final debugLogger = const SimpleLoggingManager(level: RpsLogLevel.debug);
      expect(debugLogger.level, equals(RpsLogLevel.debug));
    });

    test('should have logging methods that do not throw', () {
      expect(() => logger.debug('Debug message'), returnsNormally);
      expect(() => logger.info('Info message'), returnsNormally);
      expect(() => logger.warning('Warning message'), returnsNormally);
      expect(() => logger.error('Error message'), returnsNormally);
      expect(() => logger.fatal('Fatal message'), returnsNormally);
    });

    test('should handle error and stack trace parameters', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      expect(
        () => logger.error(
          'Error with details',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('should dispose without throwing', () {
      expect(() => logger.dispose(), returnsNormally);
    });
  });
}
