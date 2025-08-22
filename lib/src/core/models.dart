/// Core data models for the RPS SDK
///
/// This file defines the fundamental data models used throughout the SDK
/// including requests, responses, metadata, and error models with enhanced
/// functionality and serialization support.
library;

/// Enhanced request model with priority, headers, and metadata support
class RpsRequest {
  /// Unique identifier for the request
  final String id;

  /// Type of the request (e.g., 'invoice', 'payment')
  final String type;

  /// Request payload data
  final Map<String, dynamic> data;

  /// Timestamp when the request was created
  final DateTime createdAt;

  /// Custom headers for this specific request
  final Map<String, String> headers;

  /// Request priority (higher numbers = higher priority)
  final int priority;

  /// Additional metadata for the request
  final RpsMetadata metadata;

  RpsRequest({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    Map<String, String>? headers,
    this.priority = 0,
    RpsMetadata? metadata,
  }) : createdAt = createdAt ?? DateTime.now(),
       headers = headers ?? const {},
       metadata = metadata ?? const RpsMetadata();

  /// Factory constructor for creating requests with auto-generated ID
  factory RpsRequest.create({
    required String type,
    required Map<String, dynamic> data,
    String? customId,
    Map<String, String>? headers,
    int priority = 0,
    Map<String, dynamic>? customMetadata,
  }) {
    final id = customId ?? _generateRequestId();
    final metadata = RpsMetadata(custom: customMetadata ?? {});

    return RpsRequest(
      id: id,
      type: type,
      data: data,
      headers: headers,
      priority: priority,
      metadata: metadata,
    );
  }

  /// Creates a copy with modified fields
  RpsRequest copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    Map<String, String>? headers,
    int? priority,
    RpsMetadata? metadata,
  }) {
    return RpsRequest(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      headers: headers ?? this.headers,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'headers': headers,
      'priority': priority,
      'metadata': metadata.toJson(),
    };
  }

  /// Creates from JSON
  factory RpsRequest.fromJson(Map<String, dynamic> json) {
    return RpsRequest(
      id: json['id'] as String,
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      priority: json['priority'] as int? ?? 0,
      metadata: RpsMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  static String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return 'req_$random';
  }
}

/// Enhanced response model with timing, cache status, and detailed response info
class RpsResponse {
  /// HTTP status code
  final int statusCode;

  /// Response payload data
  final Map<String, dynamic> data;

  /// Response headers
  final Map<String, String> headers;

  /// Time taken to receive the response
  final Duration responseTime;

  /// Whether the response came from cache
  final bool fromCache;

  /// Timestamp when the response was received
  final DateTime timestamp;

  /// Request ID this response corresponds to
  final String? requestId;

  RpsResponse({
    required this.statusCode,
    required this.data,
    Map<String, String>? headers,
    Duration? responseTime,
    this.fromCache = false,
    DateTime? timestamp,
    this.requestId,
  }) : headers = headers ?? const {},
       responseTime = responseTime ?? Duration.zero,
       timestamp = timestamp ?? DateTime.now();

  /// Whether the response indicates success (2xx status code)
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response indicates a client error (4xx status code)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the response indicates a server error (5xx status code)
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// Creates a copy with modified fields
  RpsResponse copyWith({
    int? statusCode,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    Duration? responseTime,
    bool? fromCache,
    DateTime? timestamp,
    String? requestId,
  }) {
    return RpsResponse(
      statusCode: statusCode ?? this.statusCode,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      responseTime: responseTime ?? this.responseTime,
      fromCache: fromCache ?? this.fromCache,
      timestamp: timestamp ?? this.timestamp,
      requestId: requestId ?? this.requestId,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'data': data,
      'headers': headers,
      'responseTime': responseTime.inMilliseconds,
      'fromCache': fromCache,
      'timestamp': timestamp.toIso8601String(),
      'requestId': requestId,
    };
  }

  /// Creates from JSON
  factory RpsResponse.fromJson(Map<String, dynamic> json) {
    return RpsResponse(
      statusCode: json['statusCode'] as int,
      data: Map<String, dynamic>.from(json['data'] as Map),
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      responseTime: Duration(milliseconds: json['responseTime'] as int? ?? 0),
      fromCache: json['fromCache'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['requestId'] as String?,
    );
  }
}

/// Metadata class for SDK version, platform, and custom data
class RpsMetadata {
  /// SDK version information
  final String sdkVersion;

  /// Platform information (iOS, Android, Web, etc.)
  final String sdkPlatform;

  /// Client identifier
  final String clientId;

  /// Custom metadata fields
  final Map<String, dynamic> custom;

  const RpsMetadata({
    this.sdkVersion = '1.0.0',
    this.sdkPlatform = 'dart',
    this.clientId = 'default',
    this.custom = const {},
  });

  /// Creates a copy with modified fields
  RpsMetadata copyWith({
    String? sdkVersion,
    String? sdkPlatform,
    String? clientId,
    Map<String, dynamic>? custom,
  }) {
    return RpsMetadata(
      sdkVersion: sdkVersion ?? this.sdkVersion,
      sdkPlatform: sdkPlatform ?? this.sdkPlatform,
      clientId: clientId ?? this.clientId,
      custom: custom ?? this.custom,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'sdkVersion': sdkVersion,
      'sdkPlatform': sdkPlatform,
      'clientId': clientId,
      'custom': custom,
    };
  }

  /// Creates from JSON
  factory RpsMetadata.fromJson(Map<String, dynamic> json) {
    return RpsMetadata(
      sdkVersion: json['sdkVersion'] as String? ?? '1.0.0',
      sdkPlatform: json['sdkPlatform'] as String? ?? 'dart',
      clientId: json['clientId'] as String? ?? 'default',
      custom: Map<String, dynamic>.from(json['custom'] as Map? ?? {}),
    );
  }
}
