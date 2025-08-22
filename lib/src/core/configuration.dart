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

/// Abstract configuration interface that defines all configurable aspects
/// of the RPS SDK. Implementations must provide all required settings
/// with validation and sensible defaults.
abstract class RpsConfiguration {
  /// Base URL for the RPS service
  String get baseUrl;

  /// API key for authentication
  String get apiKey;

  /// Connection timeout duration
  Duration get connectTimeout;

  /// Response receive timeout duration
  Duration get receiveTimeout;

  /// Retry policy for failed requests
  RetryPolicy get retryPolicy;

  /// Cache policy for request caching
  CachePolicy get cachePolicy;

  /// Custom headers to include with all requests
  Map<String, String> get customHeaders;

  /// Validates the configuration and throws if invalid
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

  /// Sets the base URL for the RPS service
  ///
  /// Throws [RpsError] if the URL is empty or invalid
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
  ///
  /// The API key can be empty for configurations that don't require authentication
  RpsConfigurationBuilder setApiKey(String key) {
    _apiKey = key;
    return this;
  }

  /// Sets connection timeout duration
  ///
  /// Throws [RpsError] if timeout is negative or zero
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
  ///
  /// Throws [RpsError] if timeout is negative or zero
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
  ///
  /// Throws [RpsError] if either timeout is negative, zero, or if
  /// connect timeout is greater than receive timeout
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

  /// Adds a custom header that will be included with all requests
  ///
  /// Throws [RpsError] if key is empty or contains invalid characters
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
  ///
  /// Throws [RpsError] if any key is invalid
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

  /// Builds and validates the configuration
  ///
  /// Throws [RpsConfigurationException] if validation fails
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
