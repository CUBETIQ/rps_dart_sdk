/// Core configuration interfaces for the RPS SDK
///
/// This file defines the configuration system that allows comprehensive
/// customization of all SDK aspects including HTTP communication, retry policies,
/// cache settings, and logging configuration.
library;

import 'dart:core';

import '../retry/retry_policy.dart';
import 'error.dart';
import '../cache/cache_policy.dart';
import '../cache/cache_storage_factory.dart';

/// Abstract configuration interface that defines all configurable aspects
/// of the RPS SDK. Implementations must provide all required settings
/// with validation and sensible defaults.
abstract class RpsConfiguration {
  String get baseUrl;
  String get apiKey;
  Duration get connectTimeout;
  Duration get receiveTimeout;
  RetryPolicy get retryPolicy;
  CachePolicy get cachePolicy;
  Map<String, String> get customHeaders;
  void validate();
}

/// Builder pattern implementation for creating RpsConfiguration instances
/// with fluent API for easy setup and comprehensive validation.
class RpsConfigurationBuilder {
  String? _baseUrl;
  String? _apiKey;
  Duration? _connectTimeout;
  Duration? _receiveTimeout;
  RetryPolicy? _retryPolicy;
  CachePolicy? _cachePolicy;
  final Map<String, String> _customHeaders = {};

  CacheStorageType? _cacheStorageType;
  Duration? _cacheMaxAge;
  Map<String, dynamic>? _cacheConfig;

  /// Sets the base URL for the RPS service
  RpsConfigurationBuilder setBaseUrl(String url) {
    if (url.isEmpty) {
      throw RpsError.configuration(
        message: 'Base URL cannot be empty',
        details: {'provided_url': url},
      );
    }
    _baseUrl = url;
    return this;
  }

  /// Sets the API key for authentication
  RpsConfigurationBuilder setApiKey(String key) {
    _apiKey = key;
    return this;
  }

  /// Sets connection timeout duration
  RpsConfigurationBuilder setConnectTimeout(Duration timeout) {
    if (timeout.isNegative || timeout == Duration.zero) {
      throw RpsError.configuration(
        message: 'Connect timeout must be positive',
        details: {'provided_timeout': timeout.toString()},
      );
    }
    _connectTimeout = timeout;
    return this;
  }

  /// Sets receive timeout duration
  RpsConfigurationBuilder setReceiveTimeout(Duration timeout) {
    if (timeout.isNegative || timeout == Duration.zero) {
      throw RpsError.configuration(
        message: 'Receive timeout must be positive',
        details: {'provided_timeout': timeout.toString()},
      );
    }
    _receiveTimeout = timeout;
    return this;
  }

  /// Sets connection and receive timeout durations
  RpsConfigurationBuilder setTimeouts(Duration connect, Duration receive) {
    if (connect.isNegative || connect == Duration.zero) {
      throw RpsError.configuration(
        message: 'Connect timeout must be positive',
        details: {'provided_connect_timeout': connect.toString()},
      );
    }
    if (receive.isNegative || receive == Duration.zero) {
      throw RpsError.configuration(
        message: 'Receive timeout must be positive',
        details: {'provided_receive_timeout': receive.toString()},
      );
    }
    if (connect > receive) {
      throw RpsError.configuration(
        message: 'Connect timeout cannot be greater than receive timeout',
        details: {
          'connect_timeout': connect.toString(),
          'receive_timeout': receive.toString(),
        },
      );
    }
    _connectTimeout = connect;
    _receiveTimeout = receive;
    return this;
  }

  /// Sets the retry policy for failed requests
  RpsConfigurationBuilder setRetryPolicy(RetryPolicy policy) {
    _retryPolicy = policy;
    return this;
  }

  /// Sets the cache policy for request caching
  RpsConfigurationBuilder setCachePolicy(CachePolicy policy) {
    _cachePolicy = policy;
    return this;
  }

  /// Set the cache storage type
  RpsConfigurationBuilder setCacheStorageType(CacheStorageType type) {
    _cacheStorageType = type;
    return this;
  }

  /// Set the maximum age for cache entries
  RpsConfigurationBuilder setCacheMaxAge(Duration maxAge) {
    _cacheMaxAge = maxAge;
    return this;
  }

  /// Set additional cache configuration
  RpsConfigurationBuilder setCacheConfig(Map<String, dynamic> config) {
    _cacheConfig = Map.from(config);
    return this;
  }

  /// Configure cache for in-memory storage (fast, not persistent)
  RpsConfigurationBuilder useInMemoryCache({
    Duration maxAge = const Duration(hours: 1),
  }) {
    _cacheStorageType = CacheStorageType.inMemory;
    _cacheMaxAge = maxAge;
    return this;
  }

  /// Configure cache for SharedPreferences storage (persistent, small data)
  RpsConfigurationBuilder useSharedPreferencesCache({
    Duration maxAge = const Duration(hours: 24),
  }) {
    _cacheStorageType = CacheStorageType.hive;
    _cacheMaxAge = maxAge;
    return this;
  }

  /// Configure cache for Hive CE storage (persistent, high-performance, large data)
  RpsConfigurationBuilder useHiveCache({
    Duration maxAge = const Duration(days: 7),
    String? boxName,
    bool autoCompact = true,
  }) {
    _cacheStorageType = CacheStorageType.hive;
    _cacheMaxAge = maxAge;
    _cacheConfig = {
      'boxName': boxName ?? 'rps_cache',
      'autoCompact': autoCompact,
    };
    return this;
  }

  /// Auto-select cache storage based on use case
  RpsConfigurationBuilder autoSelectCacheStorage({
    required bool needsPersistence,
    bool isHighFrequency = false,
    bool isLargeData = false,
    Duration? maxAge,
  }) {
    _cacheStorageType = CacheStorageFactory.getRecommendedStorageType(
      needsPersistence: needsPersistence,
      isHighFrequency: isHighFrequency,
      isLargeData: isLargeData,
    );

    if (maxAge != null) {
      _cacheMaxAge = maxAge;
    }

    return this;
  }

  /// Adds a custom header that will be included with all requests
  RpsConfigurationBuilder addCustomHeader(String key, String value) {
    if (key.isEmpty) {
      throw RpsError.configuration(
        message: 'Header key cannot be empty',
        details: {'provided_key': key, 'value': value},
      );
    }
    if (key.contains(' ') || key.contains('\n') || key.contains('\r')) {
      throw RpsError.configuration(
        message: 'Header key contains invalid characters: "$key"',
        details: {'provided_key': key, 'value': value},
      );
    }
    _customHeaders[key] = value;
    return this;
  }

  /// Adds multiple custom headers at once
  RpsConfigurationBuilder addCustomHeaders(Map<String, String> headers) {
    for (final entry in headers.entries) {
      addCustomHeader(entry.key, entry.value);
    }
    return this;
  }

  /// Removes a custom header
  RpsConfigurationBuilder removeCustomHeader(String key) {
    _customHeaders.remove(key);
    return this;
  }

  /// Clears all custom headers
  RpsConfigurationBuilder clearCustomHeaders() {
    _customHeaders.clear();
    return this;
  }

  /// Creates a configuration optimized for development environments
  RpsConfigurationBuilder development() {
    return setTimeouts(
      const Duration(seconds: 10),
      const Duration(seconds: 30),
    ).setCachePolicy(CachePolicy.disabled());
  }

  /// Creates a configuration optimized for production environments
  RpsConfigurationBuilder production() {
    return setTimeouts(
      const Duration(seconds: 30),
      const Duration(seconds: 60),
    ).setCachePolicy(CachePolicy.performance());
  }

  /// Creates a configuration optimized for offline-first applications
  RpsConfigurationBuilder offlineFirst() {
    return setTimeouts(
      const Duration(seconds: 15),
      const Duration(seconds: 30),
    ).setCachePolicy(CachePolicy.offlineFirst());
  }

  /// Get the selected cache storage type
  CacheStorageType? get cacheStorageType => _cacheStorageType;

  /// Get the cache max age
  Duration? get cacheMaxAge => _cacheMaxAge;

  /// Get the cache configuration
  Map<String, dynamic>? get cacheConfig => _cacheConfig;

  /// Builds and validates the configuration
  RpsConfiguration build() {
    final config = _DefaultRpsConfiguration(
      baseUrl: _baseUrl ?? 'https://api.rps.com',
      apiKey: _apiKey ?? '',
      connectTimeout: _connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: _receiveTimeout ?? const Duration(seconds: 60),
      retryPolicy: _retryPolicy ?? _createDefaultRetryPolicy(),
      cachePolicy: _cachePolicy ?? _createDefaultCachePolicy(),
      customHeaders: Map.unmodifiable(_customHeaders),
    );

    // Validate the built configuration
    config.validate();

    return config;
  }

  RetryPolicy _createDefaultRetryPolicy() {
    return _DefaultRetryPolicy();
  }

  CachePolicy _createDefaultCachePolicy() {
    return const CachePolicy();
  }
}

/// Default implementation of RpsConfiguration
class _DefaultRpsConfiguration implements RpsConfiguration {
  @override
  final String baseUrl;

  @override
  final String apiKey;

  @override
  final Duration connectTimeout;

  @override
  final Duration receiveTimeout;

  @override
  final RetryPolicy retryPolicy;

  @override
  final CachePolicy cachePolicy;

  @override
  final Map<String, String> customHeaders;

  const _DefaultRpsConfiguration({
    required this.baseUrl,
    required this.apiKey,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.retryPolicy,
    required this.cachePolicy,

    required this.customHeaders,
  });

  @override
  void validate() {
    final errors = <String>[];

    // Validate base URL
    if (baseUrl.isEmpty) {
      errors.add('Base URL cannot be empty');
    } else {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null) {
        errors.add('Base URL must be a valid URL: $baseUrl');
      } else if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        errors.add('Base URL must use HTTP or HTTPS protocol: $baseUrl');
      } else if (!uri.hasAuthority || uri.host.isEmpty) {
        errors.add('Base URL must have a valid host: $baseUrl');
      }
    }

    // Validate API key (can be empty for some configurations)
    if (apiKey.isNotEmpty && apiKey.length < 8) {
      errors.add('API key must be at least 8 characters long');
    }

    // Validate timeouts
    if (connectTimeout.isNegative || connectTimeout == Duration.zero) {
      errors.add(
        'Connect timeout must be positive, got: ${connectTimeout.inMilliseconds}ms',
      );
    }

    if (receiveTimeout.isNegative || receiveTimeout == Duration.zero) {
      errors.add(
        'Receive timeout must be positive, got: ${receiveTimeout.inMilliseconds}ms',
      );
    }

    // Validate timeout relationship
    if (connectTimeout > receiveTimeout) {
      errors.add(
        'Connect timeout (${connectTimeout.inMilliseconds}ms) cannot be greater than receive timeout (${receiveTimeout.inMilliseconds}ms)',
      );
    }

    // Validate custom headers
    for (final entry in customHeaders.entries) {
      if (entry.key.isEmpty) {
        errors.add('Custom header keys cannot be empty');
      }
      if (entry.key.contains(' ') ||
          entry.key.contains('\n') ||
          entry.key.contains('\r')) {
        errors.add(
          'Custom header key contains invalid characters: "${entry.key}"',
        );
      }
    }

    // Validate policies
    try {
      cachePolicy.validate();
    } catch (e) {
      errors.add('Cache policy validation failed: $e');
    }

    if (errors.isNotEmpty) {
      throw RpsConfigurationException(
        'Configuration validation failed',
        errors,
      );
    }
  }
}

/// Exception thrown when configuration validation fails
class RpsConfigurationException implements Exception {
  /// Main error message
  final String message;

  /// List of specific validation errors
  final List<String> errors;

  const RpsConfigurationException(this.message, this.errors);

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (errors.isNotEmpty) {
      buffer.write(':\n');
      for (int i = 0; i < errors.length; i++) {
        buffer.write('  ${i + 1}. ${errors[i]}');
        if (i < errors.length - 1) buffer.write('\n');
      }
    }
    return buffer.toString();
  }
}

/// Default retry policy implementation for configuration system
class _DefaultRetryPolicy implements RetryPolicy {
  @override
  int get maxAttempts => 3;

  @override
  Duration get baseDelay => const Duration(seconds: 1);

  @override
  Duration get maxDelay => const Duration(seconds: 30);

  @override
  bool shouldRetry(int attemptCount, RpsError error) {
    if (attemptCount >= maxAttempts) return false;

    // Use the error's built-in retryability determination
    return error.isRetryable;
  }

  @override
  Duration getDelay(int attemptCount, RpsError error) {
    final multiplier = 1 << attemptCount; // 2^attemptCount
    var delay = Duration(milliseconds: baseDelay.inMilliseconds * multiplier);

    // Cap at maximum delay
    if (delay > maxDelay) {
      delay = maxDelay;
    }

    return delay;
  }
}
