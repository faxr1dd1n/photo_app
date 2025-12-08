import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'services/document_scanner_service.dart';
import 'services/api_service.dart';
import 'pages/document_ai_invoice_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sklad Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DocumentScannerPage(),
    );
  }
}

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({super.key});

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  final _scanner = DocumentScannerService();
  final _docScanner = DocumentScannerHelper();
  final _api = ApiService();
  final _picker = ImagePicker();

  File? _imageFile;
  DocumentData? _scannedData;
  bool _isLoading = false;
  String? _loadingMessage; // Loading vaqtida ko'rsatiladigan xabar
  String? _ocrText; // OCR natijasini ko'rsatish uchun
  int _scannedPagesCount = 0; // Nechta sahifa scan qilindi
  bool _useAI = false; // AI parsing yoqilganmi
  String? _parsingMethod; // Qaysi usul ishlatildi

  // ============= GEMINI API KEY =============
  // MUHIM: O'zingizning API key'ingizni kiriting!
  // Free API key: https://makersuite.google.com/app/apikey
  static const String _geminiApiKey = 'AIzaSyCEcHk2kSCs7tL1ndV8MC22dxajVRg81W8';

  @override
  void initState() {
    super.initState();
    // ============= GEMINI O'CHIRILGAN =============
    // Agar API key mavjud bo'lsa, AI parsing ni yoqish
    // if (_geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' && _geminiApiKey.isNotEmpty) {
    //   _enableAIParsing();
    //   // ignore: avoid_print
    //   print('✅ AI PARSING YOQILDI!');
    //   // ignore: avoid_print
    //   print('📝 API Key: ${_geminiApiKey.substring(0, 20)}...');
    // } else {
    //   // ignore: avoid_print
    //   print('❌ AI PARSING O\'CHIRILGAN - API key topilmadi');
    //   // ignore: avoid_print
    //   print('💡 API key kiriting: lib/main.dart, 54-qator');
    // }

    // ignore: avoid_print
    print('ℹ️ Faqat Google Document AI ishlatiladi');
  }

  void _enableAIParsing() {
    setState(() => _useAI = true);
    _scanner.enableAIParsing(_geminiApiKey);
    _docScanner.enableAIParsing(_geminiApiKey);
    // ignore: avoid_print
    print('🤖 AI Parser initialized with Gemini API');
  }

  void _disableAIParsing() {
    setState(() => _useAI = false);
    _scanner.disableAIParsing();
    _docScanner.disableAIParsing();
  }

  /// iOS-like Document Scanner (burchaklarni to'g'irlab crop qilish)
  Future<void> _scanDocumentWithCrop() async {
    try {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Document scanner ochilmoqda...';
      });

      // Document Scanner UI ni ochish
      final scannedImages = await _docScanner.scanDocument();

      if (scannedImages != null && scannedImages.isNotEmpty) {
        // Birinchi rasmni preview uchun saqlash
        setState(() {
          _imageFile = scannedImages.first;
          _scannedPagesCount = scannedImages.length;
          _loadingMessage = 'OCR va ${_useAI ? 'AI' : 'Regex'} parsing...';
        });

        // Barcha sahifalarni OCR qilish
        final result = await _docScanner.scanMultiplePages(scannedImages);

        setState(() {
          _scannedData = result?.data;
          _ocrText = result?.ocrText;
          _parsingMethod = result?.parsingMethod;
          _isLoading = false;
          _loadingMessage = null;
        });

        if (result?.data == null) {
          _showMessage('Ma\'lumot topilmadi. OCR natijasini tekshiring.');
        } else {
          final methodIcon = result?.usedAI == true ? '🤖' : '🔧';
          _showMessage(
            '$methodIcon ${result?.parsingMethod}: $_scannedPagesCount sahifa, ${_scannedData!.products.length} ta mahsulot topildi',
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
      _showMessage('Xatolik: $e');
    }
  }

  /// Oddiy kamera (eskisi kabi)
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _isLoading = true;
          _scannedPagesCount = 1;
          _loadingMessage = 'OCR va ${_useAI ? 'AI' : 'Regex'} parsing...';
        });

        // OCR orqali matnni o'qish
        final result = await _scanner.scanDocument(_imageFile!);

        setState(() {
          _scannedData = result?.data;
          _ocrText = result?.ocrText;
          _parsingMethod = result?.parsingMethod;
          _isLoading = false;
          _loadingMessage = null;
        });

        if (result?.data == null) {
          _showMessage('Ma\'lumot topilmadi. OCR natijasini tekshiring.');
        } else {
          final methodIcon = result?.usedAI == true ? '🤖' : '🔧';
          _showMessage(
            '$methodIcon ${result?.parsingMethod}: ${_scannedData!.products.length} ta mahsulot topildi',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
      _showMessage('Xatolik: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _isLoading = true;
          _scannedPagesCount = 1;
          _loadingMessage = 'OCR va ${_useAI ? 'AI' : 'Regex'} parsing...';
        });

        final result = await _scanner.scanDocument(_imageFile!);

        setState(() {
          _scannedData = result?.data;
          _ocrText = result?.ocrText;
          _parsingMethod = result?.parsingMethod;
          _isLoading = false;
          _loadingMessage = null;
        });

        if (result?.data == null) {
          _showMessage('Ma\'lumot topilmadi. OCR natijasini tekshiring.');
        } else {
          final methodIcon = result?.usedAI == true ? '🤖' : '🔧';
          _showMessage(
            '$methodIcon ${result?.parsingMethod}: ${_scannedData!.products.length} ta mahsulot topildi',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
      _showMessage('Xatolik: $e');
    }
  }

  Future<void> _sendToApi() async {
    if (_scannedData == null) return;

    setState(() => _isLoading = true);

    final success = await _api.sendDocumentData(_scannedData!);

    setState(() => _isLoading = false);

    if (success) {
      _showMessage('Ma\'lumot muvaffaqiyatli yuborildi!');
      _resetState();
    } else {
      _showMessage('Yuborishda xatolik. Qaytadan urinib ko\'ring.');
    }
  }

  void _copyJsonToClipboard() {
    if (_scannedData == null) return;

    final jsonString = const JsonEncoder.withIndent('  ').convert(_scannedData!.toJson());
    Clipboard.setData(ClipboardData(text: jsonString));
    _showMessage('JSON nusxalandi!');
  }

  String _getFormattedJson() {
    if (_scannedData == null) return '';
    return const JsonEncoder.withIndent('  ').convert(_scannedData!.toJson());
  }

  void _resetState() {
    setState(() {
      _imageFile = null;
      _scannedData = null;
      _ocrText = null;
      _scannedPagesCount = 0;
      _loadingMessage = null;
      _parsingMethod = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sklad Hujjat Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Document AI page button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DocumentAIInvoicePage(),
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Google Document AI',
          ),
          // AI status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _useAI ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _useAI ? Colors.green.shade600 : Colors.grey.shade400,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _useAI ? Icons.psychology : Icons.pattern,
                      size: 16,
                      color: _useAI ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _useAI ? 'AI ON' : 'Regex',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _useAI ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (_loadingMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage!,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_imageFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imageFile!,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_ocrText != null && _ocrText!.isNotEmpty) ...[
                    Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.text_fields, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'OCR natijasi (rasmdan o\'qilgan matn):',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: SelectableText(
                                _ocrText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_scannedData != null) ...[
                    // ========== PARSING METHOD INDICATOR ==========
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _parsingMethod?.contains('AI') == true
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _parsingMethod?.contains('AI') == true
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _parsingMethod?.contains('AI') == true
                                ? Icons.psychology
                                : Icons.settings,
                            color: _parsingMethod?.contains('AI') == true
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parsingMethod?.contains('AI') == true
                                      ? '🤖 AI Parsing Ishlatildi'
                                      : '🔧 Regex Parsing Ishlatildi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _parsingMethod?.contains('AI') == true
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _parsingMethod ?? 'Noma\'lum usul',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _parsingMethod?.contains('AI') == true
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _parsingMethod?.contains('AI') == true
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _parsingMethod?.contains('AI') == true ? 'AI' : 'REGEX',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Topilgan mahsulotlar: ${_scannedData!.products.length} ta',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_scannedPagesCount > 1) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.pages,
                                              size: 14,
                                              color: Colors.blue.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_scannedPagesCount sahifa scan qilindi',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_scannedData!.products.length}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._scannedData!.products.asMap().entries.map((entry) {
                              final index = entry.key;
                              final product = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.inventory_2_outlined,
                                                size: 16,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${product.quantity}${product.unit != null ? ' ${product.unit}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.grey[100],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'API ga yuboriladigan JSON:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _copyJsonToClipboard,
                                  icon: const Icon(Icons.copy, size: 20),
                                  tooltip: 'Nusxalash',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                _getFormattedJson(),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _sendToApi,
                      icon: const Icon(Icons.send),
                      label: const Text('API ga yuborish'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _resetState,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yangi rasm'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.document_scanner,
                      size: 100,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sklad hujjatini rasimga oling',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    // Google Document AI promo card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DocumentAIInvoicePage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade50, Colors.blue.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.cloud,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Google Document AI',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kuchliroq AI invoice scanner',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Asosiy Document Scanner tugmasi (iOS-like)
                    ElevatedButton.icon(
                      onPressed: _scanDocumentWithCrop,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Document Scanner (iOS-like)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Burchaklarni to\'g\'irlab crop qilish',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Yoki oddiy kamera',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Oddiy kamera'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galereyadan tanlash'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

}