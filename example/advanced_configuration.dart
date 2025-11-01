/// RPS SDK v2 - Advanced Configuration Example
///
/// Shows advanced features like retry policies, authentication methods, and monitoring.
library;

import 'dart:async';
import '../lib/rps_sdk_v2.dart';

Future<void> main() async {
  print('⚙️ RPS SDK v2 - Advanced Configuration');
  print('=====================================');

  await customRetryPolicyExample();
  await authenticationMethodsExample();
  await monitoringAndHealthExample();
  await productionSetupExample();
}

/// Custom retry policy configuration
Future<void> customRetryPolicyExample() async {
  print('\n🔄 Custom Retry Policy Example');
  print('------------------------------');

  // Create different retry policies for different scenarios

  // 1. Aggressive retry for critical operations
  final aggressiveClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/status/503', // Service unavailable
      timeout: const Duration(seconds: 10),
    ),
    retryPolicy: RetryUtils.aggressive(
      maxAttempts: 5,
      baseDelay: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 8),
    ),
  );

  print('Testing aggressive retry policy...');
  try {
    await aggressiveClient.sendWebhook(
      data: {'test': 'aggressive_retry', 'critical': true},
    );
  } on RpsHttpException catch (e) {
    print('❌ Failed after aggressive retries: ${e.statusCode}');
    print('  Total attempts: ${aggressiveClient.stats.totalRequests}');
  } finally {
    await aggressiveClient.dispose();
  }

  // 2. Conservative retry for non-critical operations
  final conservativeClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/status/503',
      timeout: const Duration(seconds: 15),
    ),
    retryPolicy: RetryUtils.conservative(
      maxAttempts: 2,
      baseDelay: const Duration(seconds: 3),
      maxDelay: const Duration(minutes: 1),
    ),
  );

  print('\nTesting conservative retry policy...');
  try {
    await conservativeClient.sendWebhook(
      data: {'test': 'conservative_retry', 'critical': false},
    );
  } on RpsHttpException catch (e) {
    print('❌ Failed after conservative retries: ${e.statusCode}');
    print('  Total attempts: ${conservativeClient.stats.totalRequests}');
  } finally {
    await conservativeClient.dispose();
  }

  // 3. Custom retry policy
  final customRetryConfig = RetryConfig(
    maxAttempts: 4,
    baseDelay: const Duration(seconds: 2),
    maxDelay: const Duration(seconds: 20),
    useExponentialBackoff: true,
    useJitter: true,
  );

  final customClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post', // Working endpoint
      retryConfig: customRetryConfig,
    ),
  );

  print('\nTesting custom retry configuration...');
  try {
    final response = await customClient.sendWebhook(
      data: {'test': 'custom_retry', 'success': true},
    );
    print('✅ Success with custom config: ${response.statusCode}');
  } finally {
    await customClient.dispose();
  }
}

/// Different authentication methods
Future<void> authenticationMethodsExample() async {
  print('\n🔐 Authentication Methods Example');
  print('---------------------------------');

  final testData = {
    'auth_test': 'methods_comparison',
    'timestamp': DateTime.now().toIso8601String(),
  };

  // 1. API Key Authentication
  print('1. API Key Authentication:');
  final apiKeyClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      auth: RpsAuthUtils.apiKey('your-api-key-here'),
    ),
  );

  try {
    final response = await apiKeyClient.sendWebhook(data: testData);
    print('  ✅ API Key method working');

    // Check if API key was included in headers
    if (response.data.containsKey('headers')) {
      final headers = response.data['headers'] as Map;
      print('  📋 X-API-Key header: ${headers['X-Api-Key'] ?? 'Not found'}');
    }
  } finally {
    await apiKeyClient.dispose();
  }

  // 2. Bearer Token Authentication
  print('\n2. Bearer Token Authentication:');
  final bearerClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      auth: RpsAuthUtils.bearer('your-token-here'),
    ),
  );

  try {
    final response = await bearerClient.sendWebhook(data: testData);
    print('  ✅ Bearer token method working');

    if (response.data.containsKey('headers')) {
      final headers = response.data['headers'] as Map;
      print(
        '  📋 Authorization header: ${headers['Authorization'] ?? 'Not found'}',
      );
    }
  } finally {
    await bearerClient.dispose();
  }

  // 3. Custom Authentication
  print('\n3. Custom Authentication:');
  final customClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      auth: RpsAuthUtils.custom({
        'X-Custom-Auth': 'custom-value',
        'X-API-Version': '2.0',
        'X-Client-ID': 'posara-cafe',
      }, name: 'posara_custom'),
    ),
  );

  try {
    final response = await customClient.sendWebhook(data: testData);
    print('  ✅ Custom auth method working');

    if (response.data.containsKey('headers')) {
      final headers = response.data['headers'] as Map;
      print(
        '  📋 Custom headers included: ${headers.keys.where((k) => k.toString().startsWith('X-')).toList()}',
      );
    }
  } finally {
    await customClient.dispose();
  }

  // 4. No Authentication
  print('\n4. No Authentication:');
  final noAuthClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      // No auth specified
    ),
  );

  try {
    await noAuthClient.sendWebhook(data: testData);
    print('  ✅ No auth method working for public endpoints');
  } finally {
    await noAuthClient.dispose();
  }
}

/// Monitoring and health checking
Future<void> monitoringAndHealthExample() async {
  print('\n📊 Monitoring and Health Example');
  print('--------------------------------');

  final client = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      enableOfflineCache: true,
      maxOfflineCacheSize: 20,
    ),
  );

  // 1. Health Check
  print('🏥 Health Check:');
  final isHealthy = await client.isHealthy();
  print('  API Health: ${isHealthy ? "✅ Healthy" : "❌ Unhealthy"}');

  // 2. Send multiple requests to generate statistics
  print('\n📈 Generating Statistics:');
  for (int i = 1; i <= 5; i++) {
    try {
      await client.sendWebhook(
        data: {
          'request_number': i,
          'test_type': 'monitoring',
          'timestamp': DateTime.now().toIso8601String(),
        },
        requestId: 'monitor_$i',
      );
      print('  Request $i: ✅');
    } catch (e) {
      print('  Request $i: ❌');
    }
  }

  // 3. Check Statistics
  final stats = client.stats;
  print('\n📊 Request Statistics:');
  print('  Total requests: ${stats.totalRequests}');
  print('  Successful: ${stats.successfulRequests}');
  print('  Failed: ${stats.failedRequests}');
  print('  Success rate: ${stats.successRate.toStringAsFixed(1)}%');
  print(
    '  Average response time: ${stats.averageResponseTime.inMilliseconds}ms',
  );
  print('  Last request: ${stats.lastRequestTime}');

  // 4. Cache Statistics
  final cacheStats = await client.getOfflineCacheStats();
  if (cacheStats != null) {
    print('\n📦 Cache Statistics:');
    print('  Cached requests: ${cacheStats.totalRequests}');
    print('  Retryable: ${cacheStats.retryableRequests}');
    print('  Expired: ${cacheStats.expiredRequests}');
    if (cacheStats.oldestRequestAge.inMinutes > 0) {
      print(
        '  Oldest request: ${cacheStats.oldestRequestAge.inMinutes} minutes ago',
      );
    }
  }

  await client.dispose();
}

/// Production-ready setup
Future<void> productionSetupExample() async {
  print('\n🏭 Production Setup Example');
  print('---------------------------');

  // Production configuration
  final productionClient = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
      auth: RpsAuthUtils.apiKey('6057c8d2-3b11-4e0b-8bb8-649d9510904d'),
      timeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'POSARA-CAFE/2.0.0',
        'X-Client-Version': 'RPS-SDK-v2.0.0',
        'X-Environment': 'production',
      },
      enableOfflineCache: true,
      maxOfflineCacheSize: 100,
      retryConfig: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
        useExponentialBackoff: true,
        useJitter: true,
      ),
    ),
    retryPolicy: RetryUtils.simple(maxAttempts: 3),
  );

  // Set up monitoring timer
  Timer? monitoringTimer;

  void startMonitoring() {
    print('🔍 Starting production monitoring...');

    monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      // Process offline cache
      await productionClient.processOfflineCache();

      // Check cache health
      final cacheStats = await productionClient.getOfflineCacheStats();
      if (cacheStats != null && cacheStats.retryableRequests > 0) {
        print(
          '⚠️  Warning: ${cacheStats.retryableRequests} requests in offline cache',
        );
      }

      // Clean up expired requests
      final cleaned = await productionClient.cleanupOfflineCache();
      if (cleaned > 0) {
        print('🧹 Cleaned up $cleaned expired cache entries');
      }

      // Log statistics
      final stats = productionClient.stats;
      if (stats.totalRequests > 0) {
        print(
          '📊 Stats: ${stats.totalRequests} total, ${stats.successRate.toStringAsFixed(1)}% success',
        );
      }
    });
  }

  // Production error handling
  Future<void> sendProductionWebhook(
    Map<String, dynamic> data,
    String type,
  ) async {
    try {
      final response = await productionClient.sendWebhook(
        data: data,
        headers: {'X-Request-Type': type, 'X-Station-ID': 'POS-001'},
      );

      print('✅ $type sent successfully (${response.statusCode})');
    } on RpsHttpException catch (e) {
      print('❌ $type failed: HTTP ${e.statusCode}');

      // Log for monitoring
      print('  Error: ${e.message}');
      print('  Retryable: ${e.isRetryable}');

      // In production, you might send this to your monitoring system
      if (e.statusCode >= 500) {
        print('  🚨 Server error - consider alerting operations team');
      }
    } on RpsTimeoutException catch (e) {
      print('❌ $type timed out after ${e.timeout.inSeconds}s');
      print('  🔄 Request cached for retry');
    } on RpsNetworkException catch (e) {
      print('❌ $type network error: ${e.message}');
      print('  🔄 Request cached for retry');
    } on RpsException catch (e) {
      print('❌ $type failed: ${e.runtimeType} - ${e.message}');

      if (!e.isRetryable) {
        print('  ⚠️  Non-retryable error - requires manual intervention');
      }
    }
  }

  // Start monitoring
  startMonitoring();

  // Example production usage
  print('\n🖨️ Production Webhook Examples:');

  // 1. Customer Receipt
  await sendProductionWebhook({
    'type': 'customer_receipt',
    'order_id': 'ORD_${DateTime.now().millisecondsSinceEpoch}',
    'total': 25.99,
    'items': ['Americano', 'Sandwich'],
    'payment_method': 'credit_card',
  }, 'receipt');

  // 2. Kitchen Order
  await sendProductionWebhook({
    'type': 'kitchen_order',
    'order_id': 'KIT_${DateTime.now().millisecondsSinceEpoch}',
    'table': 'Table 7',
    'items': ['Latte', 'Pastry'],
    'priority': 'normal',
  }, 'kitchen');

  // 3. Payment Confirmation
  await sendProductionWebhook({
    'type': 'payment_confirmation',
    'payment_id': 'PAY_${DateTime.now().millisecondsSinceEpoch}',
    'amount': 25.99,
    'method': 'contactless',
    'status': 'approved',
  }, 'payment');

  // Final statistics
  await Future.delayed(const Duration(seconds: 2));
  final finalStats = productionClient.stats;
  print('\n📈 Final Production Statistics:');
  print('  Requests processed: ${finalStats.totalRequests}');
  print('  Success rate: ${finalStats.successRate.toStringAsFixed(1)}%');
  print(
    '  Average response time: ${finalStats.averageResponseTime.inMilliseconds}ms',
  );

  // Cleanup
  monitoringTimer?.cancel();
  await productionClient.dispose();

  print('\n✅ Production example completed');
}

/// Utility class for production monitoring
class ProductionMonitor {
  final RpsClient client;
  Timer? _monitoringTimer;

  ProductionMonitor(this.client);

  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _monitoringTimer = Timer.periodic(interval, (timer) async {
      await _performHealthCheck();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  Future<void> _performHealthCheck() async {
    // Process offline cache
    await client.processOfflineCache();

    // Check cache health
    final cacheStats = await client.getOfflineCacheStats();
    if (cacheStats != null) {
      final utilizationPercent =
          (cacheStats.totalRequests / client.config.maxOfflineCacheSize) * 100;

      if (utilizationPercent > 80) {
        print(
          '⚠️  Cache utilization high: ${utilizationPercent.toStringAsFixed(1)}%',
        );
      }

      if (cacheStats.expiredRequests > 10) {
        final cleaned = await client.cleanupOfflineCache();
        print('🧹 Cleaned $cleaned expired requests');
      }
    }

    // Check request statistics
    final stats = client.stats;
    if (stats.successRate < 95 && stats.totalRequests > 10) {
      print('🚨 Low success rate: ${stats.successRate.toStringAsFixed(1)}%');
    }
  }

  Map<String, dynamic> getHealthReport() {
    final stats = client.stats;
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'total_requests': stats.totalRequests,
      'success_rate': stats.successRate,
      'average_response_time_ms': stats.averageResponseTime.inMilliseconds,
      'has_offline_cache': client.hasOfflineCache,
      'last_request_time': stats.lastRequestTime?.toIso8601String(),
    };
  }
}
