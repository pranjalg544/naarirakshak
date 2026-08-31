import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';

class ApiClient {
  static String? customBaseUrl;
  
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  static String? authToken;

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static void _handleNetworkError(Object error) {
    final errStr = error.toString();
    if (errStr.contains('ClientException') ||
        errStr.contains('Failed to fetch') ||
        errStr.contains('SocketException') ||
        errStr.contains('Connection refused')) {
      throw Exception('Unable to connect to safety server. Please ensure backend server is running.');
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      } else {
        final message = decoded['message'] ?? 'API Request failed with status ${response.statusCode}';
        throw Exception(message);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to parse API response: $e');
    }
  }
}
