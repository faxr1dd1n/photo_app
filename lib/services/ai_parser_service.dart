import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_scanner_service.dart';

/// AI-based document parsing service using Google Gemini
class AIParserService {
  late final GenerativeModel _model;
  final String apiKey;
  String _modelName = 'gemini-1.5-flash-latest';

  AIParserService({required this.apiKey}) {
    // ignore: avoid_print
    print('🔧 AI Parser yaratilmoqda...');
    // ignore: avoid_print
    print('📝 API Key uzunligi: ${apiKey.length} belgi');
    // ignore: avoid_print
    print('📝 API Key boshi: ${apiKey.substring(0, 15)}...');

    try {
      // Model nomlari ro'yxati (eng yangidan eskisiga)
      final modelNames = [
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash',
        'gemini-pro',
        'gemini-1.0-pro-latest',
      ];

      // Birinchi model nomini ishlatish
      _modelName = modelNames[0];

      // ignore: avoid_print
      print('📝 Model: $_modelName');

      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          topK: 1,
          topP: 1,
          maxOutputTokens: 2048,
        ),
      );
      // ignore: avoid_print
      print('✅ AI Parser tayyor');
    } catch (e) {
      // ignore: avoid_print
      print('❌ AI Parser yaratishda xatolik: $e');
      rethrow;
    }
  }

  /// OCR matnidan mahsulotlarni AI orqali extract qilish
  Future<List<ProductItem>?> extractProducts(String ocrText) async {
    try {
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('═══════════════════════════════════════');
      // ignore: avoid_print
      print('🤖 GEMINI AI PARSING BOSHLANDI');
      // ignore: avoid_print
      print('═══════════════════════════════════════');
      // ignore: avoid_print
      print('📄 OCR matn uzunligi: ${ocrText.length} belgi');

      final prompt = _buildPrompt(ocrText);

      // ignore: avoid_print
      print('🌐 Gemini API ga request yuborilmoqda...');

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      // ignore: avoid_print
      print('✅ Gemini javob olindi');

      if (responseText == null || responseText.isEmpty) {
        // ignore: avoid_print
        print('⚠️ Gemini bo\'sh javob qaytardi');
        return null;
      }

      // ignore: avoid_print
      print('📝 Gemini javobi uzunligi: ${responseText.length} belgi');
      // ignore: avoid_print
      print('📝 Javob boshi: ${responseText.substring(0, responseText.length > 150 ? 150 : responseText.length)}...');

      // JSON ni parse qilish
      final products = _parseJsonResponse(responseText);

      if (products != null) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🎉 AI MUVAFFAQIYATLI!');
        // ignore: avoid_print
        print('📊 Topilgan mahsulotlar: ${products.length} ta');
        for (var i = 0; i < products.length; i++) {
          // ignore: avoid_print
          print('   ${i + 1}. ${products[i].name} - ${products[i].quantity} ${products[i].unit ?? ''}');
        }
        // ignore: avoid_print
        print('═══════════════════════════════════════');
        // ignore: avoid_print
        print('');
      }

      return products;
    } catch (e) {
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('❌ AI PARSING XATOLIK!');
      // ignore: avoid_print
      print('💥 Xato turi: ${e.runtimeType}');
      // ignore: avoid_print
      print('💥 Xato: $e');

      // Aniq xato turini aniqlash
      if (e.toString().contains('404')) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🔍 404 XATO - Model yoki endpoint topilmadi!');
        // ignore: avoid_print
        print('📝 Ishlatilgan model: $_modelName');
        // ignore: avoid_print
        print('💡 Ehtimoliy sabablar:');
        // ignore: avoid_print
        print('   1. API key noto\'g\'ri yoki eskirgan');
        // ignore: avoid_print
        print('   2. Model nomi o\'zgargan (gemini-1.5-flash-latest → gemini-2.0-flash)');
        // ignore: avoid_print
        print('   3. Internet muammosi');
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('💡 Yechim:');
        // ignore: avoid_print
        print('   1. https://aistudio.google.com/apikey da yangi API key oling');
        // ignore: avoid_print
        print('   2. API key\'ni lib/main.dart, 54-qatorda yangilang');
        // ignore: avoid_print
        print('   3. Internet ulanishini tekshiring');
      } else if (e.toString().contains('API key') || e.toString().contains('401')) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🔑 API KEY XATO (401 Unauthorized)!');
        // ignore: avoid_print
        print('💡 API key noto\'g\'ri yoki bekor qilingan');
        // ignore: avoid_print
        print('💡 Yechim: https://aistudio.google.com/apikey da yangi key oling');
      } else if (e.toString().contains('quota') || e.toString().contains('429')) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('⏰ LIMIT TO\'LGAN (429 Too Many Requests)!');
        // ignore: avoid_print
        print('💡 15 requests/minute limiti oshdi');
        // ignore: avoid_print
        print('💡 Yechim: 1-2 daqiqa kuting');
      }

      // ignore: avoid_print
      print('═══════════════════════════════════════');
      // ignore: avoid_print
      print('');
      return null;
    }
  }

  /// Gemini uchun optimallashtirilgan prompt
  String _buildPrompt(String text) {
    return '''
Siz hujjatlardan mahsulot ma'lumotlarini ajratib oluvchi tizmsiz.

Quyidagi OCR matnida nakladnoy, faktura yoki kirim-chiqim hujjati mavjud.
Matn turli tillarda (o'zbek, rus, ingliz) va turli formatlarda bo'lishi mumkin.

VAZIFA:
1. Matndan BARCHA mahsulotlarni toping
2. Har bir mahsulot uchun: nom, miqdor va birlikni aniqlang
3. Faqat JSON formatida javob bering (boshqa matn yo'q!)

QOIDALAR:
- Mahsulot nomi - raqamdan oldingi matn
- Miqdor - mahsulot nomidan keyingi birinchi raqam
- Birlik - kg, dona, pcs, шт, metr, l, ml, bag, quti va h.k.
- Agar birlik yo'q bo'lsa, null qo'ying
- Header qatorlarni (Nomi, Soni, Total, Jami va h.k.) o'tkazib yuboring
- Faqat haqiqiy mahsulotlarni qaytaring

JSON FORMAT (faqat shu formatda javob bering):
{
  "products": [
    {
      "name": "mahsulot nomi",
      "quantity": 100,
      "unit": "kg"
    }
  ]
}

OCR MATN:
$text

JAVOB (faqat JSON):''';
  }

  /// JSON javobni parse qilish
  List<ProductItem>? _parseJsonResponse(String responseText) {
    try {
      // JSON ni topish - ba'zan AI qo'shimcha matn qo'shishi mumkin
      String jsonText = responseText.trim();

      // Agar markdown code block bo'lsa, uni olib tashlash
      if (jsonText.startsWith('```')) {
        final startIndex = jsonText.indexOf('{');
        final endIndex = jsonText.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1) {
          jsonText = jsonText.substring(startIndex, endIndex + 1);
        }
      }

      // JSON parse qilish
      final jsonData = jsonDecode(jsonText) as Map<String, dynamic>;
      final productsList = jsonData['products'] as List<dynamic>;

      // ProductItem listiga o'tkazish
      return productsList.map((item) {
        final product = item as Map<String, dynamic>;
        return ProductItem(
          name: product['name'] as String,
          quantity: (product['quantity'] is int)
            ? product['quantity'] as int
            : int.tryParse(product['quantity'].toString()) ?? 0,
          unit: product['unit'] as String?,
        );
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('JSON parsing xatolik: $e');
      // ignore: avoid_print
      print('Response text: $responseText');
      return null;
    }
  }
}
