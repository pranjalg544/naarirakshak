import '../core/network/api_client.dart';

class PodMember {
  final String userId;
  final String fullName;
  final String initials;
  final String role;
  final String checkInStatus;
  final String? checkedInAt;

  const PodMember({
    required this.userId,
    required this.fullName,
    required this.initials,
    required this.role,
    required this.checkInStatus,
    this.checkedInAt,
  });

  factory PodMember.fromJson(Map<String, dynamic> json) {
    return PodMember(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Pod Member',
      initials: (json['initials'] as String?)?.isNotEmpty == true
          ? json['initials'] as String
          : _buildInitials(json['full_name'] as String? ?? ''),
      role: json['role'] as String? ?? 'MEMBER',
      checkInStatus: json['check_in_status'] as String? ?? 'EN_ROUTE',
      checkedInAt: json['checked_in_at'] as String?,
    );
  }

  bool get hasReached => checkInStatus == 'REACHED_SAFELY';

  static String _buildInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || fullName.isEmpty) return '??';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

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

  /// Fetches all pod members for a given commute session.
  /// Returns an empty list on error (non-fatal — the user can still commute).
  static Future<List<PodMember>> getPodMembers(String commuteId) async {
    try {
      final response = await ApiClient.get('/commute/$commuteId/members');
      final rawList = response['members'] as List<dynamic>? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(PodMember.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> checkInSafe(String commuteId) async {
    final response = await ApiClient.post('/commute/check-in', {
      'commuteId': commuteId,
    });
    return response['success'] == true;
  }
}
