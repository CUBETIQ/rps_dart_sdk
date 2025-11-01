/// RPS SDK v2 - Basic Usage Example
///
/// Simple example showing how to use the RPS SDK for webhook requests.
library;

import '../lib/rps_sdk_v2.dart';

Future<void> main() async {
  print('🚀 RPS SDK v2 - Basic Usage Example');
  print('===================================');

  await basicWebhookExample();
  await errorHandlingExample();
  await statisticsExample();
}

/// Basic webhook sending
Future<void> basicWebhookExample() async {
  print('\n📤 Basic Webhook Example');
  print('------------------------');

  // Create RPS client
  final client = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
      auth: RpsAuthUtils.apiKey('6057c8d2-3b11-4e0b-8bb8-649d9510904d'),
      timeout: const Duration(seconds: 30),
    ),
  );

  try {
    // Send a simple webhook
    final response = await client.sendWebhook(
      data: {
        'message': 'Hello from RPS SDK v2!',
        'timestamp': DateTime.now().toIso8601String(),
        'order_id': 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    print('✅ Success!');
    print('  Status: ${response.statusCode}');
    print('  Duration: ${response.duration.inMilliseconds}ms');
    print('  Response: ${response.data}');
  } on RpsHttpException catch (e) {
    print('❌ HTTP Error: ${e.statusCode}');
    print('  Message: ${e.message}');
    print('  User-friendly: ${e.userMessage}');
  } on RpsException catch (e) {
    print('❌ RPS Error: ${e.runtimeType}');
    print('  Message: ${e.message}');
    print('  Retryable: ${e.isRetryable}');
  } finally {
    await client.dispose();
  }
}

/// Error handling demonstration
Future<void> errorHandlingExample() async {
  print('\n⚠️  Error Handling Example');
  print('-------------------------');

  final client = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/status/500', // Will return 500 error
      timeout: const Duration(seconds: 10),
    ),
    retryPolicy: RetryUtils.simple(maxAttempts: 2),
  );

  try {
    await client.sendWebhook(data: {'test': 'error handling'});
  } on RpsHttpException catch (e) {
    print('✅ Caught HTTP exception as expected');
    print('  Status: ${e.statusCode}');
    print('  Is server error: ${e.isServerError}');
    print('  Is retryable: ${e.isRetryable}');
    print('  User message: ${e.userMessage}');
  } finally {
    await client.dispose();
  }
}

/// Statistics tracking example
Future<void> statisticsExample() async {
  print('\n📊 Statistics Example');
  print('---------------------');

  final client = RpsClient.create(
    config: RpsConfig(
      baseUrl: 'https://httpbin.org/post',
      timeout: const Duration(seconds: 15),
    ),
  );

  try {
    // Send multiple requests
    for (int i = 1; i <= 3; i++) {
      try {
        await client.sendWebhook(
          data: {
            'request_number': i,
            'timestamp': DateTime.now().toIso8601String(),
          },
          requestId: 'stats_test_$i',
        );
        print('✅ Request $i: Success');
      } catch (e) {
        print('❌ Request $i: Failed');
      }
    }

    // Check statistics
    final stats = client.stats;
    print('\n📈 Final Statistics:');
    print('  Total requests: ${stats.totalRequests}');
    print('  Successful: ${stats.successfulRequests}');
    print('  Failed: ${stats.failedRequests}');
    print('  Success rate: ${stats.successRate.toStringAsFixed(1)}%');
    print(
      '  Average response time: ${stats.averageResponseTime.inMilliseconds}ms',
    );
  } finally {
    await client.dispose();
  }
}
