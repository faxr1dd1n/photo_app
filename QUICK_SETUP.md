# Tezkor Setup - Document AI

## ❌ Xatolik: 403 Permission Denied

Bu xatolik **PROJECT_ID** va **PROCESSOR_ID** o'zgartirilmagani uchun yuzaga keladi.

---

## ✅ YECHIM - 5 daqiqada

### 1. Google Cloud Console ga kiring

[https://console.cloud.google.com/](https://console.cloud.google.com/)

### 2. Project yarating yoki tanlang

Yuqori chap burchakdan:
- Yangi project: **New Project** → nom kiriting → **Create**
- Yoki mavjud projectni tanlang

**MUHIM:** Project ID ni yozib oling (masalan: `my-app-123456`)

### 3. Document AI API ni yoqing

Console da qidiruv qatoriga yozing: **"Document AI API"**
- **Enable** tugmasini bosing
- 1-2 daqiqa kutib turing

### 4. Invoice Processor yaratish

1. Menyudan: **Artificial Intelligence** → **Document AI** → **Processors**
2. **CREATE PROCESSOR** tugmasini bosing
3. **Processor type:** **Invoice Parser** ni tanlang
4. **Processor name:** `invoice-processor` (ixtiyoriy nom)
5. **Region:** **us** (yoki **eu** Evropa uchun)
6. **CREATE** tugmasini bosing

### 5. Processor ID ni nusxalash

Processor yaratilgach:
- Processor nomini bosing (masalan: "invoice-processor")
- **Processor ID** ko'rinadi (masalan: `abc123def456789`)
- Yoki URL dan oling: `.../processors/ABC123...` ← bu qism

URL misol:
```
https://console.cloud.google.com/ai/document-ai/locations/us/processors/abc123def456789
                                                                         ^^^ Bu Processor ID
```

### 6. Service Account yaratish

1. Menyudan: **IAM & Admin** → **Service Accounts**
2. **CREATE SERVICE ACCOUNT**
3. **Name:** `doc-ai-service` → **CREATE**
4. **Role:** **Document AI API User** ni tanlang → **CONTINUE**
5. **DONE**

### 7. Service Account Key yuklab olish

1. Yaratgan service account ni bosing
2. **KEYS** tab → **ADD KEY** → **Create new key**
3. **JSON** → **CREATE**
4. JSON file yuklab olinadi

### 8. Key ni loyihaga qo'shish

Terminal da:
```bash
# Photo app papkasiga o'ting
cd /Users/mac/StudioProjects/photo_app

# assets papkasini yarating (agar yo'q bo'lsa)
mkdir -p assets

# Yuklab olingan JSON file ni assets ga ko'chiring
# (Downloads dan assets ga)
mv ~/Downloads/my-project-abc123-xyz789.json assets/service_account.json
```

Yoki Finder da:
- Downloads dagi JSON file ni topish
- Nomini `service_account.json` ga o'zgartirish
- `photo_app/assets/` ga ko'chirish

### 9. Kodni yangilash

`lib/pages/document_ai_invoice_page.dart` faylini oching va 39-41 qatorlarni yangilang:

**AVVAL:**
```dart
_documentAI = DocumentAIService(
  projectId: "YOUR_PROJECT_ID",      // ← BU NOTO'G'RI!
  processorId: "YOUR_PROCESSOR_ID",  // ← BU NOTO'G'RI!
  location: "us",
);
```

**KEYIN:**
```dart
_documentAI = DocumentAIService(
  projectId: "my-photo-app-123456",           // ← O'z Project ID
  processorId: "abc123def456789",             // ← O'z Processor ID
  location: "us",  // yoki "eu" agar processor "eu" da bo'lsa
);
```

### 10. Ishga tushirish

```bash
flutter pub get
flutter run
```

---

## ✅ Tekshirish

Agar hammasi to'g'ri bo'lsa:
- ✅ Document AI page ochiladi
- ✅ Rasm yuklanadi
- ✅ Ma'lumotlar ajratib olinadi
- ✅ Xatolik yo'q

## ❌ Agar yana xatolik bo'lsa:

### "Unable to load asset: assets/service_account.json"
- `assets/service_account.json` fayli mavjudligini tekshiring
- Fayl nomi to'g'ri yozilganligini tekshiring (kichik harflar!)

### "401 Unauthorized"
- Service account key noto'g'ri
- Yangi key yarating va qayta urinib ko'ring

### "404 Not Found"
- Processor ID noto'g'ri
- Processor ni oching va ID ni qayta nusxalang

---

## Yordam

Agar muammo hal bo'lmasa, quyidagilarni yuboring:
1. Konsolda chiqayotgan xato matni
2. Project ID (birinchi 4 ta belgisini yashiring)
3. Region (us yoki eu)
