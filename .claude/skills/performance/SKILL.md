---
name: performance
description: ทำให้เว็บนักเรียนโหลดเร็วบนมือถือ + เน็ตช้า ด้วยการแก้ 5-6 จุดที่ deterministic preconnect Google Fonts, ใส่ font-display:swap, ใส่ loading=lazy ให้รูปครึ่งล่าง, ใส่ fetchpriority=high ให้รูป hero, preload hero image + critical font, ตรวจขนาดรูปเตือนถ้าใหญ่เกิน 500 KB และเรียก web-images ลดขนาดให้. เน้นเฉพาะที่ stack ของคอร์สใช้ (HTML/CSS + Cloudflare Pages) ข้ามเรื่อง npm framework build pipeline service worker ที่ไม่เกี่ยว เพราะ Cloudflare ทำ Brotli + edge cache + HTTP/3 ให้ฟรีและ web-finish + web-images ทำส่วนอื่นให้แล้ว ครอบคลุม Core Web Vitals ทั้ง 3 ตัว (LCP จาก preload/fetchpriority, INP จาก script defer ของ web-finish, CLS จาก width/height img ใน Step 3.6). Triggers include "ทำให้เว็บเร็ว", "speed up เว็บ", "ทำเว็บโหลดเร็ว", "เว็บโหลดช้า", "lazy load รูป", "preload", "ตรวจ performance", "ทำให้โหลดเร็วบนมือถือ", "speed up my site", "improve performance", "performance audit", "performance", or any similar request to make the page load faster. Auto-fixes the deterministic loading hints and flags oversized images (asks before compressing via web-images). Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# performance ทำให้เว็บโหลดเร็ว

ภารกิจ ทำให้หน้าเว็บแสดงเร็วบนมือถือ + เน็ตช้า โดยแก้สิ่งที่ deterministic ใน HTML ไม่ใช่เรื่อง framework/build pipeline ที่ stack ของคอร์สไม่ได้ใช้

หลักการ แก้ตัวใหญ่ก่อนตัวเล็ก รูป hero 2 MB สำคัญกว่า font 50 KB เป็นพัน

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก

- **ภาษาไทยเรียบง่าย** นักเรียนไม่รู้จัก preload fetchpriority preconnect
- **อธิบายเป็นภาษาคน** ห้ามโชว์ tag code ในรายงาน
- **Fix ก่อน ถามทีหลัง** ส่วนที่มีคำตอบถูกแบบเดียว auto-apply ทันที
- **ห้ามแต่งค่า** ที่ต้องการการตัดสินใจของนักเรียน เช่น "ลดรูปจาก 2 MB → 300 KB ไหม" ต้องถามก่อน
- **เคารพสิ่งที่ skill อื่นทำไปแล้ว**
  - Cloudflare ทำ Brotli + edge cache + HTTP/3 ฟรี ไม่ต้อง config
  - web-finish เพิ่ม defer ใน scripts.js ไปแล้ว ไม่ต้องสั่งซ้ำ
  - web-images optimize รูป (WebP, ลดขนาด) ใช้มันแทนการ implement เอง
- **อย่า over-preload** preload เยอะเกินทำให้สิ่งที่สำคัญช้าลง preload ไม่เกิน 2-3 ตัว (hero image + 1-2 fonts)

---

## Step 1 ตรวจไฟล์พร้อมไหม

อ่าน project root

| สิ่งที่ต้องเจอ | ถ้าไม่เจอ |
|----------------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `assets/images/` (optional) | ถ้ามี ใช้ตรวจขนาดรูป |

---

## Step 2 อ่าน HTML + รวบรวมข้อมูล

อ่าน `index.html` + ทุก `pages/*.html`

เก็บข้อมูล
- มี `<link rel="preconnect" href="https://fonts.gstatic.com">` ใน head หรือไม่
- มี `<link href="https://fonts.googleapis.com/css2?family=...">` หรือไม่ และ URL มี `&display=swap` หรือไม่
- มี self-hosted `@font-face` rule ใน styles.css หรือไม่ และมี `font-display: swap` ครบหรือไม่
- รายการ `<img>` ทุกรูปในหน้า แยกเป็น
  - **hero image** = รูปแรกในหน้า หรืออยู่ใน element class มี "hero"/"header"/"top"
  - **below-fold** = ที่เหลือทั้งหมด
  - ขนาดไฟล์จริง (อ่านจาก `assets/images/` ขนาดเป็น KB)
- มี `<link rel="preload">` อยู่แล้วหรือไม่

---

## Step 3 Auto-fix 5 จุด (เงียบๆ)

แก้ตรงนี้โดยไม่ต้องถาม เพราะมีคำตอบถูกแบบเดียว

### 3.1 Preconnect ให้ Google Fonts

ถ้าหน้าใช้ Google Fonts (เจอ `https://fonts.googleapis.com` ใน HTML) และยังไม่มี preconnect ใส่ใน <head>

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
```

ผลคือ browser เริ่ม TCP+TLS handshake ตั้งแต่ HTML parse ไม่รอจนเจอ link CSS

### 3.2 font-display: swap

**กรณี Google Fonts** ตรวจ URL `fonts.googleapis.com/css2?family=...` มี `&display=swap` ไหม
- ถ้าไม่มี append `&display=swap` ที่ท้าย URL
- ถ้ามี ข้าม

**กรณี self-hosted `@font-face`** ใน styles.css ตรวจทุก rule ว่ามี `font-display: swap` ไหม
- ถ้าไม่มี เพิ่มเข้าไป

ผลคือ browser แสดงตัวอักษรสำรอง (Tahoma sans-serif default) ทันทีระหว่างที่ custom font โหลด ไม่เห็นข้อความหายเป็นจังหวะ (Flash of Invisible Text)

### 3.3 loading="lazy" สำหรับรูปครึ่งล่าง

ทุก `<img>` ที่**ไม่ใช่ hero image** เพิ่ม `loading="lazy"`

```html
<img src="..." alt="..." loading="lazy">
```

ผลคือ browser ไม่โหลดรูปเหล่านี้จนกว่า user เลื่อนใกล้ ประหยัด data + speed up first paint

**สำคัญ** ห้ามใส่ `loading="lazy"` ที่รูป hero เด็ดขาด มันจะทำให้รูปแรกที่ visitor เห็นโหลดช้าลง

### 3.4 fetchpriority="high" สำหรับรูป hero

รูป hero (รูปแรก / อยู่ใน .hero / .header / .top) เพิ่ม `fetchpriority="high"`

```html
<img src="..." alt="..." fetchpriority="high">
```

ผลคือ browser โหลดรูปนี้ก่อนรูปอื่น ก่อน script ก่อน CSS ที่ priority ต่ำกว่า

ถ้าตามมาตรฐาน HTML รูปแรกอาจไม่ได้รับ priority สูงสุดอัตโนมัติ เราบอกชัดเจน

### 3.5 Preload hero image + critical fonts

ใส่ใน <head>

```html
<link rel="preload" as="image" href="assets/images/hero.jpg" fetchpriority="high">
```

ถ้า self-hosted font เช่น `assets/fonts/Sarabun.woff2`
```html
<link rel="preload" as="font" type="font/woff2" href="assets/fonts/Sarabun.woff2" crossorigin>
```

ถ้า Google Fonts ไม่ต้อง preload font แยก (preconnect ใน 3.1 พอแล้ว)

**ไม่เกิน 2-3 ตัว** preload เยอะเกินทำให้สิ่งที่สำคัญที่สุด (hero) ช้าลง

### 3.6 ใส่ width + height ทุก <img> (กันหน้ากระตุก / CLS)

ภาษาคน "จองพื้นที่ให้รูปก่อนรูปจะมาถึง" ถ้าไม่จอง browser จะคิดว่ารูปสูง 0 px ตอนรูปโหลดมา หน้าจะกระโดดลงเพื่อทำที่ให้รูป (เรียก Layout Shift) UX แย่ + Google ลด rank

```
สำหรับทุก <img> ใน HTML
- ถ้ามี width + height attribute ครบแล้ว → ข้าม
- ถ้าขาด → อ่านไฟล์รูปจริงใน assets/images/ เอาขนาด pixel จริง
  แล้วใส่ attribute เช่น width="1200" height="630"
- ไม่กระทบ visual ขนาดแสดงผล (CSS คุมขนาดแสดงผล) attribute แค่บอก ratio
  ให้ browser จองที่ถูกต้องตั้งแต่ HTML parse
```

หา image dimension จริงด้วย (เรียก interpreter ตาม OS macOS ใช้ `python3` Windows ใช้ `python`/`py` ห้ามใช้ python เปล่าบน Mac)
- Python Pillow `Image.open(path).size` (ถ้า web-finish/web-images install Pillow แล้วใช้ตัวเดียวกัน)
- หรือ `from PIL import Image; w,h = Image.open(p).size`
- ถ้าไฟล์ไม่อยู่ (link external) ข้าม

**สำคัญ** ถ้า <img> เป็น `<image-slot>` placeholder ของ Claude Design ที่ยังไม่ถูก web-images แทนที่ ข้ามไป แล้วแจ้งให้รัน web-images ก่อน (มิฉะนั้น dimension จะไม่ตรงรูปจริง)

---

## Step 4 ตรวจขนาดรูป + เสนอลดขนาด (ถาม)

อ่านขนาดไฟล์รูปใน `assets/images/`

| ขนาด | จัดการ |
|------|-------|
| < 200 KB | OK ไม่ต้องทำอะไร |
| 200-500 KB | OK แต่ถ้าเป็นรูป hero เสนอลดให้ ~150-300 KB |
| 500 KB - 1 MB | **เตือน** เสนอเรียก web-images ลดขนาดให้ |
| > 1 MB | **เตือนชัดเจน** เสนอเรียก web-images ลดให้ลง พร้อมแปลงเป็น WebP |

### เสนอนักเรียน

```
⚠️ พบรูปขนาดใหญ่
   - assets/images/hero.jpg = 2.4 MB
   - assets/images/photo-2.jpg = 1.1 MB

รูปใหญ่ทำให้เว็บโหลดช้าโดยเฉพาะบนมือถือ
อยากให้ผมเรียก web-images ลดขนาด + แปลงเป็น WebP ไหม?
target ขนาด: hero ~300 KB, อื่นๆ ~150 KB
คุณภาพยังคงดี ต่างจากตาเปล่าแทบไม่ออก

ตอบ "ทำ" หรือ "ข้าม"
```

ถ้าตอบ "ทำ" เรียก /web-images skill ให้จัดการ
ถ้าตอบ "ข้าม" บันทึก list ไว้ใน FYI section

---

## Step 5 รายงานนักเรียน (3 buckets)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ ทำเว็บให้โหลดเร็วให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ แก้ให้อัตโนมัติแล้ว [N] จุด
   [list จาก Step 3 แปลเป็นภาษาคน]

⚠️ พบจุดที่ควรลดขนาด [M] รูป (รอตอบ)
   [list รูปใหญ่จาก Step 4]

ℹ️ บอกไว้ให้รู้
   - Cloudflare ทำ Brotli compression + edge cache + HTTP/3 ให้ฟรี ไม่ต้อง config
   - script ของ Claude Design ตั้ง defer ไปแล้วโดย web-finish
   - ทดสอบ speed จริงได้ที่ https://pagespeed.web.dev หลัง deploy
```

### ตารางแปลเป็นภาษาคน

| สิ่งที่แก้ | บอกนักเรียนว่า |
|-----------|----------------|
| preconnect Google Fonts | "บอก browser ให้เริ่มต่อ Google Fonts ทันที ไม่รอ" |
| font-display: swap | "แสดงตัวอักษรสำรองก่อนระหว่างที่ font โหลด ไม่เห็นข้อความหายเป็นจังหวะ" |
| loading="lazy" | "รูปที่อยู่ครึ่งล่างของหน้า รอโหลดตอนเลื่อนถึง ประหยัด data" |
| fetchpriority="high" | "รูป hero ใหญ่สุด ตั้งให้โหลดก่อนใคร" |
| preload | "บอก browser ว่าต้องโหลดอะไรก่อนแน่ๆ ไม่ต้องรอเจอใน HTML" |
| width + height img | "จองพื้นที่ให้รูปก่อนรูปจะมาถึง เว็บจะไม่กระตุก/กระโดดตอนรูปโหลด" |
| รูปขนาดเกิน 500 KB | "พบรูป [ชื่อ] ใหญ่ [ขนาด] เสนอลดขนาดให้" |

---

## Step 6 ปิดท้าย

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Performance พร้อม
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ สรุป
- preconnect/preload/lazy/priority/font-display พร้อม
- รูปใหญ่ [ลดแล้ว N รูป / รอ student ตอบ M รูป / ไม่มี]

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ตอน deploy แล้ว ทดสอบที่ https://pagespeed.web.dev
   คะแนน Performance ควรได้ ≥ 90 บนมือถือ
```

---

## Edge cases

### ไม่มีรูปในเว็บ (text-only)

ข้าม Step 3.3 3.4 3.5 (preload image) ข้าม Step 4 (audit รูป) ทำแค่ font (3.1 + 3.2)

### หน้ามีหลาย hero image (gallery / slider)

ตั้ง fetchpriority="high" เฉพาะรูปแรก (active slide) รูปที่เหลือ lazy

### Claude Design ใช้ image-slot.js (lazy ที่ run-time)

ถ้าเจอ class `image-slot` แปลว่ามีระบบ lazy ของ Claude Design อยู่แล้ว ตรวจไม่ทับ ถ้า image-slot ยังไม่ถูกแทนด้วย `<img>` จริง (web-images ยังไม่รัน) แจ้งให้รัน web-images ก่อน

### นักเรียนไม่อยากลดรูป (ต้องการคุณภาพสูง)

เคารพ บันทึกใน FYI section แต่แจ้งว่าจะส่งผลกับ pagespeed คะแนน

### ไม่มี Google Fonts (ใช้ system font ล้วน)

ข้าม 3.1 + 3.2 ทำส่วนอื่น

---

## สิ่งที่ต้องระวัง

- **ห้ามใส่ `loading="lazy"` ที่รูป hero** จะช้าลงมาก
- **ห้ามใส่ `fetchpriority="high"` ที่หลายรูป** browser จะงงว่าโหลดอะไรก่อน
- **preload ไม่เกิน 2-3 ตัว** preload ทุกอย่าง = ไม่ได้ priority อะไรเลย
- **ห้ามลดขนาดรูปเอง** เรียก web-images ให้จัดการเสมอ (มี logic WebP fallback aspect ratio EXIF)
- **อย่าใช้ technical term กับนักเรียน** ไม่ใช้คำว่า preconnect preload fetchpriority CLS LCP FCP TTFB ใช้ภาษาคน "บอก browser โหลดก่อน" "รอโหลดตอนเลื่อนถึง" "ตัวอักษรสำรอง"
- **Cloudflare ทำ compression + cache + HTTP/3 ให้ฟรี** อย่าไปแนะนำให้ install package หรือ config server
- **web-finish ทำ defer scripts ไปแล้ว** อย่าทำซ้ำ
- **web-images optimize รูป ไม่ใช่ skill นี้** delegate เสมอ
- **Step 3.6 ใส่ width/height ทุก img** อ่านขนาด pixel จริงจากไฟล์ใน assets/images/ ห้ามเดาขนาด ห้ามใส่ที่ image-slot ที่ยังไม่ถูกแทนที่
- **localhost ทดสอบ speed ไม่แม่น** Brotli/HTTP3 ทำงานจริงตอน deploy ใช้ pagespeed.web.dev ที่ deploy URL
- **บนเว็บที่ Claude Design vary ขนาด font/รูปตาม breakpoint** preload เฉพาะ asset ที่จะถูกใช้บน mobile breakpoint แน่ๆ
- **ห้ามแตะ element ที่มี `data-cnc-widget`** widget ที่ web-add ฝังไว้ (จองเวลา รีวิว พร้อมเพย์ ฯลฯ) ติด marker นี้ไว้ทุกตัว ห้ามใส่ defer ห้ามย้าย ห้ามแก้ `<script>` ที่มี marker นี้ (widget script บางตัวต้องรันแบบของมันเอง การ optimize จะทำให้พัง) รูปใน widget ใส่ width/height ได้แต่ห้าม rewrite markup รอบๆ marker นี้คือ invariant ที่ทำให้นักเรียนเพิ่ม widget แล้วรัน performance ทีหลังได้โดยไม่พัง
