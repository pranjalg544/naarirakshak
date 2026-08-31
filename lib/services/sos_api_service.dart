import '../core/network/api_client.dart';

class SosIncidentResult {
  final String incidentId;
  final String trackingToken;
  final String trackingUrl;

  SosIncidentResult({
    required this.incidentId,
    required this.trackingToken,
    required this.trackingUrl,
  });

  factory SosIncidentResult.fromJson(Map<String, dynamic> json) {
    final incident = json['incident'] as Map<String, dynamic>? ?? json;
    return SosIncidentResult(
      incidentId: (incident['id'] ?? json['incidentId']) as String,
      trackingToken: (incident['tracking_token'] ?? json['trackingToken']) as String,
      trackingUrl: (json['liveTrackingUrl'] ?? json['trackingUrl']) as String,
    );
  }
}

class SosApiService {
  static Future<SosIncidentResult> triggerSos({
    String triggerType = 'MANUAL_SOS',
    required double lat,
    required double lng,
    double confidenceScore = 1.0,
  }) async {
    final response = await ApiClient.post('/sos/trigger', {
      'triggerType': triggerType,
      'lat': lat,
      'lng': lng,
      'confidenceScore': confidenceScore,
    });
    return SosIncidentResult.fromJson(response);
  }

  static Future<bool> resolveSos(String incidentId) async {
    final response = await ApiClient.post('/sos/resolve', {
      'incidentId': incidentId,
    });
    return response['success'] == true;
  }
}
