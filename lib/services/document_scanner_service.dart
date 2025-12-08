import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'ai_parser_service.dart';

// ================== MODELS ==================

/// Bitta mahsulot ma'lumotlari
class ProductItem {
  final String name;
  final int quantity;
  final String? unit;
  final double? price; // Narx (ixtiyoriy)

  ProductItem({
    required this.name,
    required this.quantity,
    this.unit,
    this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (price != null) 'price': price,
    };
  }

  @override
  String toString() => '$name: $quantity${unit != null ? ' $unit' : ''}${price != null ? ' - $price so\'m' : ''}';
}

/// Document scan natijasi
class DocumentData {
  final List<ProductItem> products;

  // Backward compatibility uchun
  String? get productName => products.isNotEmpty ? products.first.name : null;
  int? get quantity => products.isNotEmpty ? products.first.quantity : null;
  String? get unit => products.isNotEmpty ? products.first.unit : null;

  DocumentData({
    List<ProductItem>? products,
    String? productName,
    int? quantity,
    String? unit,
  }) : products = products ??
         (productName != null && quantity != null
           ? [ProductItem(name: productName, quantity: quantity, unit: unit)]
           : []);

  Map<String, dynamic> toJson() {
    return {
      'products': products.map((p) => p.toJson()).toList(),
      // Backward compatibility
      if (products.isNotEmpty) ...{
        'product_name': products.first.name,
        'quantity': products.first.quantity,
        if (products.first.unit != null) 'unit': products.first.unit,
      }
    };
  }
}

class ScanResult {
  final DocumentData? data;
  final String ocrText;
  final bool usedAI; // AI ishlatildimi?
  final String parsingMethod; // "AI", "Regex", "Failed"

  ScanResult({
    this.data,
    required this.ocrText,
    this.usedAI = false,
    this.parsingMethod = 'Regex',
  });
}

// ================== SERVICE ==================

class DocumentScannerService {
  final _textRecognizer = TextRecognizer();
  AIParserService? _aiParser;
  bool _useAI = false;

  /// AI parsing ni yoqish (Gemini API key kerak)
  void enableAIParsing(String geminiApiKey) {
    _aiParser = AIParserService(apiKey: geminiApiKey);
    _useAI = true;
  }

  /// AI parsing ni o'chirish (faqat regex ishlatadi)
  void disableAIParsing() {
    _aiParser = null;
    _useAI = false;
  }

  Future<ScanResult?> scanDocument(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final ocrText = recognizedText.text;

      DocumentData? data;
      bool usedAI = false;
      String parsingMethod = 'Regex';

      // AI parsing yoqilgan bo'lsa, uni ishlatish
      if (_useAI && _aiParser != null) {
        // ignore: avoid_print
        print('🤖 AI Parsing boshlandi (Gemini)...');

        try {
          final aiProducts = await _aiParser!.extractProducts(ocrText);
          if (aiProducts != null && aiProducts.isNotEmpty) {
            data = DocumentData(products: aiProducts);
            usedAI = true;
            parsingMethod = 'AI (Gemini)';
            // ignore: avoid_print
            print('✅ AI muvaffaqiyatli: ${aiProducts.length} ta mahsulot topildi');
          } else {
            // ignore: avoid_print
            print('⚠️ AI mahsulot topmadi, Regex fallback...');
          }
        } catch (e) {
          // ignore: avoid_print
          print('❌ AI xatolik: $e, Regex fallback...');
        }
      }

      // AI ishlamasa yoki o'chirilgan bo'lsa, regex fallback
      if (data == null || data.products.isEmpty) {
        // ignore: avoid_print
        print('🔧 Regex parsing boshlandi...');
        data = _extractData(ocrText);
        parsingMethod = 'Regex';
        if (data != null && data.products.isNotEmpty) {
          // ignore: avoid_print
          print('✅ Regex: ${data.products.length} ta mahsulot topildi');
        }
      }

      return ScanResult(
        data: data,
        ocrText: ocrText,
        usedAI: usedAI,
        parsingMethod: parsingMethod,
      );
    } catch (e) {
      // Log error for debugging
      // ignore: avoid_print
      print('❌ Document scanner xatolik: $e');
      return null;
    }
  }

  /// Universal extraction - ko'p formatlarni support qiladi
  DocumentData? _extractData(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final products = <ProductItem>[];

    // ============= STRATEGY 1: TABLE FORMAT =============
    // Nakladnoy ko'pincha table formatida bo'ladi:
    // № | Nomi | Soni | Birlik
    // 1 | Cement M400 | 25 | kg
    // 2 | Armatura 12mm | 120 | metr

    final tableProducts = _extractTableFormat(lines);
    if (tableProducts.isNotEmpty) {
      products.addAll(tableProducts);
    }

    // ============= STRATEGY 2: INLINE FORMAT =============
    // Bitta qatorda: "Cement M400 25 kg"
    if (products.isEmpty) {
      final inlineProducts = _extractInlineFormat(lines);
      if (inlineProducts.isNotEmpty) {
        products.addAll(inlineProducts);
      }
    }

    // ============= STRATEGY 3: MULTI-LINE FALLBACK =============
    // Agar hech narsa topilmasa, oddiy single-product fallback
    if (products.isEmpty) {
      final singleProduct = _extractSingleProduct(lines);
      if (singleProduct != null) {
        products.add(singleProduct);
      }
    }

    // ============= STRATEGY 4: AGGRESSIVE LINE-BY-LINE =============
    // Har bir qatorni tekshirish - numberli qatorlarni topish
    if (products.isEmpty) {
      final aggressiveProducts = _extractAggressiveFormat(lines);
      if (aggressiveProducts.isNotEmpty) {
        products.addAll(aggressiveProducts);
      }
    }

    return products.isNotEmpty ? DocumentData(products: products) : null;
  }

  // ========== TABLE FORMAT DETECTION ==========
  List<ProductItem> _extractTableFormat(List<String> lines) {
    final products = <ProductItem>[];

    // Table headerlarini topish
    final headerKeywords = ['nomi', 'name', 'наименование', 'товар', 'product',
                           'mahsulot', 'soni', 'qty', 'quantity', 'кол-во',
                           'количество', 'miqdor'];

    int? headerIndex;
    for (int i = 0; i < lines.length; i++) {
      final lowerLine = lines[i].toLowerCase();
      if (headerKeywords.any((kw) => lowerLine.contains(kw))) {
        headerIndex = i;
        break;
      }
    }

    // Agar header topilsa, keyingi qatorlardan mahsulotlarni extract qilish
    if (headerIndex != null && headerIndex < lines.length - 1) {
      for (int i = headerIndex + 1; i < lines.length; i++) {
        final line = lines[i];

        // Qator raqam bilan boshlanishi mumkin: "1. Cement 25 kg" yoki "1 | Cement | 25 | kg"
        final tableRowPattern = RegExp(
          r'^\d+[\.\)\|]?\s*(.+?)\s+(\d{1,6})\s*(kg|кг|g|гр|l|л|ml|мл|metr|m|м|шт|dona|pcs|bag|bags|piece|pieces|units|ta|litr|box)?',
          caseSensitive: false,
        );

        final match = tableRowPattern.firstMatch(line);
        if (match != null) {
          final name = match.group(1)!.trim();
          final qty = int.tryParse(match.group(2)!);
          final unit = match.group(3)?.trim();

          if (qty != null && name.isNotEmpty) {
            // Nomni tozalash - pipe, tab va boshqa belgilarni olib tashlash
            final cleanName = name
                .replaceAll(RegExp(r'[\|\t]+'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            if (cleanName.length > 2) {
              products.add(ProductItem(name: cleanName, quantity: qty, unit: unit));
            }
          }
        }
      }
    }

    return products;
  }

  // ========== INLINE FORMAT DETECTION ==========
  List<ProductItem> _extractInlineFormat(List<String> lines) {
    final products = <ProductItem>[];

    // Pattern: "Product name 25 kg" yoki "Product name - 25 kg"
    final inlinePattern = RegExp(
      r'^(.+?)\s*[-–—:]?\s*(\d{1,6})\s*(kg|кг|g|гр|l|л|ml|мл|metr|m|м|шт|dona|pcs|bag|bags|piece|pieces|units|ta|litr|box|quti)?$',
      caseSensitive: false,
    );

    for (var line in lines) {
      // Skip header yoki bo'sh qatorlar
      if (_isHeaderLine(line)) continue;

      final match = inlinePattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final qty = int.tryParse(match.group(2)!);
        final unit = match.group(3)?.trim();

        if (qty != null && qty > 0 && name.length > 2) {
          // Faqat harflar va raqamlardan iborat ismlarni qabul qilish
          if (RegExp(r'[a-zа-яёәғқўҳ]', caseSensitive: false).hasMatch(name)) {
            final cleanName = _cleanProductName(name);
            products.add(ProductItem(name: cleanName, quantity: qty, unit: unit));
          }
        }
      }
    }

    return products;
  }

  // ========== SINGLE PRODUCT FALLBACK ==========
  ProductItem? _extractSingleProduct(List<String> lines) {
    String? productName;
    int? quantity;
    String? unit;

    final unitList = [
      'kg', 'кг', 'g', 'гр', 'l', 'л', 'ml', 'мл', 'metr', 'm', 'м',
      'шт', 'dona', 'pcs', 'bag', 'bags', 'piece', 'pieces', 'units',
      'ta', 'litr', 'box', 'quti'
    ];

    // 1) Product nomi topish
    final productPatterns = [
      RegExp(r'(?:product|mahsulot|товар|tovar|name|nomi?)[:\s]+(.+)',
          caseSensitive: false),
      RegExp(r'^([A-Za-zА-Яа-яЁёӘәҒғҚқҮүҲҳ0-9\-\s]{3,50})$',
          caseSensitive: false),
    ];

    for (var line in lines) {
      if (productName == null && !_isHeaderLine(line)) {
        for (var p in productPatterns) {
          final match = p.firstMatch(line);
          if (match != null) {
            final name = match.group(1)!.trim();
            if (name.length > 2 &&
                RegExp(r'[a-zа-яёәғқүҳ]', caseSensitive: false)
                    .hasMatch(name)) {
              productName = _cleanProductName(name);
              break;
            }
          }
        }
      }
    }

    // 2) Quantity topish
    final unitsPattern = unitList.join('|');
    final quantityPatterns = [
      RegExp(
          r'(?:qty|quantity|soni?|amount|miqdor|количество|кол-во)[:\s]*(\d{1,6})',
          caseSensitive: false),
      RegExp(r'^(\d{1,6})$'),
      RegExp(r'(\d{1,6})\s*(?:' + unitsPattern + r')',
          caseSensitive: false),
    ];

    for (var line in lines) {
      if (quantity == null) {
        for (var p in quantityPatterns) {
          final match = p.firstMatch(line);
          if (match != null) {
            final qty = int.tryParse(match.group(1)!);
            if (qty != null && qty > 0) {
              quantity = qty;
              break;
            }
          }
        }
      }
    }

    // 3) Unit topish
    for (var line in lines) {
      if (unit == null) {
        for (var u in unitList) {
          final pattern = RegExp(r'\d+\s*(' + RegExp.escape(u) + r')\b',
              caseSensitive: false);
          final match = pattern.firstMatch(line);
          if (match != null) {
            unit = match.group(1)!.toLowerCase();
            break;
          }
        }
      }
      if (unit != null) break;
    }

    if (productName != null && quantity != null) {
      return ProductItem(name: productName, quantity: quantity, unit: unit);
    }

    return null;
  }

  // ========== AGGRESSIVE LINE-BY-LINE ==========
  List<ProductItem> _extractAggressiveFormat(List<String> lines) {
    final products = <ProductItem>[];

    // Har qatorni tekshirish - har qanday nom + number kombinatsiyasini topish
    final aggressivePattern = RegExp(
      r'([A-Za-zА-Яа-яЁёӘәҒғҚқҮүҲҳ][A-Za-zА-Яа-яЁёӘәҒғҚқҮүҲҳ0-9\s\-\.]{2,})\s+(\d{1,6})(?:\s*(kg|кг|g|гр|l|л|ml|мл|metr|m|м|шт|dona|pcs|bag|bags|piece|pieces|units|ta|litr|box|quti))?',
      caseSensitive: false,
    );

    for (var line in lines) {
      if (_isHeaderLine(line)) continue;

      final matches = aggressivePattern.allMatches(line);
      for (var match in matches) {
        final name = match.group(1)!.trim();
        final qty = int.tryParse(match.group(2)!);
        final unit = match.group(3)?.trim();

        if (qty != null && qty > 0 && name.length >= 3) {
          // Filter out likely false positives
          if (!_isFalsePositive(name)) {
            final cleanName = _cleanProductName(name);
            products.add(ProductItem(name: cleanName, quantity: qty, unit: unit));
          }
        }
      }
    }

    return products;
  }

  // ========== HELPER FUNCTIONS ==========

  bool _isHeaderLine(String line) {
    final headerKeywords = [
      'nakladnoy', 'накладная', 'invoice', 'kirim', 'chiqim', 'hujjat',
      'document', 'nomi', 'name', 'наименование', 'soni', 'qty', 'quantity',
      'кол-во', 'количество', 'birlik', 'unit', 'единица', 'data', 'дата',
      'date', 'sana'
    ];

    final lowerLine = line.toLowerCase();
    return headerKeywords
        .any((kw) => lowerLine.contains(kw) && lowerLine.length < 50);
  }

  bool _isFalsePositive(String name) {
    // Filter out common false positives
    final falsePositives = [
      'page', 'страница', 'bet', 'total', 'итого', 'jami', 'sum', 'сумма',
      'date', 'дата', 'sana'
    ];

    final lowerName = name.toLowerCase();
    return falsePositives.any((fp) => lowerName == fp) ||
           name.length < 3 ||
           RegExp(r'^\d+$').hasMatch(name);
  }

  String _cleanProductName(String name) {
    return name
        .replaceAll(RegExp(r'[\|\t:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[-–—\.]+|[-–—\.]+$'), '')
        .trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}

// ================== DOCUMENT SCANNER HELPER ==================

/// iOS-like Document Scanner (burchaklarni belgilash va crop qilish)
class DocumentScannerHelper {
  AIParserService? _aiParser;
  bool _useAI = false;

  /// AI parsing ni yoqish
  void enableAIParsing(String geminiApiKey) {
    _aiParser = AIParserService(apiKey: geminiApiKey);
    _useAI = true;
  }

  /// AI parsing ni o'chirish
  void disableAIParsing() {
    _aiParser = null;
    _useAI = false;
  }

  /// Document scanner UI ni ochish
  /// Returns: Scan qilingan rasmlar (bir nechta sahifa bo'lishi mumkin)
  Future<List<File>?> scanDocument() async {
    try {
      // Document Scanner options
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full, // full = preview + crop, base = faqat crop
        pageLimit: 5, // Maksimal 5 ta sahifa
        isGalleryImport: true, // Galereyadan ham import qilish imkoni
      );

      final documentScanner = DocumentScanner(options: options);

      // Scanner UI ni ochish
      final result = await documentScanner.scanDocument();

      // Natijalarni qaytarish
      if (result.images.isNotEmpty) {
        return result.images.map((img) => File(img)).toList();
      }

      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Document scanner xatolik: $e');
      return null;
    }
  }

  /// Bir nechta rasmlarni scan qilish va birlashtirilgan matn qaytarish
  Future<ScanResult?> scanMultiplePages(List<File> images) async {
    try {
      final textRecognizer = TextRecognizer();
      final allText = StringBuffer();

      // Har bir rasmni OCR qilish
      for (var imageFile in images) {
        final inputImage = InputImage.fromFile(imageFile);
        final recognizedText = await textRecognizer.processImage(inputImage);
        allText.writeln(recognizedText.text);
      }

      textRecognizer.close();

      DocumentData? extractedData;
      bool usedAI = false;
      String parsingMethod = 'Regex';

      // AI parsing yoqilgan bo'lsa, ishlatish
      if (_useAI && _aiParser != null) {
        // ignore: avoid_print
        print('🤖 AI Parsing boshlandi (multi-page, Gemini)...');

        try {
          final aiProducts = await _aiParser!.extractProducts(allText.toString());
          if (aiProducts != null && aiProducts.isNotEmpty) {
            extractedData = DocumentData(products: aiProducts);
            usedAI = true;
            parsingMethod = 'AI (Gemini)';
            // ignore: avoid_print
            print('✅ AI muvaffaqiyatli: ${aiProducts.length} ta mahsulot topildi');
          } else {
            // ignore: avoid_print
            print('⚠️ AI mahsulot topmadi, Regex fallback...');
          }
        } catch (e) {
          // ignore: avoid_print
          print('❌ AI xatolik: $e, Regex fallback...');
        }
      }

      // AI ishlamasa, regex fallback
      if (extractedData == null || extractedData.products.isEmpty) {
        // ignore: avoid_print
        print('🔧 Regex parsing boshlandi (multi-page)...');
        final scannerService = DocumentScannerService();
        extractedData = scannerService._extractData(allText.toString());
        parsingMethod = 'Regex';
        if (extractedData != null && extractedData.products.isNotEmpty) {
          // ignore: avoid_print
          print('✅ Regex: ${extractedData.products.length} ta mahsulot topildi');
        }
      }

      if (extractedData != null) {
        return ScanResult(
          data: extractedData,
          ocrText: allText.toString(),
          usedAI: usedAI,
          parsingMethod: parsingMethod,
        );
      }

      return ScanResult(
        data: null,
        ocrText: allText.toString(),
        usedAI: false,
        parsingMethod: 'Failed',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Multi-page scan xatolik: $e');
      return null;
    }
  }
}
