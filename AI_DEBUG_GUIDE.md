# 🔍 AI vs Regex - Debug Guide

AI yoki Regex ishlatilganini **100% aniq** bilish uchun to'liq guide.

---

## ✅ App Ochilganda (Console)

App ishga tushganda console'da:

### AI yoqilgan bo'lsa:
```
✅ AI PARSING YOQILDI!
📝 API Key: AIzaSyCEcHk2kSCs7tL...
🤖 AI Parser initialized with Gemini API
```

### AI o'chirilgan bo'lsa:
```
❌ AI PARSING O'CHIRILGAN - API key topilmadi
💡 API key kiriting: lib/main.dart, 54-qator
```

---

## 📱 UI Indicators

### 1. AppBar Badge (O'ng burchak)

**AI yoqilgan:**
```
┌────────────────────────────┐
│ Sklad Scanner     [AI ON]  │  ← Yashil
└────────────────────────────┘
```

**AI o'chirilgan:**
```
┌────────────────────────────┐
│ Sklad Scanner     [Regex]  │  ← Kulrang
└────────────────────────────┘
```

---

### 2. Parsing Method Badge (Natijalar ostida)

**AI ishlatilgan:**
```
╔═══════════════════════════════╗
║ 🤖 AI Parsing Ishlatildi      ║
║ AI (Gemini)              [AI] ║
╚═══════════════════════════════╝
     ↑                        ↑
   Yashil                  Yashil badge
```

**Regex ishlatilgan:**
```
╔═══════════════════════════════╗
║ 🔧 Regex Parsing Ishlatildi   ║
║ Regex                 [REGEX] ║
╚═══════════════════════════════╝
     ↑                        ↑
   To'q sariq            To'q sariq badge
```

**Bu eng aniq indicator!** Natijalarning tepasida katta card ko'rinadi.

---

## 🖥️ Console Logs (Real-time)

### AI ishlayotganda:

```
═══════════════════════════════════════
🤖 GEMINI AI PARSING BOSHLANDI
═══════════════════════════════════════
📄 OCR matn uzunligi: 145 belgi
🌐 Gemini API ga request yuborilmoqda...
✅ Gemini javob olindi
📝 Gemini javobi: {
  "products": [
    {"name": "Cement M400", "quantity": 25, "unit": "kg"},
    ...

🎉 AI MUVAFFAQIYATLI!
📊 Topilgan mahsulotlar: 3 ta
   1. Cement M400 - 25 kg
   2. Armatura 12mm - 120 metr
   3. Gips Knauf - 30 bag
═══════════════════════════════════════
```

### Regex ishlayotganda:

```
🤖 AI Parsing boshlandi (Gemini)...
❌ AI xatolik: [xato matni], Regex fallback...
🔧 Regex parsing boshlandi...
✅ Regex: 2 ta mahsulot topildi
```

---

## 🧪 Test Qilish (Bosqichma-bosqich)

### Test 1: AI yoqilganligini tekshirish

1. **Appni ishga tushiring:**
```bash
flutter run
```

2. **Console'ni oching:**
   - VS Code: `View → Debug Console`
   - Android Studio: `Run → View Console`

3. **Birinchi qatorlarni o'qing:**
```
✅ AI PARSING YOQILDI!          ← Bor = AI yoqilgan
📝 API Key: AIzaSyC...          ← API key to'g'ri
🤖 AI Parser initialized...     ← Init muvaffaqiyatli
```

✅ **Agar bu 3 ta qator ko'rinsa - AI ishga tayyor!**

---

### Test 2: Rasm scan qilish (AI test)

1. **Har qanday usulda rasm oling:**
   - Document Scanner
   - Oddiy kamera
   - Galereyadan

2. **Console'ni kuzating:**

**AI ishlayotganini ko'rasiz:**
```
═══════════════════════════════════════
🤖 GEMINI AI PARSING BOSHLANDI
═══════════════════════════════════════
📄 OCR matn uzunligi: 145 belgi
🌐 Gemini API ga request yuborilmoqda...
    ↑
   Bu 2-3 soniya davom etishi mumkin (internet tezligiga bog'liq)

✅ Gemini javob olindi
    ↑
   AI javob qaytardi!

🎉 AI MUVAFFAQIYATLI!
📊 Topilgan mahsulotlar: X ta
```

3. **UI'ni tekshiring:**

Natijalar ostida **KATTA YASHIL CARD** ko'rinadi:
```
╔═══════════════════════════════╗
║ 🤖 AI Parsing Ishlatildi      ║  ← YASHIL
║ AI (Gemini)              [AI] ║
╚═══════════════════════════════╝
```

✅ **Agar yashil card va console'da "GEMINI AI PARSING" ko'rinsa - 100% AI ishladi!**

---

### Test 3: Internet yo'q (Regex fallback test)

1. **Telefonning internetini o'chiring**

2. **Rasm scan qiling**

3. **Console:**
```
🤖 AI Parsing boshlandi (Gemini)...
❌ AI xatolik: SocketException, Regex fallback...
🔧 Regex parsing boshlandi...
✅ Regex: X ta mahsulot topildi
```

4. **UI:**
```
╔═══════════════════════════════╗
║ 🔧 Regex Parsing Ishlatildi   ║  ← TO'Q SARIQ
║ Regex                 [REGEX] ║
╚═══════════════════════════════╝
```

✅ **Smart fallback ishlaydi!**

---

## 🎯 Qaysi Usulda AI Ishlaydi?

**HAMMA USULDA! ✅**

| Scan Usuli | AI Support | Console Log Boshlangan |
|------------|------------|------------------------|
| 📱 Document Scanner | ✅ Ha | `🤖 AI Parsing boshlandi (multi-page, Gemini)...` |
| 📷 Oddiy Kamera | ✅ Ha | `🤖 AI Parsing boshlandi (Gemini)...` |
| 🖼️ Galereyadan | ✅ Ha | `🤖 AI Parsing boshlandi (Gemini)...` |

---

## 🐛 Troubleshooting

### Muammo: "AI ON" ko'rinmayapti

**Tekshirish:**
```dart
// lib/main.dart, 54-qator
static const String _geminiApiKey = 'AIzaSyC...';
```

- `'YOUR_GEMINI_API_KEY_HERE'` bo'lsa → O'zgartiring
- Bo'sh bo'lsa → API key kiriting

**Console:**
```
❌ AI PARSING O'CHIRILGAN - API key topilmadi
```

---

### Muammo: Hamma vaqt "Regex" ko'rinmoqda

**Sabablar:**

1. **Internet yo'q**
   - Test: `ping google.com`
   - Yechim: Wi-Fi yoqing

2. **API key xato**
   - Console: `❌ AI xatolik: API_KEY_INVALID`
   - Yechim: API key'ni yangilang

3. **API limit to'lgan**
   - Console: `❌ AI xatolik: quota exceeded`
   - Yechim: 1 daqiqa kuting (15 req/min limit)

---

### Muammo: Console'da hech narsa ko'rinmayapti

**VS Code:**
1. `Run and Debug` (Ctrl+Shift+D)
2. `Start Debugging` (F5)
3. `Debug Console` tab'ini oching

**Android Studio:**
1. `Run` → `Run 'main.dart'`
2. Pastdagi `Run` tab'ini oching
3. Console output'ni ko'ring

---

## 📊 AI vs Regex - Vizual Farq

### AI Natijasi:
```
╔════════════════════════════════════════╗
║ 🤖 AI Parsing Ishlatildi               ║
║ AI (Gemini)                       [AI] ║  ← YASHIL
╚════════════════════════════════════════╝

Topilgan mahsulotlar: 5 ta

┌────────────────────────────────────────┐
│ 1  Cement M400                         │
│    📦 25 kg                            │
├────────────────────────────────────────┤
│ 2  Armatura 12mm                       │
│    📦 120 metr                         │
└────────────────────────────────────────┘
```

### Regex Natijasi:
```
╔════════════════════════════════════════╗
║ 🔧 Regex Parsing Ishlatildi            ║
║ Regex                           [REGEX]║  ← TO'Q SARIQ
╚════════════════════════════════════════╝

Topilgan mahsulotlar: 2 ta

┌────────────────────────────────────────┐
│ 1  Cement                              │
│    📦 25 kg                            │
└────────────────────────────────────────┘
```

**Ko'ryapsizmi?** AI 5 ta topdi, Regex faqat 2 ta!

---

## ✨ Xulosa

### AI ishlayotganini bilish uchun:

1. ✅ **App ochilganda console:** `✅ AI PARSING YOQILDI!`
2. ✅ **AppBar:** `[AI ON]` yashil badge
3. ✅ **Scan vaqtida console:** `🤖 GEMINI AI PARSING BOSHLANDI`
4. ✅ **Natijada:** Yashil card `🤖 AI Parsing Ishlatildi`

### Agar birorta ham ko'rinmasa:

1. API key'ni tekshiring (54-qator)
2. Internetni tekshiring
3. Console logs'ni o'qing
4. Bu guide'ni qayta o'qing

**Hali muammo bo'lsa, console screenshot yuboring!** 📸
