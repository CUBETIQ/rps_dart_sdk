/// Modern RPS Dart SDK
///
/// A comprehensive SDK for the RPS (Remote Printing Service) with modern
/// architecture, offline support, retry logic, and comprehensive error handling.
library rps_dart_sdk;

// Core Modern Client
export 'src/core/rps_client.dart';
export 'src/core/rps_client_builder.dart';
export 'src/core/configuration.dart';
export 'src/core/models.dart';
export 'src/core/error.dart';
export 'src/core/simple_logger.dart';
export 'src/core/events.dart';

// Authentication
export 'src/auth/authentication_provider.dart';

// Caching
export 'src/cache/cache.dart'; // This exports all cache implementations
export 'src/cache/cache_storage_factory.dart';

// Transport
export 'src/transport/http_transport.dart';
export 'src/transport/connection_manager.dart';
export 'src/transport/interceptors.dart';

// Validation
export 'src/validation/request_validator.dart';

// Retry
export 'src/retry/retry_policy.dart';
