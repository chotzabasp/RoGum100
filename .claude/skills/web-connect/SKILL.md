---
name: web-connect
description: Use when the student has a contact or signup form (or contact buttons) on their site that look real but submit nowhere and they want to make them actually work by sending submissions into a Google Sheet. The native on-brand form that Claude Design produced has no action and often a fake JS success message so the data is lost. web-connect wires that existing form to the student own Google Form endpoint so every submission lands in their Google Sheet automatically and also fixes dead contact buttons (href="#") to point at the real LINE tel mailto or link. Triggers include "ต่อฟอร์ม", "เชื่อมฟอร์ม", "ฟอร์มส่งไปไหน", "ฟอร์มกรอกแล้วไม่ไปไหน", "ฟอร์มไม่ทำงาน", "ทำให้ฟอร์มใช้ได้", "เก็บข้อมูลลูกค้า", "เชื่อม google sheet", "เชื่อม google form", "ต่อ google sheet", "ปุ่มกดไม่ไปไหน", "ปุ่มไม่ลิงก์", "ต่อปุ่ม line", "connect form", "wire form", "form to google sheet", "form-connect", "web-connect", or any similar request to make a form or button actually do something. Reads the native form that already exists (does NOT build a new form that is Claude Design + web-design job) skips anything marked data-cnc-widget (those widgets like Calendly own their own submission) asks the student only for one thing a Google Form pre-filled link harvests the form id and field ids from that single URL maps the fields confirms with the student then wires the submit to fire into Google via fetch no-cors so it works with strict CSP and on localhost. Registers the needed domain by calling best-practices Mode B and previews on localhost. Built for absolute beginners with zero coding knowledge works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-connect ต่อฟอร์มและปุ่มให้ทำงานจริง

นักเรียนมีฟอร์มสวยๆ ในเว็บที่ Claude Design ทำให้ แต่กรอกแล้วข้อมูลหายไปเฉยๆ ไม่ไปไหน web-connect ต่อฟอร์มนั้นเข้ากับ Google Sheet ของนักเรียนเอง ทุกครั้งที่ลูกค้ากรอกข้อมูลจะไปโผล่ใน Sheet อัตโนมัติ และซ่อมปุ่มติดต่อที่กดแล้วไม่ไปไหนให้ลิงก์ไปช่องทางจริง

skill นี้ **ไม่สร้างฟอร์มใหม่** (ฟอร์มมาจาก Claude Design ตอน web-design แล้ว) แต่ **ต่อปลายทาง** ให้ฟอร์มที่มีอยู่

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## ความจริงสำคัญ static site ส่งข้อมูลเข้า Google Sheet ตรงๆ ไม่ได้

เว็บ HTML ล้วนบน Cloudflare Pages ไม่มี backend จึง **เขียนลง Google Sheet ตรงๆ ไม่ได้** ลิงก์ Google Sheet เป็นแค่เอกสาร ไม่มีปลายทางรับ form submission

ตัวที่รับ submission ได้คือ **Google Form** เมื่อตั้ง Google Form ให้เก็บคำตอบลง Sheet ทุก submission จะไปโผล่ใน Sheet เอง นักเรียนอ่าน lead ใน Sheet แต่ของที่เราต่อฟอร์มเข้าไปคือ **endpoint ของ Google Form**

เราขอจากนักเรียนแค่ **สิ่งเดียว** คือ **pre-filled link** ของ Google Form ลิงก์เดียวนี้มีทั้ง form id และ field id (`entry.XXX`) ครบ ไม่ต้องให้นักเรียนเปิดดู HTML หรือถาม Sheet แยก

---

## กฎหลัก (lock ไว้)

1. **ไม่สร้างฟอร์มใหม่ ต่อของที่มีอยู่เท่านั้น** อ่าน `<form>` ที่ Claude Design ทำไว้แล้วต่อปลายทาง ห้าม redesign ฟอร์ม
2. **ข้าม widget** element ที่มี `data-cnc-widget` เป็นของ web-add (เช่น Calendly จัดการ submission ของตัวเองอยู่แล้ว) web-connect **ห้ามแตะ** แตะเฉพาะ native form + ปุ่มธรรมดา
3. **ขอข้อมูลให้น้อยที่สุด** ฟอร์ม = ขอ pre-filled link อันเดียว ปุ่ม = ขอช่องทางจริง (เบอร์ ไอดีไลน์ ลิงก์)
4. **ห้ามแต่งค่าปลอม** ไม่มีลิงก์จริง ไม่เดา เก็บไว้ก่อนแล้วบอกนักเรียนมาเติมทีหลัง
5. **CSP-clean** ส่งข้อมูลด้วย `fetch(..., {mode:'no-cors'})` (ไม่มี inline script ไม่มี unsafe-inline) ลงทะเบียน domain ผ่าน best-practices Mode B
6. **ภาษาไทยเรียบง่าย** ห้ามโชว์ชื่อ tag attribute ชื่อ entry id ในรายงานนักเรียน

---

## หัวใจ marker `data-cnc-form`

ทุกฟอร์มที่ต่อแล้ว **ติด attribute `data-cnc-form="connected"`** บน `<form>` และคอมเมนต์ `/* cnc-form: <id> */` ครอบ handler ใน scripts.js

marker นี้ทำให้

- รัน web-connect ซ้ำ **รู้ว่าฟอร์มนี้ต่อแล้ว** ไม่ต่อซ้ำ (idempotent)
- audit ทีหลัง (performance accessibility) เห็นแล้ว **ไม่แตะ handler** ของฟอร์ม
- เหมือนหลักการ `data-cnc-widget` ของ web-add

---

## โหมดการทำงาน

```
นักเรียนพูด "ต่อฟอร์ม" หรือ "ฟอร์มกรอกแล้วไม่ไปไหน"
   → Step 0 ตรวจความพร้อม
   → Step 1 สแกน + แยกประเภท (native form / ปุ่มตาย / widget ที่ต้องข้าม)
   → Step 2 ปุ่มตาย ต่อ href ช่องทางจริง (ง่ายก่อน)
   → Step 3 native form ต่อเข้า Google Form endpoint
   → Step 4 ลงทะเบียน CSP ผ่าน best-practices Mode B
   → Step 5 preview localhost
   → Step 6 รายงาน + next step
```

---

## Step 0 ตรวจความพร้อม

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `scripts.js` (หรือไฟล์ JS ของเว็บ) | ฟอร์มยังต่อได้แบบ native POST + iframe (ดู Step 3 ทางสำรอง) |

ถ้ามี `pages/` หลายหน้า สแกนทุกหน้า

---

## Step 1 สแกน + แยกประเภท

อ่าน `index.html` + ทุก `pages/*.html` แล้วแยกเป็น 3 กอง

| กอง | หาอะไร | ทำยังไง |
|-----|--------|---------|
| **native form** | `<form>` ที่ **ไม่ได้อยู่ใต้ element ที่มี `data-cnc-widget`** และยัง **ไม่มี `data-cnc-form`** | ต่อใน Step 3 |
| **ปุ่มตาย** | `<a>` หรือ `<button>` ที่ `href="#"` `href=""` หรือ `href="#contact"` ที่ไม่มีปลายทางจริง และ **ไม่ได้อยู่ใต้ `data-cnc-widget`** | ต่อใน Step 2 |
| **ข้าม** | อะไรก็ตามที่อยู่ใต้ `data-cnc-widget` (Calendly pricing CTA gallery ฯลฯ) หรือฟอร์มที่มี `data-cnc-form` อยู่แล้ว | ไม่แตะ |

**กฎการข้าม widget เด็ดขาด** ถ้า `<form>` หรือปุ่มอยู่ภายใน `<section data-cnc-widget="...">` ให้ข้าม element นั้นทั้งหมด เพราะ web-add เป็นเจ้าของ (เช่น Calendly ส่ง booking ของมันเอง pricing CTA ชี้ไป anchor ในหน้าอยู่แล้ว)

โชว์สรุปสั้นๆ ให้นักเรียนว่าเจออะไรบ้าง

```
เจอในเว็บคุณ
- ฟอร์มกรอกข้อมูล 1 อัน (ตอนนี้กรอกแล้วข้อมูลหายไปเฉยๆ ยังไม่ได้ส่งไปไหน)
- ปุ่มที่ยังไม่ได้ต่อปลายทาง 2 อัน

อยากต่อให้ทำงานจริงเลยไหมคะ/ครับ
```

ถ้าไม่เจออะไรเลยที่ต้องต่อ บอกว่า "ฟอร์มและปุ่มต่อปลายทางครบแล้วนะคะ/ครับ" จบ skill

---

## Step 2 ต่อปุ่มตาย (ง่ายก่อน)

สำหรับแต่ละปุ่มตาย ดู context (ข้อความบนปุ่ม section รอบๆ) แล้วถามช่องทางจริง อ่าน CLAUDE.md `web-scope:v1` block (`ปุ่มชวนกด + รับข้อมูล`) มาเดาช่องทางก่อนแล้วให้นักเรียนยืนยัน (generate-then-confirm)

| นักเรียนเลือก | ใส่ href แบบนี้ |
|---------------|----------------|
| LINE | `https://line.me/ti/p/~ไอดีไลน์` หรือ `https://lin.ee/XXXX` (ลิงก์ทางการ) |
| โทร | `tel:+66XXXXXXXXX` (แปลง 08X เป็น +668X) |
| Email | `mailto:ที่อยู่อีเมล` |
| Facebook / IG | ลิงก์เพจ/โปรไฟล์เต็ม |
| Google Form (ลิงก์ออก) | ลิงก์ viewform ของฟอร์ม |

- ปุ่มที่ออกนอกเว็บ (line ig fb form) ใส่ `target="_blank" rel="noopener"`
- ปุ่ม `tel:` `mailto:` ไม่ต้อง target
- **ห้ามเดาเบอร์/ไอดี** ถ้านักเรียนยังไม่ให้ เก็บปุ่มไว้ก่อนบอกให้มาเติม

---

## Step 3 ต่อ native form เข้า Google Form (หัวใจของ skill)

**skill นี้ทำงานกับเว็บนักเรียนทุกคน ไม่ใช่เว็บตัวอย่าง** ตัวอย่างในขั้นนี้ (ชื่อ LINE เคยฝึกไหม) มาจากเว็บสาธิตหนึ่งอันเท่านั้น **ห้าม hardcode** ชื่อช่อง ข้อความ ตัวเลือก หรือ entry id ของเว็บใดเว็บหนึ่ง ทุกค่าต้อง **อ่านจากฟอร์มจริงของเว็บนี้** (input name + label) บวกกับ **pre-filled link จริง** ที่นักเรียนวางมา ฟอร์มมีกี่ช่อง ชื่อช่องอะไร ตัวเลือกอะไร อ่านสดทุกครั้ง

### 3.1 อธิบาย + พานักเรียนเตรียม Google Form

อ่านฟิลด์ในฟอร์มก่อน (label + name ของ input แต่ละช่อง) แล้วบอกนักเรียนให้สร้าง Google Form ที่มีคำถาม **ตรงกับฟิลด์ในเว็บ**

```
ฟอร์มในเว็บคุณมี 3 ช่อง
1. ชื่อ
2. LINE ID หรือเบอร์
3. เคยฝึกมาก่อนไหม (ไม่เคย / เคยลองสั้นๆ / ฝึกบ้าง / ฝึกประจำ)

ทำ 3 ขั้นนี้นะคะ/ครับ
1. ไป forms.google.com สร้างฟอร์มใหม่ ใส่คำถามให้ตรงกับช่องในเว็บ (ช่องเลือกตอบ ใส่ตัวเลือกให้ **ตรงกับข้อความปุ่มที่เห็นในเว็บเป๊ะ** เช่น ไม่เคย เคยลองสั้นๆ ฝึกบ้าง ฝึกประจำ ไม่งั้น Google จะไม่รับคำตอบข้อนั้น)
2. ในแท็บ Responses กดไอคอน Sheets เพื่อให้คำตอบเก็บลง Google Sheet
3. กดเมนู ⋮ มุมขวาบน เลือก Get pre-filled link กรอกคำตอบมั่วๆ ในแต่ละช่อง แล้วกด Get link ปุ่มล่าง copy ลิงก์มาวางให้ผม

ลิงก์ที่ได้จะหน้าตาแบบ
https://docs.google.com/forms/d/e/AbC.../viewform?usp=pp_url&entry.123=...&entry.456=...
```

ถ้านักเรียนยังไม่มี Google account หยุดรอ ให้ไปสมัครก่อน ห้ามเดาลิงก์

### 3.2 แกะ pre-filled link

จากลิงก์เดียวที่นักเรียนวาง ดึง 2 อย่าง

```
FORM_ID   = ส่วนที่อยู่ระหว่าง /forms/d/e/ กับ /viewform   (regex /forms/d/e/([^/]+)/)
entries   = ทุก entry.<ตัวเลข>=<ค่า> ตามลำดับที่เจอในลิงก์  (regex entry\.(\d+)=([^&]*))
```

สร้าง endpoint จริง

```
ACTION = https://docs.google.com/forms/d/e/FORM_ID/formResponse
```

(เปลี่ยน `/viewform` เป็น `/formResponse`)

### 3.3 จับคู่ฟิลด์ (generate-then-confirm)

จับคู่ช่องในเว็บกับ entry id **ตามลำดับ** (ช่องที่ 1 ในเว็บ คู่กับ entry แรกในลิงก์ ไปเรื่อยๆ) แล้ว **โชว์การจับคู่ให้นักเรียนยืนยันก่อน** เสมอ

```
ผมจับคู่แบบนี้นะคะ/ครับ ถ้าตรงกดตกลง ถ้าสลับช่องบอกได้
- ช่อง "ชื่อ" ในเว็บ  →  คำถามที่ 1 ใน Google Form
- ช่อง "LINE ID หรือเบอร์"  →  คำถามที่ 2
- ช่อง "เคยฝึกมาก่อนไหม"  →  คำถามที่ 3
```

ถ้าจำนวน entry ไม่เท่าจำนวนช่องในฟอร์ม **หยุดถาม** อย่าเดา (อาจสร้างคำถามไม่ครบ หรือกรอก pre-filled ไม่ครบทุกช่อง)

**ช่องแบบเลือกตอบ (radio/select)** ค่าที่ Google รับต้องตรงกับ **ข้อความตัวเลือกใน Google Form** เป๊ะ วิธีที่ generic กับทุกเว็บคือ **ส่งข้อความ label ที่คนเห็น** ไม่ใช่ `value` ใน HTML เพราะ Claude Design วาง label text ไว้ติดกับ input อยู่แล้ว (เช่น `<label class="radio"><input ... value="never">ไม่เคย</label>` label คือ `ไม่เคย`) อ่าน label text ของตัวเลือกที่ติ๊กแล้วส่งอันนั้น แล้ว **บอกนักเรียนตอน 3.1 ให้ตั้งตัวเลือกใน Google Form ให้ตรงกับข้อความปุ่มที่เห็นในเว็บเป๊ะ** วิธีนี้ไม่ต้อง map ค่าอะไรเลย (pre-filled link โชว์แค่ตัวเลือกเดียวที่นักเรียนเลือก map ทั้งชุดไม่ได้อยู่แล้ว) ดู snippet ใน 3.4

### 3.4 wire เข้า scripts.js (สำคัญที่สุด ระวัง handler เดิม)

**ตรวจก่อนว่ามี submit handler เดิมไหม** (Claude Design มักใส่ handler ที่ `e.preventDefault()` + โชว์ success ปลอม โดยข้อมูลไม่ไปไหน)

**กรณี A มี handler เดิม** อย่าเพิ่ม listener ตัวที่สอง (จะยิงซ้อนกัน) ให้ **แทรก fetch เข้าไปใน handler เดิม** หลัง validation ผ่าน ก่อน animation success เดิม เก็บ animation เดิมไว้ทั้งหมด (UX สวยอยู่แล้ว)

แทรกบล็อกนี้ (ใช้ name เดิมของ input ไม่ต้อง rename ใน HTML กัน JS เดิมพัง)

```js
/* cnc-form: signupForm -> Google Form (web-connect) */
var __cncData = new FormData();
/* ช่องพิมพ์ข้อความ 1 บรรทัดต่อ 1 ช่อง (อ่าน name จริงของฟอร์มนี้) */
__cncData.append('entry.ID_NAME', form.querySelector('[name="name"]').value.trim());
__cncData.append('entry.ID_LINE', form.querySelector('[name="line"]').value.trim());
/* ช่องเลือกตอบ ส่ง label text ที่คนเห็น (generic ไม่ต้อง map ค่า) */
var __cncExp = form.querySelector('[name="exp"]:checked');
if (__cncExp) {
  var __cncLbl = __cncExp.closest('label');
  __cncData.append('entry.ID_EXP', (__cncLbl ? __cncLbl.textContent : __cncExp.value).trim());
}
fetch('https://docs.google.com/forms/d/e/FORM_ID/formResponse', { method:'POST', mode:'no-cors', body:__cncData });
/* end cnc-form */
```

(โครงนี้เป็น template สร้าง `append()` หนึ่งบรรทัดต่อ **ทุกช่องจริง** ในฟอร์มนี้ แทน `entry.ID_*` ด้วย id จริง `FORM_ID` ด้วยของจริง ช่องพิมพ์ใช้ `.value` ช่องเลือกตอบ (radio/select) ใช้ label text ตาม snippet ฟอร์มมีกี่ช่องก็ไล่ให้ครบ)

**กรณี B ไม่มี handler เดิม** เพิ่ม handler ใหม่แบบเต็มใน scripts.js (validate ช่องที่ required แล้ว fetch แล้วโชว์ข้อความขอบคุณ) ติด guard `if(!form) return;` กันหน้าอื่นไม่มีฟอร์ม

**ทำไม fetch no-cors ไม่ใช่ native POST** เพราะ handler เดิมมี `e.preventDefault()` ขวาง native submit อยู่แล้ว และ fetch no-cors ส่งเข้า Google ได้แม้ตอบกลับเป็น opaque (อ่าน response ไม่ได้ แต่ข้อมูลถูกบันทึก) ทำงานบน localhost ได้เลย ไม่ต้อง deploy ก่อน ไม่ต้องแตะ name ของ input

**ทางสำรอง (ไม่มี scripts.js เลย)** ใส่ `action="ACTION"` `method="POST"` `target="cnc-sink"` บน `<form>` rename input `name` เป็น `entry.XXX` แล้วเพิ่ม `<iframe name="cnc-sink" hidden></iframe>` ท้าย body วิธีนี้ไม่ต้อง JS แต่ใช้เฉพาะตอนฟอร์มไม่มี handler เดิม (ไม่งั้น preventDefault จะขวาง)

### 3.5 ติด marker

- บน `<form>` ใส่ `data-cnc-form="connected"`
- ใน scripts.js ครอบด้วยคอมเมนต์ `/* cnc-form: <id> */ ... /* end cnc-form */`

---

## Step 4 ลงทะเบียน CSP ผ่าน best-practices Mode B

`fetch` ถูกคุมด้วย `connect-src` (ไม่ใช่ `form-action`) default ของ best-practices มีแค่ `connect-src 'self' https://cloudflareinsights.com` ยังไม่มี Google จึงต้อง merge เพิ่ม

เรียก best-practices **Mode B** ด้วย pair

```
connect-src:  https://docs.google.com
```

(ถ้าใช้ทางสำรอง native POST + iframe ให้ขอ `form-action: https://docs.google.com` (มีอยู่แล้ว default) + `frame-src: https://docs.google.com` สำหรับ iframe รับ response แทน)

best-practices Mode B เป็น idempotent merge ถ้ามี domain อยู่แล้วไม่ซ้ำ ถ้ายังไม่มี `_headers` มันสร้างให้พร้อม domain เลย

---

## Step 5 preview localhost

เปิด preview ให้นักเรียนลองกรอกฟอร์มจริง (fetch no-cors ทำงานบน localhost ได้)

**เช็คพอร์ตว่างก่อน start เสมอ** (กฎเดียวกับ web-finish/web-add) อย่า bind 8000 ดื้อๆ ถ้ามี server อื่นครองอยู่ ตัวใหม่ bind ไม่ติดแบบเงียบ แล้วนักเรียนเปิดมาเจอเว็บผิดตัว

```
PY: macOS ใช้ python3 เสมอ (ห้าม python เปล่า มักไม่มีบน Mac) / Windows ลอง python ก่อน ไม่มีค่อยใช้ py
```

1. หาพอร์ตว่างตัวแรกจาก 8000 8080 8888 3000
   - Windows `(Test-NetConnection localhost -Port <p> -WarningAction SilentlyContinue).TcpTestSucceeded` (true = ไม่ว่าง)
   - macOS/Linux `lsof -i :<p>` (เจอผล = ไม่ว่าง)
2. start จาก project root ใช้ `--directory .` (ห้ามใส่ path เต็มเป็น argument กัน path มีเว้นวรรคโดนตัดคำบน Windows)
   ```
   $PY -m http.server <พอร์ตว่าง> --directory .
   ```
3. รัน background verify ด้วย curl ที่ path จริง (เช่น `/index.html`) ว่าได้ 200 **และเป็นเว็บโปรเจกต์นี้**
4. บอกนักเรียนเปิดลิงก์ด้วยพอร์ตที่ start จริง

บอกนักเรียนลองกรอกฟอร์มแล้วไปเปิด Google Sheet ดูว่ามีแถวใหม่โผล่ไหม **นี่คือหลักฐานว่าต่อสำเร็จ**

ℹ️ submission แรกบางทีช้า 2-3 วิ ปกติ และถ้า `_headers` เพิ่ง merge CSP ผลเต็มจะเห็นตอน deploy บน Cloudflare (localhost ไม่บังคับ CSP แต่ fetch ยังส่งได้)

---

## Step 6 รายงาน + next step

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ ต่อฟอร์มและปุ่มให้ทำงานจริงแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ฟอร์มกรอกข้อมูล ต่อเข้า Google Sheet ของคุณแล้ว
   ลูกค้ากรอกแล้วข้อมูลจะไปโผล่ใน Sheet อัตโนมัติ
✅ ปุ่มติดต่อ [N] อัน ต่อไป [LINE / โทร] แล้ว

👀 เปิดดูได้ที่ http://localhost:[พอร์ตที่ start จริง]
   ลองกรอกฟอร์มดู แล้วเปิด Google Sheet เช็คว่ามีแถวใหม่

ℹ️ ข้อมูลส่งตรงเข้า Sheet ของคุณเอง ไม่ผ่านใคร
   อยากให้ใครช่วยดู lead แชร์ Sheet ให้เขาได้เลย

ต่อไป
1. /save-work    เซฟขึ้น GitHub
2. deploy        เอาขึ้นเว็บจริง
```

ปิดท้ายด้วยภาษาคน ห้ามโชว์ entry id ชื่อ tag หรือ CSP directive ในรายงาน

---

## Edge cases

- **ฟอร์มต่อแล้ว (มี `data-cnc-form`)** ข้าม บอกนักเรียนว่าต่อแล้ว ถ้าอยากเปลี่ยนปลายทาง Google Form ใหม่ ให้ลบ marker ก่อนแล้วรันใหม่
- **หลายฟอร์มในเว็บ** ต่อทีละอัน ขอ pre-filled link แยกของแต่ละฟอร์ม
- **จำนวน entry ไม่ตรงจำนวนช่อง** หยุดถามนักเรียนให้ทำ pre-filled link ใหม่ให้ครบทุกช่อง ห้ามเดา
- **นักเรียนไม่อยากใช้ Google Form** เสนอทางออกง่ายสุดคือเปลี่ยนปุ่ม submit เป็นปุ่มทักไลน์แทน (Step 2) ฟอร์มแบบกรอกต้องมีปลายทางรับ ถ้าไม่เอา Google ก็ใช้ช่องทางตรงอย่าง LINE
- **JS ปิด** ฟอร์มที่ใช้ fetch จะไม่ส่ง (ทั้งเว็บ Claude Design พึ่ง JS อยู่แล้ว) เพิ่ม `<noscript>` เล็กๆ บอกให้ทักไลน์แทนได้ (optional)
- **ช่องเลือกตอบหลายแบบ (checkbox หลายค่า)** Google รับเป็นหลาย `entry.XXX` ค่าซ้ำ key ส่งทีละค่าที่ติ๊ก

---

## FYI สำหรับนักเรียนที่อยากเข้าใจเพิ่ม

- ข้อมูลไป Sheet ผ่าน Google Form ที่คุณสร้าง คุณเป็นเจ้าของข้อมูลเอง
- อยากได้อีเมลแจ้งเตือนทุกครั้งที่มีคนกรอก ตั้งใน Google Form ได้ (Responses → ⋮ → Get email notifications)
- อยากได้ฟิลด์เพิ่มทีหลัง แก้ทั้งในเว็บและใน Google Form ให้ตรงกัน แล้วรัน web-connect ใหม่
