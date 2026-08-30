import '../core/network/api_client.dart';

class CommuteApiService {
  static Future<Map<String, dynamic>> startCommute({
    required String originName,
    required String destinationName,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final response = await ApiClient.post('/commute/start', {
      'originName': originName,
      'destinationName': destinationName,
      'originLat': originLat,
      'originLng': originLng,
      'destLat': destLat,
      'destLng': destLng,
    });
    return response;
  }

  static Future<bool> checkInSafe(String commuteId) async {
    final response = await ApiClient.post('/commute/check-in', {
      'commuteId': commuteId,
    });
    return response['success'] == true;
  }
}
