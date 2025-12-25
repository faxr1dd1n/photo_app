import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/google_document_ai_service.dart';
import '../services/document_scanner_service.dart';

/// Editable product - user tomonidan o'zgartirilishi mumkin
class EditableProduct {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController priceController;

  bool isEditing = false;

  EditableProduct({
    required String name,
    required int quantity,
    String? unit,
    double? price,
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity.toString()),
        unitController = TextEditingController(text: unit ?? ''),
        priceController = TextEditingController(text: price?.toString() ?? '');

  // ProductItem ga konvert qilish
  ProductItem toProductItem() {
    return ProductItem(
      name: nameController.text,
      quantity: int.tryParse(quantityController.text) ?? 1,
      unit: unitController.text.isEmpty ? null : unitController.text,
      price: priceController.text.isEmpty ? null : double.tryParse(priceController.text),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    priceController.dispose();
  }
}

class DocumentAIInvoicePage extends StatefulWidget {
  const DocumentAIInvoicePage({super.key});

  @override
  State<DocumentAIInvoicePage> createState() => _DocumentAIInvoicePageState();
}

class _DocumentAIInvoicePageState extends State<DocumentAIInvoicePage> {
  final _picker = ImagePicker();
  late final DocumentAIService _documentAI;

  File? _imageFile;
  bool _isLoading = false;
  String? _loadingStatus;

  // Document AI natijasi
  Map<String, dynamic>? _documentAIResponse;
  String? _fullText;
  List<ProductItem>? _extractedProducts;

  // Editable products - user o'zgartirishi mumkin
  List<EditableProduct>? _editableProducts;

  // Statistika
  int _totalPages = 0;
  double _confidence = 0.0;

  @override
  void initState() {
    super.initState();
    // Google Document AI Service ni initialize qilish
    _documentAI = DocumentAIService(
      projectId: "gentle-pier-480517-k8",
      processorId: "ce85e3655b0e60c1",
      location: "us",
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _loadingStatus = source == ImageSource.camera
            ? 'Kamera ochilmoqda...'
            : 'Galeriya ochilmoqda...';
      });

      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) {
        setState(() {
          _isLoading = false;
          _loadingStatus = null;
        });
        return;
      }

      setState(() {
        _imageFile = File(picked.path);
        _loadingStatus = 'Google Document AI ishga tushmoqda...';
      });

      // Rasmni base64 ga o'tkazish
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() {
        _loadingStatus = 'Document AI invoice ni tahlil qilmoqda...';
      });

      // Google Document AI orqali process qilish
      final result = await _documentAI.processImage(base64Image);

      setState(() {
        _loadingStatus = 'Ma\'lumotlar ajratib olinmoqda...';
      });

      // Natijani parse qilish
      _parseDocumentAIResponse(result);

      setState(() {
        _isLoading = false;
        _loadingStatus = null;
      });

      if (_extractedProducts == null || _extractedProducts!.isEmpty) {
        _showMessage('Ma\'lumot topilmadi. Iltimos boshqa rasm yuklang.');
      } else {
        _showMessage(
          '${_extractedProducts!.length} ta mahsulot topildi! Confidence: ${_confidence.toStringAsFixed(1)}%'
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingStatus = null;
      });
      _showMessage('Xatolik: $e');
      debugPrint('Document AI xatolik: $e');
    }
  }

  void _parseDocumentAIResponse(Map<String, dynamic> response) {
    try {
      final document = response['document'] as Map<String, dynamic>?;
      if (document == null) return;

      // Full text ni olish
      _fullText = document['text'] as String? ?? '';

      // Pages statistikasi
      final pages = document['pages'] as List<dynamic>? ?? [];
      _totalPages = pages.length;

      // Entities (mahsulotlar, summalar, sanalar) ni extract qilish
      final entities = document['entities'] as List<dynamic>? ?? [];

      // Products ni parse qilish
      _extractedProducts = _extractProductsFromEntities(entities);

      // Agar entities bo'sh bo'lsa, raw text dan regex bilan parse qilish
      if (_extractedProducts == null || _extractedProducts!.isEmpty) {
        _extractedProducts = _extractProductsFromText(_fullText ?? '');
      }

      // Editable products yaratish
      if (_extractedProducts != null && _extractedProducts!.isNotEmpty) {
        _editableProducts = _extractedProducts!.map((product) {
          return EditableProduct(
            name: product.name,
            quantity: product.quantity,
            unit: product.unit,
            price: product.price,
          );
        }).toList();
      }

      // Confidence score ni hisoblash
      if (entities.isNotEmpty) {
        double totalConfidence = 0;
        for (var entity in entities) {
          final confidence = entity['confidence'] as num? ?? 0;
          totalConfidence += confidence;
        }
        _confidence = (totalConfidence / entities.length) * 100;
      }

      _documentAIResponse = response;
    } catch (e) {
      debugPrint('Parse xatolik: $e');
    }
  }

  List<ProductItem>? _extractProductsFromEntities(List<dynamic> entities) {
    final products = <ProductItem>[];

    try {
      for (var entity in entities) {
        final type = entity['type'] as String? ?? '';
        final mentionText = entity['mentionText'] as String? ?? '';
        final confidence = entity['confidence'] as num? ?? 0;

        // Line items yoki product entities ni topish
        if (type.contains('line_item') ||
            type.contains('product') ||
            type.contains('item')) {

          // Properties dan product ma'lumotlarini olish
          final properties = entity['properties'] as List<dynamic>? ?? [];

          String? productName;
          int? quantity;
          String? unit;
          double? price;

          // Debug: entity confidence va text
          debugPrint('Entity: $mentionText (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

          for (var prop in properties) {
            final propType = prop['type'] as String? ?? '';
            final propText = prop['mentionText'] as String? ?? '';

            // DETALLI DEBUG LOG
            debugPrint('  Property: $propType = "$propText"');

            // MUHIM: Avval price ni tekshirish, keyin unit ni (unit_price chalkashtirmasligi uchun)
            if (propType.contains('price') ||
                propType.contains('amount') ||
                propType.contains('unit_price')) {
              // Price ni parse qilish - faqat raqamlar va nuqtani qoldirish
              final cleanPrice = propText.replaceAll(RegExp(r'[^\d\.]'), '');
              price = double.tryParse(cleanPrice);
              debugPrint('    💰 Price: $propText → $price');
            } else if (propType.contains('description') || propType.contains('name')) {
              productName = propText.trim();
              debugPrint('    ✅ Product Name: $productName');
            } else if (propType.contains('quantity') || propType.contains('qty')) {
              final cleanQty = propText.replaceAll(RegExp(r'[^\d]'), '');
              quantity = int.tryParse(cleanQty);
              debugPrint('    ✅ Quantity: $propText → $quantity');
            } else if (propType.contains('unit') && !propType.contains('unit_price')) {
              // DIQQAT: unit_price ni exclude qilamiz!
              unit = propText.trim();
              debugPrint('    ✅ Unit: $unit');
            }
          }

          // Agar product ma'lumotlari topilsa, listga qo'shish
          if (productName != null && productName.isNotEmpty) {
            final product = ProductItem(
              name: productName,
              quantity: quantity ?? 1,
              unit: unit,
              price: price,
            );
            products.add(product);

            // YAKUNIY NATIJA
            debugPrint('  ➡️ YAKUNIY: ${product.name} | ${product.quantity} ${product.unit ?? ''} | ${product.price ?? 'narx yo\'q'}');
          }
        }
      }

      debugPrint('\n📦 Jami ${products.length} ta mahsulot topildi (entities dan)\n');
      return products.isNotEmpty ? products : null;
    } catch (e) {
      debugPrint('Entities parse xatolik: $e');
      return null;
    }
  }

  List<ProductItem>? _extractProductsFromText(String text) {
    final products = <ProductItem>[];
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Invoice pattern: Product name, quantity, unit, price (ixtiyoriy)
    final productPattern = RegExp(
      r'(.+?)\s+(\d+)\s*(kg|g|l|ml|pcs|dona|шт|metr|m|bag|box|ta|units?)?\s*(?:[\$₽₸]*\s*(\d+(?:\.\d{1,2})?))?',
      caseSensitive: false,
    );

    for (var line in lines) {
      // Skip header lines
      if (_isHeaderLine(line)) continue;

      final match = productPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim();
        final qty = int.tryParse(match.group(2) ?? '');
        final unit = match.group(3)?.trim();
        final priceStr = match.group(4);
        final price = priceStr != null ? double.tryParse(priceStr) : null;

        if (name != null && name.length > 2 && qty != null && qty > 0) {
          products.add(ProductItem(
            name: name,
            quantity: qty,
            unit: unit,
            price: price,
          ));
        }
      }
    }

    return products.isNotEmpty ? products : null;
  }

  bool _isHeaderLine(String line) {
    final headers = ['invoice', 'total', 'subtotal', 'date', 'name', 'qty', 'quantity',
                      'price', 'amount', 'description', 'item', 'product'];
    final lower = line.toLowerCase();
    return headers.any((h) => lower == h || lower.startsWith('$h:'));
  }

  void _resetState() {
    // Dispose all controllers
    if (_editableProducts != null) {
      for (var product in _editableProducts!) {
        product.dispose();
      }
    }

    setState(() {
      _imageFile = null;
      _documentAIResponse = null;
      _fullText = null;
      _extractedProducts = null;
      _editableProducts = null;
      _totalPages = 0;
      _confidence = 0;
    });
  }

  @override
  void dispose() {
    // Dispose all controllers
    if (_editableProducts != null) {
      for (var product in _editableProducts!) {
        product.dispose();
      }
    }
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitToAPI() async {
    if (_editableProducts == null || _editableProducts!.isEmpty) {
      _showMessage('Yuborishga mahsulot yo\'q');
      return;
    }

    // Hamma mahsulotlarni validate qilish
    for (var product in _editableProducts!) {
      if (!_validateProduct(product)) {
        _showMessage('Iltimos barcha mahsulotlarni to\'g\'ri to\'ldiring');
        return;
      }
    }

    // Editable products dan ProductItem ga convert qilish
    final productsToSubmit = _editableProducts!.map((ep) => ep.toProductItem()).toList();

    // JSON format
    final jsonData = {
      'products': productsToSubmit.map((p) => p.toJson()).toList(),
      'total_count': productsToSubmit.length,
      'submitted_at': DateTime.now().toIso8601String(),
    };

    // API ga yuborish (hozircha faqat ko'rsatish)
    debugPrint('📤 API ga yuborilmoqda:');
    debugPrint(const JsonEncoder.withIndent('  ').convert(jsonData));

    // Dialog orqali tasdiqlash
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Tayyor!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${productsToSubmit.length} ta mahsulot tayyorlandi',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(jsonData),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu ma\'lumotlarni API endpointingizga yuboring',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(jsonData),
              ));
              Navigator.pop(context);
              _showMessage('JSON nusxalandi');
            },
            child: const Text('Nusxalash'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Actual API call
              // await apiService.submitProducts(productsToSubmit);
              _showMessage('API ga yuborildi (demo)');
            },
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            // Kattalashtiriladigan rasm
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(imageFile),
              ),
            ),
            // Yopish tugmasi
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.black),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Yorliq - zoom qilish mumkin
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ikki barmog\'ingiz bilan kattalashtirib ko\'ring',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullResponse() {
    if (_documentAIResponse == null) return;

    // Faqat kerakli qismlarni ajratib olish
    final document = _documentAIResponse!['document'] as Map<String, dynamic>?;
    final simplifiedData = {
      'document': {
        'text': document?['text'] ?? '',
        'entities': document?['entities'] ?? [],
        // pages, blocks, tokens, paragraphs - olib tashlandi
      }
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(simplifiedData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document AI - Kerakli Ma\'lumotlar'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Izoh
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '📋 Faqat muhim qismlar:\n'
                  '• document.text - OCR matn\n'
                  '• document.entities - Topilgan ma\'lumotlar\n'
                  '  └─ properties - Nom, miqdor, narx',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
              ),
              // JSON
              SelectableText(
                jsonString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.pop(context);
              _showMessage('Soddalashtirilgan JSON nusxalandi');
            },
            child: const Text('Nusxalash'),
          ),
          TextButton(
            onPressed: () {
              // To'liq JSON ni nusxalash
              final fullJson = const JsonEncoder.withIndent('  ').convert(_documentAIResponse!);
              Clipboard.setData(ClipboardData(text: fullJson));
              Navigator.pop(context);
              _showMessage('To\'liq JSON nusxalandi');
            },
            child: const Text('To\'liq JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(

        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // Google Cloud logo style
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Document AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Powered by Google Cloud',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade700,
                Colors.blue.shade500,
                Colors.lightBlue.shade400,
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google Cloud animation effect
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.blue.shade100.withOpacity(0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Progress indicator
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: CircularProgressIndicator(
                            strokeWidth: 6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
                            ),
                          ),
                        ),
                        // Center icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 28,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (_loadingStatus != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _loadingStatus!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_outlined,
                                  size: 14,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Google Cloud AI ishlamoqda',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image preview
                  if (_imageFile != null) ...[
                    GestureDetector(
                      onTap: () => _showImagePreview(_imageFile!),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _imageFile!,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Zoom belgisi
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Kattalashtirish',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statistics card - Premium style
                  if (_extractedProducts != null && _extractedProducts!.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade600,
                            Colors.blue.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Tahlil Natijalari',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.inventory_2_outlined,
                                '${_extractedProducts!.length}',
                                'Mahsulotlar',
                                Colors.white,
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              _buildStatItem(
                                Icons.description_outlined,
                                '$_totalPages',
                                'Sahifalar',
                                Colors.white,
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              _buildStatItem(
                                Icons.verified_outlined,
                                '${_confidence.toStringAsFixed(0)}%',
                                'Aniqlik',
                                Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Extracted products
                  if (_extractedProducts != null && _extractedProducts!.isNotEmpty) ...[
                    // Section header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade400],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Aniqlangan Mahsulotlar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade600, Colors.green.shade400],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_extractedProducts!.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._extractedProducts!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final product = entry.value;
                      return _buildProductCard(product, index + 1);
                    }),
                    const SizedBox(height: 16),

                    // OCR Text
                    if (_fullText != null && _fullText!.isNotEmpty) ...[
                      ExpansionTile(
                        leading: Icon(Icons.text_fields, color: Colors.blue.shade700),
                        title: const Text(
                          'Document AI OCR Matni',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SelectableText(
                              _fullText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Submit button - API ga yuborish
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade600, Colors.green.shade500],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _submitToAPI,
                        icon: const Icon(Icons.cloud_upload, color: Colors.white),
                        label: const Text(
                          'API ga yuborish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showFullResponse,
                            icon: const Icon(Icons.code),
                            label: const Text('JSON'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetState,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yangi'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_imageFile == null) ...[
                    // Empty state
                    const SizedBox(height: 60),
                    Icon(
                      Icons.receipt_long,
                      size: 120,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Invoice yoki Nakladnoy\nrasimga oling',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Google Document AI avtomatik\nma\'lumotlarni ajratib oladi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Camera button
                    ElevatedButton.icon(
                      onPressed: () => _pickAndProcessImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 28),
                      label: const Text(
                        'Kamera',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gallery button
                    OutlinedButton.icon(
                      onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 28),
                      label: const Text(
                        'Galereyadan tanlash',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        side: BorderSide(color: Colors.blue.shade700, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[ 
                    // No products found
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.warning_amber, size: 48, color: Colors.orange.shade700),
                            const SizedBox(height: 12),
                            Text(
                              'Mahsulot topilmadi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Iltimos boshqa invoice rasmi yuklang',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _resetState,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Qayta urinish'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductItem product, int index) {
    if (_editableProducts == null || index > _editableProducts!.length) {
      return const SizedBox.shrink();
    }

    final editableProduct = _editableProducts![index - 1];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: editableProduct.isEditing ? Colors.orange.shade300 : Colors.blue.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: editableProduct.isEditing ? Colors.orange.shade50 : Colors.blue.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: editableProduct.isEditing
                          ? [Colors.orange.shade700, Colors.orange.shade500]
                          : [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: editableProduct.isEditing ? Colors.orange.shade300 : Colors.blue.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Product info
                Expanded(
                  child: editableProduct.isEditing
                      ? _buildEditableFields(editableProduct)
                      : _buildDisplayFields(editableProduct),
                ),

                // Edit/Save button
                IconButton(
                  icon: Icon(
                    editableProduct.isEditing ? Icons.check_circle : Icons.edit,
                    color: editableProduct.isEditing ? Colors.green.shade600 : Colors.blue.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      if (editableProduct.isEditing) {
                        // Validate before saving
                        if (_validateProduct(editableProduct)) {
                          editableProduct.isEditing = false;
                          _showMessage('Saqlandi');
                        }
                      } else {
                        editableProduct.isEditing = true;
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayFields(EditableProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mahsulot nomi
        Text(
          product.nameController.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        // Miqdor va narx
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Miqdor
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade500, Colors.green.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade200,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '${product.quantityController.text}${product.unitController.text.isNotEmpty ? ' ${product.unitController.text}' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Narx
            if (product.priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade500, Colors.orange.shade400],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade200,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      double.tryParse(product.priceController.text)?.toStringAsFixed(2) ?? product.priceController.text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableFields(EditableProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mahsulot nomi
        TextField(
          controller: product.nameController,
          decoration: InputDecoration(
            labelText: 'Mahsulot nomi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Miqdor
            Expanded(
              flex: 2,
              child: TextField(
                controller: product.quantityController,
                decoration: InputDecoration(
                  labelText: 'Miqdor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),

            // Birlik
            Expanded(
              flex: 1,
              child: TextField(
                controller: product.unitController,
                decoration: InputDecoration(
                  labelText: 'Birlik',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Narx
        TextField(
          controller: product.priceController,
          decoration: InputDecoration(
            labelText: 'Narx (ixtiyoriy)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  bool _validateProduct(EditableProduct product) {
    if (product.nameController.text.trim().isEmpty) {
      _showMessage('Mahsulot nomi bo\'sh bo\'lishi mumkin emas');
      return false;
    }

    final quantity = int.tryParse(product.quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showMessage('Miqdor musbat son bo\'lishi kerak');
      return false;
    }

    final priceText = product.priceController.text.trim();
    if (priceText.isNotEmpty) {
      final price = double.tryParse(priceText);
      if (price == null || price < 0) {
        _showMessage('Narx to\'g\'ri formatda bo\'lishi kerak');
        return false;
      }
    }

    return true;
  }
}
