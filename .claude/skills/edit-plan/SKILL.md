---
name: edit-plan
description: Use when the student wants to change something they previously decided about their project (scope, writing, headline, framework, archetype, tone, CTA, features, etc.) without rerunning the entire scoping skill triggers include "แก้แผน", "เปลี่ยนใจ", "อยากแก้ headline", "เปลี่ยน archetype", "แก้ scope", "เปลี่ยน framework", "ปรับ tone", "แก้ CTA", "อยากเปลี่ยน", "edit plan", "edit-plan", or any similar request to modify an existing decision. Reads the marker blocks (web-scope, web-writing, future ux-brief) inside CLAUDE.md, lets the student pick which one to edit, then surgically updates just the field they want. Does NOT edit live HTML/CSS files (that is web-update skill). Built for absolute beginners with zero coding experience in pure Thai writes without em dash or comma between clauses.
---

# edit-plan แก้ไขข้อมูล project ที่บันทึกไว้

ช่วยนักเรียนแก้สิ่งที่เคยตัดสินใจไปแล้วใน `CLAUDE.md` โดยไม่ต้องรัน skill เดิมใหม่ทั้งหมด เช่นเปลี่ยน headline เปลี่ยน archetype ปรับ tone หรือเปลี่ยน framework

---

## กฎเด็ดขาด Thai content

**ห้ามใช้ em dash (—) และห้ามใช้ comma (,) แยก clause ใน Thai text**

ทำไม ทั้งคู่เป็น AI tell คนไทยจริงไม่ใช้

ใช้แทนแบบนี้
1. **เว้นวรรค (space)** วิธีหลัก default
2. **ขึ้นบรรทัดใหม่** ถ้าต้องการเบรกหนัก
3. **full stop** แยกประโยคใหม่

❌ "headline เก่า — ยาวไป"
❌ "headline เก่า, ยาวไป"
✅ "headline เก่า ยาวไป"

ตรวจ output ทุกครั้งก่อนเขียนกลับลง CLAUDE.md ถ้าเจอ em dash หรือ comma แยก clause แก้เป็น space ทันที

---

## กฎหลักอื่นๆ

- **ภาษาไทยเรียบง่าย** assume นักเรียนไม่เคยเขียน code
- **ห้ามแก้ block อื่นที่ student ไม่ได้เลือก** กระทบของที่ไม่ควรกระทบ
- **ห้ามลบ marker comments** `<!-- web-scope:v1 -->` และ `<!-- /web-scope -->` ต้องอยู่ครบ
- **ไม่แก้ HTML/CSS** ถ้า student อยากแก้เว็บ live แจ้งว่ายังไม่มี skill สำหรับ live edit ตอนนี้ทำได้แค่แก้แผนใน CLAUDE.md
- **ถ้า student อยากทำใหม่หมด** ส่งกลับไป skill เดิม (`/web-scope` หรือ `/web-writing`)

---

## รู้จัก marker blocks

| Block | ทำอะไร | จาก skill |
|-------|--------|----------|
| `<!-- web-scope:v1 -->` | ขอบเขตเว็บ archetype features form CTA channels backend | `/web-scope` |
| `<!-- web-writing:v1 -->` | headline sections CTA framework tone audience | `/web-writing` |
| `<!-- ux-brief:v1 -->` | (อนาคต) แผน UX/UI | `/ux-brief` |

ถ้าเจอ block อื่นที่ไม่รู้จัก แสดงชื่อ block ให้ student เห็น แล้วถามว่าอยากแก้ไหม

---

## Step 1 อ่าน CLAUDE.md

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| ไม่มีไฟล์ CLAUDE.md | แจ้ง "ยังไม่มี project ให้แก้นะ ลองทำ `/web-scope` ก่อนเพื่อตั้ง project แล้วค่อยกลับมาแก้ทีหลัง" |
| มีไฟล์แต่ไม่มี marker block | เหมือนด้านบน |
| มี block | ✅ ไปต่อ |

---

## Step 2 List Blocks ที่มี

### กรณีมี 1 block

ยืนยันกับ student

> "ตอนนี้ใน project คุณมีแค่ **[ชื่อ block เป็นไทย เช่น ขอบเขตเว็บ จาก /web-scope]** อยากแก้อันนี้ใช่ไหมคะ/ครับ"

### กรณีมี 2 block ขึ้นไป

ให้ student เลือก

> "ใน project คุณมีสิ่งเหล่านี้บันทึกไว้
> 🅰️ **ขอบเขตเว็บ** archetype features ฟอร์ม ช่องทางติดต่อ
> 🅱️ **เนื้อหาเว็บ** headline sections CTA น้ำเสียง
>
> อยากแก้อันไหนคะ/ครับ"

---

## Step 3 โชว์ Current Content

แสดงเนื้อหาปัจจุบันของ block ที่เลือก สวยอ่านง่าย เช่น

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ขอบเขตเว็บปัจจุบัน
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Archetype: Local Business
📄 เว็บนี้คือ: หน้าเว็บแนะนำร้านติดเครื่องเสียงรถยนต์
✨ ฟีเจอร์: ฟอร์มสั้นๆ รูปประกอบ ปุ่ม LINE
📞 ช่องทางติดต่อ: LINE, โทรศัพท์
📦 Database: ใช้ Supabase
📅 ตัดสินใจวันที่: 27-05-2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Step 4 ถามอยากแก้อะไร

แสดง menu ของสิ่งที่แก้ได้ตาม block

### ถ้าเลือก web-scope

> "อยากแก้ส่วนไหน
> 🅰️ Archetype (เปลี่ยนประเภทเว็บ)
> 🅱️ เว็บนี้คืออะไร (1 ประโยค)
> 🆎 ฟีเจอร์หลัก
> 🅓 ช่องทางติดต่อ
> 🅔 Backend (มี Supabase หรือไม่)
> 🅕 อื่นๆ บอกได้เลย
>
> ถ้าอยากทำใหม่ทั้งหมด พิมพ์ `/web-scope` ได้เลยนะ"

### ถ้าเลือก web-writing

> "อยากแก้ส่วนไหน
> 🅰️ Headline
> 🅱️ Sections (เนื้อหาตรงกลาง)
> 🆎 CTA (ปุ่ม)
> 🅓 น้ำเสียง
> 🅔 Framework (เปลี่ยนเป็น PAS / AIDA / BAB)
> 🅕 อื่นๆ บอกได้เลย
>
> ถ้าอยากทำใหม่ทั้งหมด พิมพ์ `/web-writing` ได้เลยนะ"

---

## Step 5 ทำการแก้

### กฎการแก้

1. **Surgical** แก้เฉพาะส่วนที่ student ระบุ ไม่กระทบส่วนอื่น
2. **ถ้าเป็นเนื้อหา Thai** apply กฎ em dash + comma ก่อนเขียน
3. **ถ้าเปลี่ยน framework ใน web-writing** ต้อง regenerate sections ทั้งหมดของ framework ใหม่ ใช้ข้อมูลเดิมจาก block (audience, pain, outcome, tone) ที่มีอยู่
4. **ถ้าเปลี่ยน archetype ใน web-scope** เตือน student ว่า web-writing อาจไม่ตรงกับ archetype ใหม่ ถามว่าอยากรัน `/web-writing` ใหม่ไหมหลังแก้เสร็จ
5. **อย่าแต่งข้อมูลเอง** ถ้า student ไม่ได้ระบุ ถามก่อน

### เคสพิเศษ

**"ทำใหม่ทั้งหมด"**

ส่ง student กลับไป skill เดิม

> "อ่ะ ถ้าอยากทำใหม่หมดเลย พิมพ์ `/web-scope` (หรือ `/web-writing`) ได้เลยนะ
> skill เดิมจะทับ block เก่าให้อัตโนมัติ คุณไม่ต้องเสียงานก่อนหน้านี้นะคะ/ครับ"

แล้วจบ skill

**"แก้เว็บ live"**

แจ้ง

> "skill นี้แก้ได้เฉพาะข้อมูล project (CLAUDE.md) นะคะ/ครับ
> ส่วนการแก้เว็บที่ live อยู่จริงๆ เรายังไม่มี skill สำหรับเรื่องนี้ตอนนี้
> ระหว่างนี้ลองบอก Claude ตรงๆ ว่าอยากแก้ HTML ตรงไหน Claude จะช่วยแก้ให้"

---

## Step 6 โชว์ Before/After

แสดงการเปลี่ยนแปลงให้ student เห็นชัด

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 การเปลี่ยนแปลง
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ก่อน
[เนื้อหาเก่าเฉพาะส่วนที่แก้]

🟢 หลัง
[เนื้อหาใหม่]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Step 7 ขอ Approve

> "ตรงตามที่อยากแก้ไหมคะ/ครับ
>
> ถ้าโอเค จะบันทึกลง CLAUDE.md ให้
> ถ้าอยากปรับเพิ่ม บอกได้เลย"

### Loop

- ถ้า student ขอแก้ต่อ ปรับตาม กลับไป Step 5
- ถ้า approve ไป Step 8

---

## Step 8 เขียนกลับลง CLAUDE.md

**ตรวจ plan mode ก่อน**
- ถ้าอยู่ใน **plan mode** call `ExitPlanMode` พร้อมเนื้อหาที่จะเขียน รอ approve ค่อยเขียน
- ถ้า**ไม่ได้อยู่ใน plan mode** เขียนได้เลย

**กฎการเขียน**
- หา marker block เดิม
- แทนที่**เฉพาะ field ที่แก้** keep field อื่นๆ ในส่วน block เหมือนเดิม
- update "ตัดสินใจวันที่" เป็นวันที่ปัจจุบัน (DD-MM-YYYY)
- ห้ามแก้ block อื่นที่ไม่ได้เลือก

---

## Step 9 ปิดท้าย

> "อัพเดทเรียบร้อยแล้วค่ะ/ครับ 🎉
>
> 💾 บันทึกใน CLAUDE.md ของ project แล้ว
> ✨ Claude จะใช้ข้อมูลใหม่นี้ในการทำงานต่อๆ ไป
>
> [ถ้าเปลี่ยน archetype หรือเปลี่ยน framework เพิ่มประโยคนี้ด้วย]
> 💡 เนื่องจากคุณเปลี่ยน [archetype/framework] อาจอยากรัน `/web-writing` ใหม่
> เพื่อให้เนื้อหาเว็บตรงกับการเปลี่ยนแปลงนี้"

---

## สิ่งที่ต้องระวัง

- **กฎ em dash + comma** ตรวจทุกครั้งก่อนเขียนกลับ
- **ห้ามลบ marker comments** `<!-- web-scope:v1 -->` และ `<!-- /web-scope -->` ต้องอยู่ครบ
- **ห้ามแก้ block อื่น** student เลือกแก้ web-scope ห้ามแตะ web-writing
- **ห้ามแต่งข้อมูลที่ student ไม่ได้บอก** ถ้าไม่ชัด ถามก่อน
- **เปลี่ยน archetype = แนะนำรัน web-writing ใหม่** เพราะ writing ผูกกับ archetype
- **เปลี่ยน framework ใน web-writing = regenerate sections ใหม่** ใช้ข้อมูลเดิมที่มี
- **ห้ามรวบคำถาม** ถาม 1 ข้อต่อ 1 รอบ
- **ถ้า student อยากแก้ live website** แจ้งว่า skill นี้ทำได้แค่แผน เว็บจริงต้องบอกตรงๆ
