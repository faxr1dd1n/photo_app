# Google Document AI Setup Guide

Bu loyihada Google Document AI integration qo'shildi. Quyidagi qadamlarni bajaring:

## 1. Google Cloud Project yaratish

1. [Google Cloud Console](https://console.cloud.google.com/) ga kiring
2. Yangi project yarating yoki mavjud projectni tanlang
3. Billing ni yoqing (Document AI trial uchun kredit karta kerak, lekin 1000 ta request/oy bepul)

## 2. Document AI API ni yoqish

1. Cloud Console da **APIs & Services > Library** ga o'ting
2. "Document AI API" ni qidiring
3. **Enable** tugmasini bosing

## 3. Invoice Processor yaratish

1. **Document AI > Processors** ga o'ting
2. **Create Processor** tugmasini bosing
3. Processor type: **Invoice Parser** ni tanlang
4. Processor nomini kiriting (masalan: "invoice-processor")
5. Region: **us** yoki **eu** ni tanlang
6. **Create** tugmasini bosing
7. **Processor ID** ni nusxalab oling (masalan: `abc123def456`)

## 4. Service Account yaratish

1. **IAM & Admin > Service Accounts** ga o'ting
2. **Create Service Account** tugmasini bosing
3. Nom kiriting (masalan: "document-ai-service")
4. **Create and Continue** tugmasini bosing
5. Role: **Document AI API User** ni tanlang
6. **Continue > Done** tugmasini bosing

## 5. Service Account Key yuklab olish

1. Yaratilgan service account ni oching
2. **Keys** tabiga o'ting
3. **Add Key > Create new key** ni bosing
4. **JSON** ni tanlang va **Create** tugmasini bosing
5. JSON file yuklab olinadi

## 6. Loyihaga Key qo'shish

1. Yuklab olingan JSON file nomini `service_account.json` ga o'zgartiring
2. Uni `assets/` papkasiga joylashtiring:
   ```
   photo_app/
   ├── assets/
   │   └── service_account.json  ← Bu yerga
   ├── lib/
   └── pubspec.yaml
   ```

## 7. Project ID va Processor ID ni kiriting

`lib/pages/document_ai_invoice_page.dart` faylini oching va quyidagi qatorlarni o'zgartiring:

```dart
_documentAI = DocumentAIService(
  projectId: "YOUR_PROJECT_ID",        // ← Google Cloud project ID
  processorId: "YOUR_PROCESSOR_ID",    // ← Invoice processor ID
  location: "us",                      // yoki "eu"
);
```

**Project ID ni topish:**
- Cloud Console da yuqori chap burchakdagi project nomini bosing
- Project ID ko'rinadi (masalan: `my-project-123456`)

**Processor ID ni topish:**
- Document AI > Processors da processor nomini bosing
- URL dagi oxirgi qism - bu processor ID
- URL: `https://console.cloud.google.com/.../processors/abc123def456`
- Processor ID: `abc123def456`

## 8. Ishga tushirish

1. Dependencies ni o'rnatish:
   ```bash
   flutter pub get
   ```

2. Ilovani ishga tushirish:
   ```bash
   flutter run
   ```

3. Main ekranda **Google Document AI** kartochkasini bosing
4. Kamera yoki galereyadan invoice rasmini yuklang
5. Document AI avtomatik ma'lumotlarni ajratib oladi

## Xatoliklarni bartaraf etish

### "Unable to load asset"
- `assets/service_account.json` fayli mavjudligini tekshiring
- `pubspec.yaml` da asset to'g'ri ko'rsatilganligini tekshiring

### "401 Unauthorized"
- Service account key noto'g'ri yoki eskirgan
- Yangi key yarating va qayta urinib ko'ring

### "403 Permission Denied"
- Service account ga **Document AI API User** role berilganligini tekshiring
- Document AI API yoqilganligini tekshiring

### "404 Not Found"
- Project ID yoki Processor ID noto'g'ri kiritilgan
- Location (`us` yoki `eu`) to'g'ri tanlanganligini tekshiring

## Narxlar

Google Document AI pricing:
- **Free tier:** 0-1,000 pages/month - **$0**
- **Standard:** 1,001-1,000,000 pages - **$1.50 per 1,000 pages**

Invoice Parser uchun har bir sahifa 1 ta page hisoblanadi.

## Qo'shimcha ma'lumot

- [Document AI Documentation](https://cloud.google.com/document-ai/docs)
- [Invoice Parser Guide](https://cloud.google.com/document-ai/docs/processors-list#processor_invoice-processor)
- [Pricing](https://cloud.google.com/document-ai/pricing)
