---
name: web-quality-audit
description: ปุ่มเดียวเรียกตรวจคุณภาพเว็บนักเรียนแบบรอบด้านก่อน ship ให้ลูกค้าจริง ทำหน้าที่ orchestrator เรียก skill เครื่องยนต์ 4 ตัวทำงานต่อเนื่อง seo → performance → accessibility → best-practices แล้วรวมรายงานเป็นกระดาษเดียว 3 ส่วน (auto-fixed / ขอข้อมูลจากคุณ / FYI). ใช้ตอนนักเรียนพร้อม ship คือหลัง deploy ครั้งแรก (Day 2) เพราะบางอย่างต้องใช้ deploy URL จริง (og:image, canonical, sitemap, robots.txt). Triggers include "ตรวจคุณภาพเว็บ", "ตรวจสุขภาพเว็บ", "ตรวจเว็บก่อน ship", "audit เว็บ", "เช็คเว็บก่อน deploy", "เช็คเว็บก่อน publish", "Pre-flight check", "ตรวจครบทุกอย่าง", "ตรวจเว็บรอบสุดท้าย", "audit my site", "review web quality", "check page quality", "optimize my website", "web-quality-audit", or any similar request before sharing the site widely. Thin shell ~150 lines no duplicate logic all checks live in the 4 engine skills. Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# web-quality-audit ตรวจคุณภาพเว็บก่อน ship

ทำหน้าที่ปุ่มเดียว นักเรียนเรียกครั้งเดียวได้ตรวจครบ 4 ด้าน
- 🔍 **SEO** ทำให้ Google หาเจอ + แชร์ LINE/FB สวย
- ⚡ **Performance** ทำให้เว็บโหลดเร็วบนมือถือ
- ♿ **Accessibility** ทำให้ทุกคนเข้าใช้ได้ (คนตาบอด คน keyboard)
- 🔒 **Best-practices** ตั้งระบบความปลอดภัย

skill นี้ไม่ทำ check เอง เรียก 4 engine skill ทำงานตามลำดับแล้วรวมรายงาน

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก

- **Thin shell** ไม่มี check logic อยู่ใน skill นี้เลย ทุก check อยู่ใน engine skill
- **Sequential** เรียก engine ทีละตัว ไม่ parallel เพราะลำดับสำคัญ (best-practices ต้องเป็นตัวสุดท้าย)
- **Post-deploy ideal** ถ้ายังไม่ deploy เตือนนักเรียนก่อน เพราะบางอย่างต้องใช้ live URL
- **ภาษาไทยเรียบง่าย** สรุปจาก engine แต่ละตัวเป็นภาษาคน
- **ห้ามแก้ไฟล์เอง** engine แต่ละตัวเป็นคนแก้ skill นี้แค่ orchestrate + aggregate
- **ห้ามถามนักเรียนคำถาม technical** เช่น "strict CSP หรือ unsafe-inline" "extract inline หรือไม่" นักเรียนไม่รู้คำตอบที่ถูก ตัดสินใจแทนเสมอ เลือกทางที่ "ปลอดภัย/ดีที่สุดสำหรับ production" ทุกครั้ง ถามเฉพาะข้อมูลที่นักเรียนเท่านั้นรู้ (ชื่อร้าน คำอธิบายเว็บ alt text ฯลฯ)

---

## Step 1 Prerequisite check (internal)

ตรวจภายใน 3 อย่าง (ไม่ต้องแสดงรายละเอียดให้นักเรียน)

| ตรวจอะไร | ถ้าผ่าน | ถ้าไม่ผ่าน (ภาษาคน) |
|---------|---------|---------------------|
| `index.html` ที่ root มีอยู่ | เงียบ | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน (ถ้าได้จาก Claude Design) หรือ /web-generate (ถ้าให้ Claude Code สร้าง)" จบ skill |
| ไม่มี `[placeholder]` ค้าง | เงียบ | "ยังมีค่าตัวอย่างค้างอยู่ ทำ /web-finish ก่อนเพื่อใส่ข้อมูลจริงนะคะ/ครับ" จบ skill |
| ไม่มี inline `<style>`/`<script>` ใหญ่ใน HTML | เงียบ → ไป Step 2 | แสดง dialog ด้านล่าง (ภาษาคน) |

### ถ้าเจอ inline style/script ก้อนใหญ่

**ห้ามถามนักเรียน** เพราะนักเรียนไม่รู้คำตอบที่ถูกต้อง default ไปทางที่ปลอดภัยที่สุดเสมอ คือเก็บงานให้เรียบร้อยก่อนแล้วตรวจต่อ

แสดงแค่นี้แล้วทำต่อเลย ไม่ต้องรอคำตอบ

```
🔎 เช็คความพร้อมก่อนเริ่ม

✅ ข้อมูลจริงใส่ครบแล้ว
✅ เว็บออนไลน์อยู่: <URL>
✨ ขอเก็บงานให้เรียบร้อยอีก 1-2 นาทีก่อนเริ่มตรวจนะคะ/ครับ
```

จากนั้นเรียก `/web-finish` ให้อัตโนมัติ รอจน finish เก็บงานเสร็จ แล้วเข้า Step 2 ต่อ

**หลักการ** ถ้าเลือกได้ระหว่าง "ปลอดภัยสุด" กับ "เร็วสุด" ตัดสินใจแทนนักเรียนเสมอ → เลือกปลอดภัยสุด เพราะ
- นักเรียนไม่รู้ว่า "ระบบความปลอดภัยระดับมาตรฐาน" vs "ระดับสูงสุด" ต่างกันยังไง
- 1-2 นาทีไม่ใช่ภาระหนัก
- skill เราคือผู้เชี่ยวชาญตัดสินใจให้ ไม่ใช่ระบบเลือกตัวเลือก

---

## Step 2 ตรวจว่ารู้ deploy URL ไหม

หา deploy URL ได้จากหลายแหล่ง (ลำดับความแม่นยำ)
1. CLAUDE.md ส่วน scope/writing/deploy block ถ้ามี
2. `git remote get-url origin` ถ้าเป็น Cloudflare Pages auto repo (`<repo>.pages.dev`)
3. ไฟล์ `CNAME` หรือ config file ที่ project root
4. ถ้าไม่เจอ → ถามนักเรียน

### ถ้าไม่รู้ deploy URL → 2 ทางเลือก

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤔 ยังไม่ได้ deploy เว็บใช่ไหมคะ/ครับ?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

skill นี้ทำงานได้ดีที่สุดหลัง deploy ครั้งแรกแล้ว
เพราะบางอย่างต้องใช้ลิงก์เว็บจริง (preview แชร์ลิงก์ Google เก็บข้อมูล)

A. แนะนำ deploy ก่อนค่ะ/ครับ
   ทำตามขั้นตอน deploy ที่เคยสอน แล้วกลับมาเรียก /web-quality-audit อีกที
   ผมจะตรวจครบทุกด้านพร้อมใส่ลิงก์จริงให้

B. รันตอนนี้ก็ได้
   ผมจะตรวจส่วนที่ทำได้โดยไม่ต้องใช้ลิงก์ (ความปลอดภัย accessibility ขนาดรูป ฯลฯ)
   ส่วนที่ต้องใช้ลิงก์ (preview แชร์ sitemap) จะใส่ slot ไว้ ตอน deploy แล้วเรียกใหม่
```

ถ้าเลือก A → จบ skill
ถ้าเลือก B → ดำเนินต่อ (engine แต่ละตัวจะ handle URL ที่ขาดเอง เช่น seo จะ skip og:image)

---

## Step 3 ประกาศแล้วเรียก engine ตามลำดับ

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏥 เริ่มตรวจคุณภาพเว็บ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

จะตรวจ 4 ด้านเรียงตามลำดับนะคะ/ครับ
1. 🔍 ทำให้ Google หาเจอ + แชร์ LINE Facebook ให้สวย
2. ⚡ ทำให้เว็บโหลดเร็วบนมือถือ
3. ♿ ทำให้ทุกคนใช้ได้ (คนตาบอด คนใช้ keyboard)
4. 🔒 ตั้งระบบความปลอดภัย

ระหว่างทางจะถามบางจุดที่ต้องใช้ความตั้งใจของคุณ
(เช่น ชื่อร้าน คำอธิบายเว็บ คำบรรยายรูป) ตอบทีละข้อได้เลย
```

### Sequential invocation

เรียก engine ทีละตัวผ่าน Skill tool

```
1. invoke seo skill           → รอจบ collect รายงาน
2. invoke performance skill   → รอจบ collect รายงาน
3. invoke accessibility skill → รอจบ collect รายงาน
4. invoke best-practices skill (Mode A) → รอจบ collect รายงาน
```

**สำคัญ best-practices ต้องเป็นตัวสุดท้าย** เพราะ strict CSP ของ best-practices ทำงานได้ก็ต่อเมื่อ inline ถูกแยกแล้ว และ engine ก่อนหน้าไม่ inject inline ใหม่ (ปกติไม่ทำอยู่แล้ว แต่ defensive)

แต่ละ engine จะถามคำถามของตัวเอง (seo ถาม title/desc/og:image; performance ถามลดรูป; accessibility ถาม alt) นักเรียนตอบเป็น conversation flow ปกติ orchestrator แค่รอจบแล้วเก็บข้อมูลที่ engine fix/ask ไว้

### ถ้า engine บาง engine fail

- ไม่หยุด orchestrator
- จดไว้ใน report ส่วน "ตรวจไม่ผ่าน" + เหตุผล + suggest fix
- เรียก engine ถัดไปต่อ

---

## Step 4 รวมรายงานเป็นกระดาษเดียว (3 buckets)

หลัง engine 4 ตัวจบ รวมรายงานเป็นกระดาษเดียว เรียงข้อมูลตามลำดับความสำคัญที่ student ต้องลงมือ

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏥 ตรวจคุณภาพเว็บเสร็จเรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ แก้ให้อัตโนมัติแล้ว [TOTAL] จุด

  🔍 SEO        [N1]
  ⚡ Performance [N2]
  ♿ Accessibility [N3]
  🔒 Security    [N4]

  [แสดง summary 1 บรรทัดต่อ engine list ของ auto-fix ที่ทำ
   เช่น "lang=th + robots.txt + sitemap.xml + share preview พื้นฐาน"]

✏️ ขอข้อมูลจากคุณ [M] จุด
  [engine แต่ละตัวที่มี pending ask แสดงรายการ
   เรียง SEO → Performance → Accessibility]
  1. [ask 1]
  2. [ask 2]
  ...

⚠️ พบจุดที่ควรลดขนาด [K] รูป
  [จาก performance image audit]

ℹ️ ทดสอบเพิ่มได้ (ไม่บังคับ ทำตอนว่าง)
  - เช็คความเร็วเว็บ: pagespeed.web.dev
  - เช็คตอน Google แสดงผล: search.google.com/test/rich-results
  - เช็คระบบความปลอดภัย: securityheaders.com (หลัง deploy)
  - เช็ค keyboard กดใช้ได้: กด Tab ทีละครั้ง ดูว่ามีกรอบแสดงว่าตอนนี้เลือกอะไรอยู่
  [ถ้ารูปแชร์ใน LINE/Facebook ยังไม่ได้ใส่ → แจ้ง "รูปสำหรับแชร์ลิงก์รอใส่หลัง deploy เสร็จ"]
  [ถ้า URL deploy ยังเป็นค่าตัวอย่าง → แจ้ง "ค่าบางอย่างที่ Google ใช้รอ URL เว็บจริง deploy เสร็จเรียก /ตรวจ seo อีกครั้งนะคะ/ครับ"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 พร้อม ship เว็บแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ตอบคำถามด้านบนเสร็จ → /save-work → deploy
```

### ลำดับ engine ใน auto-fixed summary

แสดงตามลำดับนี้ (worst impact ก่อน) 🔍 SEO → ⚡ Performance → ♿ Accessibility → 🔒 Security

### ลำดับ pending ask

เรียงตามที่นักเรียนต้องตอบ (high-effort ก่อน เพื่อให้ทำเสร็จก่อน abandon)
1. ภาพ alt text (มีหลายข้อ เร็ว)
2. title + description (พิมพ์อย่างละไม่กี่คำ)
3. og:image (ถ้ายังไม่ skip)
4. image compression yes/no
5. LocalBusiness JSON-LD (optional)

---

## Step 5 ปิดท้าย

ถ้านักเรียนตอบ ask ทุกข้อแล้ว
```
✨ เสร็จสมบูรณ์
- auto-fix [N] จุด
- ตอบ ask [M] จุด
- skip [K] จุด (ใส่ทีหลังได้)

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ตอน deploy แล้ว ทดสอบที่ลิงก์ใน FYI ด้านบน
```

ถ้านักเรียน skip ask บางข้อ
```
✨ ตรวจเสร็จ
- auto-fix [N] จุด
- รอข้อมูล [M] จุด (เก็บ slot ไว้แล้ว ใส่ทีหลังเรียก /web-quality-audit อีกครั้งได้)
```

---

## Edge cases

### deploy URL เปลี่ยน (เคย pages.dev ตอนนี้เป็น custom domain)

ตรวจ CLAUDE.md ก่อนแล้วถ้าไม่เจอใหม่ ถามนักเรียน "ใช้ URL ใหม่หรือเดิม"

### นักเรียนเคยรัน orchestrator ครั้งก่อน

ปกติ engine แต่ละตัว idempotent (ทำซ้ำได้ ไม่ duplicate) เรียกได้เลย จะ skip ส่วนที่ทำไปแล้ว

### Engine ตัวใดตัวหนึ่ง fail mid-way

จดใน report บอกนักเรียน "ตรวจ [engine] ไม่สำเร็จเพราะ [reason]" แต่ engine อื่นยังรันต่อ ตอนจบเสนอ "อยากให้รัน [engine] ใหม่ลำพังไหม"

### นักเรียนกด Esc / cancel ระหว่าง engine กำลังทำงาน

orchestrator catch interrupt แจ้ง "หยุดที่ [engine X] แล้ว เรียกใหม่ได้ตลอด" จบ skill

### ไม่มี pages/ folder (single-page site)

engine แต่ละตัว handle อยู่แล้ว ไม่กระทบ orchestrator

### มี widget skill เคยเพิ่ม domain ใน _headers แล้ว

best-practices Mode A จะตรวจเจอ `_headers` ที่มีอยู่ ถามว่า merge หรือเริ่มใหม่ (ปกติ merge)

---

## สิ่งที่ต้องระวัง

- **ห้ามมี check logic ใน skill นี้** ทุก check อยู่ใน engine เด็ดขาด orchestrator แค่เรียก + รวม
- **ลำดับเรียง engine สำคัญ** seo → performance → accessibility → best-practices best-practices ต้องเป็นตัวสุดท้ายเพราะ strict CSP
- **best-practices Mode A เท่านั้น** (สร้าง _headers) ห้ามเรียก Mode B จาก orchestrator (Mode B ใช้สำหรับ widget skill)
- **ห้ามรัน engine แบบ parallel** sequential เท่านั้น เพราะแต่ละ engine แก้ HTML และ parallel จะชนกัน
- **ห้ามแก้ HTML เอง** orchestrator เป็นตัวประสาน ไม่ใช่ตัวแก้
- **ถ้านักเรียนยังไม่ deploy** ให้เลือก A (deploy ก่อน) เป็น default แนะนำ B แค่ถ้านักเรียนยืนยัน
- **แสดง deploy URL ที่ใช้** ใน report ตอน FYI เพื่อให้ student เห็นว่า skill รู้ URL อะไรอยู่
- **อย่าใช้ technical term กับนักเรียน** ไม่ใช้ orchestrator engine invoke sequential parallel ใช้ภาษาคน "ตรวจ 4 ด้าน" "ตรวจไปทีละด้าน"
- **report ของ orchestrator ต้องสั้น** สรุปจาก engine ไม่ดูดทุกบรรทัดที่ engine print ออกมา student ไม่ได้ต้องการ debug log

### 🚫 คำต้องห้ามใน output (zero tolerance)

| หมวด | ห้ามใช้ | ใช้แทน |
|------|---------|--------|
| HTML elements | `<style>` `<script>` `<head>` `<body>` | "ส่วนตกแต่ง" "ส่วนเอฟเฟกต์" "ส่วนหัวเว็บ" |
| File names | `styles.css` `scripts.js` `index.html` | "ไฟล์เว็บ" "ไฟล์ตกแต่ง" "ไฟล์เอฟเฟกต์" (หรือไม่ต้องพูดถึงไฟล์เลย) |
| Line numbers | "บรรทัด 10" "line 700" | (ไม่จำเป็นต้องบอกตำแหน่งกับนักเรียน) |
| Skill internals | `best-practices skill` `web-finish skill` `engine` | "ระบบ" "ตัวตรวจ" หรือไม่ต้องพูดถึงเลย |
| Security jargon | `strict CSP` `unsafe-inline` `XSS` `CSP header` | "ระบบความปลอดภัย" "ระดับการป้องกัน" |
| Generic English | `audit` `extract` `inline` `placeholder` | "ตรวจ" "แยก" "ค่าตัวอย่าง" |
| File extension | `.css` `.js` `.html` `.md` `.json` | "ไฟล์เว็บ" (หรือไม่พูดถึง) |
| Code-y braces | `[placeholder]` | "ค่าตัวอย่าง" "ที่ใส่ตัวอย่างไว้" |

**กฎพิมพ์ลัด** ถ้าประโยคต้องใช้คำต้องห้ามเพื่ออธิบาย ให้ลบประโยคทั้งประโยคออก ไม่จำเป็นต้องอธิบาย "ทำไม" ถ้านักเรียนถามค่อยอธิบาย
