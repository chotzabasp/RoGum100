---
name: web-update
description: Use when the student wants to change the actual words on a page that already exists. This is different from edit-plan (which only edits the decision notes in CLAUDE.md not the page) and different from web-style (which changes the look not the words) and different from web-page (which adds a whole new page). web-update finds the real text in the HTML and swaps it safely on a draft branch so the student previews the change before it ever goes live. Text is the focus but it is NOT a wall if the student also wants a color or style change mid-edit it hands off to web-style and keeps going never blocks them. Triggers include "แก้ข้อความ", "เปลี่ยนคำ", "แก้ headline", "เปลี่ยนหัวข้อ", "แก้ข้อความบนเว็บ", "เปลี่ยนข้อความปุ่ม", "แก้คำผิด", "เปลี่ยนคำพูด", "อัปเดตข้อความ", "แก้เนื้อหา", "update text", "edit content", "change wording", "fix typo", "web-update", or any similar request to change copy on an existing page. Works on a draft branch by default (reuses draft-mode) so the live site is never touched until the student approves. Edits only the text content never the tags classes or structure. Built for absolute beginners with zero coding knowledge shows before and after for every change works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-update แก้ข้อความบนเว็บที่มีอยู่แล้ว

นักเรียนอยากเปลี่ยนคำบนหน้าเว็บ เช่น แก้ headline แก้คำผิด เปลี่ยนข้อความปุ่ม web-update หาข้อความจริงใน HTML แล้วเปลี่ยนให้ **อย่างปลอดภัยบน draft branch** นักเรียนได้ดู preview ก่อนที่จะขึ้นเว็บจริง

แก้ **ข้อความ** เป็นหลัก แต่ถ้านักเรียนอยากเปลี่ยนสี/สไตล์ด้วยระหว่างทาง **ไม่ขวาง** ส่งต่อให้ web-style แล้วทำต่อ

---

## กฎเด็ดขาด Thai content

ห้าม em dash (—) ห้าม comma (,) แยก clause ใน Thai text ใช้ space เท่านั้น

---

## ขอบเขต (soft boundary ไม่ใช่กำแพง)

| นักเรียนอยาก | ใคร | web-update ทำไง |
|--------------|-----|------------------|
| เปลี่ยน **คำ/ข้อความ** บนหน้า | **web-update** | ทำเลย |
| เปลี่ยน **สี/ทรง** component | web-style | ไม่ขวาง บอก "อันนี้เปลี่ยนสไตล์นะ ขอเรียก /web-style ต่อให้เลยไหม" แล้วส่งต่อ |
| เปลี่ยน **การตัดสินใจ** (archetype scope framework) | edit-plan | บอกแล้วส่งต่อ |
| เพิ่ม **หน้าใหม่** | web-page | บอกแล้วส่งต่อ |

หลักคือ text คือเลนหลัก ไม่ใช่ประตูล็อก ถ้านักเรียนอยากได้มากกว่าข้อความ ส่งต่อ skill ที่ใช่ แล้วทำต่อให้ลื่น

---

## กฎหลัก (lock ไว้)

1. **แก้แค่ text content ห้ามแตะ tag class attribute structure** เปลี่ยนคำที่อยู่ระหว่าง tag เท่านั้น (เช่น `<h1>เก่า</h1>` เป็น `<h1>ใหม่</h1>`)
2. **ทำบน draft branch เสมอ (default)** เรียก draft-mode ห่อการแก้ นักเรียน preview ก่อน live ไม่แตะเว็บจริงจนกว่าจะอนุมัติ
3. **generate-then-confirm** โชว์ ก่อน → หลัง ทุกจุด ห้ามเดาข้อความใหม่เอง ถ้าไม่ชัดถาม
4. **exact match เท่านั้น** เปลี่ยนข้อความที่นักเรียนระบุชัด ถ้าเจอหลายที่ถามว่าจุดไหน
5. **ภาษาไทยตามกฎ** ข้อความใหม่ที่พิมพ์ลงเว็บห้าม em dash ห้าม comma แยก clause
6. **ไม่ผูก marker** การแก้ข้อความไม่ต้องติด marker (เป็น content ไม่ใช่ feature) audit ไม่ต้องจำ

---

## flow

```
นักเรียนพูด "แก้ข้อความ X เป็น Y" หรือ "เปลี่ยน headline"
   → Step 0 ตรวจความพร้อม
   → Step 1 เข้าใจว่าจะแก้อะไรเป็นอะไร
   → Step 2 เปิด draft branch (draft-mode) กันพังเว็บจริง
   → Step 3 หาข้อความจริงใน HTML (ทุกหน้า)
   → Step 4 โชว์ ก่อน → หลัง ให้ยืนยัน
   → Step 5 แก้เฉพาะ text
   → Step 6 preview localhost
   → Step 7 draft-mode ปิดงาน (ใช้เลย / ทิ้ง / เก็บไว้ก่อน)
```

---

## Step 0 ตรวจความพร้อม

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ |

มี `pages/` หลายหน้า สแกนทุกหน้า

---

## Step 1 เข้าใจการแก้

นักเรียนบอกได้ 2 แบบ

- **ชัด** "เปลี่ยน 21 วัน เป็น 30 วัน" → รู้ทั้งของเก่าของใหม่ ไป Step 2
- **กว้าง** "อยากแก้ headline" → ถามว่าจะเปลี่ยนเป็นอะไร หรืออ่าน headline ปัจจุบันให้ฟังแล้วถามว่าจะแก้ตรงไหน

ถ้านักเรียนขอเปลี่ยน **สี/สไตล์** (ไม่ใช่ข้อความ) ส่งต่อ web-style (ดู soft boundary)

---

## Step 2 เปิด draft branch

เรียก skill `draft-mode` เพื่อทำงานบน branch แยก นักเรียนไม่ต้องรู้จัก git draft-mode จัดการให้ + ตอนจบมี 3 ทางเลือก (ใช้เลย / ทิ้ง / เก็บไว้)

> "ขอลองแก้ในพื้นที่ปลอดภัยก่อนนะคะ/ครับ เว็บจริงยังไม่เปลี่ยน พอใจแล้วค่อยเอาขึ้น"

(ถ้าเป็นการแก้คำผิดเล็กๆ ที่ชัวร์มาก นักเรียนอาจขอแก้ตรงเลย ก็ได้ แต่ default คือ branch ปลอดภัยกว่า)

---

## Step 3 หาข้อความจริงใน HTML

scan `index.html` + ทุก `pages/*.html` หา **ข้อความเป้าหมายแบบ exact**

- เจอ 1 ที่ → ไป Step 4
- เจอหลายที่ (เช่นคำเดียวกันโผล่หลายจุด) → โชว์แต่ละจุดพร้อม context สั้นๆ ถามว่าจะแก้จุดไหน หรือทุกจุด
- ไม่เจอ → บอกตรงๆ ว่าหาไม่เจอข้อความนี้ ขอให้ copy คำที่เห็นบนเว็บมาเป๊ะ หรือบอก section
- **ข้อความใน widget (`data-cnc-widget`)** แก้ได้ (เป็น content เช่นรีวิว) แต่แก้แค่ตัวอักษร ห้ามแตะ markup ของ widget

ระวัง อย่าจับข้อความที่อยู่ใน tag/attribute (เช่นใน `class="..."` หรือ `alt="..."`) ถ้าจะแก้ alt บอกให้ชัดว่าแก้คำอธิบายรูป

---

## Step 4 โชว์ ก่อน → หลัง (generate-then-confirm)

```
ขอแก้ตรงนี้นะคะ/ครับ

ก่อน  21 วัน หายใจช้าลง
หลัง  30 วัน หายใจช้าลง

ตรงนี้ถูกไหม ถ้าใช่ผมแก้ให้เลย ถ้าอยากปรับคำบอกได้
```

ถ้านักเรียนให้ผมร่างคำใหม่ (เช่น "ช่วยเขียน headline ใหม่ให้สั้นลง") ร่าง 2-3 ตัวเลือกจาก tone เดิม (อ่าน CLAUDE.md web-writing) ให้เลือก ห้าม finalize เอง

---

## Step 5 แก้เฉพาะ text

ใช้ Edit แก้เฉพาะข้อความระหว่าง tag **เก็บ tag class attribute โครงสร้างเดิมครบ**

- ข้อความไทยใหม่ตามกฎ ห้าม em dash ห้าม comma แยก clause
- ถ้าคำยาวขึ้นเยอะ เตือนว่าอาจกระทบ layout บนมือถือ (ดูใน preview)

---

## Step 6 preview localhost

เปิด preview ให้เห็นผล **เช็คพอร์ตว่างก่อน bind** (กฎเดียวกับ web-finish/web-style)

```
PY: macOS ใช้ python3 เสมอ (ห้าม python เปล่า มักไม่มีบน Mac) / Windows ลอง python ก่อน ไม่มีค่อยใช้ py
หาพอร์ตว่างตัวแรกจาก 8000 8080 8888 3000
  Windows (Test-NetConnection localhost -Port <p> -WarningAction SilentlyContinue).TcpTestSucceeded
  macOS   lsof -i :<p>
start จาก project root ใช้ $PY -m http.server <พอร์ต> --directory .
verify path จริงได้ 200 แล้วบอกพอร์ตจริง
```

บอกนักเรียนเลื่อนไปดูจุดที่แก้

---

## Step 7 draft-mode ปิดงาน

ให้ draft-mode รัน flow ปิด

```
ดูแล้วโอเคไหมคะ/ครับ
1. ใช้เลย      เอาขึ้นเว็บจริง (merge + พร้อม deploy)
2. ทิ้ง        ไม่เอา กลับไปแบบเดิม
3. เก็บไว้ก่อน  เก็บ branch ไว้ค่อยตัดสินใจ
```

ถ้า "ใช้เลย" หลัง merge แนะนำ /save-work + deploy

---

## Edge cases

- **หาข้อความไม่เจอ** ขอให้ copy คำที่เห็นบนหน้าจอมาเป๊ะ หรือบอก section
- **เจอหลายจุด** ถามจุดไหน หรือทุกจุด อย่าเดา
- **นักเรียนอยากเปลี่ยนสี/ทรง** ส่งต่อ web-style ไม่ขวาง
- **นักเรียนอยากเปลี่ยนการตัดสินใจ** (เปลี่ยน archetype CTA framework) ส่งต่อ edit-plan
- **นักเรียนอยากเพิ่มหน้า** ส่งต่อ web-page
- **แก้เยอะหลายจุดรวด** ทำทีละจุด โชว์ ก่อน → หลัง ครบทุกจุดก่อน apply
- **ข้อความซ้ำกับ code** (เช่นคำที่ดันไปตรงกับ class name) match เฉพาะที่อยู่ระหว่าง tag เป็นเนื้อหา ไม่แตะใน attribute

---

## FYI

- การแก้ข้อความไม่กระทบความปลอดภัย/ความเร็ว/SEO โครงสร้าง (แก้แค่คำ)
- ทำบน draft branch เสมอ พังยาก ถ้าไม่ชอบกด ทิ้ง ได้
- อยากเปลี่ยนหลายอย่าง (คำ + สี + เพิ่มหน้า) ทำเป็นรอบๆ แต่ละ skill รับช่วงกันได้
