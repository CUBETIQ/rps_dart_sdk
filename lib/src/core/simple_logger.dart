/// Simple logging implementation for the RPS SDK
///
/// This file provides a basic logging implementation that doesn't depend
/// on external logging packages.
library;

enum RpsLogLevel { debug, info, warning, error, fatal, off }

abstract class LoggingManager {
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void info(String message, {Object? error, StackTrace? stackTrace});
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
  void fatal(String message, {Object? error, StackTrace? stackTrace});
  void dispose();
}

class SimpleLoggingManager implements LoggingManager {
  final RpsLogLevel level;
  final bool enableColors;

  const SimpleLoggingManager({
    this.level = RpsLogLevel.info,
    this.enableColors = true,
  });

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (_shouldLog(RpsLogLevel.debug)) {
      _log('DEBUG', message, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    if (_shouldLog(RpsLogLevel.info)) {
      _log('INFO', message, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    if (_shouldLog(RpsLogLevel.warning)) {
      _log('WARNING', message, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (_shouldLog(RpsLogLevel.error)) {
      _log('ERROR', message, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    if (_shouldLog(RpsLogLevel.fatal)) {
      _log('FATAL', message, error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    // No-op for simple logger
  }

  bool _shouldLog(RpsLogLevel messageLevel) {
    if (level == RpsLogLevel.off) return false;
    return messageLevel.index >= level.index;
  }

  void _log(
    String levelName,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = enableColors ? _getColoredPrefix(levelName) : '[$levelName]';

    print('$timestamp $prefix $message');

    if (error != null) {
      print('  Error: $error');
    }

    if (stackTrace != null) {
      print('  Stack trace: $stackTrace');
    }
  }

  String _getColoredPrefix(String level) {
    switch (level) {
      case 'DEBUG':
        return '\x1B[36m[DEBUG]\x1B[0m'; // Cyan
      case 'INFO':
        return '\x1B[32m[INFO]\x1B[0m'; // Green
      case 'WARNING':
        return '\x1B[33m[WARNING]\x1B[0m'; // Yellow
      case 'ERROR':
        return '\x1B[31m[ERROR]\x1B[0m'; // Red
      case 'FATAL':
        return '\x1B[35m[FATAL]\x1B[0m'; // Magenta
      default:
        return '[$level]';
    }
  }
}

class NoOpLoggingManager implements LoggingManager {
  const NoOpLoggingManager();

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void dispose() {}
}
