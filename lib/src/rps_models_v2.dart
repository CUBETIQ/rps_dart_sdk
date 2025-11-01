/// Core models for RPS SDK v2
/// 
/// Simple, focused data models for webhook API requests and responses.
library;

import 'dart:math';
import 'rps_auth_v2.dart';

/// Configuration for the RPS client
class RpsConfig {
  /// Base URL for the webhook API
  final String baseUrl;
  
  /// Request timeout duration
  final Duration timeout;
  
  /// Default headers to include with all requests
  final Map<String, String> headers;
  
  /// Retry policy configuration
  final RetryConfig retryConfig;
  
  /// Authentication provider (optional)
  final RpsAuth? auth;
  
  /// Enable offline caching for failed requests
  final bool enableOfflineCache;
  
  /// Maximum number of requests to cache offline
  final int maxOfflineCacheSize;

  const RpsConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.headers = const {},
    this.retryConfig = const RetryConfig(),
    this.auth,
    this.enableOfflineCache = true,
    this.maxOfflineCacheSize = 100,
  });

  /// Create a copy with updated values
  RpsConfig copyWith({
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? headers,
    RetryConfig? retryConfig,
    RpsAuth? auth,
    bool? enableOfflineCache,
    int? maxOfflineCacheSize,
  }) {
    return RpsConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      timeout: timeout ?? this.timeout,
      headers: headers ?? this.headers,
      retryConfig: retryConfig ?? this.retryConfig,
      auth: auth ?? this.auth,
      enableOfflineCache: enableOfflineCache ?? this.enableOfflineCache,
      maxOfflineCacheSize: maxOfflineCacheSize ?? this.maxOfflineCacheSize,
    );
  }
}

/// Retry configuration
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;
  
  /// Base delay between retries
  final Duration baseDelay;
  
  /// Maximum delay between retries
  final Duration maxDelay;
  
  /// Whether to use exponential backoff
  final bool useExponentialBackoff;
  
  /// Whether to add jitter to delays
  final bool useJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.useExponentialBackoff = true,
    this.useJitter = true,
  });

  /// Calculate delay for a given attempt
  Duration getDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    
    Duration delay = baseDelay;
    
    if (useExponentialBackoff) {
      // Exponential backoff: 1s, 2s, 4s, 8s, etc.
      final multiplier = pow(2, attempt - 1).toInt();
      delay = Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
    }
    
    // Cap at max delay
    if (delay > maxDelay) {
      delay = maxDelay;
    }
    
    // Add jitter to prevent thundering herd
    if (useJitter) {
      final jitterMs = Random().nextInt(delay.inMilliseconds ~/ 4);
      delay = Duration(milliseconds: delay.inMilliseconds + jitterMs);
    }
    
    return delay;
  }
}

/// Webhook request model
class WebhookRequest {
  /// Unique request identifier
  final String id;
  
  /// Request payload data
  final Map<String, dynamic> data;
  
  /// Additional headers for this request
  final Map<String, String> headers;
  
  /// Request timestamp
  final DateTime timestamp;

  WebhookRequest({
    String? id,
    required this.data,
    this.headers = const {},
    DateTime? timestamp,
  }) : id = id ?? _generateId(),
       timestamp = timestamp ?? DateTime.now();

  /// Create from JSON
  factory WebhookRequest.fromJson(Map<String, dynamic> json) {
    return WebhookRequest(
      id: json['id'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'headers': headers,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Generate a unique request ID
  static String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'req_${timestamp}_$random';
  }

  @override
  String toString() => 'WebhookRequest(id: $id, data: $data)';
}

/// Webhook response model
class WebhookResponse {
  /// Response status code
  final int statusCode;
  
  /// Response data
  final Map<String, dynamic> data;
  
  /// Response headers
  final Map<String, String> headers;
  
  /// Request duration
  final Duration duration;
  
  /// Original request ID
  final String requestId;

  const WebhookResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
    required this.duration,
    required this.requestId,
  });

  /// Whether the response indicates success
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response indicates a client error
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the response indicates a server error
  bool get isServerError => statusCode >= 500;

  /// Create from JSON
  factory WebhookResponse.fromJson(Map<String, dynamic> json) {
    return WebhookResponse(
      statusCode: json['statusCode'] as int,
      data: Map<String, dynamic>.from(json['data'] as Map),
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      duration: Duration(milliseconds: json['durationMs'] as int),
      requestId: json['requestId'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'data': data,
      'headers': headers,
      'durationMs': duration.inMilliseconds,
      'requestId': requestId,
    };
  }

  @override
  String toString() => 
    'WebhookResponse(id: $requestId, status: $statusCode, duration: ${duration.inMilliseconds}ms)';
}

/// Request/response statistics
class RequestStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration averageResponseTime;
  final DateTime? lastRequestTime;

  const RequestStats({
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.averageResponseTime = Duration.zero,
    this.lastRequestTime,
  });

  /// Success rate as a percentage
  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  /// Create updated stats
  RequestStats withRequest({
    required bool success,
    required Duration responseTime,
  }) {
    final newTotal = totalRequests + 1;
    final newSuccessful = success ? successfulRequests + 1 : successfulRequests;
    final newFailed = success ? failedRequests : failedRequests + 1;
    
    // Calculate new average response time
    final totalTime = averageResponseTime.inMilliseconds * totalRequests + responseTime.inMilliseconds;
    final newAverageTime = Duration(milliseconds: totalTime ~/ newTotal);

    return RequestStats(
      totalRequests: newTotal,
      successfulRequests: newSuccessful,
      failedRequests: newFailed,
      averageResponseTime: newAverageTime,
      lastRequestTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'RequestStats('
        'total: $totalRequests, '
        'success: $successfulRequests, '
        'failed: $failedRequests, '
        'avgTime: ${averageResponseTime.inMilliseconds}ms, '
        'successRate: ${successRate.toStringAsFixed(1)}%)';
  }
}