import '../core/network/api_client.dart';

class EmergencyContactItem {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContactItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
  });

  factory EmergencyContactItem.fromJson(Map<String, dynamic> json) {
    return EmergencyContactItem(
      id: json['id']?.toString() ?? '',
      name: (json['contact_name'] ?? json['name'])?.toString() ?? '',
      phone: (json['phone_number'] ?? json['phone'])?.toString() ?? '',
      relation: (json['relationship'] ?? json['relation'])?.toString() ?? 'Contact',
      isPrimary: (json['is_primary'] ?? json['isPrimary']) as bool? ?? false,
    );
  }
}

class ContactsApiService {
  static Future<List<EmergencyContactItem>> fetchContacts() async {
    final response = await ApiClient.get('/contacts');
    if (response['success'] == true && response['contacts'] != null) {
      final list = response['contacts'] as List;
      return list.map((item) => EmergencyContactItem.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<EmergencyContactItem> addContact({
    required String name,
    required String phone,
    required String relation,
    bool isPrimary = false,
  }) async {
    final response = await ApiClient.post('/contacts', {
      'name': name,
      'phone': phone,
      'relation': relation,
      'isPrimary': isPrimary,
    });
    if (response['success'] == true && response['contact'] != null) {
      final contactJson = response['contact'] as Map<String, dynamic>;
      return EmergencyContactItem.fromJson(contactJson);
    }
    throw Exception(response['message'] ?? 'Failed to add contact');
  }

  static Future<bool> deleteContact(String id) async {
    final response = await ApiClient.delete('/contacts/$id');
    return response['success'] == true;
  }
}
