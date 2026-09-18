import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Api {
  static const String _configuredUrl = String.fromEnvironment('API_URL');
  static String? token;

  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:5000';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5000'
        : 'http://localhost:5000';
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (error) {
      if (_isApiError(error)) rethrow;
      throw Exception(_connectionMessage);
    }
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (error) {
      if (_isApiError(error)) rethrow;
      throw Exception(_connectionMessage);
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? data['error'] ?? 'Request failed');
    }
    return data;
  }

  static bool _isApiError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception:') &&
        !text.contains('ClientException') &&
        !text.contains('TimeoutException');
  }

  static String get _connectionMessage =>
      'Cannot reach the SuperMart API at $baseUrl. '
      'Start Flask or configure the deployed API URL.';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

String money(dynamic value) =>
    'Rs. ${(value is num ? value : num.tryParse('$value') ?? 0).toStringAsFixed(2)}';

class AsyncPanel extends StatelessWidget {
  const AsyncPanel({super.key, required this.future, required this.builder});
  final Future<Map<String, dynamic>> future;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }
      return builder(snapshot.data!);
    },
  );
}
