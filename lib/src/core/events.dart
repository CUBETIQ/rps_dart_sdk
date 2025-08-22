/// Event system for SDK operation notifications and monitoring
///
/// This file defines the event system that provides real-time notifications
/// of SDK operations including requests, retries, cache operations, and errors
/// for monitoring and observability.

import 'dart:async';

/// Base class for all RPS SDK events
abstract class RpsEvent {
  /// Timestamp when the event occurred
  final DateTime timestamp;

  /// Event type identifier
  String get eventType;

  /// Event data as a map for serialization
  Map<String, dynamic> get data;

  RpsEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

/// Event fired when a request starts
class RequestStartedEvent extends RpsEvent {
  final String requestId;
  final String requestType;
  final Map<String, dynamic> requestData;

  RequestStartedEvent({
    required this.requestId,
    required this.requestType,
    required this.requestData,
    super.timestamp,
  });

  @override
  String get eventType => 'request_started';

  @override
  Map<String, dynamic> get data => {
    'requestId': requestId,
    'requestType': requestType,
    'requestData': requestData,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event fired when a request completes successfully
class RequestCompletedEvent extends RpsEvent {
  final String requestId;
  final int statusCode;
  final Duration responseTime;
  final bool fromCache;
  final int retryCount;

  RequestCompletedEvent({
    required this.requestId,
    required this.statusCode,
    required this.responseTime,
    required this.fromCache,
    required this.retryCount,
    super.timestamp,
  });

  @override
  String get eventType => 'request_completed';

  @override
  Map<String, dynamic> get data => {
    'requestId': requestId,
    'statusCode': statusCode,
    'responseTime': responseTime.inMilliseconds,
    'fromCache': fromCache,
    'retryCount': retryCount,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event fired when a request fails
class RequestFailedEvent extends RpsEvent {
  final String requestId;
  final String errorType;
  final String errorMessage;
  final int retryCount;
  final bool willRetry;

  RequestFailedEvent({
    required this.requestId,
    required this.errorType,
    required this.errorMessage,
    required this.retryCount,
    required this.willRetry,
    super.timestamp,
  });

  @override
  String get eventType => 'request_failed';

  @override
  Map<String, dynamic> get data => {
    'requestId': requestId,
    'errorType': errorType,
    'errorMessage': errorMessage,
    'retryCount': retryCount,
    'willRetry': willRetry,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event fired when a retry attempt is made
class RetryAttemptEvent extends RpsEvent {
  final String requestId;
  final int attemptNumber;
  final Duration delay;
  final String reason;

  RetryAttemptEvent({
    required this.requestId,
    required this.attemptNumber,
    required this.delay,
    required this.reason,
    super.timestamp,
  });

  @override
  String get eventType => 'retry_attempt';

  @override
  Map<String, dynamic> get data => {
    'requestId': requestId,
    'attemptNumber': attemptNumber,
    'delay': delay.inMilliseconds,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event fired for cache operations
class CacheOperationEvent extends RpsEvent {
  final String operation;
  final String? key;
  final bool success;
  final String? errorMessage;

  CacheOperationEvent({
    required this.operation,
    this.key,
    required this.success,
    this.errorMessage,
    super.timestamp,
  });

  @override
  String get eventType => 'cache_operation';

  @override
  Map<String, dynamic> get data => {
    'operation': operation,
    'key': key,
    'success': success,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event fired for authentication operations
class AuthenticationEvent extends RpsEvent {
  final String operation;
  final String? provider;
  final bool success;
  final String? errorMessage;

  AuthenticationEvent({
    required this.operation,
    this.provider,
    required this.success,
    this.errorMessage,
    super.timestamp,
  });

  @override
  String get eventType => 'authentication';

  @override
  Map<String, dynamic> get data => {
    'operation': operation,
    'provider': provider,
    'success': success,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Event bus for managing SDK events with filtering and subscription support
class RpsEventBus {
  final StreamController<RpsEvent> _controller =
      StreamController<RpsEvent>.broadcast();

  /// Stream of all events
  Stream<RpsEvent> get events => _controller.stream;

  /// Filtered stream for specific event types
  Stream<T> eventsOfType<T extends RpsEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  /// Filtered stream with custom predicate
  Stream<RpsEvent> eventsWhere(bool Function(RpsEvent) predicate) {
    return _controller.stream.where(predicate);
  }

  /// Publishes an event to all subscribers
  void publish(RpsEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Closes the event bus and stops all subscriptions
  Future<void> close() async {
    await _controller.close();
  }
}
