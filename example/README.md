# RPS SDK v2 Examples

This directory contains comprehensive examples showing how to use the RPS SDK v2 for webhook-based printing and API requests.

## 📁 Example Files

### 🚀 [basic_usage.dart](basic_usage.dart)
**Perfect for getting started**
- Simple webhook sending
- Basic error handling
- Statistics tracking
- Quick setup and configuration

**Run it:**
```bash
dart run example/basic_usage.dart
```

### 🖨️ [pos_printing.dart](pos_printing.dart)
**Real-world POS system examples**
- Customer receipt printing
- Kitchen order printing
- Payment confirmation
- Offline caching for reliability
- POSARA Cafe specific scenarios

**Run it:**
```bash
dart run example/pos_printing.dart
```

### ⚙️ [advanced_configuration.dart](advanced_configuration.dart)
**Production-ready setup**
- Custom retry policies
- Multiple authentication methods
- Health monitoring and statistics
- Production deployment patterns
- Automatic cache management

**Run it:**
```bash
dart run example/advanced_configuration.dart
```

---

## 🎯 Quick Start

### 1. Basic Webhook
```dart
import 'package:rps_dart_sdk/rps_sdk_v2.dart';

final client = RpsClient.create(
  config: RpsConfig(
    baseUrl: 'https://your-api.com/webhook',
    auth: RpsAuthUtils.apiKey('your-api-key'),
  ),
);

final response = await client.sendWebhook(
  data: {'message': 'Hello, webhook!'},
);

print('Status: ${response.statusCode}');
await client.dispose();
```

### 2. POS Receipt Printing
```dart
final client = RpsClient.create(
  config: RpsConfig(
    baseUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    auth: RpsAuthUtils.apiKey('6057c8d2-3b11-4e0b-8bb8-649d9510904d'),
    enableOfflineCache: true, // Cache failed requests
  ),
);

await client.sendWebhook(
  data: {
    'type': 'customer_receipt',
    'receipt': {
      'order_number': 'ORD_12345',
      'items': [
        {'name': 'Americano', 'qty': 2, 'price': 4.50},
        {'name': 'Croissant', 'qty': 1, 'price': 3.50},
      ],
      'total': 12.50,
    },
  },
);
```

### 3. Error Handling
```dart
try {
  await client.sendWebhook(data: orderData);
} on RpsHttpException catch (e) {
  print('HTTP Error: ${e.statusCode}');
  print('User message: ${e.userMessage}');
} on RpsException catch (e) {
  print('RPS Error: ${e.message}');
  print('Retryable: ${e.isRetryable}');
}
```

---

## 🔧 Configuration Options

### Basic Configuration
```dart
RpsConfig(
  baseUrl: 'https://api.example.com/webhook',
  timeout: Duration(seconds: 30),
  enableOfflineCache: true,
)
```

### Authentication Methods
```dart
// API Key
auth: RpsAuthUtils.apiKey('your-key'),

// Bearer Token
auth: RpsAuthUtils.bearer('your-token'),

// Custom Headers
auth: RpsAuthUtils.custom({
  'X-API-Key': 'your-key',
  'X-Client-ID': 'posara-cafe',
}),
```

### Retry Policies
```dart
// Simple retry (default)
retryPolicy: RetryUtils.simple(maxAttempts: 3),

// Aggressive (more attempts, faster)
retryPolicy: RetryUtils.aggressive(),

// Conservative (fewer attempts, slower)
retryPolicy: RetryUtils.conservative(),

// No retries
retryPolicy: RetryUtils.noRetry(),
```

### Offline Caching
```dart
RpsConfig(
  enableOfflineCache: true,
  maxOfflineCacheSize: 100,
)

// Process cached requests when online
await client.processOfflineCache();

// Check cache status
final stats = await client.getOfflineCacheStats();
print('Cached: ${stats.retryableRequests} requests');
```

---

## 🖨️ POS Integration Examples

### Customer Receipt
```dart
final receiptData = {
  'type': 'customer_receipt',
  'business': {
    'name': 'POSARA CAFE',
    'address': '123 Coffee Street',
    'phone': '+1-555-COFFEE',
  },
  'transaction': {
    'id': 'TXN_12345',
    'cashier': 'John Doe',
    'station': 'POS-001',
  },
  'items': [
    {'name': 'Americano', 'qty': 2, 'price': 4.50, 'total': 9.00},
    {'name': 'Croissant', 'qty': 1, 'price': 3.50, 'total': 3.50},
  ],
  'totals': {
    'subtotal': 12.50,
    'tax': 1.25,
    'total': 13.75,
  },
  'payment': {
    'method': 'Credit Card',
    'last4': '****4242',
  },
};
```

### Kitchen Order
```dart
final kitchenOrder = {
  'type': 'kitchen_order',
  'order_id': 'KIT_12345',
  'table': 'Table 5',
  'items': [
    {
      'item': 'Americano',
      'quantity': 2,
      'modifications': ['Extra hot', 'Oat milk'],
      'allergy_notes': 'No nuts',
    },
  ],
  'special_instructions': 'Customer celebrating anniversary',
};
```

### Payment Confirmation
```dart
final paymentData = {
  'type': 'payment_confirmation',
  'payment_id': 'PAY_12345',
  'amount': 13.75,
  'method': 'contactless',
  'status': 'approved',
  'authorization_code': 'AUTH123456',
};
```

---

## 📊 Monitoring & Statistics

### Request Statistics
```dart
final stats = client.stats;
print('Total: ${stats.totalRequests}');
print('Success rate: ${stats.successRate}%');
print('Avg time: ${stats.averageResponseTime.inMilliseconds}ms');
```

### Cache Statistics
```dart
final cacheStats = await client.getOfflineCacheStats();
print('Cached: ${cacheStats.retryableRequests}');
print('Expired: ${cacheStats.expiredRequests}');
```

### Health Monitoring
```dart
// Check if API is healthy
final isHealthy = await client.isHealthy();

// Automatic monitoring
Timer.periodic(Duration(minutes: 5), (_) async {
  await client.processOfflineCache();
  await client.cleanupOfflineCache();
});
```

---

## 🚨 Error Handling

### Exception Types
- **`RpsHttpException`**: HTTP status errors (4xx, 5xx)
- **`RpsTimeoutException`**: Request timeouts
- **`RpsNetworkException`**: Network connectivity issues
- **`RpsConfigException`**: Configuration errors
- **`RpsCancelledException`**: Cancelled requests
- **`RpsIdempotencyException`**: Duplicate request prevention

### User-Friendly Messages
```dart
try {
  await client.sendWebhook(data: data);
} on RpsException catch (e) {
  // Technical message
  print('Error: ${e.message}');
  
  // User-friendly message
  showUserMessage(e.userMessage);
  
  // Severity level
  print('Severity: ${e.severity}');
  
  // Retry recommendation
  if (e.isRetryable) {
    print('Will retry automatically');
  }
}
```

---

## 🏭 Production Deployment

### Recommended Configuration
```dart
final client = RpsClient.create(
  config: RpsConfig(
    baseUrl: 'https://rps.service.ctdn.net/third-party/rps/webhook',
    auth: RpsAuthUtils.apiKey('your-production-key'),
    timeout: Duration(seconds: 30),
    headers: {
      'User-Agent': 'POSARA-CAFE/2.0.0',
      'X-Environment': 'production',
    },
    enableOfflineCache: true,
    maxOfflineCacheSize: 200,
    retryConfig: RetryConfig(
      maxAttempts: 3,
      baseDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 30),
      useExponentialBackoff: true,
      useJitter: true,
    ),
  ),
);
```

### Monitoring Setup
```dart
// Set up periodic cache processing
Timer.periodic(Duration(minutes: 5), (_) async {
  await client.processOfflineCache();
  
  final stats = await client.getOfflineCacheStats();
  if (stats.retryableRequests > 50) {
    // Alert operations team
    sendAlert('High cache usage: ${stats.retryableRequests} pending');
  }
});
```

### Graceful Shutdown
```dart
// In your app shutdown process
await client.processOfflineCache(); // Process any pending requests
await client.dispose(); // Clean up resources
```

---

## 🔍 Troubleshooting

### Common Issues

#### 403 Forbidden
```
Problem: API key recognized but access denied
Solution: Contact RPS support to activate API key
```

#### Requests Not Retrying
```
Problem: Failed requests not being retried
Check: Ensure enableOfflineCache: true in config
Check: Verify error is retryable (e.isRetryable)
```

#### High Memory Usage
```
Problem: Too many cached requests
Solution: Reduce maxOfflineCacheSize or increase cache processing frequency
```

#### Slow Performance
```
Problem: Requests taking too long
Solution: Reduce timeout duration or check network connectivity
```

### Debug Mode
```dart
// Enable verbose logging (in development only)
final client = RpsClient.create(
  config: RpsConfig(
    baseUrl: 'your-url',
    headers: {'X-Debug': 'true'},
  ),
);
```

---

## 📚 Additional Resources

- **[Main README](../README.md)**: Project overview and setup
- **[API Documentation](../lib/rps_sdk_v2.dart)**: Complete API reference
- **[Test Examples](../test/rps_sdk_v2_test.dart)**: Unit test examples
- **[Real API Tests](../test/real_rps_api_test.dart)**: Integration test examples

---

## 🤝 Contributing

Found an issue or want to improve the examples?
1. Check existing issues and examples
2. Create a minimal reproduction case
3. Submit a pull request with improvements

---

## ⚡ Performance Tips

1. **Reuse clients** instead of creating new ones for each request
2. **Enable offline caching** for reliability in poor network conditions
3. **Set appropriate timeouts** based on your network environment
4. **Monitor cache size** to prevent memory issues
5. **Process offline cache regularly** to ensure timely delivery
6. **Use appropriate retry policies** for different request types

---

**Happy coding with RPS SDK v2!** 🚀