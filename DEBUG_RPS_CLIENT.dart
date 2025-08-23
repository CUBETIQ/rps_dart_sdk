import 'dart:convert';

import 'package:rps_dart_sdk/rps_dart_sdk.dart';

// Debug version to identify the 404 issue
class DebugRpsClientService {
  late final RpsClient _client;
  final String _baseUrl;
  final String _apiKey;
  bool _initialized = false;

  static String get getApiKey => '6057c8d2-3b11-4e0b-8bb8-649d9510904d';
  static String get getUrl =>
      'https://rps.service.ctdn.net/third-party/rps/webhook';

  DebugRpsClientService({String? baseUrl, String? apiKey})
    : _baseUrl =
          baseUrl ?? 'https://rps.service.ctdn.net/third-party/rps/webhook',
      _apiKey = apiKey ?? '6057c8d2-3b11-4e0b-8bb8-649d9510904d';

  Future<void> _initializeClient() async {
    if (_initialized) return;

    try {
      // Create the builder manually to set up authentication
      final builder = RpsClientBuilder();

      // Try different base URL configurations to debug the 404
      // Option 1: Exact URL that worked in direct test
      final config1 = RpsConfigurationBuilder()
          .setBaseUrl(_baseUrl) // Full URL including /webhook
          .setApiKey(_apiKey)
          .setConnectTimeout(const Duration(seconds: 30))
          .setReceiveTimeout(const Duration(seconds: 30))
          .addCustomHeader('Authorization', 'Api-Key $_apiKey')
          .addCustomHeader('Content-Type', 'application/json')
          .build();

      // Build the client
      _client = await builder.withConfiguration(config1).build();

      print('🔧 RPS Client initialized');
      print('📍 Using Base URL: $_baseUrl');
      print('🔑 Using API Key: ${_apiKey.substring(0, 8)}...');

      await _client.initialize();
      _initialized = true;

      print('✅ RPS Client initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize RPS Client: $e');
      rethrow;
    }
  }

  String generateUniqueId() {
    final DateTime now = DateTime.now();
    final String uniqueId =
        '${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}${now.millisecond}';
    return uniqueId.hashCode.toString();
  }

  /// Debug version with multiple URL attempts
  Future<RpsResponse?> sendMessage({
    Map<String, dynamic>? input,
    String? type,
  }) async {
    try {
      await _initializeClient();

      final messageData = RpsModel(
        id: generateUniqueId(),
        type: type ?? 'invoice',
        data: input,
        details: InvoiceDetails(
          sdkVersion: '1.0.0',
          sdkPlatform: 'Dart/Client',
        ),
        createdAt: DateTime.now().toIso8601String(),
      );

      print('🔍 DEBUG INFO:');
      print('📍 Base URL: $_baseUrl');
      print('🔑 API Key: ${_apiKey.substring(0, 8)}...');
      print('📦 Message Type: ${messageData.type}');
      print('📄 Message ID: ${messageData.id}');
      print('📤 Sending RPS Message...');

      // Try the SDK call
      final response = await _client.sendMessage(
        type: messageData.type,
        data: messageData.toJson(),
        headers: {
          'Authorization': 'Api-Key $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      print('✅ SUCCESS! Status: ${response.statusCode}');
      print('📄 Response: ${response.data}');
      return response;
    } on RpsError catch (e) {
      print('❌ RPS SDK Error: ${e.message}');
      print('🔍 Error Code: ${e.code}');
      print('🔍 Error Type: ${e.type}');

      // Always try alternatives on any error to debug
      print('');
      print('🚨 ERROR ANALYSIS:');
      print('   📍 Configured Base URL: $_baseUrl');
      print('   ✅ Direct HTTP test worked to the full webhook URL');
      print(
        '   🤔 SDK might be modifying the URL or using different endpoints',
      );
      print('');
      print('💡 TRYING ALTERNATIVE URLs...');

      // Create a simple test message for alternative URL testing
      final testData = RpsModel(
        id: generateUniqueId(),
        type: type ?? 'invoice',
        data: input,
        details: InvoiceDetails(
          sdkVersion: '1.0.0',
          sdkPlatform: 'Dart/Client',
        ),
        createdAt: DateTime.now().toIso8601String(),
      );

      await _tryAlternativeConfigurations(testData);

      return null;
    } catch (e) {
      print('💥 Unexpected error: $e');
      return null;
    }
  }

  /// Try different URL configurations
  Future<void> _tryAlternativeConfigurations(RpsModel messageData) async {
    print('🔄 Trying alternative URL configurations...');

    final alternativeUrls = [
      'https://rps.service.ctdn.net/third-party/rps', // Without /webhook
      'https://rps.service.ctdn.net', // Base domain only
      'https://rps.service.ctdn.net/third-party', // Partial path
    ];

    for (String altUrl in alternativeUrls) {
      try {
        print('🔍 Testing: $altUrl');

        final builder = RpsClientBuilder();
        final config = RpsConfigurationBuilder()
            .setBaseUrl(altUrl)
            .setApiKey(_apiKey)
            .addCustomHeader('Authorization', 'Api-Key $_apiKey')
            .addCustomHeader('Content-Type', 'application/json')
            .build();

        final altClient = await builder.withConfiguration(config).build();
        await altClient.initialize();

        final response = await altClient.sendMessage(
          type: messageData.type,
          data: messageData.toJson(),
          headers: {
            'Authorization': 'Api-Key $_apiKey',
            'Content-Type': 'application/json',
          },
        );

        print('✅ SUCCESS with alternative URL: $altUrl');
        print('📄 Response: ${response.data}');

        await altClient.dispose();
        return;
      } catch (e) {
        print('❌ $altUrl failed: ${e.toString().split('\n').first}');
      }
    }

    print('❌ All alternative URLs failed');
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _client.dispose();
    }
  }
}

class RpsModel {
  final String id;
  final String type;
  final dynamic data;
  final InvoiceDetails details;
  final String? createdAt;
  final String? sendAt;

  RpsModel({
    required this.id,
    required this.type,
    required this.data,
    required this.details,
    this.createdAt,
    this.sendAt,
  });

  factory RpsModel.fromJson(Map<String, dynamic> json) => RpsModel(
    id: json['id'] as String,
    type: json['type'] as String,
    data: json['data'],
    details: InvoiceDetails.fromJson(json['details'] as Map<String, dynamic>),
    createdAt: json['createdAt'] as String?,
    sendAt: json['sendAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'details': details.toJson(),
    'createdAt': createdAt,
    'sendAt': sendAt,
  };

  @override
  String toString() => jsonEncode(toJson());
}

class InvoiceDetails {
  final String sdkVersion;
  final String sdkPlatform;

  InvoiceDetails({required this.sdkVersion, required this.sdkPlatform});

  factory InvoiceDetails.fromJson(Map<String, dynamic> json) => InvoiceDetails(
    sdkVersion: json['sdk_version'] as String,
    sdkPlatform: json['sdk_platform'] as String,
  );

  Map<String, dynamic> toJson() => {
    'sdk_version': sdkVersion,
    'sdk_platform': sdkPlatform,
  };
}

void main() {
  final debugClient = DebugRpsClientService();

  // Test sending a message
  debugClient
      .sendMessage(
        input: {
          'amount': 100.0,
          'currency': 'USD',
          'description': 'Test Invoice',
        },
        type: 'invoice',
      )
      .then((response) {
        if (response != null) {
          print('Final Response: ${response.data}');
        } else {
          print('No response received.');
        }
      })
      .catchError((error) {
        print('Error during sendMessage: $error');
      })
      .whenComplete(() async {
        await debugClient.dispose();
        print('Client disposed.');
      });
}
