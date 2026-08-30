import '../core/network/api_client.dart';

class AuthApiService {
  static Future<bool> requestOtp(String phone) async {
    final response = await ApiClient.post('/auth/request-otp', {
      'phone': phone,
    });
    return response['success'] == true;
  }

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await ApiClient.post('/auth/verify-otp', {
      'phone': phone,
      'otp': otp,
    });

    if (response['success'] == true && response['token'] != null) {
      ApiClient.authToken = response['token'] as String;
    }
    return response;
  }

  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post('/auth/signup', {
      'fullName': fullName,
      'email': email,
      'password': password,
    });

    if (response['success'] == true && response['token'] != null) {
      ApiClient.authToken = response['token'] as String;
    }
    return response;
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response['success'] == true && response['token'] != null) {
      ApiClient.authToken = response['token'] as String;
    }
    return response;
  }
}
