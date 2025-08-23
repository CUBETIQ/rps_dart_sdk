# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-08-23

### Added

- **Enhanced cache storage system** with multiple backend support
  - In-memory cache storage (default, fastest)
  - SharedPreferences cache storage (persistent, small data)
  - Hive CE cache storage (high-performance, large data)
- **Intelligent cache storage factory** with auto-selection based on requirements
- **Enhanced configuration builder** with fluent API for cache storage selection
- **Pre-configured client factories** for common use cases
- **Configurable retry intervals** for cached request processing
- **Comprehensive migration guide** for upgrading from single storage to multi-storage

### Changed

- **BREAKING**: Client creation is now async to support storage initialization
- **BREAKING**: Factory methods now return `Future<RpsClient>` instead of `RpsClient`
- Updated from `hive` to `hive_ce` (Community Edition) for better performance and features
- Enhanced client builder supports storage-aware cache management

### Dependencies

- Added `hive_ce: ^2.11.3` for high-performance cache storage
- Added `hive_ce_flutter: ^2.3.1` for Flutter integration
- Added `hive_ce_generator: ^1.9.3` for code generation (dev dependency)
- Updated `shared_preferences: ^2.5.3` for simple persistent storage

### Documentation

- Added comprehensive cache migration guide
- Added usage examples for all storage types
- Updated API documentation with new cache features

## [0.0.1] - Initial Release

### Added

- Initial RPS Dart SDK implementation
- Basic HTTP transport with Dio
- Request validation and error handling
- Retry mechanisms with exponential backoff
- Simple in-memory caching
- Event system for monitoring
- Comprehensive logging
