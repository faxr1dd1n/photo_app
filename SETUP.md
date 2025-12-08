# Sklad Scanner - Setup Yo'riqnomasi

## 🎯 Loyiha haqida
Bu minimal Flutter ilova sklad hujjatlarini scan qilish va ma'lumotlarni avtomatik ajratib olish uchun.

## 🛠 Texnologiyalar
- **OCR**: Google ML Kit Text Recognition
- **Image Picker**: Kamera va galereya
- **API**: HTTP paket

## 📦 O'rnatish

### 1. Dependency'lar allaqachon o'rnatilgan
```bash
flutter pub get
```

### 2. Platform Configuration

#### Android (android/app/src/main/AndroidManifest.xml):
```xml
<manifest>
    <!-- Kamera uchun permission -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.INTERNET"/>

    <application>
        <!-- ML Kit uchun metadata -->
        <meta-data
            android:name="com.google.mlkit.vision.DEPENDENCIES"
            android:value="ocr" />
    </application>
</manifest>
```

#### iOS (ios/Runner/Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>Sklad hujjatlarini scan qilish uchun kamera kerak</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Rasmlarni yuklash uchun galereya kerak</string>
```

### 3. API URL ni o'zgartirish
`lib/services/api_service.dart` faylida o'z backend URL'ingizni kiriting:

```dart
static const String baseUrl = 'https://sizning-api.uz/api';
```

## 🚀 Ishlatish

### Oddiy foydalanish:
1. Ilovani ochish
2. "Kamera orqali" yoki "Galereyadan tanlash" tugmasini bosish
3. Hujjat rasmini olish
4. OCR avtomatik ishlaydi va ma'lumotlarni ko'rsatadi
5. "API ga yuborish" tugmasi orqali backendga yuborish

### Qanday ishlaydi:

```
User → Rasm oladi
  ↓
Google ML Kit OCR → Matnni ajratadi
  ↓
Regex Parser → Product name va quantity topadi
  ↓
JSON → API ga yuboriladi
```

## 📝 API Format

Backend sizga quyidagi formatda JSON oladi:

```json
{
  "product_name": "Cement M400",
  "quantity": 25,
  "unit": "bags"
}
```

## 🔧 Sozlash

### Regex patternlarni o'zgartirish
Agar sizning hujjatlaringiz boshqacha formatda bo'lsa, `lib/services/document_scanner_service.dart` faylida regex pattern'larni sozlang:

```dart
// Mahsulot nomini topish uchun
final productPatterns = [
  RegExp(r'(?:product|mahsulot|товар)[\s:]*(.+)', caseSensitive: false),
];

// Sonni topish uchun
final quantityPatterns = [
  RegExp(r'(?:qty|soni?)[\s:]*(\d+)', caseSensitive: false),
];
```

## 🎨 UI Sozlash
Rang va theme'ni `lib/main.dart` da o'zgartiring:
```dart
colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
```

## ⚠️ Muhim eslatmalar

1. **Internet kerak**: API ga yuborish uchun
2. **Kamera permission**: Birinchi marta so'raladi
3. **ML Kit**: Birinchi marta OCR ishlatganda model yuklanadi (internet kerak)

## 🐛 Muammolar

### OCR ishlamayapti?
- Internet borligiga ishonch hosil qiling (birinchi marta)
- AndroidManifest.xml da ML Kit metadata bor ekanligini tekshiring

### API yuborilmayapti?
- `api_service.dart` da URL to'g'ri ekanligini tekshiring
- Internet borligini tekshiring

## 📱 Test qilish
```bash
# Android
flutter run

# iOS
flutter run
```

## 🔮 Keyingi qadamlar (ixtiyoriy)

Agar oddiy OCR etarli bo'lmasa:
1. **OpenAI Vision API** ishlatish (eng aniq)
2. **Custom backend** yaratish AI bilan
3. **Barcode scanner** qo'shish

---

Yaratuvchi: Claude Code
Sana: 2025-12-04
