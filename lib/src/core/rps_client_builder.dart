/// Modern RPS Client Builder with fluent API and dependency injection
///
/// This file implements the builder pattern for creating RpsClient instances
/// with fluent API, dependency injection for all pluggable components, and
/// factory methods for common SDK configurations.
library;

import 'dart:async';

import 'package:rps_dart_sdk/src/core/core.dart';

import '../auth/authentication_provider.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_storage.dart';
import '../cache/cache_storage_factory.dart';
import '../cache/in_memory_cache_storage.dart';
import '../transport/http_transport.dart';
import 'rps_client.dart';

class RpsClientBuilder {
  RpsConfiguration? _configuration;
  HttpTransport? _transport;
  RequestValidator? _validator;
  CacheManager? _cacheManager;
  LoggingManager? _logger;
  RpsEventBus? _eventBus;
  AuthenticationProvider? _authProvider;

  /// Set the configuration for the client
  RpsClientBuilder withConfiguration(RpsConfiguration configuration) {
    _configuration = configuration;
    return this;
  }

  /// Set the HTTP transport for the client
  RpsClientBuilder withTransport(HttpTransport transport) {
    _transport = transport;
    return this;
  }

  /// Set the request validator for the client
  RpsClientBuilder withValidator(RequestValidator validator) {
    _validator = validator;
    return this;
  }

  /// Set the cache manager for the client
  RpsClientBuilder withCacheManager(CacheManager cacheManager) {
    _cacheManager = cacheManager;
    return this;
  }

  /// Set the logger for the client
  RpsClientBuilder withLogger(LoggingManager logger) {
    _logger = logger;
    return this;
  }

  /// Set the event bus for the client
  RpsClientBuilder withEventBus(RpsEventBus eventBus) {
    _eventBus = eventBus;
    return this;
  }

  Future<RpsClient> build() async {
    if (_configuration == null) {
      throw RpsError.configuration(message: 'Configuration is required');
    }

    _configuration!.validate();

    if (_transport == null) {
      _transport = await DioHttpTransport.create(
        config: _configuration!,
        authProvider: _authProvider,
        logger: _logger,
      );
    }

    if (_validator == null) {
      _validator = DefaultRequestValidator();
    }

    if (_cacheManager == null &&
        _configuration!.cachePolicy.enableOfflineCache) {
      final storage = InMemoryCacheStorage();
      _cacheManager = CacheManager(
        storage: storage,
        policy: _configuration!.cachePolicy,
        logger: _logger,
      );
    }

    final client = RpsClient.create(
      config: _configuration!,
      transport: _transport!,
      validator: _validator!,
      cacheManager: _cacheManager,
      logger: _logger,
      eventBus: _eventBus,
    );

    return client;
  }

  /// Create a simple client for basic webhook usage (in-memory cache)
  static Future<RpsClient> createSimple({
    required String webhookUrl,
    required String apiKey,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(webhookUrl)
        .setApiKey(apiKey)
        .useInMemoryCache()
        .setConnectTimeout(connectTimeout ?? const Duration(seconds: 30))
        .setReceiveTimeout(receiveTimeout ?? const Duration(seconds: 60))
        .build();

    // Create cache manager with in-memory storage
    final storage = InMemoryCacheStorage();
    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .build();
  }

  /// Create a production client with persistent cache
  static Future<RpsClient> createProduction({
    required String webhookUrl,
    required String apiKey,
    CacheStorageType storageType = CacheStorageType.hive,
    Duration? cacheMaxAge,
    RpsLogLevel logLevel = RpsLogLevel.warning,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(webhookUrl)
        .setApiKey(apiKey)
        .setConnectTimeout(const Duration(seconds: 30))
        .setReceiveTimeout(const Duration(seconds: 60))
        .build();

    // Create cache manager with selected storage type
    final storage = await CacheStorageFactory.create(
      type: storageType,
      config: cacheMaxAge != null ? {'maxAge': cacheMaxAge} : null,
    );
    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );
    await cacheManager.initialize();

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .withLogger(SimpleLoggingManager(level: logLevel))
        .build();
  }

  /// Create a high-performance client with Hive CE cache
  static Future<RpsClient> createHighPerformance({
    required String webhookUrl,
    required String apiKey,
    String? hiveBoxName,
    Duration? cacheMaxAge,
    RpsLogLevel logLevel = RpsLogLevel.info,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(webhookUrl)
        .setApiKey(apiKey)
        .setConnectTimeout(const Duration(seconds: 30))
        .setReceiveTimeout(const Duration(seconds: 60))
        .build();

    // Create cache manager with Hive CE storage
    final storage = await CacheStorageFactory.create(
      type: CacheStorageType.hive,
      config: {
        'boxName': hiveBoxName ?? 'rps_cache',
        'maxAge': cacheMaxAge ?? const Duration(days: 7),
      },
    );
    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );
    await cacheManager.initialize();

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .withLogger(SimpleLoggingManager(level: logLevel))
        .build();
  }

  /// Create a client optimized for offline-first usage
  static Future<RpsClient> createOfflineFirst({
    required String webhookUrl,
    required String apiKey,
    CacheStorageType storageType = CacheStorageType.hive,
    Duration? cacheMaxAge,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(webhookUrl)
        .setApiKey(apiKey)
        .offlineFirst()
        .build();

    // Create cache manager with selected storage type
    final storage = await CacheStorageFactory.create(
      type: storageType,
      config: cacheMaxAge != null ? {'maxAge': cacheMaxAge} : null,
    );
    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );
    await cacheManager.initialize();

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .withLogger(SimpleLoggingManager(level: RpsLogLevel.debug))
        .build();
  }

  /// Create an Android-compatible offline-first client with automatic fallback
  static Future<RpsClient> createAndroidOfflineFirst({
    required String webhookUrl,
    required String apiKey,
    String? cachePath,
    Duration? cacheMaxAge,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(webhookUrl)
        .setApiKey(apiKey)
        .offlineFirst()
        .build();

    CacheStorage? storage;

    try {
      // Try to create Hive storage with custom path or fallback paths
      storage = await CacheStorageFactory.create(
        type: CacheStorageType.hive,
        config: {
          if (cachePath != null) 'path': cachePath,
          if (cacheMaxAge != null) 'maxAge': cacheMaxAge,
        },
      );
    } catch (e) {
      // If Hive fails (likely due to read-only filesystem), fall back to in-memory
      print(
        'Warning: Hive cache initialization failed, falling back to in-memory cache. Error: $e',
      );
      storage = await CacheStorageFactory.create(
        type: CacheStorageType.inMemory,
        config: cacheMaxAge != null ? {'maxAge': cacheMaxAge} : null,
      );
    }

    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );
    await cacheManager.initialize();

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .withLogger(SimpleLoggingManager(level: RpsLogLevel.debug))
        .build();
  }

  /// Configure for specific webhook endpoint with auto cache selection
  static Future<RpsClient> forWebhook({
    required String url,
    required String apiKey,
    bool needsPersistence = true,
    bool isHighFrequency = false,
    bool isLargeData = false,
    Duration? cacheMaxAge,
    RpsLogLevel logLevel = RpsLogLevel.info,
  }) async {
    final config = RpsConfigurationBuilder()
        .setBaseUrl(url)
        .setApiKey(apiKey)
        .setConnectTimeout(const Duration(seconds: 30))
        .setReceiveTimeout(const Duration(seconds: 60))
        .build();

    // Auto-select storage type
    final storageType = CacheStorageFactory.getRecommendedStorageType(
      needsPersistence: needsPersistence,
      isHighFrequency: isHighFrequency,
      isLargeData: isLargeData,
    );

    final storage = await CacheStorageFactory.create(
      type: storageType,
      config: cacheMaxAge != null ? {'maxAge': cacheMaxAge} : null,
    );
    final cacheManager = CacheManager(
      storage: storage,
      policy: config.cachePolicy,
    );
    await cacheManager.initialize();

    return RpsClientBuilder()
        .withConfiguration(config)
        .withCacheManager(cacheManager)
        .withLogger(SimpleLoggingManager(level: logLevel))
        .build();
  }

  /// Validate builder configuration before creating client
  void validateConfiguration() {
    if (_configuration == null) {
      throw RpsError.configuration(message: 'Configuration is required');
    }

    _configuration!.validate();

    // Additional validation logic can be added here
  }

  /// Reset builder to initial state
  RpsClientBuilder reset() {
    _configuration = null;
    _transport = null;
    _validator = null;
    _cacheManager = null;
    _logger = null;
    _eventBus = null;
    _authProvider = null;
    return this;
  }

  /// Create a copy of this builder
  RpsClientBuilder copy() {
    final builder = RpsClientBuilder();
    builder._configuration = _configuration;
    builder._transport = _transport;
    builder._validator = _validator;
    builder._cacheManager = _cacheManager;
    builder._logger = _logger;
    builder._eventBus = _eventBus;
    builder._authProvider = _authProvider;
    return builder;
  }
}
