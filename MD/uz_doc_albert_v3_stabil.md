# 📞 AVTOMATLASHTIRISH SKRIPTI: FOYDALANUVCHI QO'LLANMASI (v2.0)

Ushbu qo'llanma Call-markaz operatori uchun kundalik ishlarni (qo'ng'iroq qilish, raqamlardan nusxa olish, jadvallar va Telegram bilan ishlash) tezlashtirishga yordam beradigan tugmalar va rejimlarni tushuntiradi.

---

## ⚙️ 1. ISH REJIMLARINI BOSHQARISH

Dastur bir nechta turli xil ish rejimlariga ega. Har bir rejimda klaviaturadagi tugmalar o'z vazifasini o'zgartiradi.

### 🔄 Rejimlarni almashtirish tugmalari:
*   **`F11` tugmasi:** Asosiy rejimlarni aylanma shaklda o'zgartiradi:
    *   👉 **BITRIX** (CRM tizimida ishlash)
    *   👉 **SVERKA** (Sverka jadvali bilan ishlash)
    *   👉 **NORMAL** (Skriptni vaqtincha o'chirish / oddiy klaviatura holati)
*   **`F12` tugmasi:** Qo'shimcha rejimlarni o'zgartiradi:
    *   👉 **MICROSIP** (Faqat qo'ng'iroqlar bilan ishlash)
    *   👉 **TELEGRAM** (Telegramda xabar yozish va raqam izlash)

### 📝 Holatlarni (Status) sozlash:
*   **`F10` tugmasi:** Ekranda kichik oyna ochiladi. Bu yerdan siz mijozlarga qo'yiladigan avtomatik javoblarni (masalan: *boradi*, *ko'tarmadi*, *gaplashilingan*, *ko'chada*) o'zgartirishingiz va saqlashingiz mumkin.

---

## 🟢 2. REJIMLAR BO'YICHA TUGMALAR VAZIFASI

Siz qaysi rejimni tanlaganingizga qarab, **F1 dan F9 gacha** bo'lgan tugmalar turlicha ishlaydi.

### 🎧 1-REJIM: MICROSIP (Asosiy qo'ng'iroqlar)
Bu rejim jadvaldan raqam olib, tinmasdan qo'ng'iroq qilish uchun mo'ljallangan.

| Tugma | Nima ish qiladi? |
| :--- | :--- |
| **`F1`** | **Qayta qo'ng'iroq:** MicroSIP'ni ochadi va oxirgi terilgan raqamga qayta telefon qiladi. |
| **`F2`** | **Holat: Boradi.** Qo'ng'iroqni o'chiradi -> Jadvalga o'tib "boradi" deb yozadi -> Keyingi raqamni olib (998 siz) darhol qo'ng'iroq qiladi. |
| **`F3`** | **Holat: Ko'tarmadi.** Qo'ng'iroqni o'chiradi -> Jadvalga "ko'tarmadi" deb yozadi -> Keyingi raqamni olib darhol qo'ng'iroq qiladi. |
| **`F4`** | **Holat: Gaplashilingan.** Qo'ng'iroqni o'chiradi -> Jadvalga "gaplashilingan" deb yozadi -> Keyingi raqamni olib qo'ng'iroq qiladi. |
| **`F9`** | Xotiradagi (nusxa olingan) raqamdan "998" va ortiqcha belgilarni tozalab, SIP orqali darhol qo'ng'iroq qiladi. |

### 🏢 2-REJIM: BITRIX (CRM va Telegram qidiruv)
Bu rejim mijoz ma'lumotlarini Bitrix'dan olib, Telegram'da qidirish uchun moslangan.

| Tugma | Nima ish qiladi? |
| :--- | :--- |
| **`F1`** | MicroSIP'da oxirgi raqamga qayta qo'ng'iroq qiladi. |
| **`F2`** | **Telegramda qidirish:** Raqamdan nusxa oladi -> "998" qo'shadi -> Telegramni ochib, qidiruv (Global Search) orqali shu raqamni topib beradi. |
| **`F3`** | **998 ni o'chirish:** Telegram chatida yozuv qatorining boshiga o'tib, "998" ni tezda o'chirib tashlaydi. |
| **`F4`** | **Telegramdan SIP'ga:** Telegramdan nusxa olingan raqamni tozalab (998 siz), MicroSIP'ga qo'yadi va qo'ng'iroqni boshlaydi. |
| **`F9`** | Xotiradagi raqamga "998" qo'shib, xabarlar qatoriga joylab beradi. |

### 📊 3-REJIM: SVERKA
Sverka jadvalining tuzilishi boshqacharoq bo'lgani uchun (kataklar siljishi farq qiladi) maxsus rejim.

| Tugma | Nima ish qiladi? |
| :--- | :--- |
| **`F1`** | MicroSIP'da oxirgi raqamga qayta qo'ng'iroq qiladi. |
| **`F2`** | **Holat: Boradi.** (Sverka katagiga moslab siljiydi) -> "boradi" deb yozib, keyingi raqamga qo'ng'iroq qiladi. |
| **`F3`** | **Holat: Ko'tarmadi.** Qo'ng'iroqni o'chiradi -> "ko'tarmadi" deb yozadi -> keyingi raqamga o'tadi. |
| **`F4`** | **Holat: Ko'chada.** Qo'ng'iroqni o'chiradi -> "ko'chada" deb yozadi -> keyingi raqamga o'tadi. |
| **`F7`** | Oddiy nusxa olish (Ctrl+C). |
| **`F8`** | Oddiy joylash (Ctrl+V). |

### 📨 4-REJIM: TELEGRAM
Telegram orqali mijozlarga xabar jo'natish uchun mo'ljallangan.

| Tugma | Nima ish qiladi? |
| :--- | :--- |
| **`F1`** | Matnni o'chiradi -> Jadvaldan keyingi raqamni (998 bilan) oladi -> Telegramga qaytib joylaydi. |
| **`F2`** | Yozuv qatoridan "998" raqamini o'chirib tashlaydi. |
| **`F3`** | Xotiradagi `F3` holatini (ko'tarmadi) jadvalga yozadi -> Keyingi raqamni olib, Telegramga joylaydi. |
| **`F4`** | Xotiradagi `F4` holatini jadvalga yozadi -> Keyingi raqamni olib, Telegramga joylaydi. |

---

## 🏆 3. STATISTIKA VA SAVDO HISOBOTI

Ushbu tugmalar qaysi rejimda bo'lishingizdan qat'i nazar har doim ishlaydi.

*   **`PrintScreen (PrtScn)` tugmasi:** 
    *   MicroSIP'ni ochadi va qo'ng'iroqni tugatadi (Enter).
    *   Bugungi muvaffaqiyatli sotuvlar soniga **+1** qo'shadi.
    *   Ekranda "Zvonok tugatildi! Bugungi sotuvlar: X" degan yozuv chiqadi.
*   **`Insert` tugmasi:** 
    *   Ekranda **"GRAFIK SOTUVLAR"** nomli oyna ochiladi.
    *   Bu yerda oxirgi 10 kun ichida qilingan sotuvlar soni va progress-bar (yashil chiziqcha) ko'rinishidagi statistika ko'rsatiladi.
*   **`F6` tugmasi:** MicroSIP dasturini butunlay yopadi (avariyali yopish).

---

## 🚀 4. EKRANLAR VA TIZIMNI BOSHQARISH (SUPER TUGMALAR)

Bu tugmalar Windows tizimi, jadvallar va boshqa dasturlarni avtomatik ochish/yopish uchun ishlatiladi.

*   **`Pause / Break` tugmasi:** (Ish kunini boshlash)
    *   Kompyuterdagi barcha kerakli dasturlarni 5 ta turli xil "Virtual ish stollariga" (Virtual Desktop) avtomatik tarzda bo'lib chiqadi.
    *   *1-stol:* Sublime Text.
    *   *2-stol:* YouTube va Yandex.
    *   *3-stol:* Bitrix, Telegram, MicroSIP (Siz shu stolda ishlashni boshlaysiz).
    *   *4-stol:* Sklad CRM va Kalkulyator.
    *   *5-stol:* Razmerlar va Manzillar jadvallari (Excel).
*   **`ScrollLock` tugmasi:** (Ish kunini tugatish / Qutqaruv tugmasi)
    *   Qotib qolgan tugmalarni qo'yib yuboradi.
    *   Barcha ochiq ish dasturlarini (Chrome, Telegram, SIP, Excel va h.k.) xotiradan to'liq va majburiy yopadi.
    *   Barcha oynalarni pastga tushirib, toza ish stolini (Desktop) ko'rsatadi.

---

## 🎵 5. QO'SHIMCHA VA MULTIMEDIA TUGMALARI

Klaviaturangizdagi maxsus tugmalar ham ishni tezlashtirish uchun sozlangan.

*   **`Ovozni pasaytirish` (Volume Down) tugmasi:** Bitta oldingi (chapdagi) ish stoliga o'tadi (Ctrl+Win+Left).
*   **`Ovozni ko'tarish` (Volume Up) tugmasi:** Bitta keyingi (o'ngdagi) ish stoliga o'tadi (Ctrl+Win+Right).
*   **`Uycha` (Browser Home) tugmasi:** Aktiv turgan oyna yoki brauzer tabini yopadi (Ctrl+W) va darhol chapdagi ish stoliga qaytadi.
*   **`Pley (Uchburchak)` tugmasi:** 
    *   Siz nusxa olgan har qanday matndan faqat raqamlarni ajratib oladi (998 siz).
    *   Telegramni ochadi va hamma ochiq chatlardan chiqadi (3 marta Esc).
    *   Tepadagi qadab qo'yilgan (zakrep qilingan) 2-chatga (**"Sverka" kanaliga**) kiradi.
    *   Tozalangan raqamni yozuv qatoriga joylab, bitta probel qo'yib beradi.