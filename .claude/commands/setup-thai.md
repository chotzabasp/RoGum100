# /setup-thai

ติดตั้งกฎ Thai punctuation ลงใน memory ของ project นี้ ครั้งเดียวจบ ใช้ตลอด project

## Usage

```
/setup-thai
```

ไม่ต้องส่ง argument อะไร พิมพ์คำเดียว

---

## กฎหลัก

- **สื่อสารภาษาไทยเสมอ** ห้ามให้ student เห็น error
- **ใช้ space แทน em dash และ comma แยก clause** ในทุก Thai output (รวมข้อความทักทาย และข้อความแจ้งสำเร็จในไฟล์นี้)
- **idempotent** student รันซ้ำได้ไม่พัง

---

## ขั้นตอน

### ขั้น 1 รู้ตำแหน่ง memory ของ project

memory ของ Claude Code อยู่ที่ `~/.claude/projects/<project-id>/memory/`
- project-id คือ encoding ของ working directory ปัจจุบัน
- Claude Code รู้ตำแหน่งนี้อัตโนมัติ ไม่ต้องคำนวณเอง

ใช้ tool `Write` ตรงๆ ไปที่ path เต็ม Claude Code จะแก้ให้

### ขั้น 2 เขียนไฟล์ `no-em-dash-in-thai.md`

เนื้อหาที่ต้องเขียน

```markdown
---
name: no-em-dash-in-thai
description: Thai punctuation rules no em dash no comma between clauses use space only because both are AI tells
metadata:
  type: feedback
---

ห้ามใช้ em dash (—) **และห้ามใช้ comma (,) แยก clause** ใน Thai text ทุกชนิด ทั้งใน output ทั่วไป ใน skill output ใน CLAUDE.md และในการคุยกับ user เป็นภาษาไทย

**Why** ทั้งคู่เป็น AI tell ที่ชัดเจนในการเขียนไทย
- em dash ภาษาไทยไม่ใช้
- comma แบบฝรั่ง (แยก clause กลางประโยค) ภาษาไทยไม่ใช้เช่นกัน
- Thai writing ใช้ "เว้นวรรค" (space) เป็น punctuation หลักของประโยค

**How to apply**
- แทน em dash และ comma ด้วย **space** (เว้นวรรค) เป็น default ทุกกรณี
- ถ้าต้องการเบรกหนัก ขึ้นบรรทัดใหม่ หรือใช้ full stop
- comma ใช้ได้เฉพาะใน list ของ noun (เช่น "สีแดง สีเขียว สีน้ำเงิน" จริงๆ space ก็พอ)
- กฎนี้ใช้กับ Thai text เท่านั้น English text ใช้ em dash + comma ปกติได้

ตัวอย่าง

❌ "ปัญหาไม่ใช่ลำโพง — แต่อยู่ที่การติดตั้ง"
❌ "ปัญหาไม่ใช่ลำโพง, แต่อยู่ที่การติดตั้ง"
✅ "ปัญหาไม่ใช่ลำโพง แต่อยู่ที่การติดตั้ง"
✅ "ปัญหาไม่ใช่ลำโพง. ปัญหาอยู่ที่การติดตั้ง"
```

### ขั้น 3 จัดการ MEMORY.md index

อ่าน MEMORY.md ที่ memory folder

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| ไม่มีไฟล์ | สร้างใหม่ ใส่ header + บรรทัด index |
| มีไฟล์แต่ยังไม่มี entry นี้ | append บรรทัดใหม่ |
| มี entry อยู่แล้ว | ไม่ต้องแก้ ข้ามได้ |

Format ของ MEMORY.md

```markdown
# Memory index

- [No em dash in Thai](no-em-dash-in-thai.md) Thai punctuation rules no em dash no comma between clauses use space only
```

ถ้ามี entry อื่นอยู่แล้ว ใส่บรรทัดนี้ต่อท้ายโดยไม่ทับของเดิม

### ขั้น 4 แจ้งสำเร็จ

ข้อความตัวอย่าง (ใช้ space ไม่ใช้ em dash)

> "ติดตั้งกฎ Thai เรียบร้อยแล้วค่ะ/ครับ 🎉
>
> ตั้งแต่ตอนนี้ Claude จะเขียนภาษาไทยของคุณโดยไม่ใช้ em dash (—) และไม่ใช้ comma (,) แยกประโยคแบบฝรั่งแล้วนะคะ/ครับ
>
> ใช้ได้กับทุกการคุยกับ Claude ใน project นี้ ไม่ว่าจะเขียน Facebook post แปลข้อความ หรือใช้ skill ใดก็ตาม
>
> ถ้าเปลี่ยน project อย่าลืมรัน `/setup-thai` ใหม่นะคะ/ครับ"

---

## Edge cases

### Student รันซ้ำ

ถ้าเจอไฟล์ memory อยู่แล้ว
- ถ้าเนื้อหาเหมือนเดิม แจ้ง "ติดตั้งไว้แล้วนะคะ/ครับ ไม่ต้องทำอะไรเพิ่ม"
- ถ้าเนื้อหาต่างจาก current version ทับให้ใหม่ แจ้ง "อัพเดทกฎ Thai เป็นเวอร์ชั่นล่าสุดแล้วค่ะ/ครับ"

### Student อยู่ใน Plan Mode

ถ้าอยู่ใน plan mode call `ExitPlanMode` พร้อมเนื้อหาที่จะเขียน รอ approve ค่อยเขียน

### ไม่สามารถเขียน memory ได้ (permission error)

แจ้งข้อความสุภาพ บอก path ที่พยายามเขียน student อาจต้องตรวจสิทธิ์โฟลเดอร์
