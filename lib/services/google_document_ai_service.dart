import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class DocumentAIService {
  final String projectId;
  final String location;
  final String processorId;

  // Token cache - 1 soat davomida qayta ishlatiladi
  String? _cachedToken;
  DateTime? _tokenExpiry;
  AutoRefreshingAuthClient? _authClient;

  DocumentAIService({
    required this.projectId,
    this.location = "us",
    required this.processorId,
  });

  /// Access token olish (avtomatik cache bilan)
  /// Token 1 soat amal qiladi, shuning uchun cache dan qayta ishlatamiz
  Future<String> _getAccessToken() async {
    // Agar token hali amal qilayotgan bo'lsa, cache dan qaytarish
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      // 5 daqiqa oldin yangilash (xavfsizlik uchun)
      return _cachedToken!;
    }

    // Yangi token olish
    final jsonKey =
        await rootBundle.loadString('assets/service_account.json');

    final credentials =
        ServiceAccountCredentials.fromJson(json.decode(jsonKey));

    _authClient?.close(); // Eski client ni yopish

    final client = await clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/cloud-platform'],
    );

    // Token va expiry vaqtini saqlash
    _cachedToken = client.credentials.accessToken.data;
    _tokenExpiry = client.credentials.accessToken.expiry;
    _authClient = client;

    // ignore: avoid_print
    print('🔑 Yangi token olinadi. Amal qilish muddati: $_tokenExpiry');

    return _cachedToken!;
  }

  /// Token cache ni tozalash (agar kerak bo'lsa)
  void dispose() {
    _cachedToken = null;
    _tokenExpiry = null;
    _authClient?.close();
    _authClient = null;
  }

  Future<Map<String, dynamic>> processImage(String base64Image) async {
    final token = await _getAccessToken();

    final url =
        "https://$location-documentai.googleapis.com/v1/projects/$projectId/locations/$location/processors/$processorId:process";

    final body = {
      "rawDocument": {
        "content": base64Image,
        "mimeType": "image/jpeg",
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Document AI Error: ${response.statusCode}\n${response.body}",
      );
    }
  }
}
