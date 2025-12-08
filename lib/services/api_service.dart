import 'dart:convert';
import 'package:http/http.dart' as http;
import 'document_scanner_service.dart';

class ApiService {
  // API URL'ni o'zingizniki bilan almashtiring
  static const String baseUrl = 'https://your-api.com/api';

  Future<bool> sendDocumentData(DocumentData data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/warehouse/document'),
        headers: {
          'Content-Type': 'application/json',
          // Agar kerak bo'lsa: 'Authorization': 'Bearer YOUR_TOKEN',
        },
        body: jsonEncode(data.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
