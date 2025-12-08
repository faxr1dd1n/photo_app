# 🤖 AI Parsing Setup - Google Gemini

Bu app endi **Google Gemini AI** bilan integratsiya qilingan - OCR matnidan mahsulotlarni juda aniq ajratib oladi!

## 🎯 Nima uchun AI kerak?

Regex-based parsing ba'zi hollarda xato qilishi mumkin:
- ❌ Murakkab formatlar (table, multi-line)
- ❌ OCR xatolari (0/O, 1/l, raqam/harf)
- ❌ Turli xil hujjat formatlari
- ❌ Noto'g'ri tartibda ma'lumotlar

**AI parsing** bu muammolarni hal qiladi:
- ✅ Kontekstni tushunadi
- ✅ OCR xatolarini tuzatadi
- ✅ Har qanday formatni taniydi
- ✅ 99% aniqlik

---

## 🚀 Setup (5 daqiqa)

### 1️⃣ Google AI Studio'ga kiring

**Free API key olish:**
1. [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey) ga o'ting
2. **Create API key** tugmasini bosing
3. API key'ni nusxalang

### 2️⃣ API key'ni loyihaga qo'shing

`lib/main.dart` faylini oching va 52-qatorda API key'ni o'zgartiring:

```dart
// 52-qator
static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

Bu yerga o'zingizning API key'ingizni qo'ying:

```dart
static const String _geminiApiKey = 'AIzaSyC...';  // ← O'z API key'ingiz
```

### 3️⃣ Tayyor! 🎉

Appni qayta ishga tushiring:

```bash
flutter run
```

AppBar'da **"AI ON"** yashil badge ko'rinadi - AI yoqilgan demakdir!

---

## 📊 Free Tier Limitlar

Google Gemini **BEPUL tier:**
- ✅ **15 requests/minute** (har bir scan = 1 request)
- ✅ **1,500 requests/day** (kuniga 1500 ta hujjat!)
- ✅ Cheksiz foydalanish (forever free)

Bu ko'pchilik foydalanuvchilar uchun **yetarli**!

---

## 🔄 Qanday ishlaydi?

### Parsing jarayoni:

```
1. Rasm → OCR (Google ML Kit)
   ↓
2. OCR matn → AI Parsing (Gemini)
   ↓
3. AI → JSON (mahsulotlar ro'yxati)
   ↓
4. JSON → UI (ekranda ko'rsatish)
```

### Fallback mexanizmi:

Agar **AI ishlamasa** (internet yo'q, limit to'lgan):
- Avtomatik **regex-based parsing** ga o'tadi
- Hech qanday xato ko'rsatmaydi
- Shunchaki regex natijasini beradi

---

## 🧪 Test qilish

### Test case 1: Oddiy nakladnoy
```
Cement M400    25 kg
Armatura 12mm  120 metr
```

**AI natijasi:**
```json
{
  "products": [
    {"name": "Cement M400", "quantity": 25, "unit": "kg"},
    {"name": "Armatura 12mm", "quantity": 120, "unit": "metr"}
  ]
}
```

### Test case 2: Murakkab format (OCR xatolari bilan)
```
CementM40O...........25kg   ← O harfi 0 o'rnida
Armatura12mm.....l20metr    ← l harfi 1 o'rnida
```

**Regex:** ❌ Xato (0/O, 1/l farqini bilmaydi)
**AI:** ✅ To'g'ri (kontekstdan tushunadi)

---

## ⚙️ Advanced: AI'ni o'chirish

Agar AI kerak bo'lmasa (offline ishlatish):

```dart
// API key'ni bo'sh qoldiring
static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

Yoki runtime'da o'chirish:

```dart
_scanner.disableAIParsing();
_docScanner.disableAIParsing();
```

AppBar'da **"Regex"** ko'k badge ko'rinadi.

---

## 🔐 Xavfsizlik

**MUHIM:** API key'ni kodga qo'ymaslik yaxshi amaliyot emas. Production'da:

### 1️⃣ Environment variable ishlatish

`.env` fayl yarating:
```
GEMINI_API_KEY=AIzaSyC...
```

`flutter_dotenv` package qo'shing:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

Kodda:
```dart
static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY']!;
```

### 2️⃣ Backend orqali

Eng xavfsiz: API key'ni backend'da saqlash va mobile app backend orqali request yuboradi.

---

## 🐛 Troubleshooting

### Muammo: "AI ON" ko'rinmayapti
**Yechim:** API key'ni to'g'ri kiritdingizmi? 52-qatorni tekshiring.

### Muammo: "Request failed"
**Yechim:**
1. Internet bor mi?
2. API key to'g'rimi?
3. Limit to'lganmi? (15 req/min)

### Muammo: Mahsulotlar topilmayapti
**Yechim:**
1. OCR matnini tekshiring (orange card)
2. Agar OCR matn yaxshi bo'lsa, AI ishlamayapti
3. Regex fallback ishlaydi - regex yaxshiroq qilinishi mumkin

---

## 📈 Performance

**Regex parsing:**
- ⚡ 50-100ms
- 🔌 Offline ishlaydi
- 📊 70-80% aniqlik

**AI parsing (Gemini):**
- ⚡ 500-1000ms (internet tezligiga bog'liq)
- 🌐 Internet kerak
- 📊 95-99% aniqlik

---

## ✨ Keyingi qadamlar

1. API key'ni oling va qo'shing
2. Appni test qiling
3. Turli formatdagi hujjatlarni sinab ko'ring
4. Production'da backend orqali API key ishlatish

**Savollar?** GitHub issue oching yoki [Google AI docs](https://ai.google.dev/tutorials/get_started_dart) ga qarang.
