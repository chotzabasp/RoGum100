---
name: web-add
description: Use when the student wants to ADD a new feature or widget to their existing website without redesigning it. One skill one trigger "อยากเพิ่ม..." then it routes to the right widget. Triggers include "อยากเพิ่ม", "เพิ่มฟีเจอร์", "เพิ่ม widget", "เพิ่มปฏิทินจอง", "ระบบจองคิว", "ให้ลูกค้าจองเวลา", "นัดหมายออนไลน์", "calendly", "เพิ่มรีวิว", "เพิ่ม testimonial", "คำชมลูกค้า", "เสียงตอบรับลูกค้า", "social proof", "add a widget", "add booking", "add reviews", "web-add", or any similar request to bolt a new section or third-party embed onto a site that already exists. The skill is an ENGINE plus a CATALOG of widget recipes. The engine reads the student brand colors from the CLAUDE.md web-design block first then design tokens from styles.css (spacing font) plus the site own component DNA (corner radius edge weight) and reveal animation so every widget comes out styled and animated to match THEIR brand automatically not a generic bolt-on. Self-built widgets (reviews) consume the tokens directly. Third-party embeds (Calendly) get wrapped in a matching card and pass the brand accent via URL param. Every widget is stamped with a data-cnc-widget marker so later audit re-runs recognize and preserve it. Widgets that load from outside auto-register their domain by calling best-practices Mode B so they work and stay secure with zero extra steps. Does NOT edit existing copy or design (that is edit-plan) and does NOT add new pages (separate concern). Built for absolute beginners with zero coding knowledge works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-add เพิ่มของใหม่ให้เว็บที่มีอยู่แล้ว

นักเรียนพูดสั้นๆ ว่า "อยากเพิ่ม..." skill ถามว่าจะเพิ่มอะไร แล้วจัดการให้ครบ อ่านสไตล์เว็บเดิมของนักเรียน เพิ่มของใหม่ให้เข้ากับแบรนด์อัตโนมัติ ลงทะเบียนความปลอดภัยให้เอง เปิด preview ให้ดู

skill นี้คือ **เครื่องยนต์ 1 ตัว + แคตตาล็อก widget** เครื่องยนต์เป็นตัวเดียวกันทุก widget ต่างกันแค่ "สูตร" ของแต่ละ widget เท่านั้น

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก (lock ไว้ตั้งแต่ต้น)

1. **1 skill = 1 ความต้องการของนักเรียน ไม่ใช่ชื่อ library** นักเรียนพูดว่า "อยากให้ลูกค้าจองเวลา" ไม่ใช่ "อยากใช้ Calendly" ถ้ามีหลาย library ทำสิ่งเดียวกัน skill เลือกให้ หรือถามครั้งเดียว นักเรียนไม่ต้องรู้จักชื่อ library
2. **เพิ่มของใหม่เท่านั้น ห้ามแก้ของเดิม** ห้ามแก้ headline copy สี layout ที่นักเรียนตั้งใจไว้แล้ว (งานนั้นเป็นของ edit-plan และ web-update) web-add แค่ "เพิ่ม section ใหม่" หรือ "ฝัง widget" ลงไป
3. **เข้ากับแบรนด์อัตโนมัติ** ทุก widget อ่าน design token จาก styles.css ของนักเรียน (สี ระยะห่าง ฟอนต์) แล้วใช้ token เดียวกัน ผลคือ widget หน้าตาเหมือนเว็บเดิมไม่ใช่ของแปลกปลอม
4. **ไม่เพิ่มหน้าใหม่** การเพิ่มหน้า + เมนูเป็นเรื่องโครงสร้าง อยู่คนละ skill (อนาคต web-page)
5. **ภาษาไทยเรียบง่าย** ห้ามโชว์ชื่อ library ชื่อไฟล์ ชื่อ tag ในรายงานนักเรียน

---

## หัวใจของระบบ marker `data-cnc-widget`

ทุกอย่างที่ web-add ใส่เข้าเว็บ **ต้องติด attribute `data-cnc-widget="<id>"`** ไว้เสมอ ทั้งบน section ที่ฝัง ทั้งบน `<script>` หรือ `<link>` ที่เพิ่ม

```html
<section data-cnc-widget="booking" class="container"> ... </section>
<script src="https://assets.calendly.com/assets/external/widget.js" async data-cnc-widget="booking"></script>
```

marker นี้คือสัญญาที่ทำให้ "เพิ่ม widget แล้วรัน /web-quality-audit ทีหลังได้โดยทุกอย่างไม่พัง" เพราะ

- **performance** เห็น marker บน script แล้ว **ไม่แตะ ไม่ defer ไม่ย้าย** (widget script บางตัวต้องรันแบบของมันเอง)
- **best-practices** เห็น domain ที่ widget ลงทะเบียนไว้ใน `_headers` แล้ว **เก็บไว้ ไม่ลบ** ตอน re-run
- **accessibility / seo** เห็น marker แล้วรู้ว่าเป็นของ widget **เพิ่ม alt/aria ได้แต่ห้าม rewrite/ลบ markup**

ถ้าลืมติด marker = audit ทีหลังอาจ optimize จน widget พัง อย่าลืมเด็ดขาด

---

## 4 invariant ที่ทำให้ระบบโตได้โดยไม่พัง (สำคัญมาก)

web-add ออกแบบมาให้นักเรียนเพิ่ม widget กี่ตัวก็ได้ เพิ่มหน้าก็ได้ แล้วรัน /web-quality-audit ทีหลัง โดยทุกอย่างยังทำงาน animation ยังเล่น เพราะยึด 4 ข้อนี้

1. **CSP merge อย่างเดียว ห้าม reset** `_headers` คือแหล่งความจริงเดียวของ "รายชื่อที่อนุญาต" widget เขียน domain ลงไปตอนติดตั้ง audit ทีหลัง merge เข้าเท่านั้น ห้ามเขียนทับกลับเป็น default (ไม่อย่างนั้น Calendly Maps จะกลับมาโดน block)
2. **แก้แบบเพิ่มเท่านั้น ห้ามแก้แบบลบ** engine ตรวจคุณภาพเพิ่ม attribute ที่ขาด (alt lazy aria) แต่ห้าม rewrite หรือลบ markup/script ของ widget
3. **สแกนทุกหน้า** ทุก engine อ่าน `index.html` + ทุก `pages/*.html` หน้าใหม่ที่นักเรียนเพิ่มก็ได้รับการตรวจด้วย
4. **ห้ามแตะ script ของ widget** performance ใส่ defer/preload เฉพาะ resource ที่ปลอดภัยและรู้จัก ข้าม element ที่มี `data-cnc-widget` ทุกตัว

invariant 1 4 บังคับใช้ผ่าน marker ด้านบน web-add มีหน้าที่ติด marker ให้ครบ engine มีหน้าที่เคารพ marker

---

## โหมดการทำงาน

web-add มี flow เดียว routing ด้วย intent

```
นักเรียนพูด "อยากเพิ่ม X"
   → Step 0 ตรวจความพร้อม
   → Step 1 จับ intent เลือก row จากแคตตาล็อก (ถ้าไม่ชัดโชว์เมนู)
   → Step 2 อ่าน design token จาก styles.css ของนักเรียน
   → Step 3 ถามข้อมูลเฉพาะของ row นั้น (ถามให้น้อยที่สุด)
   → Step 4 เลือกจุดวาง (default ฉลาด + ให้ย้ายได้)
   → Step 5 ฝัง widget ติด marker ใช้ token
   → Step 6 ถ้า row มี CSP domain → เรียก best-practices Mode B
   → Step 7 preview localhost
   → Step 8 รายงาน + next step
```

---

## แคตตาล็อก widget

แต่ละ widget เป็น **แถวข้อมูล ไม่ใช่ skill** เพิ่ม widget ใหม่ = เพิ่มแถว ไม่ใช่เพิ่มไฟล์ skill

| id | นักเรียนอยากได้ | เลือกให้ | ประเภท | CSP domain | ถามอะไร | สถานะ |
|----|------------------|----------|--------|-----------|---------|-------|
| `booking` | ให้ลูกค้าจองเวลา/นัดหมาย | Calendly | ฝัง 3rd party | calendly.com (4 directive) | ลิงก์ Calendly | ✅ test แล้ว (fitness mechanics) |
| `social-proof` | โชว์รีวิว/คำชมลูกค้า | section สร้างเอง | สร้างเอง | ไม่มี | รีวิว 1-5 อัน (ชื่อ ข้อความ ดาว) | ✅ build + test แล้ว |
| `faq` | คำถามที่พบบ่อย | accordion สร้างเอง | สร้างเอง (HTML ล้วน ไม่มี JS) | ไม่มี | คู่ถาม-ตอบ (generate-then-confirm) | ✅ test แล้ว (yoga) |
| `timeline` | ประวัติ/เส้นทาง/ความเป็นมา | vertical timeline สร้างเอง | สร้างเอง (HTML/CSS ไม่มี JS) | ไม่มี | milestones (ปี + เหตุการณ์) + โหมด (spine/alt) | ✅ build + test แล้ว (yoga + fitness) |
| `pricing` | ตารางราคา/แพ็กเกจ | cards สร้างเอง | สร้างเอง (HTML/CSS ไม่มี JS) | ไม่มี | จำนวน tier + ชื่อ ราคา features (generate-then-confirm) | ✅ test แล้ว (yoga + fitness) |
| `gallery` | แกลเลอรีรูป + ขยายดู | grid + lightbox สร้างเอง | สร้างเอง (JS ใน scripts.js รูป local) | ไม่มี | จำนวน + แนวรูป + รูป (ผ่าน web-images) | ✅ test แล้ว (yoga landscape+mixed) |
| `before-after` | โชว์รูปก่อน/หลัง เลื่อนเทียบ | slider สร้างเอง | สร้างเอง (JS ใน scripts.js รูป local) | ไม่มี | คู่รูปก่อน+หลัง + แนวรูป (ผ่าน web-images) | ✅ test แล้ว (yoga square) |
| `map` | แผนที่ร้าน | Google Maps embed (keyless) | iframe ล้วน | google.com | ที่อยู่ | ✅ build แล้ว |
| `media` | ฝังวิดีโอ/รีล | YouTube Vimeo IG FB TikTok | iframe ล้วน | ตาม source (youtube/vimeo/instagram/facebook/tiktok) | ลิงก์วิดีโอ/รีล | ✅ test แล้ว YouTube IG TikTok FB (Vimeo iframe มาตรฐานยังไม่ test) |
| `motion` | animation ตอน scroll | AOS/confetti/Typed | ext-script + init | ไม่มี | สไตล์ | 🔜 อนาคต |
| `countdown` | นับถอยหลังโปร | timer สร้างเอง | สร้างเอง (JS ใน scripts.js) | ไม่มี | วันเวลาจบ | ✅ test แล้ว (yoga) |
| `counter` | ตัวเลขนับขึ้น | CountUp / สร้างเอง | ext-script / สร้างเอง | ไม่มี | ตัวเลข | 🔜 อนาคต |
| `chart` | กราฟ/ชาร์ต | Chart.js | ext-script + init | cdn.jsdelivr.net | ชนิด + ข้อมูล (พิมพ์/CSV/Excel) | ✅ test แล้ว bar line pie doughnut (fitness) |

**ลบออกแล้ว** `form` (web-scope จัดการฟอร์มอยู่แล้ว) `payment-promptpay` + `payment-stripe` (เรื่องเงินพักไว้ก่อน นักเรียนรับเงินผ่าน LINE/ช่องทางส่วนตัว) live visitor count (ต้อง backend ไป Day 2 Supabase) Lottie (ใช้วิดีโอ/รีลจริงแทน)

**ยังไม่มี widget หมวดเงินในแคตตาล็อก** ถ้านักเรียนถามเรื่องรับเงิน บอกว่าตอนนี้ให้รับผ่าน LINE หรือช่องทางส่วนตัวไปก่อน ฟีเจอร์จ่ายเงินบนเว็บกำลังจะมา

**banned widget-farm** Elfsight POWR Common Ninja TickCounter (ทำเกรดความปลอดภัยตก + brand-match ไม่ได้ งานพวกนี้ใช้ self-built row 1/countdown/counter แทน)

---

## กฎการรับ widget เข้าแคตตาล็อก (curation ป้องกันเกรดตกตั้งแต่ต้น)

widget จะถูกรับเข้าแคตตาล็อกได้ก็ต่อเมื่อ embed แบบที่ **ไม่ต้องใช้ `'unsafe-inline'`** เท่านั้น เพื่อให้เกรดความปลอดภัย A+/A ไม่มีทางตกตั้งแต่แรก ไม่ต้องพึ่ง runtime guard

### รับได้ (CSP-clean ทั้ง 3 แบบนี้)

| แบบ embed | ทำไมปลอดภัย | ตัวอย่าง |
|-----------|--------------|---------|
| **สร้างเอง** | เขียน CSS ลง styles.css ไม่มี inline | review cards countdown counter |
| **iframe ล้วน** | เนื้อหาอยู่ใน iframe sandbox ใช้แค่ frame-src | Google Maps Google Calendar YouTube Vimeo |
| **external script + init ของเราเขียนลง scripts.js** | `<script src>` ภายนอก การ styling runtime ใช้ CSSOM (`el.style.x`) ซึ่ง CSP ไม่ block | AOS Typed.js Swiper confetti CountUp Chart.js Lottie |
| **external widget.js + iframe** | script ภายนอก + iframe แยก | Calendly (booking) Tally แบบ iframe |

### ห้ามรับเข้า (ทำให้เกรดตก + ไม่เข้าแบรนด์อยู่ดี)

**widget-farm platform** ที่ render widget ในระบบตัวเองแล้ว inject inline `<style>`/`<script>` ตอน runtime ต้องใช้ `'unsafe-inline'` = เกรดตก

- ❌ **Elfsight** (Google Reviews คลื่นรีวิว) **POWR** **Common Ninja** **TickCounter** และ clone ทั้งหมด
- เหตุผลเสริม platform พวกนี้อ่าน design token ของนักเรียนไม่ได้ (render ใน iframe ของตัวเอง สีไม่ตรงแบรนด์ มีโฆษณา ช้า) = ผิดหลัก "เข้ากับแบรนด์อัตโนมัติ" อยู่แล้ว ไม่เสียดาย
- งานที่ platform พวกนี้ทำ เรามี self-built แทน → รีวิวใช้ `social-proof` countdown ใช้ timer สร้างเอง

### กรณีก้ำกึ่ง

บาง widget มีทั้งแบบ inline bootstrap และแบบ iframe (เช่น Cal.com Twitter/X) **รับเฉพาะแบบ iframe** หรือย้าย init ไป scripts.js ถ้ามีแต่แบบ inline อย่างเดียว → ไม่รับ

ก่อนเพิ่ม row ใหม่ในอนาคต deploy ทดสอบแล้วดู console ถ้าไม่มี error เรื่อง CSP block = clean รับได้

---

## Step 0 ตรวจความพร้อม

อ่าน project root

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `CLAUDE.md` ที่มี `<!-- web-design:v1 -->` block | แหล่งสีหลัก (Step 2.1) ถ้าไม่มี → ใช้ CSS แทน (Step 2.3) |
| `styles.css` ที่มี `:root` token | ใช้เติม text/muted + เป็น fallback สี ถ้าไม่มีเลย ใช้ neutral default เตือนว่าสีอาจไม่ตรงแบรนด์เป๊ะ |

ถ้าเว็บมี `pages/` หลายหน้า จำไว้ใช้ตอน Step 4 (ถามว่าจะวางหน้าไหน)

---

## Step 1 จับ intent เลือก row

จาก trigger ของนักเรียน map ไป id ในแคตตาล็อก

- "จองเวลา จองคิว นัดหมาย calendly" → `booking`
- "รีวิว คำชม testimonial เสียงตอบรับ" → `social-proof`
- "คำถามที่พบบ่อย faq ถาม-ตอบ q&a accordion" → `faq`
- "ประวัติ ความเป็นมา เส้นทาง ไทม์ไลน์ timeline จุดเริ่มต้น milestone เรื่องราวธุรกิจ ปีที่ก่อตั้ง" → `timeline`
- "ตารางราคา แพ็กเกจ ราคา pricing plan tier แพลน สมาชิก" → `pricing`
- "แกลเลอรี gallery รูปผลงาน อัลบั้ม รวมรูป โชว์รูป คลิกดูรูป lightbox" → `gallery`
- "ก่อนหลัง before after เทียบรูป สไลด์เทียบ ก่อนทำ-หลังทำ transformation ผลลัพธ์ก่อนหลัง" → `before-after`
- "แผนที่ ที่อยู่ร้าน มาหาเรา map maps location" → `map`
- "วิดีโอ คลิป รีล reel youtube tiktok ig reel embed วิดีโอ" → `media`
- "นับถอยหลัง countdown timer โปรหมดใน เหลือเวลา เปิดจองอีก" → `countdown`
- "กราฟ ชาร์ต chart graph แท่ง เส้น วงกลม pie bar line สถิติ ข้อมูล" → `chart`

ถ้า intent **ไม่ชัด** หรือนักเรียนพูดแค่ "อยากเพิ่มอะไรสักอย่าง" โชว์เมนูง่ายๆ (เฉพาะ row ที่ build แล้ว)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ อยากเพิ่มอะไรให้เว็บดีคะ/ครับ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 ได้ลูกค้า · ปิดการขาย
   1. 📅 จองเวลา (จองคิว นัดหมาย)
   2. 💷 ตารางราคา/แพ็กเกจ
   3. ⏰ นับถอยหลัง (โปรหมดใน)

🤝 สร้างความน่าเชื่อถือ
   4. ⭐ รีวิว/คำชมลูกค้า
   5. ❓ คำถามที่พบบ่อย (Q&A)
   6. 📊 กราฟ/ผลลัพธ์ (โชว์ตัวเลข)

📸 โชว์ของ · ข้อมูลร้าน
   7. 🖼️ แกลเลอรีรูป (คลิกขยายดู)
   8. 🎬 วิดีโอ/รีล (YouTube IG TikTok)
   9. 📍 แผนที่ที่ตั้งร้าน
   10. 📜 ประวัติ/ไทม์ไลน์ (เรื่องราวธุรกิจ)
   11. 🔁 รูปก่อน/หลัง (เลื่อนเทียบผลลัพธ์)

พิมพ์เลขที่อยากเพิ่มได้เลย
หรือบอกมาเป็นคำพูดก็ได้ว่าอยากได้อะไร
```

ถ้านักเรียนขอของที่ยังเป็น 🔜 (เช่น counter motion) บอกตรงๆ ว่า "อันนี้กำลังจะเปิดเร็วๆ นี้นะคะ/ครับ ตอนนี้เพิ่มได้ 9 อย่างนี้" อย่าพยายาม improvise widget ที่ยังไม่มีสูตร ถ้าถามเรื่องรับเงิน บอกให้รับผ่าน LINE/ช่องทางส่วนตัวไปก่อน

---

## Step 2 หาสีแบรนด์ของนักเรียน (CLAUDE.md ก่อน CSS เสริม)

**ความจริงที่ต้องรู้** Claude Design **ไม่ได้ใช้ชื่อ token มาตรฐาน `--color-*` เสมอ** บางเว็บ map มาตรฐาน (yoga `--color-accent: var(--terracotta)`) บางเว็บใช้ชื่อสั้นของตัวเอง (fitness `--accent: #E63946` ไม่มี `--color-*` เลย) จึงเชื่อชื่อ token ใน CSS ไม่ได้ **แหล่งสีที่เชื่อถือได้คือ CLAUDE.md** ที่ web-design บันทึก hex จากความตั้งใจของนักเรียนไว้ตรงๆ ใช้ได้กับทุกเว็บไม่ว่า Claude Design จะตั้งชื่อ token ยังไง

### 2.1 อ่านสีหลักจาก CLAUDE.md (PRIMARY)

หา block `<!-- web-design:v1 -->` ใน CLAUDE.md ดึง hex 3 ตัว

| บรรทัดใน CLAUDE.md | คือ role | ใช้เป็น |
|---------------------|----------|---------|
| `Color 60%` | พื้นหลัง | bgHex |
| `Color 30%` | สีรอง | surfaceHex |
| `Color 10%` | สีเน้น | accentHex |

3 ตัวนี้คือ hex จริงเชื่อได้ ใช้เป็นค่าหลักของ bg surface accent ทั้ง normalization block และ URL param

### 2.2 เติม text/muted จาก CSS (SUPPLEMENT)

CLAUDE.md เก็บแค่ 3 สี ไม่มี text/muted หา 2 ตัวนี้จาก `:root` ใน `styles.css` ตาม alias table ใช้ตัวแรกที่เจอ resolve `var(--X)` indirection ไม่เกิน 3 hop จนได้ hex

| role | ลองชื่อพวกนี้ตามลำดับ | ถ้าไม่เจอ |
|------|------------------------|-----------|
| text | `--color-text` `--text` `--fg` `--foreground` | derive จาก bgHex (พื้นสว่าง → text เข้ม พื้นมืด → text สว่าง) |
| muted | `--color-text-muted` `--muted` `--text-muted` `--fg-muted` | ใช้ text ที่ความทึบ 60% |

### 2.3 ถ้าไม่มี CLAUDE.md หรือไม่มี web-design block (FALLBACK)

เว็บเก่า หรือนักเรียน skip web-design หา bg/surface/accent จาก `:root` ใน `styles.css` ด้วย alias table เดียวกัน + resolve indirection เป็น hex

| role | ลองชื่อพวกนี้ตามลำดับ |
|------|------------------------|
| bg | `--color-bg` `--bg` `--background` |
| surface | `--color-surface` `--surface` `--card` `--bg-2` |
| accent | `--color-accent` `--accent` `--accent-color` `--brand` `--primary` |

ถ้ายัง resolve ไม่ได้เลย ใช้ neutral default (bg `#1a1a1a` surface `#f0f0f0` accent `#888888` text `#f0f0f0` muted `#9a9a9a`) widget ยังทำงานแค่สีอาจไม่ตรงแบรนด์เป๊ะ

### 2.4 เขียน normalization block ต่อท้าย styles.css (ครั้งเดียวต่อเว็บ)

bake hex ที่ได้จาก 2.1-2.3 เป็นค่าหลัก แล้วใส่ live CSS token เป็น fallback ชั้นในเผื่อเว็บ theme สีใหม่ทีหลัง

```css
/* widget tokens สีจาก CLAUDE.md เป็นหลัก live CSS เป็น fallback + DNA จาก Step 2.6 */
[data-cnc-widget] {
  --w-bg:      BGHEX;
  --w-surface: SURFACEHEX;
  --w-accent:  ACCENTHEX;
  --w-text:    var(--color-text, var(--text, TEXTHEX));
  --w-muted:   var(--color-text-muted, var(--muted, MUTEDHEX));
  --w-radius:  RADIUS;        /* DNA จาก Step 2.6 */
  --w-card-border: CARDBORDER;/* DNA จาก Step 2.6 */
}
```

(แทน `BGHEX` ฯลฯ ด้วย hex จาก 2.1-2.3 และ `RADIUS`/`CARDBORDER` จาก Step 2.6) เขียนครั้งเดียว ถ้ามีอยู่แล้ว (เคยเพิ่ม widget ก่อนหน้า) ข้าม

spacing กับ font อ่านจาก `:root` ได้ แต่ **อย่า assume ชื่อ token เป๊ะ** เพราะเว็บที่ Claude Code สร้างเอง (Path B) อาจตั้งชื่ออื่น ใช้ alias + fallback เหมือนการอ่านสี
- **spacing** ลองตามลำดับ `--s1..--s9` → `--space-*` `--gap-*` → ถ้าไม่เจอ ใช้ค่า px ตรงๆ ที่เว็บใช้บ่อย (อ่านจาก padding/gap ของ section จริง) หรือ fallback ladder ของตัวเอง (8 16 24 32 48)
- **font** ลอง `--font-display` `--font-body` `--size-display` → alias `--font-heading` `--serif` `--sans` `--font` → ถ้าไม่เจอ อ่าน `font-family` จริงที่ใช้กับ heading กับ body แล้วใช้ค่านั้นตรงๆ
widget ต้อง self-contained อยู่แล้ว ดังนั้นถ้าหา token ไม่เจอจริงๆ ใช้ค่า hardcode ที่กลมกลืนได้ ไม่พัง

**สำคัญ ห้ามพึ่ง utility class ของ codebase** (`.container` `.grid` `.grid--2` `.ratio-square` `.ratio-landscape` `.display`) เพราะ Claude Design **ตัด class พวกนี้ทิ้ง** ตอน generate ใช้ชื่อ class ของตัวเองแทน ทดสอบจริงแล้ว yoga/fitness ไม่มี `.grid--2` `.ratio-*` เลย ถ้า widget พึ่ง class พวกนี้ layout จะพัง (card กว้าง 0 หรือไม่ขึ้น grid) **widget ต้อง self-contained** นิยาม layout เอง (max-width grid columns aspect-ratio) ใน class ของ widget เอง พึ่งได้แค่ `:root` token

### 2.5 หลักการ style-match (หลัง normalize)

- widget สร้างเอง (social-proof countdown counter) → ใช้ `var(--w-accent)` `var(--w-surface)` ฯลฯ เข้ากับแบรนด์ทุกเว็บ
- widget 3rd party (booking) → ห่อใน card ที่ใช้ `--w-*` + ส่ง **accentHex** (จาก 2.1 หรือ 2.3 ตัด `#` ออก) เข้า URL param เช่น Calendly `?primary_color=` เพราะ URL param ใช้ CSS var ไม่ได้ ต้องเป็น hex จริง

### 2.6 อ่าน component DNA แล้ว mirror (กันทุกเว็บหน้าตาเหมือนกัน)

แค่ match สี ยังไม่พอ ถ้าทุก widget ใช้ card มน border บางเหมือนกันหมด นักเรียน 10 คนได้ section รีวิวหน้าตาเดียวกัน = template tell ผิดหลัก [[anti-slop-only-ai-fingerprints]] และ [[web-design-v8-architecture]] (สองเว็บต่าง brief ต้องได้ component ต่างหน้าตา)

วิธีแก้ ไม่ใช่ "สุ่มให้สวย" แต่ **อ่านภาษา component ที่เว็บนั้นใช้อยู่แล้ว แล้วเลียนแบบ** ผลคือ widget ดู native กับเว็บนั้น และเพราะแต่ละเว็บต่างกัน widget เลยต่างกันเองโดยไม่ต้องสุ่ม

อ่าน `styles.css` (ดู component จริง ไม่ใช่แค่ `:root`) จับ 2 สัญญาณหลัก

| DNA | อ่านจากไหน | ตัวอย่างจริง |
|-----|------------|--------------|
| **radius** | `border-radius` ที่ใช้กับ card/panel/button (ข้าม `50%` ที่เป็นวงกลม/dot) ค่าที่เจอบ่อยสุดของกล่องสี่เหลี่ยม | yoga `0` (คม) fitness `0` (คม) เว็บอื่นอาจ `12px` (มน) |
| **card edge** | เว็บนิยามขอบ card ด้วยอะไร เส้นบาง 1px เส้นหนา 2px+ หรือ shadow | yoga `1px solid` hairline (editorial) fitness `2px solid` หนา (brutalist) |

bake เป็น 2 token ใน normalization block

```
--w-radius:       <radius ของ card เว็บนี้ เช่น 0 หรือ 12px ถ้าหาไม่เจอ fallback var(--s3)>
--w-card-border:  <เลียนน้ำหนักขอบเว็บ ใช้สีปลอดภัยจาก color-mix ของ text>
                  เว็บเส้นบาง → 1px solid color-mix(in srgb, var(--w-text) 14%, transparent)
                  เว็บเส้นหนา → 2px solid color-mix(in srgb, var(--w-text) 30%, transparent)
                  เว็บใช้ shadow ไม่ใช้ border → none (แล้วเพิ่ม box-shadow ใน card แทน)
```

widget card ทุกตัวใช้ `border-radius: var(--w-radius)` + `border: var(--w-card-border)` แทนค่าตายตัว ผลคือ yoga ได้ card คมขอบบาง (editorial) fitness ได้ card คมขอบหนา (brutalist) ต่างกันชัด เข้ากับเว็บแต่ละอัน

**layout variant ตาม archetype** เลือกโครง section ตาม archetype ใน CLAUDE.md web-scope ด้วย ดูในแต่ละสูตร row (เช่น social-proof มี card-grid กับ stacked-list) อย่าใช้โครงเดียวทุก archetype

### 2.7 match motion ของเว็บ (widget ต้องขยับเหมือนเว็บ ไม่ใช่ตายนิ่ง)

เว็บส่วนใหญ่จาก Claude Design มี scroll-reveal (section ค่อยๆ fade ขึ้นตอน scroll ถึง) ถ้า widget โผล่มานิ่งๆ ขณะที่ทั้งหน้าขยับ = bolt-on tell อีกแบบ วิธีแก้เหมือน DNA คือ **reuse กลไก reveal ที่เว็บมีอยู่แล้ว ไม่สร้าง animation ใหม่**

**ห้ามเขียน JS animation ใหม่** เพราะเสี่ยง CSP + พัง + ต้อง test เพิ่ม ให้ reuse observer เดิมของเว็บแทน

ขั้นตอน detect แล้ว opt-in

1. หากลไก reveal ในเว็บ มองหา class ใน `styles.css` ที่ pattern แบบ reveal (`opacity: 0` + `transform` + `transition`) คู่กับ `IntersectionObserver` ใน `scripts.js` ที่ query class นั้นแล้ว toggle state visible
   - ชื่อ class ที่พบบ่อย `.reveal` `.fade-in` `.fade-up` `.animate` `.in-view` หรือ AOS ที่ใช้ attribute `data-aos`
   - ตัวอย่างจริง yoga + fitness ใช้ `.reveal` ทั้งคู่ (observer query `.reveal` toggle `is-in`/`is-visible`)
2. ถ้าเจอ ใส่ class นั้น (หรือ `data-aos`) ลงบน element ของ widget ให้ครบ **ทั้งหัวข้อ section และแต่ละ card/quote** (ไม่ใช่แค่ card อย่างเดียว ไม่งั้นหัวข้อโผล่นิ่งแต่ card ค่อย fade ดูไม่เข้ากัน) เลียนแบบเว็บที่ reveal ทั้ง heading + content widget อยู่ใน HTML ตอน load อยู่แล้ว observer เดิมจะจับ + animate ให้เอง ไม่ต้องเพิ่ม script
   - ถ้าเว็บมี stagger delay class (เช่น `.reveal--delay-1/2/3`) ใส่ไล่ทีละ card ให้ทยอยขึ้นสวยขึ้น (optional)
3. ถ้าหาไม่เจอ (เว็บไม่มี scroll animation หรือ Motion dial = 0) ปล่อย widget นิ่ง ก็ match เว็บนิ่งเหมือนกัน
4. prefers-reduced-motion ไม่ต้องจัดการเพิ่ม กลไก reveal ของเว็บ (และ foundation) จัดการให้แล้ว
5. **failsafe กัน widget หายถ้า JS ไม่ทำงาน** reveal class ตั้ง `opacity: 0` รอ JS มาเปิด ถ้า browser ปิด JS เนื้อหา widget จะหายถาวร (รีวิวคือตัวปิดการขาย หายไม่ได้) ใส่ CSS นี้ครั้งเดียว scope แค่ widget

```css
/* failsafe ถ้า browser ไม่รัน JS reveal จะไม่ทำงาน widget ต้องไม่หาย */
@media (scripting: none) {
  [data-cnc-widget] .reveal { opacity: 1 !important; transform: none !important; }
}
```

ครอบ case JS ปิด/ไม่รองรับ (case JS รันแต่ error = ทั้งเว็บพังอยู่แล้ว เป็น edge หายาก) เนื้อหาเว็บปกติของ Claude Design เสี่ยงข้อนี้อยู่แล้ว widget แค่ปลอดภัยกว่าด้วย failsafe นี้

ผล widget fade ขึ้นตอน scroll แบบเดียวกับ section อื่นของเว็บ ดู native ไม่มี JS ใหม่ ไม่กระทบ CSP และไม่มีทางหายถาวร

---

## Step 3 ถามข้อมูลเฉพาะของ row (ถามให้น้อยที่สุด)

**หลักการ generate-then-confirm (house style ของคอร์ส เหมือน seo/web-writing)** widget ที่เป็น "เนื้อหา" (เช่น faq) **อย่าถามจากศูนย์** อ่าน CLAUDE.md (archetype business services ราคา เวลา channels) แล้ว **ร่างให้ก่อน** เสนอเป็น draft ให้นักเรียนยืนยัน/ปรับ แล้วค่อย finalize นักเรียนเริ่มจากของที่มีอยู่ ดีกว่าหน้ากระดาษเปล่า

**แต่แยกให้ออก** ส่วนที่ generate ได้อิสระ (คำถาม generic หัวข้อ โครง) vs ส่วนที่เป็น **ข้อเท็จจริงจริง** (ราคา เวลา ที่อยู่ คำพูดลูกค้า) ข้อเท็จจริง **ห้าม finalize แบบเดาเอง** ต้องให้นักเรียน confirm ทุกครั้ง (กฎ ห้ามแต่งข้อมูลปลอม) ถ้า CLAUDE.md ไม่มีข้อมูลนั้น เว้นช่องให้เติม

### row `booking`
ถามแค่ลิงก์ Calendly

```
📅 เพิ่มระบบจองเวลาให้ค่ะ/ครับ

ขอลิงก์ Calendly ของคุณหน่อย
(หน้าตาแบบ https://calendly.com/ชื่อคุณ/30min)

ยังไม่มีเหรอคะ/ครับ? สมัครฟรีที่ calendly.com
ตั้งเวลาว่างเสร็จมันจะให้ลิงก์มา เอามาวางตรงนี้ได้เลย
```

ถ้านักเรียนยังไม่มีบัญชี หยุดรอ ให้เขาไปสมัครแล้วกลับมาวางลิงก์ อย่าเดาลิงก์เอง

### row `social-proof`
ถามรีวิว 1-5 อัน

```
⭐ เพิ่มรีวิวลูกค้าให้ค่ะ/ครับ

ส่งรีวิวมาได้เลย แต่ละอันบอก
- ชื่อลูกค้า (หรือชื่อย่อก็ได้)
- ข้อความที่เขาชม
- ให้กี่ดาว (1-5) ถ้าไม่บอกผมใส่ 5 ดาวให้

ส่งมากี่อันก็ได้ 1-5 อันกำลังสวย
```

ถ้านักเรียนยังไม่มีรีวิวจริง **ห้ามแต่งรีวิวปลอม** บอกว่า "เก็บ slot ไว้ก่อนได้นะคะ/ครับ พอมีรีวิวจริงค่อยส่งมา ผมจะใส่ให้" หรือใส่ section เปล่าพร้อม comment ว่ารอรีวิว

### row `faq`
**ใช้ generate-then-confirm (ดูหลักการบนสุด Step 3) ไม่ถามจากศูนย์**

```
❓ เพิ่มคำถามที่พบบ่อยให้ค่ะ/ครับ

มีคำถามในใจอยู่แล้ว หรือให้ผมร่างให้ดีคะ/ครับ?
A. มีอยู่แล้ว ส่งคู่ถาม-ตอบมาเลย
B. ช่วยร่างให้ (ผมเดาคำถามที่ธุรกิจแบบคุณมักโดนถาม จากข้อมูลเว็บ แล้วคุณเติม/แก้คำตอบ)
```

**ทาง B ร่างให้**
1. อ่าน CLAUDE.md (archetype business services channels ราคา เวลา) **ร่างคำถาม 4-6 ข้อ** ที่ธุรกิจแบบนี้โดนถามบ่อย (เวลาเปิด ที่ตั้ง/ที่จอด ราคา วิธีจอง การชำระเงิน มือใหม่ทำได้ไหม ฯลฯ) คำถามพวกนี้ generic generate ได้
2. **คำตอบ** ถ้า CLAUDE.md มีข้อเท็จจริง (เวลา ที่อยู่ ราคา) ร่างจากนั้น ถ้าไม่มี เว้น `[เติมคำตอบ]`
3. โชว์ draft ทั้งชุดให้นักเรียน บอกชัด **"ตรวจให้ตรงจริงนะคะ/ครับ ตรงไหนผิดแก้ได้เลย"** **ห้าม finalize คำตอบที่เดาเอง**
4. นักเรียนปรับ → finalize → ค่อยใส่ลงเว็บ

**ทาง A มีอยู่แล้ว** รับคู่ถาม-ตอบจากนักเรียนตรงๆ
- ข้อแรกเปิดไว้ (`open`) ให้เห็นว่ากดแล้วขยาย ที่เหลือปิด

### row `timeline`
ถาม milestones + โหมด (ปี/เหตุการณ์ = ข้อเท็จจริงจริง ห้ามแต่ง)

```
📜 เพิ่มไทม์ไลน์ประวัติให้ค่ะ/ครับ

ส่งเหตุการณ์สำคัญมาได้เลย ไล่ตามปี แต่ละอันบอก
- ปี (เช่น 2562 หรือ 2019)
- เกิดอะไรขึ้น (สั้นๆ 1 บรรทัด)
- รายละเอียดเพิ่ม (ถ้ามี)

3-8 เหตุการณ์กำลังสวย ไล่จากเก่าไปใหม่

อยากได้แบบไหน
1. เส้นเดียว (เรียบ อ่านง่าย เหมาะทุกแบรนด์)
2. สลับซ้ายขวา (มีจังหวะ เด่นบนจอใหญ่ บนมือถือพับเป็นเส้นเดียวอัตโนมัติ)
```

- **ปี + เหตุการณ์ = ข้อเท็จจริงจริง ห้ามแต่ง** ถ้านักเรียนยังไม่มีครบ เก็บ slot ไว้ก่อน
- **โหมด** map เป็น modifier `cnc-timeline--spine` (1) หรือ `cnc-timeline--alt` (2) ทั้งคู่ responsive โหมด alt บนมือถือพับเป็น spine เอง
- ไล่ปีจากเก่าไปใหม่ ใช้ `<ol>` (semantic ลำดับเวลา)

### row `pricing`
ถามจำนวน tier + เนื้อหา (generate-then-confirm ราคา = ข้อเท็จจริงจริง)

```
💷 เพิ่มตารางราคาให้ค่ะ/ครับ

อยากมีกี่แพ็กเกจ? (2-4 อัน ปกติ 3 กำลังสวย)

แต่ละแพ็กเกจบอก
- ชื่อ (เช่น เริ่มต้น / ยอดนิยม / พรีเมียม)
- ราคา (เช่น 990 บาท/เดือน)
- ได้อะไรบ้าง (list สั้นๆ)
- ปุ่มกดให้ไปไหน (ทักไลน์ / จอง / ฟอร์ม)

อันไหนอยากให้เด่นเป็น "ยอดนิยม"? ผมจะไฮไลต์ให้
```

- จำนวน tier 2-4 default 3 grid auto-fit เรียงข้างกันบน desktop ซ้อนลงบนมือถือ
- **ราคา + features = ข้อเท็จจริงจริง ห้ามแต่ง** ถ้านักเรียนยังไม่มีตัวเลข ช่วยร่าง **โครง** (ชื่อ tier ทั่วไป) แล้วเว้นราคา/features ให้เติม (generate-then-confirm)
- ปุ่ม CTA ลิงก์ไป CTA จริงของเว็บ (ไลน์ จอง ฟอร์ม) ถ้าไม่บอก ดู CTA หลักในหน้าแล้วถามยืนยัน
- 1 tier ตั้ง `--popular` ได้ ไฮไลต์ด้วย accent + badge + ยกตัวเด่น

### row `gallery`
ถามจำนวน + แนวรูป **ก่อน** แล้ว delegate ให้ web-images optimize

```
🖼️ เพิ่มแกลเลอรีรูปให้ค่ะ/ครับ

มีรูปกี่รูป? (5-10 กำลังดี ถ้าเยอะ 20-30 ก็ได้ ผมใส่ปุ่มดูเพิ่มให้)

รูปส่วนใหญ่แนวไหน?
1. แนวนอน (16:9) บรรยากาศ วิว
2. แนวตั้ง (9:16) รูปคน รูปจากมือถือแนวตั้ง
3. จัตุรัส (1:1) แบบ IG
4. ผสม (คละแนว) ผมจัดแบบ masonry ให้

ส่งรูปมาเป็นไฟล์ (ลากไฟล์ให้ path ขึ้น หรือเซฟลงโฟลเดอร์โปรเจกต์ก่อน วางภาพในแชทเฉยๆ ใช้ไม่ได้) ผม optimize + ทำแกลเลอรีคลิกขยายให้
```

- **จำนวน** ใช้กำหนดจำนวนคอลัมน์ + ถ้า > 12 ใส่ปุ่ม "ดูเพิ่ม" (โชว์ 12 รูปแรกก่อน กันหน้ายาว)
- **แนวรูป** ใส่ modifier class บน section ให้ layout เข้ากับสัดส่วน (ดู CSS Step 5) ตรงกับ 3 ratio ที่ web-images บังคับ (16:9 / 1:1 / 9:16) + ผสม = masonry
- **delegate ให้ web-images** optimize รูปลง `assets/images/` ตาม ratio ที่นักเรียนเลือก (อย่า optimize เอง)
- ใช้รูปจริงของนักเรียนเท่านั้น **ห้ามใส่รูป stock มั่ว**
- alt text แต่ละรูป generate จาก context (เหมือน accessibility skill) เดาไม่ได้ถามสั้นๆ
- ถ้านักเรียนยังไม่มีรูป เก็บ slot ไว้ก่อน

### row `before-after`
**ไม่ถามแนวรูปก่อน** ให้นักเรียนส่งรูป 2 รูป (เป็นไฟล์/path ไม่ใช่ภาพ paste ในแชท) แล้ว detect แนวจากรูปจริง (web-images อ่านขนาด) เลือก modifier ให้อัตโนมัติ

```
🔁 เพิ่มรูปเปรียบเทียบก่อน/หลังให้ค่ะ/ครับ

เซฟรูป 2 รูปลงโฟลเดอร์รูปของเว็บก่อน ตั้งชื่อ
- before  (รูปก่อน)
- after   (รูปหลัง)
แล้วบอก path หรือชื่อไฟล์มาได้เลย

ถ่ายมุมเดียวกัน กรอบใกล้กัน เทียบแล้วสวยสุด
ผมดูแนวรูปให้เอง (นอนหรือตั้ง) แล้วทำตัวเลื่อนเทียบให้
```

- **รับรูปเป็นไฟล์จริงเท่านั้น** ให้ path ของไฟล์ หรือเซฟลงโฟลเดอร์รูปของโปรเจกต์ก่อน (แค่วางรูปในแชทเฉยๆ เอาไปใส่เว็บไม่ได้ เพราะรูปที่วางในแชทไม่ได้กลายเป็นไฟล์บนเครื่อง) ใช้ชื่อ before / after
- **detect แนวจากรูปจริง** web-images อ่านขนาด 2 รูป กว้าง > สูง = แนวนอนใส่ `cnc-ba--landscape` (16:9) / สูง > กว้าง = แนวตั้งใส่ `cnc-ba--portrait` (9:16) ไม่ต้องถามนักเรียนเรื่องตัวเลข ratio
- รองรับ **2 แนวเท่านั้น 16:9 (นอน) กับ 9:16 (ตั้ง)** before/after เทียบชัดสุดเมื่อเต็มกรอบนอนหรือตั้ง ไม่ใช้ 1:1
- **2 รูปต้องแนวเดียวกัน** ถ้านักเรียนส่งคนละแนว (อันนอน อันตั้ง) ถามครั้งเดียวว่าเอาแนวไหน นอนหรือตั้ง แล้ว web-images ครอป **ทั้ง 2 รูป** เป็นแนวนั้น (ครอปกลาง) ให้ ratio ตรงกันเป๊ะ
- **รูปจริงของนักเรียนเท่านั้น ห้ามใส่รูป stock มั่ว** ถ้ายังไม่มีครบทั้งคู่ เก็บ slot ไว้ก่อน
- alt text generate จาก context (เช่น "ก่อนทำสีผม" "หลังทำสีผม") เดาไม่ได้ถามสั้นๆ
- เหมาะมากกับ archetype เสริมสวย ฟิตเนส คลินิก รีโนเวท ทำความสะอาด (โชว์ผลลัพธ์ชัดๆ)

### row `map`
ถามแค่ที่อยู่ร้าน

```
📍 เพิ่มแผนที่ที่ตั้งร้านให้ค่ะ/ครับ

บอกที่อยู่ร้านมาได้เลย (พิมพ์แบบที่ค้นใน Google Maps เจอ)
เช่น "ร้านกาแฟ ABC ซอยทองหล่อ 10 กรุงเทพ" หรือที่อยู่เต็มก็ได้

หรือถ้าเปิด Google Maps อยู่แล้ว กด Share → ฝังแผนที่ (Embed a map)
copy โค้ดมาวางตรงนี้ก็ได้ ผมดึงให้เอง
```

- ทาง A นักเรียนบอกที่อยู่ → สร้าง URL แบบ **ไม่ต้องใช้ API key** `https://maps.google.com/maps?q=<ที่อยู่ url-encoded>&z=15&output=embed` ใส่ใน iframe (วิธีนี้ไม่ต้องสมัคร Google Cloud ไม่ต้องเปิด billing เหมาะ beginner)
- ทาง B นักเรียน paste embed iframe จาก Google Maps → ดึง `src` ออกมาใช้ (เป็น `?pb=` keyless เหมือนกัน)
- **ห้ามใช้ Maps Embed API ที่ต้อง key** (`/maps/embed/v1/...&key=`) เพราะต้องสมัคร + เปิด billing = friction เกินไปสำหรับนักเรียน ใช้ keyless เสมอ

### row `media`
ถามแค่ลิงก์วิดีโอ/รีล

```
🎬 เพิ่มวิดีโอ/รีลให้ค่ะ/ครับ

วางลิงก์มาได้เลย รองรับ
- YouTube (youtube.com / youtu.be / Shorts)
- Vimeo
- Instagram (โพสต์ / รีล)
- Facebook (วิดีโอ / รีล)
- TikTok

วางลิงก์เดียวก็พอ ผมดึงมาแสดงให้เข้ากับเว็บ
```

- ต้องเป็นโพสต์/วิดีโอ **public** เท่านั้น ถ้า private จะ embed ไม่ได้ เตือนนักเรียน
- รับลิงก์เดียวต่อ 1 widget ถ้าอยากหลายอันเพิ่มหลาย widget

### row `countdown`
ถามวันเวลาจบ + หัวข้อ

```
⏰ เพิ่มตัวนับถอยหลังให้ค่ะ/ครับ

นับถอยหลังถึงเมื่อไหร่? บอกวันและเวลาจบมาได้เลย
เช่น "31 ธันวาคม 2026 เที่ยงคืน" หรือ "30 มิ.ย. 6 โมงเย็น"

อยากให้หัวข้อว่าอะไร? (เช่น "โปรหมดใน" "เปิดจองอีก")
ถ้าไม่บอกใส่ "โปรโมชั่นหมดใน" ให้
```

- แปลงวันเวลาที่นักเรียนบอก → ISO `YYYY-MM-DDTHH:MM:SS+07:00` (pin เวลาไทยกันคนต่าง timezone นับเพี้ยน)
- ถ้านักเรียนบอกวันแบบกว้างๆ (พรุ่งนี้ สิ้นเดือน) คำนวณเป็นวันเวลาจริงจากวันที่ปัจจุบันแล้ว confirm กับนักเรียนก่อน

### row `chart`
ถามชนิด + ข้อมูล (ข้อมูลรับได้ 2 ทาง)

```
📊 เพิ่มกราฟให้ค่ะ/ครับ

อยากได้กราฟแบบไหน
1. แท่ง (bar) เทียบค่าหลายอัน
2. เส้น (line) ดูแนวโน้มตามเวลา
3. วงกลม (pie) สัดส่วน
4. โดนัท (doughnut) สัดส่วนแบบมีรู

แล้วส่งข้อมูลมา 2 วิธี เลือกได้
A. พิมพ์มาเลย เช่น "ม.ค. 12, ก.พ. 19, มี.ค. 8" (ป้าย + ตัวเลข)
B. ส่งไฟล์ Excel หรือ CSV เป็นไฟล์ (ลากไฟล์ให้ path ขึ้น หรือบอก path) ผมอ่านให้เอง
```

- **ทาง A พิมพ์** แยกป้ายกำกับ + ตัวเลขจากที่นักเรียนพิมพ์
- **ทาง B ไฟล์** นักเรียนส่ง `.csv` หรือ `.xlsx` เป็นไฟล์/path (ต้องเป็นไฟล์จริงบนเครื่อง ไฟล์ที่ paste เป็นภาพในแชทใช้ไม่ได้)
  - CSV = text อ่านตรงๆ คอลัมน์ 1 = labels คอลัมน์ 2+ = ค่า (แต่ละคอลัมน์ = 1 series)
  - Excel `.xlsx` = อ่านด้วย Python `openpyxl` (auto-install แบบเดียวกับ Pillow/segno) คอลัมน์เหมือน CSV
  - ถ้าโครงไฟล์ไม่ชัด (หัวตารางอยู่ไหน คอลัมน์ไหนคือ label) **ถามนักเรียนสั้นๆ** ก่อน อย่าเดา
- **ห้ามแต่งตัวเลขปลอม** ใช้ข้อมูลจริงจากนักเรียน/ไฟล์เท่านั้น (กฎเดียวกับรีวิว) ถ้ายังไม่มีข้อมูล เก็บ slot ไว้
- แปลงเป็น JSON ใส่ `data-cnc-chart` + เขียน `aria-label` สรุปข้อมูลจริง
- สีดึงจากแบรนด์อัตโนมัติ ไม่ต้องถามเรื่องสี

---

## Step 4 เลือกจุดวาง (default ฉลาด)

เลือกตำแหน่ง default ตามชนิด widget แล้วบอกนักเรียนว่าวางไว้ตรงไหน เปิดให้ย้ายได้

| widget | default ที่วาง |
|--------|----------------|
| `booking` | ก่อนส่วนติดต่อ/footer |
| `social-proof` | หลัง hero ก่อนปุ่ม CTA หลัก |
| `faq` | ใกล้ footer ก่อนส่วนติดต่อ (ปิดข้อสงสัยก่อนตัดสินใจ) |
| `timeline` | กลางหน้า หรือในหน้า about (เล่าเรื่องสร้างความน่าเชื่อถือ) |
| `pricing` | กลางหน้า ก่อน FAQ/CTA (เทียบราคาแล้วเลือก) |
| `gallery` | หลัง hero หรือกลางหน้า (โชว์ผลงาน/บรรยากาศ) |
| `before-after` | หลัง hero หรือกลางหน้า (โชว์ผลลัพธ์ก่อน/หลัง) |
| `map` | ใกล้ส่วนติดต่อ/footer (มาหาเรา) |
| `media` | หลัง hero หรือกลางหน้า (โชว์ของ) |
| `countdown` | ใกล้ปุ่ม CTA/โปร หรือบนสุดใต้ hero (สร้าง urgency) |
| `chart` | กลางหน้า ใกล้ส่วนผลลัพธ์/ข้อมูล/proof |

ถ้าเว็บมีหลายหน้า (`pages/`) ถามสั้นๆ ว่า "วางหน้าไหนดีคะ/ครับ หน้าแรก หรือหน้า [ชื่อ]" default = หน้าแรก

หา insertion point จริงใน HTML (มองหา section ติดต่อ/footer/hero) แทรก section ใหม่เข้าไปตรงนั้น ห้ามทับของเดิม

---

## Step 5 ฝัง widget (ติด marker ใช้ token)

หลักการเขียนโค้ดให้ผ่าน strict CSP เสมอ

- **HTML** แทรก markup ลง `index.html` (หรือหน้าที่เลือก) ห่อใน `<section data-cnc-widget="<id>" ...>`
- **CSS** เขียน component style ต่อท้าย `styles.css` (ไฟล์ภายนอก) ใช้ `var(--w-bg/surface/accent/text/muted)` สำหรับสี (มาจาก normalization block ใน Step 2.3) และ `var(--s*)` `var(--font-*)` สำหรับ spacing/font ห้าม inline `<style>` ห้ามใช้ `var(--color-*)` ตรงๆ เพราะบางเว็บไม่มีชื่อนั้น
- **JS** ถ้าจำเป็น (เช่น Calendly) ใส่เป็น `<script src="..." data-cnc-widget="<id>">` ภายนอกเท่านั้น ห้าม inline `<script>` (strict CSP block) ครั้งเดียวที่ใช้ JS ใน 3 row นี้คือ booking ที่เหลือไม่มี JS เลย

### สูตร row `booking` (Calendly inline)

HTML (ใช้ค่า hex จริงของ accent ใน `data-url`)

```html
<section data-cnc-widget="booking" class="cnc-booking">
  <h2 class="cnc-booking__title">จองเวลานัดหมาย</h2>
  <div class="calendly-inline-widget"
       data-url="https://calendly.com/USER/SLUG?primary_color=ACCENTHEX"
       style="min-width:320px;height:700px"></div>
</section>
<script src="https://assets.calendly.com/assets/external/widget.js"
        async data-cnc-widget="booking"></script>
```

(`ACCENTHEX` = accentHex จาก Step 2.1 CLAUDE.md หรือ 2.3 CSS ตัด `#` ออก เช่น yoga `c97b5b` fitness `e63946` ห้ามใช้ชื่อตัวแปร URL param รับ hex จริงเท่านั้น)

CSS ต่อท้าย styles.css self-contained ไม่พึ่ง `.container`/`.display`

```css
/* widget:booking */
.cnc-booking {
  max-width: 800px; margin-left: auto; margin-right: auto;
  padding: var(--s7) var(--s4);
}
.cnc-booking__title {
  margin-bottom: var(--s5); text-align: center;
  color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display);
}
```

CSP ที่ต้องลงทะเบียน (Step 6) ตามตาราง best-practices

```
script-src:  https://assets.calendly.com
style-src:   https://assets.calendly.com
frame-src:   https://calendly.com
connect-src: https://*.calendly.com
```

### สูตร row `social-proof` (สร้างเอง ไม่มี CSP)

**เลือก layout mode ตาม archetype** (Step 2.6 layout variant) markup เดียวกัน ต่างที่ modifier class บน section

| archetype/tone (จาก CLAUDE.md web-scope) | mode | หน้าตา |
|-------------------------------------------|------|--------|
| editorial minimal wellness spa personal เงียบสงบ | `cnc-reviews--list` | quote เรียงลงเป็นแถว คั่นด้วยเส้นบาง ไม่มีกล่อง (editorial) |
| service local-business bold sport product ทั่วไป (default) | `cnc-reviews--card` | card มีขอบ เรียง grid 2 คอลัมน์ |

HTML markup เดียว (เปลี่ยนแค่ modifier class)

```html
<section data-cnc-widget="social-proof" class="cnc-reviews cnc-reviews--card">
  <h2 class="cnc-reviews__title">ลูกค้าพูดถึงเรา</h2>
  <div class="cnc-reviews__list">
    <!-- 1 figure ต่อ 1 รีวิว -->
    <figure class="review-card">
      <div class="review-card__stars" aria-label="5 ดาว">★★★★★</div>
      <blockquote class="review-card__text">ข้อความรีวิว</blockquote>
      <figcaption class="review-card__name">ชื่อลูกค้า</figcaption>
    </figure>
  </div>
</section>
```

(modifier เป็น `cnc-reviews--list` ถ้าเลือก list mode ใช้ prefix `cnc-` กัน class ชน ห้ามใช้ `container` `grid` `grid--2` `display`)

CSS ต่อท้าย styles.css self-contained ใช้ `--w-*` (รวม DNA `--w-radius` `--w-card-border`) + `:root` token

```css
/* widget:social-proof */
.cnc-reviews { max-width: 1100px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-reviews__title {
  margin-bottom: var(--s5); text-align: center;
  color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display);
}
.cnc-reviews__list { display: grid; grid-template-columns: 1fr; gap: var(--s4); }

/* การ์ด stars/text/name ใช้ร่วมทุก mode */
.review-card__stars { color: var(--w-accent); font-size: var(--s4); letter-spacing: 2px; }
.review-card__text { font-family: var(--font-body); line-height: 1.6; }
.review-card__name { font-weight: 700; color: var(--w-muted); }

/* card mode: กล่องมีขอบ grid 2 คอลัมน์ ขอบ+มุม mirror DNA ของเว็บ */
.cnc-reviews--card .review-card {
  background: color-mix(in srgb, var(--w-text) 6%, var(--w-bg));
  color: var(--w-text);
  border: var(--w-card-border);
  border-radius: var(--w-radius);
  padding: var(--s5);
  display: flex; flex-direction: column; gap: var(--s3);
}
@media (min-width: 768px) { .cnc-reviews--card .cnc-reviews__list { grid-template-columns: 1fr 1fr; } }

/* list mode: editorial quote เรียงแถว คั่นเส้นบาง ไม่มีกล่อง */
.cnc-reviews--list .cnc-reviews__list { gap: 0; max-width: 720px; margin-left: auto; margin-right: auto; }
.cnc-reviews--list .review-card {
  color: var(--w-text);
  padding: var(--s5) 0;
  border-bottom: var(--w-card-border);
  display: flex; flex-direction: column; gap: var(--s2);
}
.cnc-reviews--list .review-card:last-child { border-bottom: 0; }
```

**ทำไมไม่ใช้ `--w-surface` เป็นพื้น card** เพราะ surface ของแต่ละเว็บสว่าง/มืดไม่เท่ากันเทียบกับ text จึงไม่การันตี contrast (เว็บธีมสว่างจะ surface สว่าง + text ก็อาจสว่าง = อ่านไม่ออก) การ mix จากคู่ `bg`/`text` ปลอดภัยทุก palette `color-mix` เป็น CSS ล้วนไม่กระทบ CSP

ดาวสร้างจากจำนวนที่นักเรียนบอก (★ เต็ม ☆ ที่เหลือ) ใส่ `aria-label` บอกจำนวนดาวเป็นคำ

### สูตร row `faq` (accordion HTML ล้วน ไม่มี JS ไม่มี CSP)

widget ที่ง่ายที่สุด ใช้ `<details>`/`<summary>` ของ HTML ตรงๆ กดแล้วขยายได้เอง **ไม่ต้องเขียน JS เลย** accessible โดยกำเนิด (keyboard + screen reader) ไม่ต้องแตะ scripts.js ไม่ต้อง CSP

HTML

```html
<section data-cnc-widget="faq" class="cnc-faq">
  <h2 class="cnc-faq__title reveal">คำถามที่พบบ่อย</h2>
  <div class="cnc-faq__list reveal">
    <details class="cnc-faq__item" open>
      <summary class="cnc-faq__q">เปิดกี่โมง</summary>
      <div class="cnc-faq__a">ทุกวัน 9 โมงเช้า ถึง 2 ทุ่ม</div>
    </details>
    <details class="cnc-faq__item">
      <summary class="cnc-faq__q">มีที่จอดรถไหม</summary>
      <div class="cnc-faq__a">มี จอดฟรีหน้าร้าน</div>
    </details>
  </div>
</section>
```

CSS ต่อท้าย styles.css ใช้ DNA + `--w-*` ซ่อน marker ลูกศร default ใส่ +/− เอง

```css
/* widget:faq */
.cnc-faq { max-width: 760px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-faq__title { margin-bottom: var(--s5); text-align: center; color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-faq__list { display: flex; flex-direction: column; gap: var(--s3); }
.cnc-faq__item {
  border: var(--w-card-border); border-radius: var(--w-radius);
  background: color-mix(in srgb, var(--w-text) 4%, var(--w-bg));
  overflow: hidden;
}
.cnc-faq__q {
  cursor: pointer; list-style: none;
  padding: var(--s4) var(--s5);
  font-family: var(--font-display); font-size: 1.0625rem; font-weight: 700; color: var(--w-text);
  display: flex; justify-content: space-between; align-items: center; gap: var(--s3);
  transition: background .2s ease;
}
.cnc-faq__q::-webkit-details-marker { display: none; }
.cnc-faq__q:hover { background: color-mix(in srgb, var(--w-accent) 8%, transparent); }
.cnc-faq__q::after {
  content: "+"; color: var(--w-accent); font-size: var(--s6); line-height: 1; flex-shrink: 0;
  transition: transform .25s ease;
}
.cnc-faq__item[open] .cnc-faq__q { border-bottom: var(--w-card-border); }
.cnc-faq__item[open] .cnc-faq__q::after { transform: rotate(45deg); }
.cnc-faq__a {
  padding: var(--s4) var(--s5);
  color: var(--w-muted); font-family: var(--font-body); line-height: 1.7;
  animation: cnc-faq-open .28s ease;
}
@keyframes cnc-faq-open { from { opacity: 0; transform: translateY(-6px); } to { opacity: 1; transform: translateY(0); } }
```

- **ไม่มี JS** `<details>` กดเปิด-ปิดเองตาม native ข้าม scripts.js
- **ไม่มี CSP** ข้าม Step 6
- ใส่ `reveal` ที่หัวข้อ + list (motion เหมือน widget อื่น)
- คำถามเด่นกว่าคำตอบ (display font หนา ใหญ่กว่า + เส้นคั่นตอนเปิด) คำตอบ muted body font
- `+` หมุน 45 องศาเป็น × ตอนเปิด คำตอบ fade+slide เข้า (animation pure CSS เคารพ prefers-reduced-motion ผ่าน foundation)
- `list-style: none` + ซ่อน `::-webkit-details-marker` เอาลูกศร default ออก

### สูตร row `timeline` (vertical timeline สร้างเอง 2 โหมด responsive ไม่มี JS ไม่มี CSP)

HTML ใช้ `<ol>` (semantic ลำดับเวลา) modifier เลือกโหมด (`--spine` หรือ `--alt`)

```html
<section data-cnc-widget="timeline" class="cnc-timeline cnc-timeline--spine">
  <h2 class="cnc-timeline__title reveal">เรื่องราวของเรา</h2>
  <ol class="cnc-timeline__list">
    <li class="cnc-timeline__item reveal">
      <span class="cnc-timeline__dot" aria-hidden="true"></span>
      <div>
        <span class="cnc-timeline__year">2562</span>
        <h3 class="cnc-timeline__heading">เปิดร้านวันแรก</h3>
        <p class="cnc-timeline__desc">เริ่มจากห้องเล็กๆ</p>
      </div>
    </li>
    <!-- 1 li ต่อ 1 milestone ไล่ปีเก่าไปใหม่ -->
  </ol>
</section>
```

(modifier เป็น `cnc-timeline--alt` ถ้านักเรียนเลือกโหมดสลับซ้ายขวา prefix `cnc-` กัน class ชน)

CSS ต่อท้าย styles.css self-contained ใช้ `--w-*` (รวม DNA) **ทั้งสองโหมดพับเป็น spine เดียวบนมือถือ alt zig-zag เฉพาะจอ >= 760px**

```css
/* widget:timeline */
.cnc-timeline{max-width:760px;margin-left:auto;margin-right:auto;padding:var(--s7) var(--s4)}
.cnc-timeline__title{text-align:center;margin-bottom:var(--s5);color:var(--w-text);font-family:var(--font-display);font-size:var(--size-display)}
.cnc-timeline__list{list-style:none;margin:0;padding:0;position:relative}
.cnc-timeline__item{position:relative;padding-bottom:var(--s5)}
.cnc-timeline__dot{position:absolute;width:14px;height:14px;border-radius:var(--w-dot-radius,50%);background:var(--w-accent);box-sizing:border-box}
.cnc-timeline__year{display:block;font-weight:700;letter-spacing:1px;color:var(--w-accent)}
.cnc-timeline__heading{margin:var(--s1) 0;color:var(--w-text)}
.cnc-timeline__desc{margin:0;line-height:1.6;color:var(--w-muted)}

/* spine + alt ใช้เส้นเดียวกันบนมือถือ */
.cnc-timeline--spine .cnc-timeline__list,
.cnc-timeline--alt   .cnc-timeline__list{padding-left:28px}
.cnc-timeline--spine .cnc-timeline__list::before,
.cnc-timeline--alt   .cnc-timeline__list::before{content:"";position:absolute;left:7px;top:6px;bottom:6px;width:var(--w-card-border-w,2px);background:color-mix(in srgb,var(--w-text) 22%,transparent)}
.cnc-timeline--spine .cnc-timeline__dot,
.cnc-timeline--alt   .cnc-timeline__dot{left:1px;top:5px}

/* alt zig-zag เฉพาะจอใหญ่ */
@media(min-width:760px){
  .cnc-timeline--alt .cnc-timeline__list{padding-left:0}
  .cnc-timeline--alt .cnc-timeline__list::before{left:50%;transform:translateX(-50%)}
  .cnc-timeline--alt .cnc-timeline__item{width:50%;box-sizing:border-box}
  .cnc-timeline--alt .cnc-timeline__item:nth-child(odd){margin-left:0;padding-right:34px;text-align:right}
  .cnc-timeline--alt .cnc-timeline__item:nth-child(even){margin-left:50%;padding-left:34px;text-align:left}
  .cnc-timeline--alt .cnc-timeline__item:nth-child(odd) .cnc-timeline__dot{left:auto;right:-7px}
  .cnc-timeline--alt .cnc-timeline__item:nth-child(even) .cnc-timeline__dot{left:-7px}
}
```

- **DNA** จุด (`--w-dot-radius`) เว็บมุมคม (radius 0) ใช้จุดเหลี่ยม เว็บมุมมนใช้จุดกลม เส้น (`--w-card-border-w`) เลียนน้ำหนักขอบ card เว็บ (hairline 1px / หนา 2-3px)
- **ไม่มี CSP ไม่มี JS** ข้าม Step 6
- ใส่ `reveal` ที่หัวข้อ + แต่ละ item (motion เหมือน widget อื่น ทยอยขึ้นได้ด้วย stagger)
- **ปี/เหตุการณ์จากนักเรียนเท่านั้น ห้ามแต่ง**

### สูตร row `pricing` (cards เรียงข้างกัน ไม่มี JS hover lift)

grid `auto-fit` รองรับ 2-4 tier เองโดยไม่ต้องรู้จำนวน desktop เรียงข้างกัน mobile ซ้อนลง การ์ดใช้ DNA + `--w-*` tier ยอดนิยมไฮไลต์ accent + badge animation = hover lift + ตัวเด่นยกขึ้น (pure CSS)

HTML (ตัวอย่าง 3 tier อันกลาง popular)

```html
<section data-cnc-widget="pricing" class="cnc-pricing">
  <h2 class="cnc-pricing__title reveal">แพ็กเกจราคา</h2>
  <div class="cnc-pricing__grid reveal">
    <div class="cnc-pricing__tier">
      <h3 class="cnc-pricing__name">เริ่มต้น</h3>
      <div class="cnc-pricing__price"><span class="cnc-pricing__amount">590</span><span class="cnc-pricing__period">บาท/เดือน</span></div>
      <ul class="cnc-pricing__features">
        <li>เข้าใช้ได้ 8 ครั้ง/เดือน</li>
        <li>คลาสกลุ่มพื้นฐาน</li>
      </ul>
      <a href="#CTA" class="cnc-pricing__cta">เลือกแพ็กนี้</a>
    </div>
    <div class="cnc-pricing__tier cnc-pricing__tier--popular">
      <span class="cnc-pricing__badge">ยอดนิยม</span>
      <h3 class="cnc-pricing__name">ยอดนิยม</h3>
      <div class="cnc-pricing__price"><span class="cnc-pricing__amount">990</span><span class="cnc-pricing__period">บาท/เดือน</span></div>
      <ul class="cnc-pricing__features">
        <li>เข้าใช้ไม่จำกัด</li>
        <li>คลาสกลุ่มทุกประเภท</li>
        <li>เทรนเนอร์ส่วนตัว 2 ครั้ง</li>
      </ul>
      <a href="#CTA" class="cnc-pricing__cta">เลือกแพ็กนี้</a>
    </div>
    <div class="cnc-pricing__tier">
      <h3 class="cnc-pricing__name">พรีเมียม</h3>
      <div class="cnc-pricing__price"><span class="cnc-pricing__amount">1,890</span><span class="cnc-pricing__period">บาท/เดือน</span></div>
      <ul class="cnc-pricing__features">
        <li>ทุกอย่างในยอดนิยม</li>
        <li>เทรนเนอร์ส่วนตัวไม่จำกัด</li>
        <li>แผนโภชนาการ</li>
      </ul>
      <a href="#CTA" class="cnc-pricing__cta">เลือกแพ็กนี้</a>
    </div>
  </div>
</section>
```

(`#CTA` = anchor/ลิงก์ CTA จริงของเว็บ เช่น `#join` `#intake` `#line-out` หรือ tel:/line ใส่ badge + class `--popular` เฉพาะ tier ที่เลือกให้เด่น)

CSS ต่อท้าย styles.css

```css
/* widget:pricing */
.cnc-pricing { max-width: 1100px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-pricing__title { margin-bottom: var(--s5); text-align: center; color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-pricing__grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: var(--s4); align-items: stretch; }
.cnc-pricing__tier {
  position: relative;
  border: var(--w-card-border); border-radius: var(--w-radius);
  background: color-mix(in srgb, var(--w-text) 4%, var(--w-bg));
  padding: var(--s5); display: flex; flex-direction: column; gap: var(--s4);
  transition: transform .25s ease, border-color .25s ease, box-shadow .25s ease;
}
.cnc-pricing__tier:hover {
  transform: translateY(-6px); border-color: var(--w-accent);
  box-shadow: 0 14px 32px -14px color-mix(in srgb, var(--w-accent) 55%, transparent);
}
.cnc-pricing__tier--popular { border-color: var(--w-accent); }
@media (min-width: 768px) { .cnc-pricing__tier--popular { transform: scale(1.04); } .cnc-pricing__tier--popular:hover { transform: scale(1.04) translateY(-6px); } }
.cnc-pricing__badge { position: absolute; top: calc(-1 * var(--s3)); left: 50%; transform: translateX(-50%); background: var(--w-accent); color: var(--w-bg); font-size: 12px; font-weight: 700; letter-spacing: 1px; padding: 4px 12px; border-radius: var(--w-radius); white-space: nowrap; }
.cnc-pricing__name { font-family: var(--font-display); font-size: var(--s5); color: var(--w-text); }
.cnc-pricing__price { display: flex; align-items: baseline; gap: var(--s2); }
.cnc-pricing__amount { font-family: var(--font-display); font-size: var(--s8); line-height: 1; color: var(--w-accent); }
.cnc-pricing__period { color: var(--w-muted); font-size: 14px; }
.cnc-pricing__features { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--s2); }
.cnc-pricing__features li { position: relative; padding-left: var(--s4); color: var(--w-text); line-height: 1.5; }
.cnc-pricing__features li::before { content: "\2713"; position: absolute; left: 0; color: var(--w-accent); font-weight: 700; }
.cnc-pricing__cta { margin-top: auto; text-align: center; text-decoration: none; padding: var(--s3) var(--s4); border-radius: var(--w-radius); background: var(--w-accent); color: var(--w-bg); font-family: var(--font-display); font-weight: 700; transition: opacity .2s ease; }
.cnc-pricing__cta:hover { opacity: .88; }
```

- **ไม่มี JS ไม่มี CSP** ข้าม Step 6
- ราคาใหญ่ใช้ accent ✓ features ใช้ accent ปุ่ม accent (ตัวอักษรปุ่มใช้ `--w-bg` ตัวหนา readable เพราะ accent เป็นสี pop ที่ contrast กับ bg)
- ใส่ `reveal` ที่หัวข้อ + grid

### สูตร row `gallery` (grid + lightbox สร้างเอง JS ใน scripts.js)

grid รูป responsive คลิกรูปแล้วเปิด lightbox ขยายเต็มจอ เลื่อนซ้าย-ขวาได้ JS self-built เขียนลง scripts.js (`'self'` ไม่ต้อง CDN ไม่ต้อง CSP) รูปเป็น local (`assets/images/`) ผ่าน web-images แล้ว

HTML grid (thumb เป็น `<button>` กดได้ด้วย keyboard) + lightbox overlay 1 อันต่อหน้า

```html
<!-- modifier: --landscape / --portrait / --square / --mixed ตามแนวรูปที่นักเรียนเลือก
     ถ้ารูป > 12 เพิ่ม class --limited + ปุ่ม cnc-gallery__more -->
<section data-cnc-widget="gallery" class="cnc-gallery cnc-gallery--landscape">
  <h2 class="cnc-gallery__title reveal">แกลเลอรี</h2>
  <div class="cnc-gallery__grid reveal">
    <button class="cnc-gallery__item" type="button" data-cnc-lightbox="assets/images/g1.jpg">
      <img src="assets/images/g1.jpg" alt="คำบรรยายรูป 1" loading="lazy">
    </button>
    <!-- 1 button ต่อ 1 รูป -->
  </div>
  <!-- ใส่เฉพาะตอน --limited (รูป > 12) -->
  <button class="cnc-gallery__more" type="button" data-cnc-gallery-more>ดูเพิ่ม</button>
</section>
<div class="cnc-lightbox" data-cnc-lightbox-overlay hidden>
  <button class="cnc-lightbox__btn cnc-lightbox__close" type="button" aria-label="ปิด">&times;</button>
  <button class="cnc-lightbox__btn cnc-lightbox__prev" type="button" aria-label="รูปก่อนหน้า">&lsaquo;</button>
  <img class="cnc-lightbox__img" src="" alt="">
  <button class="cnc-lightbox__btn cnc-lightbox__next" type="button" aria-label="รูปถัดไป">&rsaquo;</button>
</div>
```

CSS ต่อท้าย styles.css (thumb ใช้ DNA + hover zoom lightbox overlay มืดเต็มจอ)

```css
/* widget:gallery */
.cnc-gallery { max-width: 1100px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-gallery__title { margin-bottom: var(--s5); text-align: center; color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-gallery__grid { display: grid; gap: var(--s3); }
.cnc-gallery__item { padding: 0; border: var(--w-card-border); border-radius: var(--w-radius); overflow: hidden; cursor: pointer; background: none; transition: transform .25s ease; }
.cnc-gallery__item:hover { transform: scale(1.03); }
.cnc-gallery__item img { width: 100%; height: 100%; object-fit: cover; display: block; }

/* layout ตามแนวรูป (ใส่ modifier บน section) */
.cnc-gallery--square .cnc-gallery__grid    { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
.cnc-gallery--square .cnc-gallery__item    { aspect-ratio: 1 / 1; }
.cnc-gallery--landscape .cnc-gallery__grid { grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
.cnc-gallery--landscape .cnc-gallery__item { aspect-ratio: 16 / 9; }
.cnc-gallery--portrait .cnc-gallery__grid  { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
.cnc-gallery--portrait .cnc-gallery__item  { aspect-ratio: 9 / 16; }
/* ผสม = masonry ด้วย CSS columns รูปคงสัดส่วนจริง ไม่ crop */
.cnc-gallery--mixed .cnc-gallery__grid { display: block; columns: 2; column-gap: var(--s3); }
@media (min-width: 768px) { .cnc-gallery--mixed .cnc-gallery__grid { columns: 3; } }
.cnc-gallery--mixed .cnc-gallery__item { break-inside: avoid; width: 100%; margin-bottom: var(--s3); display: block; }
.cnc-gallery--mixed .cnc-gallery__item img { height: auto; }

/* show-more สำหรับรูปเยอะ (>12) โชว์ 12 แรกก่อน */
.cnc-gallery--limited .cnc-gallery__item:nth-child(n+13) { display: none; }
.cnc-gallery__more { display: block; margin: var(--s4) auto 0; padding: var(--s3) var(--s5); border: var(--w-card-border); border-radius: var(--w-radius); background: none; color: var(--w-accent); font-family: var(--font-display); font-weight: 700; cursor: pointer; }
.cnc-gallery:not(.cnc-gallery--limited) .cnc-gallery__more { display: none; }
.cnc-lightbox { position: fixed; inset: 0; z-index: 9999; background: rgba(0,0,0,.92); display: flex; align-items: center; justify-content: center; }
.cnc-lightbox[hidden] { display: none; }
.cnc-lightbox__img { max-width: 92vw; max-height: 86vh; object-fit: contain; border-radius: var(--w-radius); }
.cnc-lightbox__btn { position: absolute; background: rgba(0,0,0,.4); border: 0; color: #fff; cursor: pointer; width: 48px; height: 48px; font-size: 28px; line-height: 1; border-radius: 999px; }
.cnc-lightbox__close { top: var(--s4); right: var(--s4); }
.cnc-lightbox__prev { left: var(--s3); top: 50%; transform: translateY(-50%); }
.cnc-lightbox__next { right: var(--s3); top: 50%; transform: translateY(-50%); }
```

JS **ต่อท้าย scripts.js** (lightbox self-built keyboard Esc + ลูกศร คลิกฉากหลังปิด)

```js
/* widget:gallery */
(function () {
  var overlay = document.querySelector('[data-cnc-lightbox-overlay]');
  if (!overlay) return;
  var img = overlay.querySelector('.cnc-lightbox__img');
  var items = [].slice.call(document.querySelectorAll('[data-cnc-lightbox]'));
  if (!items.length) return;
  var idx = 0;
  function show(i) {
    idx = (i + items.length) % items.length;
    var el = items[idx], thumb = el.querySelector('img');
    img.src = el.getAttribute('data-cnc-lightbox');
    img.alt = thumb ? thumb.alt : '';
    overlay.hidden = false;
  }
  function close() { overlay.hidden = true; img.src = ''; }
  items.forEach(function (el, i) { el.addEventListener('click', function () { show(i); }); });
  overlay.querySelector('.cnc-lightbox__close').addEventListener('click', close);
  overlay.querySelector('.cnc-lightbox__prev').addEventListener('click', function (e) { e.stopPropagation(); show(idx - 1); });
  overlay.querySelector('.cnc-lightbox__next').addEventListener('click', function (e) { e.stopPropagation(); show(idx + 1); });
  overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
  document.addEventListener('keydown', function (e) {
    if (overlay.hidden) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'ArrowLeft') show(idx - 1);
    else if (e.key === 'ArrowRight') show(idx + 1);
  });
  // show-more (เฉพาะ gallery ที่ --limited)
  document.querySelectorAll('[data-cnc-gallery-more]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var sec = btn.closest('.cnc-gallery');
      if (sec) sec.classList.remove('cnc-gallery--limited');
      btn.style.display = 'none';
    });
  });
})();
```

- **ไม่มี CSP** JS อยู่ scripts.js (`'self'`) รูป local ข้าม Step 6
- รูปผ่าน web-images ก่อน (optimize + ratio) gallery แค่อ้างไฟล์
- thumb เป็น `<button>` + `<img alt>` accessible lightbox ปิดด้วย Esc เลื่อนด้วยลูกศร
- ใส่ `reveal` ที่หัวข้อ + grid (overlay ไม่ต้อง)

### สูตร row `before-after` (slider เทียบรูป สร้างเอง JS ใน scripts.js)

2 รูปซ้อนกัน รูปหลังอยู่ล่าง รูปก่อนอยู่บนถูก clip ตามตำแหน่ง handle ลากเทียบได้ (เมาส์ + นิ้ว + คีย์บอร์ด) JS self-built ลง scripts.js (`'self'` ไม่ต้อง CSP) รูป local ผ่าน web-images แล้ว

HTML (modifier `--landscape` (16:9) หรือ `--portrait` (9:16) ตามแนวรูปที่ detect ได้ รูป before ใส่ inline clip 50% ไว้ก่อนเป็น failsafe ตอน JS ยังไม่รัน)

```html
<section data-cnc-widget="before-after" class="cnc-ba cnc-ba--portrait">
  <h2 class="cnc-ba__title reveal">ผลลัพธ์ก่อน หลัง</h2>
  <div class="cnc-ba__stage reveal" data-cnc-ba>
    <img class="cnc-ba__img" src="assets/images/after.jpg" alt="หลัง [บรรยายสั้น]">
    <img class="cnc-ba__img cnc-ba__img--before" src="assets/images/before.jpg" alt="ก่อน [บรรยายสั้น]" style="clip-path:inset(0 50% 0 0)">
    <span class="cnc-ba__label cnc-ba__label--before">ก่อน</span>
    <span class="cnc-ba__label cnc-ba__label--after">หลัง</span>
    <button class="cnc-ba__handle" type="button" data-cnc-ba-handle
            role="slider" tabindex="0" aria-label="เลื่อนเทียบรูปก่อนและหลัง"
            aria-valuemin="0" aria-valuemax="100" aria-valuenow="50" style="left:50%">
      <span class="cnc-ba__grip" aria-hidden="true">↔</span>
    </button>
  </div>
</section>
```

CSS ต่อท้าย styles.css self-contained ใช้ DNA + `--w-*` (ป้าย ก่อน/หลัง อ่านง่ายบนรูปใดก็ได้ใช้พื้นดำโปร่ง handle ใช้ accent แบรนด์)

```css
/* widget:before-after */
.cnc-ba { max-width: 800px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-ba__title { margin-bottom: var(--s5); text-align: center; color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-ba__stage {
  position: relative; overflow: hidden; touch-action: none; user-select: none; cursor: ew-resize;
  border: var(--w-card-border); border-radius: var(--w-radius);
  margin-left: auto; margin-right: auto;
}
.cnc-ba--landscape .cnc-ba__stage { aspect-ratio: 16 / 9; }
.cnc-ba--portrait .cnc-ba__stage  { aspect-ratio: 9 / 16; max-width: 420px; }
.cnc-ba__img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
.cnc-ba__label {
  position: absolute; top: var(--s3); z-index: 2;
  padding: 4px 10px; font-family: var(--font-body); font-size: 13px; font-weight: 700;
  color: #fff; background: color-mix(in srgb, #000 55%, transparent); border-radius: var(--w-radius);
}
.cnc-ba__label--before { left: var(--s3); }
.cnc-ba__label--after  { right: var(--s3); }
.cnc-ba__handle {
  position: absolute; top: 0; bottom: 0; width: 44px; transform: translateX(-50%);
  z-index: 3; border: 0; background: none; padding: 0; cursor: ew-resize;
  display: flex; align-items: center; justify-content: center;
}
.cnc-ba__handle::before {
  content: ""; position: absolute; top: 0; bottom: 0; left: 50%; width: 3px;
  transform: translateX(-50%); background: var(--w-accent);
}
.cnc-ba__grip {
  position: relative; width: 40px; height: 40px; border-radius: 999px;
  background: var(--w-accent); color: var(--w-bg);
  display: flex; align-items: center; justify-content: center; font-size: 18px; line-height: 1;
  box-shadow: 0 2px 10px rgba(0,0,0,.35);
}
.cnc-ba__handle:focus-visible { outline: 3px solid var(--w-accent); outline-offset: 2px; }
```

JS ต่อท้าย scripts.js (รองรับหลาย slider ในหน้าเดียว เมาส์ + นิ้ว + ลูกศรซ้ายขวา)

```js
/* widget:before-after */
(function () {
  document.querySelectorAll('[data-cnc-ba]').forEach(function (stage) {
    var before = stage.querySelector('.cnc-ba__img--before');
    var handle = stage.querySelector('[data-cnc-ba-handle]');
    if (!before || !handle) return;
    function set(p) {
      p = Math.max(0, Math.min(100, p));
      before.style.clipPath = 'inset(0 ' + (100 - p) + '% 0 0)';
      handle.style.left = p + '%';
      handle.setAttribute('aria-valuenow', Math.round(p));
    }
    function fromX(x) { var r = stage.getBoundingClientRect(); set((x - r.left) / r.width * 100); }
    var down = false;
    stage.addEventListener('pointerdown', function (e) { down = true; stage.setPointerCapture(e.pointerId); fromX(e.clientX); });
    stage.addEventListener('pointermove', function (e) { if (down) fromX(e.clientX); });
    stage.addEventListener('pointerup', function () { down = false; });
    handle.addEventListener('keydown', function (e) {
      var n = +handle.getAttribute('aria-valuenow');
      if (e.key === 'ArrowLeft')  { set(n - 4); e.preventDefault(); }
      if (e.key === 'ArrowRight') { set(n + 4); e.preventDefault(); }
    });
    set(50);
  });
})();
/* end widget:before-after */
```

- **ไม่มี CSP** JS อยู่ scripts.js (`'self'`) รูป local ข้าม Step 6
- รูป 2 รูปผ่าน web-images ก่อน (optimize + crop เป็น ratio เดียวกัน) widget แค่อ้างไฟล์
- รูป before ใส่ `clip-path:inset(0 50% 0 0)` inline ไว้ failsafe ถ้า JS ไม่รัน ยังเห็นครึ่ง/ครึ่ง เนื้อหาไม่หาย
- handle เป็น `<button role="slider">` ลูกศรซ้ายขวาเลื่อนได้ คลิกที่รูปตรงไหนก็เลื่อนไปจุดนั้น (accessible)
- ใส่ `reveal` ที่หัวข้อ + stage

### สูตร row `map` (Google Maps iframe keyless ไม่มี JS)

HTML wrapper ใช้ DNA ของเว็บ (border + radius) ส่วนแผนที่ข้างในเป็นของ Google restyle ไม่ได้ (ปกติ map ก็ควรหน้าตาแบบ Google)

```html
<section data-cnc-widget="map" class="cnc-map">
  <h2 class="cnc-map__title reveal">มาหาเราได้ที่นี่</h2>
  <div class="cnc-map__frame reveal">
    <iframe
      src="https://maps.google.com/maps?q=ADDRESS_ENCODED&z=15&output=embed"
      title="แผนที่ที่ตั้งร้าน"
      loading="lazy"
      referrerpolicy="no-referrer-when-downgrade"
      allowfullscreen></iframe>
  </div>
</section>
```

(`ADDRESS_ENCODED` = ที่อยู่ที่นักเรียนบอก url-encode แล้ว เช่น `ร้านกาแฟ ABC ทองหล่อ` → `%E0%B8%A3...` ถ้านักเรียน paste embed code มา ใช้ `src` ของเขาแทนทั้งเส้น)

CSS ต่อท้าย styles.css self-contained ใช้ DNA `--w-card-border` `--w-radius` map เป็น aspect-ratio responsive

```css
/* widget:map */
.cnc-map { max-width: 1000px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-map__title {
  margin-bottom: var(--s5); text-align: center;
  color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display);
}
.cnc-map__frame {
  position: relative; aspect-ratio: 16 / 9;
  border: var(--w-card-border); border-radius: var(--w-radius); overflow: hidden;
}
.cnc-map__frame iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
```

CSP ที่ต้องลงทะเบียน (Step 6)

```
frame-src:  https://www.google.com https://maps.google.com
```

(ถ้า deploy แล้วเจอ console block domain อื่นของ Google เพิ่มผ่าน best-practices Mode B ได้)

### สูตร row `media` (วิดีโอ/รีล iframe ล้วน ไม่มี JS)

รับลิงก์ 1 อัน detect ว่าเป็น source ไหน แปลงเป็น embed iframe URL แล้ว register frame-src เฉพาะ domain ของ source นั้น (ไม่ใส่ทั้ง 5)

**detect source + แปลง URL → embed (ทุก source เป็น iframe ล้วน CSP-clean)**

| source | ลิงก์ที่นักเรียนวาง | embed iframe src | aspect | frame-src ที่ register |
|--------|----------------------|------------------|--------|------------------------|
| YouTube | `youtube.com/watch?v=ID` `youtu.be/ID` `/shorts/ID` | `https://www.youtube-nocookie.com/embed/ID` | Shorts → 9/16 อื่น → 16/9 | `https://www.youtube-nocookie.com` |
| Vimeo | `vimeo.com/ID` | `https://player.vimeo.com/video/ID` | 16/9 | `https://player.vimeo.com` |
| Instagram | `instagram.com/p/CODE` `/reel/CODE` | `https://www.instagram.com/p/CODE/embed` (reel ใช้ `/reel/CODE/embed`) | 9/16 (เผื่อ chrome สูง) | `https://www.instagram.com` |
| Facebook | `facebook.com/.../videos/ID` `/reel/ID` `fb.watch/X` | `https://www.facebook.com/plugins/video.php?href=<URL เต็ม url-encoded>&show_text=false` | video 16/9 reel 9/16 | `https://www.facebook.com` |
| TikTok | `tiktok.com/@user/video/ID` | `https://www.tiktok.com/embed/v2/ID` | 9/16 | `https://www.tiktok.com` |

- ใช้ **youtube-nocookie.com** ไม่ใช่ youtube.com (ไม่ตั้ง cookie จนกว่าจะกดเล่น privacy ดีกว่า)
- ดึง ID/CODE จากลิงก์ด้วย pattern ของแต่ละ source (เช่น YouTube `v=` หรือหลัง `youtu.be/` หรือหลัง `/shorts/`)
- **register แค่ frame-src ของ source ที่ใช้จริง** อย่าใส่ทั้ง 5 domain

HTML (modifier `--16x9` หรือ `--9x16` ตาม aspect ของ source)

```html
<section data-cnc-widget="media" class="cnc-media">
  <h2 class="cnc-media__title reveal">ดูคลิปของเรา</h2>
  <div class="cnc-media__frame cnc-media__frame--16x9 reveal">
    <iframe
      src="EMBED_SRC"
      title="วิดีโอ"
      loading="lazy"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen></iframe>
  </div>
</section>
```

CSS ต่อท้าย styles.css self-contained ใช้ DNA `--w-card-border` `--w-radius`

```css
/* widget:media */
.cnc-media { max-width: 1000px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-media__title {
  margin-bottom: var(--s5); text-align: center;
  color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display);
}
.cnc-media__frame {
  position: relative; margin-left: auto; margin-right: auto;
  border: var(--w-card-border); border-radius: var(--w-radius); overflow: hidden;
}
.cnc-media__frame--16x9 { aspect-ratio: 16 / 9; max-width: 100%; }
.cnc-media__frame--9x16 { aspect-ratio: 9 / 16; max-width: 360px; }
.cnc-media__frame iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
```

CSP (Step 6) register **เฉพาะ frame-src ของ source ที่ใช้** เช่น YouTube → `frame-src: https://www.youtube-nocookie.com`

**verify จริงใน browser เสมอ** (บทเรียนจาก map) IG/TikTok บางทีใน preview tool หรือ headless จะ block แต่ browser จริงขึ้น ถ้า browser จริงไม่ขึ้นจริงๆ fallback เป็น embed code ทางการของ source นั้น (Share → Embed → paste blockquote + external script ของ source ซึ่งยัง CSP-clean แค่ register script-src เพิ่ม)

### สูตร row `countdown` (สร้างเอง มี JS เขียนลง scripts.js ไม่มี CSP)

widget แรกที่มี JS ของเราเอง **JS ห้าม inline ต้องเขียนต่อท้าย `scripts.js` (ไฟล์ภายนอกของเว็บ)** เพราะ scripts.js โหลดด้วย `<script src="scripts.js">` = `'self'` strict CSP ผ่าน ไม่ต้อง register domain ใหม่ ไม่ต้องเรียก best-practices

**ห้ามใส่ `<script>` ใหม่ในหน้า** (inline จะโดน CSP block + ต้อง register) append เข้า scripts.js เดิมเท่านั้น โค้ดเป็น IIFE scope แยกไม่ชนกับ JS เดิมของเว็บ

HTML (target เป็น ISO + `+07:00` pin เวลาไทย กันคนต่าง timezone นับเพี้ยน)

```html
<section data-cnc-widget="countdown" class="cnc-countdown">
  <h2 class="cnc-countdown__title reveal">โปรโมชั่นหมดใน</h2>
  <div class="cnc-countdown__timer reveal" data-cnc-countdown="2026-12-31T23:59:00+07:00">
    <div class="cnc-countdown__unit"><span class="cnc-countdown__num" data-cd="days">00</span><span class="cnc-countdown__label">วัน</span></div>
    <div class="cnc-countdown__unit"><span class="cnc-countdown__num" data-cd="hours">00</span><span class="cnc-countdown__label">ชั่วโมง</span></div>
    <div class="cnc-countdown__unit"><span class="cnc-countdown__num" data-cd="mins">00</span><span class="cnc-countdown__label">นาที</span></div>
    <div class="cnc-countdown__unit"><span class="cnc-countdown__num" data-cd="secs">00</span><span class="cnc-countdown__label">วินาที</span></div>
  </div>
</section>
```

CSS ต่อท้าย styles.css ตัวเลขใช้ `--w-accent` กล่องใช้ DNA + color-mix card

```css
/* widget:countdown */
.cnc-countdown { max-width: 800px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); text-align: center; }
.cnc-countdown__title { margin-bottom: var(--s5); color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-countdown__timer { display: flex; justify-content: center; gap: var(--s3); flex-wrap: wrap; }
.cnc-countdown__unit {
  background: color-mix(in srgb, var(--w-text) 6%, var(--w-bg));
  color: var(--w-text);
  border: var(--w-card-border); border-radius: var(--w-radius);
  padding: var(--s4); min-width: 84px;
  display: flex; flex-direction: column; gap: var(--s2);
}
.cnc-countdown__num { font-family: var(--font-display); font-size: var(--s7); line-height: 1; color: var(--w-accent); font-variant-numeric: tabular-nums; }
.cnc-countdown__label { font-size: 13px; color: var(--w-muted); letter-spacing: 1px; }
.cnc-countdown--ended .cnc-countdown__num { opacity: 0.4; }
```

JS **ต่อท้าย scripts.js** (IIFE ไม่ inline)

```js
/* widget:countdown */
(function () {
  function pad(n) { return String(n).padStart(2, '0'); }
  function tick(el) {
    var target = new Date(el.getAttribute('data-cnc-countdown')).getTime();
    var diff = target - Date.now();
    var set = function (k, v) { var s = el.querySelector('[data-cd="' + k + '"]'); if (s) s.textContent = pad(v); };
    if (isNaN(target) || diff <= 0) {
      set('days', 0); set('hours', 0); set('mins', 0); set('secs', 0);
      el.classList.add('cnc-countdown--ended');
      return false;
    }
    set('days', Math.floor(diff / 86400000));
    set('hours', Math.floor(diff % 86400000 / 3600000));
    set('mins', Math.floor(diff % 3600000 / 60000));
    set('secs', Math.floor(diff % 60000 / 1000));
    return true;
  }
  document.querySelectorAll('[data-cnc-countdown]').forEach(function (el) {
    tick(el);
    var iv = setInterval(function () { if (!tick(el)) clearInterval(iv); }, 1000);
  });
})();
```

- ถาม Step 3 แปลงวันเวลาที่นักเรียนบอก → ISO `YYYY-MM-DDTHH:MM:SS+07:00` ใส่ใน `data-cnc-countdown`
- หมดเวลาแล้ว → JS ใส่ class `cnc-countdown--ended` (เลขจาง) ไม่พังหน้า
- **ไม่มี CSP** JS อยู่ใน scripts.js = `'self'` ข้าม Step 6

### สูตร row `chart` (Chart.js CDN + renderer ใน scripts.js)

**1 row รองรับทุกชนิด** type เป็นแค่ field ใน config ของ Chart.js (`bar` `line` `pie` `doughnut`) เพิ่มชนิดใหม่ = ไม่ต้องเขียนโค้ดใหม่ ข้อมูล chart เก็บใน attribute `data-cnc-chart` (JSON) renderer ตัวเดียวใน scripts.js วาดทุก chart สีดึงจาก `--w-*` ตอน render (canvas ใช้ CSS var ตรงๆ ไม่ได้)

HTML (config อยู่ใน attribute = data ไม่ใช่ inline script ปลอดภัย)

```html
<section data-cnc-widget="chart" class="cnc-chart">
  <h2 class="cnc-chart__title reveal">ผลลัพธ์ลูกค้า</h2>
  <div class="cnc-chart__box reveal">
    <canvas data-cnc-chart='{"type":"bar","labels":["ม.ค.","ก.พ.","มี.ค."],"series":[{"label":"ยอดขาย","data":[12,19,8]}]}'
            role="img" aria-label="กราฟแท่งยอดขายรายเดือน ม.ค. 12 ก.พ. 19 มี.ค. 8"></canvas>
  </div>
</section>
```

- **`aria-label` ต้องสรุปข้อมูลจริง** (canvas screen reader อ่านไม่ได้) ใส่ตัวเลขลงไปด้วย
- Chart.js โหลดจาก CDN วาง `<script>` ก่อน scripts.js (defer เรียงลำดับ Chart โหลดก่อน renderer รัน) **ติด marker** วางก่อน `<script src="scripts.js" defer>`

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4" defer data-cnc-widget="chart"></script>
```

CSS ต่อท้าย styles.css กล่องสูงคงที่ (canvas responsive ต้องมี parent มีขนาด) ใช้ DNA

```css
/* widget:chart */
.cnc-chart { max-width: 800px; margin-left: auto; margin-right: auto; padding: var(--s7) var(--s4); }
.cnc-chart__title { margin-bottom: var(--s5); text-align: center; color: var(--w-text); font-family: var(--font-display); font-size: var(--size-display); }
.cnc-chart__box {
  position: relative; height: 360px;
  border: var(--w-card-border); border-radius: var(--w-radius);
  padding: var(--s4); background: color-mix(in srgb, var(--w-text) 4%, var(--w-bg));
}
```

JS **ต่อท้าย scripts.js** renderer ตัวเดียว อ่าน `--w-*` ตอน render สี bar/line = accent, pie/doughnut = palette tint จาก accent, axis/label = text/muted

```js
/* widget:chart */
(function () {
  function rv(el, n, f) { var v = getComputedStyle(el).getPropertyValue(n).trim(); return v || f; }
  function toRgb(h) { h = (h || '').replace('#', ''); if (h.length === 3) h = h.split('').map(function (c) { return c + c; }).join(''); var n = parseInt(h, 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
  function mix(a, b, t) { return 'rgb(' + a.map(function (x, i) { return Math.round(x + (b[i] - x) * t); }).join(',') + ')'; }
  function palette(acc, bg, n) { var a = toRgb(acc), g = toRgb(bg), o = []; for (var i = 0; i < n; i++) o.push(mix(a, g, n < 2 ? 0 : (i / n) * 0.62)); return o; }
  function render(cv) {
    if (typeof Chart === 'undefined') return;
    var cfg; try { cfg = JSON.parse(cv.getAttribute('data-cnc-chart')); } catch (e) { return; }
    var root = cv.closest('[data-cnc-widget]') || document.body;
    var accent = rv(root, '--w-accent', '#888'), text = rv(root, '--w-text', '#333'), muted = rv(root, '--w-muted', '#999'), bg = rv(root, '--w-bg', '#fff');
    var cat = cfg.type === 'pie' || cfg.type === 'doughnut';
    var grid = mix(toRgb(muted), toRgb(bg), 0.7);
    var datasets = (cfg.series || []).map(function (s) {
      return { label: s.label || '', data: s.data || [], tension: 0.3, fill: false,
        backgroundColor: cat ? palette(accent, bg, (cfg.labels || []).length) : accent,
        borderColor: cat ? bg : accent, borderWidth: cat ? 2 : 2, pointBackgroundColor: accent };
    });
    Chart.defaults.color = muted;
    new Chart(cv, { type: cfg.type || 'bar', data: { labels: cfg.labels || [], datasets: datasets },
      options: { responsive: true, maintainAspectRatio: false,
        plugins: { legend: { labels: { color: text } } },
        scales: cat ? {} : { x: { ticks: { color: muted }, grid: { color: grid } }, y: { beginAtZero: true, ticks: { color: muted }, grid: { color: grid } } } } });
  }
  document.querySelectorAll('canvas[data-cnc-chart]').forEach(render);
})();
```

- **CSP** ต้อง register `script-src: https://cdn.jsdelivr.net` (Chart.js CDN) เรียก best-practices Mode B (chart เป็น row เดียวที่ self-built แต่มี CSP เพราะใช้ CDN lib)
- ถาม Step 3 ชนิด chart + ข้อมูล (labels + ตัวเลข) ห้ามแต่งตัวเลขปลอม ใส่ลง `data-cnc-chart` JSON
- v1 รองรับ `bar` `line` `pie` `doughnut` (เพิ่ม radar/polarArea ทีหลังได้ renderer ไม่ต้องแก้)

---

## Step 6 ลงทะเบียนความปลอดภัย (เฉพาะ row ที่มี CSP)

ถ้า row มี CSP domain (ดูคอลัมน์แคตตาล็อก) **เรียก best-practices Mode B** ส่ง pair `(directive, domain)` ตามสูตรของ row นั้น

- row `social-proof` (และ self-built row อื่น) ไม่มี domain ภายนอก **ข้าม Step นี้** ไม่ต้องแตะ `_headers` เลย
- row `booking` ส่ง 4 directive ของ Calendly เข้า best-practices Mode B (idempotent เรียกซ้ำได้ domain ไม่ซ้ำ)
- row `map` ส่ง `frame-src: https://www.google.com https://maps.google.com` เข้า best-practices Mode B (iframe ล้วน ใช้แค่ frame-src)
- row `media` ส่ง `frame-src:` เฉพาะ domain ของ source ที่ใช้จริง (YouTube → `https://www.youtube-nocookie.com`, Vimeo → `https://player.vimeo.com`, IG → `https://www.instagram.com`, FB → `https://www.facebook.com`, TikTok → `https://www.tiktok.com`) อย่าใส่ทั้ง 5
- row `chart` ส่ง `script-src: https://cdn.jsdelivr.net` (Chart.js CDN) เข้า best-practices Mode B (canvas วาดด้วย JS ไม่ inline ไม่ต้อง unsafe-inline)

best-practices Mode B จะ merge เข้า CSP เดิมโดยไม่ rewrite ทั้งไฟล์ ถ้ายังไม่มี `_headers` มันจะสร้างใหม่พร้อม domain ให้เลย

**นี่คือเหตุผลที่นักเรียนไม่ต้องรัน /web-quality-audit ใหม่เพื่อให้ widget ทำงาน** widget ลงทะเบียนความปลอดภัยของตัวเองตอนติดตั้งเสร็จในตัว

### กฎทอง ห้ามลดเกรดความปลอดภัย (A+/A ต้องอยู่)

การเพิ่ม widget **ห้ามทำให้เว็บได้เกรดความปลอดภัยต่ำลง** (securityheaders.com ต้องยัง A+/A เหมือนเดิม) วิธีเดียวที่ทำได้คือ

- เพิ่ม **เฉพาะ domain https ที่ระบุชัด** เข้า CSP allowlist (merge) เท่านั้น การเพิ่ม domain ที่ระบุชื่อไม่ทำให้เกรดตก
- **ห้ามเด็ดขาด** ใส่ `'unsafe-inline'` `'unsafe-eval'` หรือ wildcard `*` เข้า script-src/style-src เพื่อให้ widget ทำงาน (นี่คือสิ่งเดียวที่ทำให้เกรดตก)
- **ห้ามลบหรือลดความเข้มของ header เดิม** (HSTS frame-ancestors Permissions-Policy ฯลฯ)
- widget ที่ build แล้ว (social-proof booking) ปลอดภัยหมด **กรณีนี้แทบไม่เกิด** เป็นแค่กันไว้สำหรับ widget ในอนาคต

### ถ้าเจอ widget ที่ต้องลดความปลอดภัยถึงจะทำงาน (future widget เท่านั้น)

**ตัดสินใจแทนนักเรียนทันที ห้ามถาม ห้ามอธิบายศัพท์เทคนิค** เลือกทางปลอดภัยเสมอ คือไม่ใส่ widget ตัวนั้น หรือหาแบบที่ปลอดภัยมาแทน

**ห้ามบอกให้นักเรียนไปรัน /web-quality-audit ใหม่** เพราะมันแก้ปัญหานี้ไม่ได้เลย widget ตัวนั้นต้องการค่าที่ไม่ปลอดภัยโดยธรรมชาติ รันตรวจซ้ำกี่ครั้งก็เจอเหมือนเดิม การชี้ไปทางนั้นแค่ทำให้นักเรียนเสียเวลา

นักเรียนเห็นแค่ข้อความภาษาคนแบบนี้ ไม่มีศัพท์เทคนิค ไม่มีการบ้าน

```
ขอโทษนะคะ/ครับ ตัวนี้ขอข้ามไปก่อน
ถ้าใส่ตอนนี้จะทำให้ความปลอดภัยของเว็บคุณอ่อนลง
ผมเลยขอไม่ใส่เพื่อให้เว็บคุณยังแข็งแรงเต็มที่เหมือนเดิม

[ถ้ามีตัวเลือกที่ทำงานคล้ายกันและปลอดภัย]
มีอีกแบบที่ทำได้คล้ายกันและปลอดภัย อยากให้ลองอันนั้นไหมคะ/ครับ
```

- เกรดทดสอบหลัง deploy (securityheaders.com อ่าน header ตอน serve จริง) widget ทุกตัวในแคตตาล็อกนี้คงเกรด A+ ไว้ booking ใช้ external script ของ Calendly อย่างเดียว social-proof ไม่แตะ header เลย

---

## Step 7 preview localhost

เปิด preview ให้นักเรียนเห็นของจริง (เหมือน web-finish) ใช้ PY variable cross-platform

```
หา PY ก่อน (ทำครั้งเดียว)
  macOS ใช้ python3 เสมอ ห้ามใช้ python เปล่า เพราะ Mac ส่วนใหญ่ไม่มี python ให้ตั้ง PY=python3
  Windows ลอง python --version ก่อน ถ้าเจอใช้ python ถ้าไม่เจอลอง py แล้วใช้ py
```

**ก่อน start ต้องเช็คก่อนว่า localhost เปิดอยู่แล้วหรือยัง** อย่ายิง `$PY -m http.server 8000` ดื้อๆ เพราะถ้ามี server รันค้างบนพอร์ตนั้นอยู่แล้ว (จากรอบก่อน หรือจากโปรเจกต์อื่น) ตัวใหม่จะ bind ไม่ติดแบบเงียบๆ นักเรียนเปิดลิงก์แล้วเจอเว็บผิดตัวหรือไม่เห็นอะไรเลย

ทำตามนี้

1. **เช็คพอร์ต 8000 ว่าง/ไม่ว่าง** ลองต่อดู ถ้าตอบกลับมาแสดงว่ามี server รันอยู่แล้ว
   - Windows `(Test-NetConnection localhost -Port 8000 -WarningAction SilentlyContinue).TcpTestSucceeded`
   - macOS/Linux `lsof -i :8000` (เจอผล = ไม่ว่าง)
2. **ถ้าพอร์ตว่าง** start server รากที่ project root แล้วใช้ 8000 (รันคำสั่งจาก project root ใช้ `--directory .` ห้ามใส่ path เต็มเป็น argument เพราะถ้า path มีเว้นวรรค เช่น `Github Project` จะโดนตัดคำ server ไม่ขึ้น)
   ```
   $PY -m http.server 8000 --directory .
   ```
3. **ถ้าพอร์ต 8000 ไม่ว่าง** อย่าฆ่าของเดิม (อาจเป็นโปรเจกต์อื่นของนักเรียน) ให้ไล่หาพอร์ตว่างถัดไป 8001 8002 8003 แล้ว start บนพอร์ตนั้นแทน
   ```
   $PY -m http.server <พอร์ตว่างที่เจอ> --directory .
   ```
4. **start แบบ background** (อย่าให้คำสั่ง block) แล้ว verify ด้วยการต่อ `http://localhost:<พอร์ต>/` ดูว่าได้ HTTP 200 **และเป็นเว็บของโปรเจกต์นี้จริง** (ลองดึง path ที่มีจริง เช่น `/index.html` ไม่ใช่แค่ root 200 เฉยๆ เพราะ server โปรเจกต์อื่นก็ตอบ 200 ได้) ก่อนค่อยบอกนักเรียน
5. **output ลิงก์จริงให้นักเรียนเสมอ** ใช้พอร์ตที่ start จริง (อาจไม่ใช่ 8000) ถ้าต้องเปลี่ยนพอร์ตบอกนักเรียนสั้นๆ ว่า "พอร์ต 8000 มีอะไรใช้อยู่เลยเปิดให้ที่ <พอร์ตใหม่> แทนนะคะ/ครับ"

บอกนักเรียนเปิดลิงก์ที่ได้ เลื่อนไปดู widget ที่เพิ่งเพิ่ม

**preview คือหลักฐานสุดท้ายว่าไม่พัง** ให้นักเรียนยืนยันด้วยตาว่า widget ขึ้นถูก animation/รูป/ปุ่มทำงาน ก่อน deploy

ℹ️ ถ้าเป็น `booking` เตือนว่า Calendly จะขึ้นเต็มตอน deploy จริง (บน localhost บางทีโหลดช้าหรือไม่ขึ้นเพราะ CSP ทำงานบน Cloudflare เท่านั้น) แต่กล่องและ section จะเห็นตำแหน่งแล้ว

---

## Step 8 รายงาน + next step

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ เพิ่ม [ชื่อ widget ภาษาคน] ให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ใส่ [ระบบจองเวลา / รีวิวลูกค้า] เข้าเว็บแล้ว
   วางไว้ [ตำแหน่งภาษาคน เช่น ก่อนส่วนติดต่อ]
   ปรับหน้าตาให้เข้ากับสีและฟอนต์เว็บคุณอัตโนมัติ
   [ถ้า booking] ตั้งระบบความปลอดภัยให้โหลด Calendly ได้แล้ว

👀 เปิดดูได้ที่ http://localhost:[พอร์ตที่ start จริง]
   เลื่อนลงไปดู [widget] ที่เพิ่งเพิ่มได้เลย

ℹ️ อยากย้ายตำแหน่ง หรือเพิ่มอันอื่นอีก บอกได้เลย

ต่อไป
1. /save-work    เซฟขึ้น GitHub
2. deploy        เอาขึ้นเว็บจริง
```

ปิดท้ายด้วยภาษาคน ห้ามโชว์ชื่อ Calendly/CSP/directive ในรายงาน (พูดว่า "ระบบจองเวลา" "ตั้งความปลอดภัยให้โหลดได้")

---

## Edge cases

### นักเรียนเพิ่ม widget เดิมซ้ำ
ตรวจ `data-cnc-widget="<id>"` ที่มีอยู่แล้วในหน้า ถ้าเจอถามว่า "มี [widget] อยู่แล้วนะคะ/ครับ อยากเพิ่มอีกอัน หรือแก้อันเดิม" (แก้อันเดิม = งานของ edit-plan/web-update บอกต่อ)

### ไม่มี CLAUDE.md web-design block และ styles.css ก็ไม่มี token (เว็บเก่า/นอก codebase)
ไล่ตามลำดับ Step 2 คือ CLAUDE.md (2.1) → CSS alias (2.3) → neutral default สุดท้าย ติดตั้ง widget ได้ปกติ เตือนว่า "สีอาจไม่ตรงแบรนด์เป๊ะ ปรับทีหลังได้"

### นักเรียนยังไม่มีลิงก์ Calendly / ยังไม่มีรีวิวจริง
หยุดรอข้อมูลจริง **ห้ามแต่งข้อมูลปลอม** (ลิงก์มั่ว รีวิวปลอม) เสนอเก็บ slot ไว้ก่อน

### เว็บหลายหน้า ไม่รู้จะวางหน้าไหน
ถามครั้งเดียว default หน้าแรก ถ้าเป็น widget ที่ควรอยู่ทุกหน้า (อนาคต เช่น chat) ค่อยจัดการตอน build row นั้น

### นักเรียนใช้ host ที่ไม่ใช่ Cloudflare
`_headers` ทำงานเฉพาะ Cloudflare/Netlify แจ้งเหมือน best-practices ถ้า row ต้องใช้ CSP

---

## สิ่งที่ต้องระวัง

- **ติด `data-cnc-widget` ให้ครบทุก element ที่ inject** ขาดแม้แต่ script เดียว audit ทีหลังอาจ optimize จนพัง นี่คือกฎที่สำคัญที่สุดของ skill นี้
- **ห้ามแก้ของเดิม** แตะแค่ของที่ตัวเองเพิ่ม ห้ามแก้ headline copy สี layout เดิม (นั่นคือ edit-plan)
- **strict CSP ต้องไม่พัง** ห้าม inline `<style>`/`<script>` CSS ไปต่อท้าย styles.css เสมอ JS ภายนอกเสมอ
- **3rd party = เรียก best-practices Mode B เสมอ** self-built = ไม่แตะ `_headers` เลย ดูคอลัมน์ CSP ก่อนทุกครั้ง
- **สีมาจาก CLAUDE.md ก่อน** อ่าน `Color 60/30/10` จาก `<!-- web-design:v1 -->` เป็นหลัก CSS เป็นตัวเสริม/fallback เพราะชื่อ token ใน CSS ไม่มาตรฐาน (บางเว็บ `--accent` บางเว็บ `--color-accent`)
- **widget CSS ใช้ `var(--w-*)` เท่านั้น** ห้ามใช้ `var(--color-*)` ตรงๆ เพราะบางเว็บไม่มีชื่อนั้น `--w-*` มาจาก normalization block ที่ bake สีไว้แล้ว
- **card ใช้ `color-mix` จากคู่ bg/text** ห้ามใช้ surface เป็นพื้น card เพราะ contrast ไม่การันตีทุก palette (ธีมสว่างจะอ่านไม่ออก)
- **ส่งค่า hex จริง ไม่ใช่ชื่อตัวแปร เข้า URL param** Calendly อ่าน `var(--w-accent)` ไม่ได้ ต้องส่ง accentHex เช่น `e63946`
- **ห้ามแต่งข้อมูลปลอม** รีวิวปลอม ลิงก์มั่ว ห้ามเด็ดขาด รอข้อมูลจริงจากนักเรียน
- **ห้ามโชว์ technical term** ไม่พูด Calendly CSP directive marker iframe ใช้ภาษาคน
- **ยังไม่มี widget หมวดเงิน** ถ้านักเรียนถามเรื่องรับเงิน บอกให้รับผ่าน LINE/ช่องทางส่วนตัวไปก่อน อย่า improvise ระบบจ่ายเงิน
- **ของที่ยังเป็น 🔜 อย่า improvise** ถ้ายังไม่มีสูตรในแคตตาล็อก บอกนักเรียนว่ากำลังจะเปิด อย่าเดาโค้ดเอง
