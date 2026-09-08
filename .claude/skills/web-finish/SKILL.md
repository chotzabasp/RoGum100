---
name: web-finish
description: Use after web-import (or anytime) to เก็บงาน หน้าเว็บที่ได้จาก Claude Design ให้เรียบร้อย แก้ปัญหาภาษาไทยอัตโนมัติ (สระบนสระล่างทับกัน บรรทัดชิดเกิน ตัวอักษรล้นขอบ ตัวเล็กเกินบนมือถือ ปุ่มกดยาก) แล้วใส่ค่าจริงแทน placeholder เช่น [ชื่อร้าน] [LOGO] เบอร์โทร ไอดีไลน์ จากนั้นเปิด preview บน localhost ให้ดู triggers include "เก็บงาน", "เก็บงานหน้าเว็บ", "เก็บงานเว็บ", "จัดหน้าเว็บ", "จัดหน้าให้เรียบร้อย", "ทำให้เว็บเรียบร้อย", "แก้สระทับกัน", "ตัวอักษรล้น", "web-finish", or any similar request to finalize a fresh design before deploy. Auto-called by web-import right after a Claude Design export lands so the page never looks broken on first preview. Auto-fixes deterministic Thai rendering and mobile issues without asking only touching Thai-text elements (leaves Latin and mono labels as designed) then asks only for placeholder values it cannot know. Built for absolute beginners with zero coding knowledge auto-installs Python if missing works on both Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-finish เก็บงานหน้าเว็บให้เรียบร้อย

ทำหน้าที่เหมือนช่างเก็บงาน หน้าเว็บที่เพิ่งได้จาก Claude Design มักสวยแต่มีจุดเล็กๆ ที่ต้องเก็บก่อนใช้จริง โดยเฉพาะ ภาษาไทย ที่ Claude Design ออกแบบด้วยสไตล์ฝรั่งเลยทำให้ สระบนสระล่างทับกัน บรรทัดชิดเกิน หรือตัวอักษรล้นขอบ skill นี้แก้ให้อัตโนมัติ แล้วใส่ค่าจริงแทน placeholder จากนั้นเปิดให้ดู

หลักการ เก็บงานก่อน ใส่ค่าจริงทีหลัง เปิดให้ชื่นชมท้ายสุด นักเรียนจะไม่เห็นหน้าเว็บพังตั้งแต่แรก

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลักอื่นๆ

- **ภาษาไทยเรียบง่าย** นักเรียนไม่รู้จัก HTML CSS Python
- **ห้ามใช้ technical term กับนักเรียน** อธิบายเป็นภาษาคน ห้ามโชว์ CSS หรือ diff
- **ห้ามให้นักเรียนเห็น error** แก้เองก่อนเสมอ
- **Cross-platform** Windows PowerShell + macOS Bash
- **Auto-install Python ถ้าไม่มี** อย่าถามอย่ารบกวน
- **Fix ก่อน ถามทีหลัง** สิ่งที่มีคำตอบถูกแบบเดียว แก้เลยไม่ต้องถาม นักเรียน non-coder ดู F12 ไม่เป็น อย่าให้ไปวินิจฉัยเอง
- **Loop จนนักเรียนพอใจ** อย่ารีบจบ skill

---

## Step 1 ตรวจว่าหน้าเว็บพร้อมเก็บงานไหม

อ่าน file structure ของ project root

| สิ่งที่ต้องเจอ | ถ้าไม่เจอ |
|----------------|----------|
| `index.html` ที่ root | แจ้ง "ยังไม่มีไฟล์เว็บเลยนะคะ/ครับ ถ้าได้ดีไซน์จาก Claude Design ทำ `/web-import` ก่อน ถ้าจะให้ Claude Code สร้างให้ พิมพ์ `/web-generate`" แล้วจบ skill |
| `assets/` folder | สร้างให้ถ้าไม่มี |
| `CLAUDE.md` (optional) | อ่าน context ถ้ามี |

---

## Step 2 อ่าน HTML + CSS แล้วหา element ที่เป็นภาษาไทย

อ่าน **ทุกหน้า** `index.html` + ทุกไฟล์ใน `pages/*.html` ไม่ใช่แค่หน้าแรก ทำขั้นตอนเก็บงานนี้ซ้ำกับทุกหน้า และทุก section ในหน้า ไม่ใช่แค่ hero ด้านบน

Read แต่ละหน้าทั้งไฟล์ แล้วอ่าน CSS **ทุกแหล่ง** อย่าพลาดแหล่งใดแหล่งหนึ่ง
- external `<link rel="stylesheet" href="styles.css">` (อ่านไฟล์นั้นด้วย ปกติคือ foundation + component)
- inline `<style>...</style>` ใน head (Claude Design มัก override ที่นี่)
- inline `style="..."` attribute บน element เดี่ยวๆ (เจอเป็นบางจุด)

ลำดับความสำคัญของ CSS ตัวที่อยู่ทีหลังหรือ specific กว่าจะชนะ ดู override ใน `@media` ด้วยเสมอ ไม่ใช่ดูแค่ base rule

### รู้จัก foundation ที่เว็บทุกหลังใช้ร่วมกัน

ทุกเว็บของนักเรียน generate จาก `codebase/styles.css` เดียวกัน เจอ token พวกนี้ได้บ่อย ใช้เป็นจุดสังเกตเร็วๆ
- font ไทย `--font-display` (หัวเรื่อง) `--font-body` (เนื้อหา)
- `.display` คือ class หัวเรื่องหลัก foundation ตั้ง `line-height: 1.1` `letter-spacing: -0.01em` ไว้ **ซึ่งคลิปสระไทย** เจอเมื่อไหร่แก้เลย
- `body` ปกติ `line-height: 1.5` `overflow-x: hidden` (M2 มักผ่านอยู่แล้ว แต่ต้องเช็คเพราะ Claude Design override ได้)
- `.container` `.grid` `.grid--2/3/4` คือ layout มาตรฐาน
- **อย่าเชื่อว่า foundation ถูกเสมอ** Claude Design override ค่าพวกนี้บ่อย ต้องดูค่าจริงที่ใช้งานเสมอ

### หา Thai-text element (ใช้ได้กับทุกเว็บทุก archetype)

หลักการเดียวที่ทนทาน ตรวจ **อักขระไทย U+0E00 ถึง U+0E7F** ใน text content
- ดูทุก tag ที่มี text (h1 h2 h3 h4 p span a button li blockquote label figcaption ฯลฯ)
- text ผสมไทยอังกฤษ (เช่น "10+ ปี" "LINE ปรึกษาฟรี") ถือเป็น Thai-text ด้วย
- text ที่ห่อใน span ซ้อน (เช่น `<h1><span><span>เครื่องเสียง</span></span></h1>`) ให้มองหา **block element ตัวนอก** ที่ตั้ง line-height/letter-spacing (ปกติคือ h1 หรือ class headline) นั่นคือตัวที่ต้องแก้
- ดูทุกระดับ หัวเรื่องใหญ่ (hero/display) หัวเรื่องรอง (section title subhead) เนื้อหา (body) label ปุ่ม footer ทุก section ทุกหน้า
- จำ selector ที่คุมแต่ละ Thai-text element ไว้ใช้ตอนแก้
- mark **double-stack** ไว้ด้วย คือ สระบน (◌ิ ◌ี ◌ึ ◌ื ◌ั ◌็ = U+0E31 U+0E34-0E37 U+0E47) ตามด้วยวรรณยุกต์ (◌่ ◌้ ◌๊ ◌๋ ◌์ = U+0E48-0E4C) เช่น ตั้ง ที่ พวกนี้สูงสุดเสี่ยงทับมากสุด

เก็บข้อมูล
- รายการ Thai-text element + selector ของมัน + effective line-height/letter-spacing/font-size ที่ใช้จริงในแต่ละ breakpoint
- selector ที่เป็น Latin/mono ล้วน (ไว้กันไม่ให้ไปแตะ)
- viewport meta tag (มีหรือไม่)
- ทุก `[bracket placeholder]` ใน text content

---

## Step 3 เก็บงานภาษาไทยอัตโนมัติ (หัวใจของ skill)

นี่คือสิ่งที่ skill อื่นไม่ทำ และเป็นปัญหาที่เจอทุกครั้งกับ export จาก Claude Design

Claude Design เขียน typography สไตล์ฝรั่ง บรรทัดชิด (line-height 0.85 ถึง 1.1) ซึ่งสวยกับภาษาอังกฤษ แต่ภาษาไทยมีสระบน วรรณยุกต์ และสระล่าง ซ้อนกันหลายชั้น พอบรรทัดชิดเกิน วรรณยุกต์กับสระบนของบรรทัดล่าง จะไปทับสระล่าง (สระอู) ของบรรทัดบน เกิดอาการ สระทับกัน

### กฎความปลอดภัย ก่อนแก้ทุกครั้ง

**แตะเฉพาะ Thai-text element เท่านั้น** ห้ามแตะ label ภาษาอังกฤษ หรือ class แนว mono หรือตัวพิมพ์ใหญ่ภาษาอังกฤษ (เช่น `.mono` คำว่า "CAR AUDIO LAB" "SCROLL" "LINE") เพราะ letter-spacing กว้างๆ ของพวกนี้คือดีไซน์ที่ตั้งใจ ถ้าไปรีเซ็ตจะพังดีไซน์

### Fix T1 บรรทัดชิดเกินทำให้สระทับกัน (สำคัญที่สุด)

ตรวจด้วย **effective line-height ratio** ไม่ใช่ดูแค่ตัวเลขดิบ เพราะ line-height เขียนได้หลายแบบ
- เลขเปล่า เช่น `line-height: 1.1` → ratio = 1.1
- หน่วย px เช่น `line-height: 36px` บน `font-size: 40px` → ratio = 36/40 = 0.9
- ผ่าน CSS variable เช่น `line-height: var(--lh)` → ตามค่าจริงของ variable
- override ใน `@media` → คิด ratio แยกแต่ละ breakpoint (car example tighten เป็น 1.02 เฉพาะจอใหญ่)

**ทำไมต้องสูง** ภาษาไทยซ้อน 2 ชั้นบน สระบน + วรรณยุกต์ stack ◌ั + ◌้ (ไม้โทบนสระอะ เช่น ตั้ง) สูงสุด ยิ่งตัวหนา weight 800 ยิ่งสูง ทดสอบจริงแล้ว ที่ เคลียร์ที่ 1.5 แต่ ตั้ง ต้องถึง 1.7 จึงใช้ **safe floor ตามขนาด** ไม่ตรวจทีละตัวเพื่อเลือกค่า เพราะ web-finish ใส่ค่าจริงแทน placeholder ทีหลัง (Step 8) อาจเพิ่ม stack ใหม่บนหัวเรื่องที่ตั้งเตี้ย floor ตายตัวกันพลาดได้ทุกกรณีและทนการแก้ทีหลัง

```
สำหรับแต่ละ Thai-text element คิด effective ratio ที่ทุก breakpoint
ถ้า ratio < target ที่ breakpoint ใดก็ตาม → ตั้งให้ถึง target ที่ breakpoint นั้น

target ตามระดับ
  - หัวเรื่องใหญ่ hero/display (ตัวใหญ่สุดหนาสุด ใช้ --font-display หรือ class display headline hero) → 1.7
  - หัวเรื่องรอง section title subhead (เล็กลงมา)                                                  → 1.6
  - เนื้อหา body p sub desc lead                                                                  → 1.5
ถ้าเป็น px เปลี่ยนเป็นเลขเปล่า
แก้ทั้ง base rule และทุก @media override ที่ยังต่ำกว่า target
```

line-height ที่สูงขึ้นไม่ทำให้อังกฤษเสีย rule เดียวคุมทั้งไทยอังกฤษแก้ได้เลย
ถ้านักเรียนอยากให้ headline แน่นกว่านี้ ทางเลือกคือลด font-weight ของ hero จาก 800 → 700 (มาร์กเล็กลง 1.5 ก็เคลียร์) แต่เป็น tweak รายคน ไม่ใช่ default

### Fix T2 letter-spacing

แยก 2 กรณีให้ชัด เพราะกระทบดีไซน์ไม่เท่ากัน

```
กรณี A letter-spacing เป็นลบ (เช่น -0.018em -0.05em)
  ทำให้ตัวไทยอัดกันจนสระเบียด
  → ตั้ง letter-spacing: 0 ได้เลยแม้ rule จะคุมอังกฤษด้วย
    (ลบเล็กน้อยบนอังกฤษมองแทบไม่ออก ปลอดภัย)

กรณี B letter-spacing เป็นบวกกว้าง (เช่น 0.18em 0.22em)
  บนไทย = ผิด แต่บน label อังกฤษ/mono ตัวพิมพ์ใหญ่ = ดีไซน์ที่ตั้งใจ
  → ถ้า element เป็นไทย ตั้ง letter-spacing: 0
  → ถ้า element เป็น Latin/mono ล้วน (เช่น .mono "CAR AUDIO LAB" "SCROLL" "LINE") ห้ามแตะ
  → ถ้า rule รวมคุมทั้งคู่ ให้สร้าง selector เจาะจงเฉพาะตัวไทย อย่ารีเซ็ตรวม
```

### Fix T3 กล่องข้อความตัดสระบน

```
หา Thai-text element ที่ rule มี height คงที่ + overflow: hidden
   หรือมี max-height ที่อาจตัดวรรณยุกต์บรรทัดบน
ถ้าเจอ: เพิ่ม padding-top เล็กน้อย หรือเปลี่ยนเป็น min-height
```

### Fix T4 ข้อความไทยล้นขอบขวา ตัวท้ายถูกตัด

ภาษาไทย **ไม่มีช่องว่างระหว่างคำ** ทั้งวลีเป็น token เดียว ถ้าถูกห่อด้วย `display: inline-block` (เช่น word-wrapper ของ reveal animation) browser จะ **เบรกข้างในไม่ได้** พอตัวใหญ่ขึ้นวลีจะกว้างเกิน container แล้วโดน `overflow: hidden` ตัดตัวท้ายทิ้ง (เคสจริง คำว่า มา หายไปในจอใหญ่)

```
ตรวจ: หน้ากว้างเกินจอไหม (document scrollWidth > viewport width)
      หรือ Thai heading ตัวท้ายถูกตัดโดย ancestor ที่ overflow: hidden
ถ้าเจอ:
  - เพิ่ม overflow-wrap: anywhere + word-break: break-word + max-width: 100%
    ให้ element ไทยที่ล้น รวม word-wrapper inline-block ให้มันเบรกข้างในได้
    ห้ามลบ display: inline-block ออก จะพัง reveal animation
  - ถ้ายังล้น ตรวจ element ที่ตั้ง width เกิน 100vw หรือ position absolute ยื่นออกขอบ
หลังแก้ verify หน้าไม่กว้างเกินจอแล้ว (curl/refresh) ก่อนบอกว่าเสร็จ
```

**ระวัง** horizontal scroll strip ที่ตั้งใจ (`overflow-x: auto` สำหรับ swipe gallery) อย่าไปแก้ ดูก่อนว่าตั้งใจหรือเป็น bug

แก้ทุกข้อข้างบนอัตโนมัติ จดไว้ใน list `thai_fixed` สำหรับรายงาน

---

## Step 4 เก็บงาน mobile อัตโนมัติ

ปัญหา mobile ที่มีคำตอบถูกแบบเดียว แก้เลยไม่ต้องถาม จดไว้ใน list `mobile_fixed`

### M1 ตัวอักษรหัวเรื่องล้นขอบจอ (ตัวอักษรถูกตัด)

```
หา h1 h2 หรือ headline class ที่ font ใหญ่ (font-size > 40px หรือ clamp max สูง)
   AND ไม่มี overflow-wrap
fix: เพิ่ม
  overflow-wrap: anywhere;
  word-break: break-word;
```

### M2 หน้าจอ scroll ซ้ายขวาได้ (ไม่ควร)

```
หา body หรือ html ที่ไม่มี overflow-x: hidden
fix: เพิ่ม overflow-x: hidden ที่ body
```

### M3 ตัวอักษรเนื้อหาเล็กเกินบนมือถือ

```
หา body หรือ paragraph ที่ font-size < 16px
fix: ตั้ง font-size อย่างน้อย 16px (กันมือถือ zoom เอง)
ยกเว้น label mono เล็กๆ ที่ตั้งใจให้เล็ก ข้ามได้
```

### M4 ปุ่มเล็กกดยาก

```
หา button หรือ .btn ที่ min-height < 44px หรือ padding น้อย
fix: เพิ่ม min-height: 44px
```

### M5 viewport meta หาย

```
หา <meta name="viewport"> ใน head
ถ้าไม่มี: เพิ่ม <meta name="viewport" content="width=device-width,initial-scale=1"> ก่อน </head>
```

### M6 ตารางหลาย column ไม่ยุบบนมือถือ

```
หา grid-template-columns หลาย column ที่ไม่มี @media ยุบเป็น 1fr
fix: เพิ่ม @media (max-width: 720px){ .selector{ grid-template-columns: 1fr } }
```

### M7 ช่องกรอกฟอร์มไม่เต็มกรอบ

```
หา input หรือ select ใน form ที่ไม่มี width: 100%
fix: เพิ่ม width: 100%
```

---

## Step 4b แยก CSS/JS เป็นไฟล์ภายนอก (เตรียม strict CSP)

Claude Design เขียน CSS ใน `<style>` block และ animation ใน `<script>` block แบบ inline ใน HTML ซึ่ง browser ทำงานได้ปกติ แต่ทำให้ best-practices ต้องเปิด `'unsafe-inline'` ใน CSP ซึ่งหละหลวม web-finish ย้าย inline เหล่านี้ออกเป็นไฟล์ภายนอกเพื่อให้
- best-practices ตั้ง CSP แบบเข้มงวดได้ (strict CSP `'self'` only)
- browser cache CSS/JS แยกได้ โหลดเร็วขึ้น
- โครงสร้างไฟล์สะอาด ตรงกับกฎ "one job per file" ใน Day 1

### กฎการแยก

```
สำหรับแต่ละหน้า (index.html + pages/*.html)

CSS extraction
- รวมทุก <style>...</style> block ใน head เรียงตามลำดับเดิม
- append ต่อท้าย styles.css ที่ project root (ถ้ายังไม่มี สร้างใหม่)
- ลบ <style> block ออกจาก HTML
- ถ้ายังไม่มี <link rel="stylesheet" href="styles.css"> ใน head ใส่ที่ตำแหน่งของ <style> block แรก
- inline style="..." attribute บน element **ห้ามแตะ** (Claude Design ใช้บ่อย best-practices อนุญาตด้วย style-src-attr)

JS extraction
- รวมทุก inline <script>...</script> block ที่ **ไม่มี src=** และ **ไม่ใช่ type="application/ld+json"** เรียงตามลำดับเดิม
- append ต่อท้าย scripts.js ที่ project root (ถ้ายังไม่มี สร้างใหม่)
- ลบ inline <script> block ออกจาก HTML
- ใส่ <script src="scripts.js" defer></script> ก่อน </body> ของแต่ละหน้า
- type="application/ld+json" คือ structured data ของ seo (LocalBusiness Product) **ห้ามแตะ** เป็นข้อมูลไม่ใช่โค้ด

ลำดับสำคัญมาก
- CSS เรียงตามที่อยู่ใน HTML เดิม (ของบนทับของล่างตาม CSS cascade) foundation styles.css ที่ link อยู่แล้วจะอยู่บน inline ที่ extract เพิ่มมาจะ append ต่อท้าย ซึ่งถูกต้องตาม cascade
- JS เรียงตามลำดับเดิม + defer ทำให้รันหลัง DOM parse แต่ก่อน DOMContentLoaded animation register event listener ปลอดภัย
```

### Verify หลังแยก

ตรวจให้แน่ว่า
- หน้าเว็บ render ครบ (curl localhost ได้ 200 + ดูว่า CSS ติด)
- animation ยังทำงาน (reveal stagger counter)
- ถ้า animation บางตัวพัง อาจเพราะ script เดิมพึ่ง parse-time (เช่น document.write rare ใน Claude Design) revert การ extract ของ block นั้นเฉพาะ ปล่อยเป็น inline ไว้

### Edge case

| สถานการณ์ | จัดการ |
|----------|--------|
| ไม่มี inline `<style>` เลย | ข้าม CSS extraction |
| ไม่มี inline `<script>` เลย | ข้าม JS extraction |
| มี `styles.css` อยู่แล้ว (foundation) | append inline ต่อท้าย (foundation อยู่บน inline override อยู่ล่าง = cascade ถูก) |
| inline script ใช้ document.write | revert เป็น inline ปล่อยไว้ก่อน |
| `<script type="application/ld+json">` | ห้ามแตะ structured data ของ seo |
| `<style>` ใช้ CSS variable ที่อ้างใน inline style="" | ปลอดภัย variable ยัง resolve ได้หลัง extract |

### บันทึก fix

ถ้า extract สำเร็จ จด `inline_extracted: true` ใน list สำหรับ report
ถ้าตัดสินใจ revert บางอันเพราะ document.write จด `inline_extracted: partial` + เหตุผล (best-practices ต้องรู้ว่ายังต้องเปิด unsafe-inline บางส่วนไหม)

---

## Step 5 เปิด preview บน localhost

ใช้ infrastructure เดียวกับ web-import (share server ตัวเดียวกันผ่าน pid/port file)

### 5.1 ตรวจ existing server ก่อน

**Windows**

```powershell
$pidFile = "$env:TEMP\cnc-web-server-pid.txt"
$portFile = "$env:TEMP\cnc-web-server-port.txt"
if ((Test-Path $pidFile) -and (Test-Path $portFile)) {
  $existingPid = Get-Content $pidFile
  $existingPort = Get-Content $portFile
  if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
    Write-Output "EXISTING_SERVER:$existingPort"
  }
}
```

**macOS**

```bash
if [ -f /tmp/cnc-web-server-pid ] && [ -f /tmp/cnc-web-server-port ]; then
  EP=$(cat /tmp/cnc-web-server-pid); PORT=$(cat /tmp/cnc-web-server-port)
  ps -p $EP > /dev/null 2>&1 && echo "EXISTING_SERVER:$PORT"
fi
```

ถ้าเจอ server ที่ยังตอบ HTTP 200 ใช้ port เดิม ข้ามการเปิดใหม่

### 5.2 ตรวจ Python และ install ถ้าไม่มี

**macOS** — ใช้ `python3` เก็บใน variable

```bash
python3 --version
PY=python3
```

ถ้าไม่มี
- `brew install python` แล้ว `PY=python3`
- Fallback ใช้ Node `npx http-server -p 8000`
- Last resort เปิด python.org/downloads แจ้งนักเรียนติดตั้งแล้วพิมพ์ `/web-finish` ใหม่

**Windows** — ลำดับ try `python` แล้ว `py` เก็บใน variable

```powershell
$PY = $null
python --version 2>$null
if ($?) { $PY = "python" }

# ถ้า python ไม่เจอ ค่อยลอง py
if (-not $PY) {
  py --version 2>$null
  if ($?) { $PY = "py" }
}
```

ถ้าทั้ง `python` และ `py` ไม่มี
- `winget install Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements` แล้ว reload PATH แล้วลองใหม่
- Fallback ใช้ Node `npx http-server -p 8000`
- Last resort เปิด python.org/downloads

อย่าให้นักเรียนเห็น error ระหว่าง install

### 5.3 เปิด server (ถ้ายังไม่มี)

**สำคัญ หาพอร์ตว่างก่อน bind** อย่า bind 8000 ดื้อๆ เพราะถ้ามี server อื่นครองพอร์ตนั้นอยู่ (โปรเจกต์อื่น หรือรอบก่อน) `Start-Process -WindowStyle Hidden` / `> /dev/null &` จะกลืน error ที่ bind ไม่ติด แล้ว curl ไปโดน server ตัวอื่นได้ 200 = นักเรียนเปิดมาเจอเว็บผิดตัว ต้องเช็คว่าพอร์ตว่างจริงก่อนค่อย start

**Windows**

```powershell
# หาพอร์ตว่างตัวแรกจาก list (ข้ามตัวที่มีคนใช้อยู่)
$port = $null
foreach ($p in 8000,8080,8888,3000) {
  if (-not (Test-NetConnection localhost -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded) { $port = $p; break }
}
$proc = Start-Process -FilePath $PY -ArgumentList "-m","http.server",$port,"--directory","." -WindowStyle Hidden -PassThru
$proc.Id | Out-File "$env:TEMP\cnc-web-server-pid.txt" -Encoding utf8
"$port" | Out-File "$env:TEMP\cnc-web-server-port.txt" -Encoding utf8
```

**macOS**

```bash
# หาพอร์ตว่างตัวแรก (lsof เจอผล = มีคนใช้ ข้ามไป)
for p in 8000 8080 8888 3000; do
  if ! lsof -i :$p > /dev/null 2>&1; then PORT=$p; break; fi
done
$PY -m http.server $PORT --directory . > /dev/null 2>&1 &
echo $! > /tmp/cnc-web-server-pid
echo $PORT > /tmp/cnc-web-server-port
```

รัน background (`run_in_background: true`) แล้ว verify ด้วย curl ที่พอร์ตที่ start จริงว่าได้ 200 **แล้วบอกนักเรียนด้วยพอร์ตนั้นเสมอ** (อาจไม่ใช่ 8000 ถ้าต้องเปลี่ยนบอกสั้นๆ ว่าพอร์ต 8000 มีอะไรใช้อยู่)

---

## Step 6 รายงานนักเรียน (สไตล์ช่างเก็บงาน)

ใช้ list `thai_fixed` และ `mobile_fixed` ที่เก็บไว้ แปลเป็นภาษาคน อย่าโชว์ CSS

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ เก็บงานหน้าเว็บให้เรียบร้อยแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ผมเก็บงานให้ [N] จุด

[list จาก thai_fixed + mobile_fixed แบบภาษาคน]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👀 เปิดดูได้เลย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👉 http://localhost:[PORT]

ลองเปิดดูทั้งบนคอมและบนมือถือ (เปิดลิงก์เดียวกันบนมือถือที่ต่อ wifi เดียวกัน)

ถ้ามีตรงไหนยังไม่ถูกใจ บอกผมได้เลย เช่น
- "สีปุ่มเข้มไปนิด"
- "section นี้ห่างกันเกินไป"
- "อยากเปลี่ยนหัวเรื่องเป็น..."

ถ้าดูแล้ว OK พิมพ์ "ok" ผมจะถามค่าจริงไปใส่แทนที่ของตัวอย่าง
```

### ตารางแปลเป็นภาษาคน

| สิ่งที่แก้ | บอกนักเรียนว่า |
|-----------|----------------|
| T1 line-height ไทย | "จัดระยะบรรทัดภาษาไทยใหม่ สระกับวรรณยุกต์ไม่ทับกันแล้ว" |
| T2 letter-spacing ไทย | "จัดระยะตัวอักษรไทยให้อ่านง่ายขึ้น" |
| T3 กล่องตัดสระ | "ขยับกรอบข้อความไม่ให้ตัดหัวสระ" |
| T4 ล้นขอบขวา | "ข้อความเคยล้นขอบจอจนตัวท้ายหาย ตอนนี้พับบรรทัดพอดีไม่ขาด" |
| M1 หัวเรื่องล้น | "หัวเรื่องเคยล้นขอบจอ ตอนนี้พับบรรทัดเองอัตโนมัติ" |
| M2 overflow-x | "เคย scroll ซ้ายขวาบนมือถือ ตอนนี้แก้แล้ว" |
| M3 font เล็ก | "ตัวอักษรเล็กไปบนมือถือ ตอนนี้ขนาดพอดีอ่านง่าย" |
| M4 ปุ่มเล็ก | "ปุ่มเล็กกดยาก ตอนนี้กดง่ายขึ้น" |
| M5 viewport | "เว็บไม่ปรับขนาดตามมือถือ ตอนนี้ปรับเองแล้ว" |
| M6 grid | "ตารางหลายช่องบนมือถือ ตอนนี้ยุบเป็นแถวเดียวสวย" |
| M7 input | "ช่องกรอกฟอร์มเคยแคบ ตอนนี้เต็มกรอบ" |

ถ้าไม่เจอจุดต้องแก้เลย (web-design prompt ดีมาก) แจ้ง "ตรวจแล้วหน้าเว็บเรียบร้อยดีมาก ไม่เจอจุดต้องเก็บงาน" แล้วไปขั้น preview ตามปกติ

---

## Step 7 Loop แก้ตามที่นักเรียนบอก

นักเรียนบอกอะไรไม่ถูกใจ ตีความแล้วแก้

| นักเรียนบอก | ทำ |
|-------------|----|
| "สีปุ่มเข้มไป" | ปรับ color ให้สว่างขึ้น |
| "ตัวอักษรเล็กไป" | เพิ่ม font-size ใน element ที่ชี้ |
| "ห่างเกินไป" | ลด margin/padding |
| "ใกล้กันเกินไป" | เพิ่ม margin/padding |
| "เปลี่ยนหัวเรื่องเป็น..." | Edit text ใน HTML |
| "รูปเล็กไป" | เพิ่ม max-width หรือ scale |
| "เอา section นี้ออก" | ลบ section |

ขั้นตอน อ่าน element ที่เกี่ยว → แก้ด้วย Edit → "แก้แล้ว refresh ดูนะคะ/ครับ" → ถาม OK ไหม → loop

ถ้านักเรียนบอกกว้างๆ เช่น "ดูไม่สวย" ขอให้ชี้เฉพาะจุด สีไหน section ไหน element ไหน

---

## Step 8 ใส่ค่าจริงแทน placeholder

หลังนักเรียนพอใจ visual แล้ว

### Scan ทุกไฟล์

Grep หา `\[([^\]]+)\]` ใน index.html ทุก .html ใน pages/ ทุก .css ใน assets/css/

อย่า hardcode list เฉพาะร้านค้า ให้ scan เจอ placeholder จริงทั้งหมดแล้วถามตามที่เจอ ตัวอย่างต่าง archetype
- ทุกแบบ `[ชื่อ...]` `[LOGO]` `[email]` `[lineid]` `[เบอร์โทร]` `[social]`
- Local Business `[ที่อยู่ร้าน]` `[เวลาเปิด]` `[แผนที่]` `[เมนู]` `[ราคา]`
- Solopreneur / Personal Brand `[ชื่อคอร์ส]` `[ลูกศิษย์ 1]` `[รีวิว]` `[ประวัติ]`
- Freelancer `[ผลงาน 1]` `[ชื่อลูกค้า]` `[บริการ]`
- Validator `[ชื่อสินค้า]` `[ราคา early bird]` `[จำนวนคนสนใจ]`

ถ้าค่าไหนเป็นตัวเลข (ราคา จำนวน รีวิว) ย้ำกับนักเรียนว่าต้องเป็นเลขจริง ห้ามแต่งเอง (สอดคล้องกับ web-writing)

### ถามทีละกลุ่ม

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✏️ ใส่ข้อมูลจริงของคุณ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ผมเจอ [N] จุดที่เป็นตัวอย่างไว้ ขอข้อมูลจริงหน่อยนะคะ/ครับ ตอบทีละข้อหรือรวบทีเดียวก็ได้

📍 ข้อมูลธุรกิจ
ชื่อร้าน = ?
เบอร์โทร = ?
ไอดีไลน์ = ?
ที่อยู่ = ?

📍 โลโก้
อยากใช้รูปโลโก้ไหม ถ้ามีส่งเป็นไฟล์ (ลากไฟล์ให้ path ขึ้น หรือเซฟลงโฟลเดอร์ก่อน วางภาพในแชทเฉยๆ ใช้ไม่ได้) ถ้ายังไม่มีใช้ชื่อร้านเป็นตัวอักษรไปก่อนได้

ถ้าจุดไหนยังไม่มีข้อมูล พิมพ์ "ยังไม่มี" ผมเก็บตัวอย่างไว้ก่อนได้
```

### Replace

- ใช้ Edit `replace_all` แทนค่าจริงทุกจุดที่ placeholder นั้นปรากฏ
- "ยังไม่มี" → เก็บ placeholder ไว้
- **ห้ามแต่งค่าเอง** ถ้านักเรียนไม่ได้ให้ ห้ามเดา (โดยเฉพาะเบอร์โทร ราคา ตัวเลข)
- ถ้า [LOGO] นักเรียนมีรูป ประสานกับ web-images ให้ optimize ก่อนใส่

---

## Step 9 ปิดท้าย

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 เก็บงานเสร็จเรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ สรุป
- เก็บงานภาษาไทย + mobile ให้ [N] จุด
- แก้ตามที่ขอ [N] รอบ
- ใส่ข้อมูลจริง [N] จุด ([M] จุดเก็บตัวอย่างไว้ก่อน)

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ตอนพร้อม deploy   เอาขึ้น Cloudflare Pages
3. /web-style       อยากให้ปุ่มกับหน้าตา component เป็นทรงเฉพาะตัว ไม่เหมือนใคร เลือกได้เลย (สีไม่เปลี่ยน)

อยากแก้อีกพิมพ์ "เก็บงาน" หรือ /web-finish ได้ตลอดนะคะ/ครับ
```

ข้อ 3 `/web-style` ใส่เสมอ (ทุกเว็บที่เพิ่งสร้างยังเป็นทรง component มาตรฐาน) เป็นแค่บรรทัดชวนให้รู้จัก ไม่ต้องทำเลย นักเรียนข้ามได้

**ถ้าเจอฟอร์มที่ยังไม่ได้ต่อปลายทาง** สแกน `<form>` ที่ไม่ได้อยู่ใต้ `data-cnc-widget` และยังไม่มี `data-cnc-form` ถ้าเจอ เติมบรรทัดนี้ใน "ต่อไป" (แค่ flag ไม่ต้องทำเลย เพราะนักเรียนอาจยังไม่มี Google Form ตอนนี้)

```
4. /web-connect    ต่อฟอร์มเข้า Google Sheet (ตอนนี้กรอกแล้วข้อมูลยังไม่เก็บที่ไหน พอพร้อมค่อยต่อ)
```

ปิด server ด้วย pid file เดิม (`cnc-web-server-pid`) เมื่อนักเรียนพิมพ์ /save-work หรือบอกว่าเสร็จแล้ว

---

## ถูกเรียกโดย web-import อัตโนมัติ (Path A)

web-import จะเรียก web-finish ให้เองหลัง extract zip เสร็จ นักเรียนไม่ต้องพิมพ์คำสั่ง หน้าเว็บจะถูกเก็บงานก่อนเปิด preview ครั้งแรกเสมอ ถ้าถูกเรียกแบบนี้ ข้าม Step 1 (web-import ตรวจ index.html ให้แล้ว) เริ่มที่ Step 2 ได้เลย

## ถูกเรียกโดย draft-mode หลัง merge ตัวอย่าง Claude Code (Path B)

เมื่อ student เลือกใช้ตัวอย่าง Path B draft-mode จะ merge ฉบับร่าง `*-claude-code-design` เข้า main แล้วเรียก web-finish ให้ ต่างจาก Path A ตรงนี้

- **ไม่ได้ผ่าน web-import** ดังนั้น **ไม่มี server ที่เปิดค้างไว้** Step 5 จะไม่เจอ existing server แล้วเปิดใหม่เอง (ปกติ ไม่ต้องทำอะไรเพิ่ม)
- **ไม่มี artifact จาก Claude Design** (ไม่มี inline `<style>`/`<script>` ไม่มี state.json ไม่มี image-slot.js) เพราะ web-generate เขียน styles.css + scripts.js เป็นไฟล์ภายนอกให้อยู่แล้ว ดังนั้น **Step 4b แทบไม่มีอะไรให้ extract** (edge case "ไม่มี inline" = ข้าม) ถือว่าปกติ
- งานหลักที่ยังต้องทำคือ **Step 3 4 (เก็บงานไทย + mobile)** และ **Step 8 (ใส่ค่าจริงแทน placeholder)** เพราะ web-generate เก็บ `[ชื่อร้าน]` `[LOGO]` `[LINE ID]` ไว้ตามเดิม
- ทำงานตั้งแต่ Step 1 ตามปกติได้เลย (index.html มีอยู่แล้วจะผ่าน Step 1)

---

## สิ่งที่ต้องระวัง

- **แตะเฉพาะ element ที่มีตัวอักษรไทย** สำหรับ T1 T2 ห้ามรีเซ็ต letter-spacing ของ label อังกฤษ/mono เด็ดขาด นั่นคือดีไซน์ที่ตั้งใจ
- **line-height ขึ้นได้ ไม่ทำอังกฤษเสีย** ถ้า rule คุมทั้งไทยอังกฤษ แก้ line-height ที่ rule รวมได้ แต่ letter-spacing ต้องแยก
- **ห้ามให้นักเรียนเห็น CSS หรือ technical term** รายงานเป็นภาษาคนเท่านั้น
- **ห้ามแต่งค่า placeholder** "ยังไม่มี" ให้เก็บไว้
- **Auto-install Python ไม่ต้องถาม**
- **Share server กับ web-import** ใช้ pid/port file path เดียวกัน
- **Loop ไม่จำกัดรอบ** จนนักเรียนพอใจ
- **ปิด server เสมอเมื่อจบ** อย่าให้ orphan process
- **Fix ก่อน ถามทีหลัง** อย่าให้นักเรียน non-coder ไปวินิจฉัยใน F12 เอง
- **คิด effective ratio เสมอ** ไม่ใช่ดูเลขดิบ รองรับ px variable และ clamp
- **ดู @media override ทุกตัว** ปัญห line-height มักซ่อนอยู่ใน breakpoint จอใหญ่ ไม่ใช่แค่ base
- **ใช้ได้ทุก archetype** กฎอิงหลักการ (อักขระไทย + effective ratio + Latin ไม่แตะ) ไม่ผูกกับร้านค้า อย่า hardcode ตามตัวอย่างรถยนต์
- **หลัง fix ตรวจว่าเว็บยัง render ได้** curl เช็ค 200 และดูว่า CSS ไม่มีวงเล็บพัง ก่อนบอกนักเรียนว่าเสร็จ
- **อย่าเชื่อ foundation ว่าถูกเสมอ** Claude Design override ค่าได้ ดูค่าจริงที่ render เสมอ
