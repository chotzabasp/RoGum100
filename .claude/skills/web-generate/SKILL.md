---
name: web-generate
description: Path B engine generates a landing page directly in Claude Code from CLAUDE.md by enforcing a creativity prompt directly (no codebase) instead of going through claude.ai/design. This is the deliberately MORE creative path Claude Design plus the codebase is the safe path Path B is the bold one so it must NOT read the codebase. Normally invoked by web-design Step 10.5 as an instant preview placed on a draft branch but can also be triggered directly by a student who wants Claude Code to try a design triggers include "ให้ Claude Code ออกแบบให้", "generate เว็บใน Claude Code", "ลองออกแบบเลย", "web-generate", or any similar request to build the page directly here. Reads the web-scope web-writing and web-design blocks from CLAUDE.md then writes index.html styles.css scripts.js at project root. Maximizes creativity by default keeping only the hard guardrails (Thai punctuation rules strict 3 image ratios works great on both mobile and desktop respects prefers-reduced-motion). Does NOT run web-finish and does NOT touch git the caller owns branch and merge. Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# web-generate สร้างหน้าเว็บตรงใน Claude Code (Path B)

ทางเลือกที่ Claude Code ออกแบบหน้าเว็บให้ตรงนี้เลย โดยอ่าน context จาก CLAUDE.md แล้ว **บังคับ prompt ความครีเอทีฟตรงๆ ไม่อ่าน codebase** แทนการไป claude.ai/design

**ทำไมไม่อ่าน codebase** Path A (Claude Design + codebase) คือทางปลอดภัย codebase เป็น FOUNDATION + บัญชี anti-slop ที่ห้ามลูกเล่นเยอะ ผลเลยออกมา restrained คล้ายกันทุกเว็บ Path B ตั้งใจให้เป็นทางที่ **กล้าและครีเอทีฟกว่า** ถ้า Path B อ่าน codebase เดียวกันมันจะ converge ไปเหมือน Claude Design ทันที เพราะงั้น Path B ใช้ prompt บังคับความครีเอทีฟตรงๆ เหลือแค่ guardrails ที่จำเป็นจริงๆ

ปกติถูกเรียกโดย `web-design` Step 10.5 เป็นตัวอย่างด่วนวางไว้ในฉบับร่าง student เปิดดูได้ทันทีระหว่างรอ Claude Design

---

## กฎเด็ดขาด Thai content

ห้าม em dash (—) ห้าม comma (,) แยก clause ใน Thai text ใช้ space เท่านั้น

---

## กฎหลัก

- **ไม่ยุ่งกับ git** ไม่ checkout ไม่ commit ไม่ merge คนเรียก (web-design) เป็นคนดูแลฉบับร่างเอง
- **ไม่เรียก web-finish** หน้าที่เก็บงานภาษาไทย placeholder อยู่ที่ web-finish ตอน student เลือกใช้ Path B แล้ว
- **ไม่อ่าน codebase** Path B ใช้ prompt บังคับความครีเอทีฟตรงๆ (อ่าน codebase = converge เหมือน Claude Design ผิดจุดประสงค์ของ Path B)
- **ครีเอทีฟเต็มที่เป็น default** ไม่ใช่โหมดพิเศษ คุมแค่ guardrails ที่จำเป็น (กฎภาษาไทย สัดส่วนรูป 3 แบบ สวยทั้งมือถือและคอม เคารพ prefers-reduced-motion)
- **ไม่ใช้ Claude Preview sidebar** ไม่ spin server การ preview เป็นงานของ web-finish

---

## Step 1 อ่าน context

อ่าน `CLAUDE.md` ของ project ต้องมีครบ

| Block | จำเป็น | ใช้ทำอะไร |
|-------|--------|----------|
| `<!-- web-scope:v1 -->` | ✅ | archetype business audience primary CTA channels |
| `<!-- web-writing:v1 -->` | ✅ | headline sections CTA framework tone copy ทั้งหมด |
| `<!-- web-design:v1 -->` | ✅ | สี 60/30/10 dials reference remix numerals |

ถ้าขาด block ใด แจ้งให้ทำ skill ที่เกี่ยวข้องก่อน (`/web-scope` `/web-writing` `/web-design`) แล้วจบ

**ไม่ต้องอ่าน codebase** Path B บังคับ prompt ตรงๆ ใน Step 2 แทน

---

## Step 2 Generate (enforce prompt ตรงๆ ไม่อ่าน codebase)

ใช้ prompt ด้านล่างเป็น brief หลัก เติม content และสี และ dials จริงจาก CLAUDE.md ลงในช่องว่าง แล้วลงมือสร้าง
นี่คือ prompt เดียวกับที่ใช้สร้างตัวอย่างพรีเมียม (เน้นครีเอทีฟ) ห้ามลดทอนความครีเอทีฟลงไปเป็นเทมเพลตปลอดภัย

```
READ CONTEXT
- อ่าน CLAUDE.md ของ project ใช้ block web-scope web-writing web-design
  (headline เนื้อหา Before/After/Bridge หรือ sections, trust points, CTA, สี 60/30/10, dials)

TOP PRIORITY
- ต้องสวยและใช้งานได้ยอดเยี่ยมทั้งบนมือถือและคอม ข้อนี้มาก่อนเสมอ

CREATIVE FREEDOM (จุดประสงค์หลักของ Path B)
- ครีเอทีฟให้สุด เซอร์ไพรส์ด้วยโครงสร้าง จังหวะ และรายละเอียด
- หา visual metaphor ที่แข็งแรงที่สุดในเนื้อหา แล้วสร้างทั้งหน้ารอบ metaphor นั้น
- คิด layout component และ motion ของตัวเอง อย่าหยิบเทมเพลตปลอดภัยมาใช้

USE LOOSELY (เป็นหมุดยึด ไม่ใช่กุญแจมือ)
- palette จาก web-design (60/30/10) ปรับ warm tint shade ได้อิสระ ตราบใดที่ยังอ่านออกว่าเป็นแบรนด์เดิม
- vibe + dials จาก web-design (reference remix, Variance, Motion, Density) ให้ Variance คุมความกล้าจริง
- นำด้วย proof ที่จริงและแข็งที่สุดของแบรนด์

IMAGE RATIOS (เข้มงวด)
- รูปทุกอันใช้ได้แค่ 3 สัดส่วน 16/9 นอน, 1/1 จัตุรัส, 9/16 ตั้ง เท่านั้น
- ไม่มีสัดส่วนอื่น รูปเต็มกรอบด้วย object-fit: cover

NON-NEGOTIABLE (มีแค่นี้)
- ข้อความที่มองเห็นทั้งหมดเป็นภาษาไทย เอาจาก web-writing แบบ verbatim ห้ามแต่งตัวเลขเกินที่ระบุ
  ห้าม em dash ห้าม comma คั่นประโยคไทย ใช้ space เท่านั้น
- เก็บ brand placeholder ไว้ [ชื่อร้าน] [LOGO] [LINE ID] ฯลฯ
- ปุ่มหลักยังเป็น primary CTA จาก web-scope (เช่น ทักไลน์ปรึกษาฟรี ลิงก์ไป LINE)

OUTPUT
- สร้างไฟล์ index.html styles.css scripts.js ที่ project root (HTML CSS JS ล้วน ไม่มี framework)
```

ก่อนจบเช็ค guardrails ให้ครบ ภาษาไทยถูกกฎ (ไม่มี em dash ไม่มี comma คั่น) รูปอยู่ใน 3 สัดส่วน
หน้าไม่ล้นแนวนอนบนมือถือ (ไม่มี horizontal scroll) สวยทั้งมือถือและคอม เคารพ prefers-reduced-motion

---

## Step 3 จบ (ส่งคืนคนเรียก)

แจ้งสั้นๆ ว่าสร้างไฟล์เสร็จแล้ว 3 ไฟล์ จากนั้น **คืนการควบคุมให้คนเรียก** (web-design จะ commit ลงฉบับร่างแล้วสลับกลับ main เอง)

ถ้า student เรียก web-generate เองตรงๆ (ไม่ได้ผ่าน web-design) แจ้งว่าดูได้ที่ไฟล์ในโฟลเดอร์ ถ้าอยากเก็บงาน + เปิด preview ให้พิมพ์ `/web-finish`

---

## ครีเอทีฟคือ default (ไม่มีโหมดปลอดภัย)

Path B ครีเอทีฟเต็มที่เป็น default อยู่แล้ว ไม่มีโหมด "อ่าน codebase ปลอดภัย" เพราะนั่นคือหน้าที่ของ Path A (Claude Design + codebase)
ถ้า student อยากได้แบบปลอดภัย on-brand ตาม codebase ให้แนะนำไปใช้ Path A (claude.ai/design) แทน

ห้ามลดทอน prompt ใน Step 2 ลงเป็นเทมเพลตปลอดภัย แม้เนื้อหาจะดู straightforward ก็ตาม จุดเด่นของ Path B คือความกล้า

---

## สิ่งที่ต้องระวัง

- **ไม่ยุ่ง git** ปล่อยให้ web-design จัดการฉบับร่าง
- **ไม่เรียก web-finish ไม่ spin server** นั่นคืองานของ flow หลังเลือก Path B
- **ไม่อ่าน codebase** Path B บังคับ prompt ตรงๆ การอ่าน codebase จะทำให้ converge เหมือน Claude Design
- **ครีเอทีฟเต็มที่** หา visual metaphor ในเนื้อหาแล้วสร้างรอบมัน อย่าหยิบเทมเพลตปลอดภัย
- **content verbatim จาก web-writing** ห้ามแต่งคำหรือตัวเลขเอง
- **No em dash no comma** ใน Thai content
- **guardrails ที่เหลือ** สัดส่วนรูป 3 แบบ สวยทั้งมือถือและคอม ไม่ล้นแนวนอน เคารพ prefers-reduced-motion
