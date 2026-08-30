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
      id: json['id'] as String,
      name: json['contact_name'] as String,
      phone: json['phone_number'] as String,
      relation: json['relation'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
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
    final contactJson = response['contact'] as Map<String, dynamic>;
    return EmergencyContactItem.fromJson(contactJson);
  }

  static Future<bool> deleteContact(String id) async {
    final response = await ApiClient.delete('/contacts/$id');
    return response['success'] == true;
  }
}
