---
name: accessibility
description: ทำให้ทุกคนเข้าใช้เว็บนักเรียนได้ ทั้งคนตาบอด คนใช้ keyboard อย่างเดียว คนพิการ. Auto-fix 5 จุด deterministic (skip link สำหรับ keyboard, focus visible CSS, aria-label บนปุ่มไอคอน LINE/โทร/menu, จับคู่ label-input ในฟอร์ม, alt="" บนรูปประดับที่มี aria-hidden อยู่แล้ว) แล้วถามนักเรียนแค่ alt text ของรูปเนื้อหา. ข้ามเรื่อง color contrast เพราะ Claude Design มี brand color ที่นักเรียนเลือกตั้งใจในขั้น web-design และการเปลี่ยนสีจะกระทบ identity (มีลิงก์ webaim ใน FYI ถ้านักเรียนอยากตรวจเอง). Triggers include "ตรวจ accessibility", "ทำ a11y", "ให้คนพิการเข้าใช้ได้", "ใส่ alt รูป", "ใส่ aria label", "ทำให้ screen reader อ่านได้", "skip link", "tab navigation", "improve accessibility", "a11y audit", "WCAG", "accessibility", or any similar request. ข้ามสิ่งที่ skill อื่นทำแล้ว (lang seo จัดการ, tap target + font size web-finish จัดการ). Auto-fix the deterministic patterns silently and auto-generates image alt text from filename + section + nearby text + CLAUDE.md context with high confidence (only asks the student when filename is generic like IMG_1234.jpg or for icon-only buttons that cannot be inferred). Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# accessibility ทำให้ทุกคนเข้าใช้เว็บได้

ภารกิจ ทำให้เว็บนักเรียนเข้าใช้ได้สำหรับ 3 กลุ่มที่มักเจอปัญหา
- คนตาบอด ใช้ screen reader (VoiceOver iOS, TalkBack Android, NVDA Windows) ฟังเว็บ
- คนใช้ keyboard อย่างเดียว ไม่ใช้เม้าส์/touchpad
- คนพิการมือ ใช้ปุ่ม Tab เลื่อนทีละจุด

หลักการ auto-fix สิ่งที่มีคำตอบถูกแบบเดียว และถามแค่ alt text รูปเนื้อหา (เพราะคนเดียวที่รู้ว่ารูปคืออะไรคือเจ้าของรูป)

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก

- **ภาษาไทยเรียบง่าย** นักเรียนไม่รู้จัก WCAG ARIA screen reader focus state
- **อธิบายเป็นภาษาคน** ไม่ใช้คำว่า ARIA WCAG semantic landmark
- **Fix ก่อน ถามทีหลัง** ส่วน deterministic auto-apply
- **ห้ามแต่ง alt text เอง** ถ้านักเรียนยังไม่ได้บอก ถามเสมอ ห้ามเดาจากชื่อไฟล์ (เดาผิดเป็นข้อมูลเท็จ)
- **ห้ามแก้สี brand** color contrast = brand decision นักเรียนตั้งใจเลือกใน web-design การเปลี่ยนสีกระทบ identity ใส่ลิงก์ webaim ใน FYI ถ้านักเรียนอยากตรวจเอง ไม่ flag ไม่เสนอ
- **ห้ามแก้ heading hierarchy** การ restructure h1→h2→h3 อาจทำ layout พัง แจ้งใน FYI ถ้าเจอ ให้นักเรียนตัดสินใจ
- **เคารพสิ่งที่ skill อื่นทำแล้ว**
  - seo จัดการ `<html lang="th">` `<title>`
  - web-finish จัดการ tap target ≥ 44px (M4), font-size ≥ 16px (M3)
  - performance จัดการ image dimensions + lazy

---

## Step 1 ตรวจไฟล์พร้อมไหม

อ่าน project root

| สิ่งที่ต้องเจอ | ถ้าไม่เจอ |
|----------------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `styles.css` (optional) | ใช้ใส่ focus + skip link CSS |

---

## Step 2 อ่าน HTML ทุกหน้า เก็บข้อมูล

อ่าน `index.html` + ทุก `pages/*.html`

เก็บข้อมูล
- ทุก `<img>` แยกเป็น **content image** (รูป hero/ผลงาน/ลูกค้า) กับ **decorative** (มี aria-hidden="true" หรือ role="presentation" หรืออยู่ใน .icon class)
- ทุก `<button>` และ `<a>` ที่เป็น **icon-only** (เนื้อหาไม่มี text หลังตัด SVG/img ออก)
- ทุก `<input>` `<select>` `<textarea>` ดูว่ามี `<label for="...">` ผูกอยู่ไหม
- ทุก heading (h1-h6) เช็ค hierarchy ว่า cascade ถูกไหม (มี h1 เดียว, ไม่กระโดดจาก h2 → h4)
- มี `<main>` หรือ landmark element อื่นไหม

---

## Step 3 Auto-fix 5 จุด (เงียบๆ)

### 3.1 Skip link สำหรับ keyboard user

ใส่เป็นบรรทัดแรกหลัง `<body>` ใน index.html + ทุก page

```html
<a href="#main" class="skip-link">ข้ามไปเนื้อหา</a>
```

เพิ่ม CSS ใน styles.css

```css
.skip-link {
  position: absolute;
  left: -9999px;
  top: 0;
  z-index: 9999;
}
.skip-link:focus {
  left: 16px;
  top: 16px;
  background: var(--color-bg, #1a1a1a);
  color: var(--color-text, #f0f0f0);
  padding: 8px 16px;
  text-decoration: none;
  border: 2px solid var(--color-accent, currentColor);
}
```

ใส่ `id="main"` ที่ `<main>` element ถ้าไม่มี `<main>` ใส่ที่ `<section>` แรกหลัง header/hero

ผล user กด Tab ครั้งแรก link "ข้ามไปเนื้อหา" จะปรากฏ กดอีกครั้งกระโดดไปเนื้อหาเลย ไม่ต้อง tab ผ่าน nav ทุกครั้ง

### 3.2 Focus visible CSS

เพิ่มใน styles.css ถ้ายังไม่มี

```css
:focus-visible {
  outline: 2px solid var(--color-accent, currentColor);
  outline-offset: 2px;
  border-radius: 2px;
}

a, button, input, select, textarea, [tabindex] {
  outline: none;
}

a:focus-visible, button:focus-visible,
input:focus-visible, select:focus-visible,
textarea:focus-visible, [tabindex]:focus-visible {
  outline: 2px solid var(--color-accent, currentColor);
  outline-offset: 2px;
}
```

ผล keyboard user เห็นชัดว่าตอนนี้ Tab อยู่ที่ไหน (mouse user ไม่เห็น `:focus-visible` ตามมาตรฐาน browser)

### 3.3 aria-label บนปุ่มไอคอน

ตรวจทุก `<button>` และ `<a>` ที่ inner text ว่าง (หลังตัด `<svg>` `<img>` ออก)

inferred จาก context ปลอดภัยที่จะ auto-fix
| pattern | aria-label |
|---------|-----------|
| href มี "line.me" หรือ class มี "line" | `แอดไลน์` |
| href ขึ้นต้น "tel:" หรือ class มี "phone" "call" | `โทรเรา` |
| href ขึ้นต้น "mailto:" | `ส่งอีเมล` |
| href มี "facebook.com" | `Facebook` |
| href มี "instagram.com" | `Instagram` |
| href มี "tiktok.com" | `TikTok` |
| href มี "youtube.com" | `YouTube` |
| class มี "menu" "hamburger" "burger" | `เปิดเมนู` |
| class มี "close" "dismiss" | `ปิด` |
| class มี "search" + ไม่มี text | `ค้นหา` |

ถ้า icon-only แต่ infer ไม่ได้ ใส่ใน Step 4 ask list

### 3.4 Form label ผูกกับ input

สำหรับทุก `<input>` `<select>` `<textarea>` ที่ไม่มี label

```
ถ้า input อยู่ใน <label>...<input>...</label> → ผ่าน
ถ้ามี <label for="id"> ผูกกับ input id → ผ่าน
ถ้าไม่มี
  - ถ้า input มี placeholder ใช้ placeholder เป็น label text
  - ถ้าไม่มี placeholder ดู text ใกล้ๆ ก่อน input (เช่น span class field__label)
  - สร้าง <label for="<input-id>"><text></label> ใส่ไว้ก่อน input
  - ถ้า input ยังไม่มี id ใส่ id อัตโนมัติ id="field-<น>"
```

ผล screen reader อ่าน "ชื่อ ช่องกรอก" แทน "ช่องกรอก" เปล่าๆ

### 3.5 alt="" บนรูปประดับ deterministic

ถ้ารูปมี **อย่างน้อย 1 สัญญาณ** ต่อไปนี้ ถือว่าเป็น decorative ใส่ alt="" ได้เลย
- มี `aria-hidden="true"` อยู่แล้ว
- มี `role="presentation"`
- อยู่ใน element class .icon .decoration .pattern .ornament
- เป็น SVG inline ที่ไม่มี `<title>` ภายใน (มัก decorative)
- รูปขนาดเล็ก < 32x32px (มัก decorative icon)

ถ้าใส่ alt="" ไว้แล้ว ไม่ทับ
ถ้ายังไม่มี alt attribute เลย + ตรงตามสัญญาณข้างบน ใส่ alt="" (decorative)
ถ้ายังไม่มี alt attribute + ไม่เข้าสัญญาณ → ใส่ใน Step 4 ask list

---

## Step 4 ใส่ alt text อัตโนมัติ (no questions for high-confidence)

นักเรียน non-coder ไม่รู้จัก alt text และไม่รู้ว่าจะตอบยังไงให้ดี **เดาให้แล้วใส่เลย** แสดง list ตอนท้ายให้นักเรียน review ถ้าอยากแก้

### สูตรการเดา (ใช้ข้อมูลรอบๆ ประกอบ)

1. **ชื่อไฟล์** เช่น `hero.jpg` `work-01.jpg` `civic-fe.jpg` `logo.png` `team-member-2.jpg`
2. **Section/class** ที่รูปอยู่ เช่น `.hero` `.work` `.testimonial` `.team`
3. **Text รอบๆ** เช่น caption ใกล้รูป heading ของ section
4. **CLAUDE.md** archetype + ชื่อร้าน + niche (รถยนต์ โยคะ ฟิตเนส) ถ้ามี
5. **alt text ในรูปแบบ Thai สั้นกระชับ** 5-15 คำ บอกสิ่งสำคัญที่เห็นในรูป ไม่ใช้ "image of" "picture of"

### ระดับความมั่นใจ → action

| confidence | ตัวอย่าง | action |
|------------|---------|--------|
| **HIGH** ชื่อไฟล์มีความหมาย + section/text สอดคล้อง | `hero.jpg` ใน `.hero` มี heading "เครื่องเสียงรถยนต์ที่ดีที่สุด" → "ภาพรถยนต์ติดตั้งระบบเสียง" | apply เงียบ ๆ |
| **HIGH** logo + ชื่อร้านใน CLAUDE.md | `logo.png` + CLAUDE.md ชื่อ "ตูนคาร์ออดิโอ" → "โลโก้ร้านตูนคาร์ออดิโอ" | apply เงียบ ๆ |
| **HIGH** work item มี text ใกล้ ๆ | `work-01.jpg` มี caption "Honda Civic FE" → "Honda Civic FE ติดตั้งระบบเสียง" | apply เงียบ ๆ |
| **LOW** ชื่อไฟล์ generic | `IMG_1234.jpg` `photo.png` ไม่มี text รอบ | ขอข้อมูลจากนักเรียน (1 คำถาม) |
| **LOW** icon-only button ที่ infer ไม่ได้ | `<button>` ที่มีแต่ SVG | ขอข้อมูลจากนักเรียน |

### Final notice (หลัง apply เงียบ ๆ แล้ว)

แค่บรรทัดเดียว ไม่ list ไม่ถาม **ไปขั้นถัดไปทันที**

```
✏️ ใส่คำบรรยายรูปให้แล้ว [N] รูป ถ้าสงสัย สามารถถามได้นะคะ/ครับ
```

**ห้าม** list alt text ทีละรูป **ห้าม** ถาม "OK มั้ย" **ห้าม** รอนักเรียนตอบ ไปขั้นถัดไปทันทีหลังพิมพ์บรรทัดนี้ นักเรียนจะถามทีหลังเองถ้าอยากแก้

### กรณีต้องถามจริง ๆ (LOW confidence)

ถ้ามีรูปที่เดาไม่ได้จริง ๆ ถามแยกในตอนท้าย รวมกับ icon-only buttons (ถ้ามี)

```
ขอข้อมูลเพิ่มอีก [K] จุด (เดาไม่ออกจริง ๆ)

1. รูป assets/images/IMG_1234.jpg เป็นรูปอะไรครับ?
2. ปุ่มไอคอนใน section ติดต่อ ใช้ทำอะไรครับ?

ตอบสั้น ๆ ก็พอ หรือพิมพ์ "ข้าม" ถ้าจะใส่ทีหลัง
```

ถ้าตอบ "ข้าม" → ใส่ alt="" (ห้ามทิ้งรูปไม่มี alt เด็ดขาด)

---

## Step 5 รายงานนักเรียน (3 buckets)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
♿ ตรวจให้ทุกคนเข้าใช้เว็บได้
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ แก้ให้อัตโนมัติ [N] จุด
   [list จาก Step 3 แปลเป็นภาษาคน]

✏️ ใส่ให้แล้วจากที่คุณตอบ
   - alt text [N] รูป
   [+ aria-label ที่ infer ไม่ได้และนักเรียนตอบ]

ℹ️ บอกไว้ให้รู้
   [ถ้าเจอ heading hierarchy ผิด] หัวข้อ h4 ที่ [section X] อยู่กลางหน้าไม่มี h2 h3 ขั้น
   ใช้ได้แต่ถ้าอยากเป๊ะตามมาตรฐานลองปรับ
   - ทดสอบจริง เปิด VoiceOver บน iPhone (Settings → Accessibility → VoiceOver)
     หรือ NVDA บน Windows ฟังเว็บตัวเองดู
   - กด Tab บน desktop ดูว่าเลื่อนผ่านทุกปุ่ม/ลิงก์ได้เห็นกรอบ focus ชัด
   - อยากตรวจสีตัดกัน (สำหรับคนตาบอดสี) ใช้ tool ที่
     https://webaim.org/resources/contrastchecker (ทางเลือก ไม่ใช่ต้องทำ)
```

### ตารางแปลเป็นภาษาคน

| สิ่งที่แก้ | บอกนักเรียนว่า |
|-----------|----------------|
| Skip link | "ใส่ลิงก์ ข้ามไปเนื้อหา สำหรับคนใช้ keyboard" |
| Focus visible CSS | "ตั้งกรอบ focus ให้ปุ่ม/ลิงก์ เวลากด Tab จะเห็นชัด" |
| aria-label LINE | "ใส่ชื่อให้ปุ่ม LINE คนตาบอดจะได้ยินว่า แอดไลน์" |
| aria-label โทร | "ใส่ชื่อให้ปุ่มโทร คนตาบอดจะได้ยินว่า โทรเรา" |
| aria-label social | "ใส่ชื่อให้ปุ่มไอคอน social media" |
| label-input pairing | "จับคู่ป้ายชื่อช่องกรอกฟอร์มกับช่อง" |
| alt="" decorative | "รูปประดับ บอก screen reader ว่าข้ามได้" |
| alt content | "ใส่คำอธิบายให้รูป [ชื่อรูป] คนตาบอดได้ยินว่ารูปคืออะไร" |

---

## Step 6 ปิดท้าย

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Accessibility เรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ สรุป
- skip link + focus + label-input + aria-label + alt ใส่ครบ
- ทุกคนเข้าใช้เว็บได้ ทั้งคนตาบอด คน keyboard คนพิการมือ
- bonus Google rank เว็บที่ a11y ดีขึ้นด้วย

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ทดสอบจริง VoiceOver/NVDA + กด Tab ดู (วิธีอยู่ใน FYI ด้านบน)
```

---

## Edge cases

### นักเรียนไม่อยากใส่ alt ตอนนี้

เคารพ ใส่ alt="" ไว้ก่อน แจ้งว่าเรียกใหม่ตอนพร้อมได้ตลอด

### เว็บไม่มี form

ข้าม 3.4

### เว็บไม่มี image

ข้าม 3.5 + Step 4 image ask (แต่ Step 4 ยังถาม icon-only ที่ infer ไม่ได้)

### Claude Design ใส่ aria-label ครบแล้ว

ตรวจไม่ทับ ผ่าน

### Heading hierarchy ผิดแต่นักเรียนตั้งใจ design แบบนั้น

flag ใน FYI ปล่อยให้นักเรียนเลือก ห้าม auto-restructure

### Icon-only ที่ infer ไม่ได้ มาก > 5 ตัว

ถ้าเยอะถาม batch รวบ ห้ามถามทีละตัวจนนักเรียนเบื่อ

### นักเรียน paste error จาก screen reader test

ช่วย diagnose ดู element ที่ screen reader บอกชื่อไม่ถูก หา root cause (มัก aria-label หรือ alt หาย)

---

## สิ่งที่ต้องระวัง

- **เดา alt text จาก context แล้ว apply เลยถ้า confidence HIGH** ใช้ filename + section + nearby text + CLAUDE.md เดาแล้วใส่เงียบ ๆ แสดง list ตอนท้ายให้นักเรียน review (UX ดีกว่ามากสำหรับ non-coder) ถามเฉพาะกรณี LOW confidence (filename generic / icon-only ไม่มี text รอบ)
- **ถ้าชื่อไฟล์ generic** (IMG_1234.jpg photo.png) เดาไม่ได้ → ถามเปล่าๆ ห้ามแต่ง "image" "picture" ใส่
- **ห้ามทิ้งรูปไม่มี alt attribute** ทุกรูปต้องมี alt อย่างน้อย alt="" (decorative)
- **ห้ามแก้สี brand** ห้าม flag ห้ามเสนอเปลี่ยนสี ใส่ลิงก์ webaim ใน FYI เฉยๆ
- **ห้ามแก้ heading hierarchy** flag ใน FYI ปล่อยให้ student decide
- **ห้ามใช้ technical term กับนักเรียน** ไม่ใช้คำว่า ARIA WCAG semantic landmark alt focus-visible :focus-visible aria-hidden role="presentation" ใช้ภาษาคน "ลิงก์ข้ามไปเนื้อหา" "ตั้งกรอบ focus" "ใส่ชื่อให้ปุ่ม"
- **skip link ต้อง first element หลัง body** ถ้ามี script tag ก่อน body ปล่อย skip link เป็น element แรกที่ visible
- **id="main" ต้อง unique** ถ้ามี id="main" อยู่แล้วในเว็บ ใช้ตัวเดิม ห้ามทับ
- **focus styles อย่าใช้ outline: none** เด็ดขาดถ้าไม่มี alternative outline:none ทำเว็บไม่ accessible
- **web-finish จัดการ tap target 44px แล้ว** ไม่ทำซ้ำ
- **seo จัดการ lang title แล้ว** ไม่ทำซ้ำ
- **CLAUDE.md ถ้ามี** อ่าน archetype + ชื่อร้าน เผื่อต้องเสนอ aria-label เช่น ปุ่ม LINE → "แอดไลน์ [ชื่อร้าน]"
- **element ที่มี `data-cnc-widget` เพิ่ม alt/aria ได้แต่ห้าม rewrite/ลบ** widget ที่ web-add ฝังไว้ติด marker นี้ ถ้ารูปใน widget ยังไม่มี alt ใส่ได้ปกติ แต่ห้ามแก้โครงสร้าง markup รอบ marker (เช่นปุ่มจองเวลา การ์ดรีวิว) เพราะอาจทำให้ widget พัง ตรวจทุกหน้า `index.html` + `pages/*.html` รวมหน้าใหม่ที่นักเรียนเพิ่ม
