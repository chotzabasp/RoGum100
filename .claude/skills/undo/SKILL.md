---
name: undo
description: Use when the student wants to roll back the most recent change to their live website — works for both regular commits AND merge commits. Triggers include "ย้อน", "ย้อนกลับ", "ย้อนเว็บกลับ", "ย้อนการเปลี่ยนแปลง", "ย้อน commit ล่าสุด", "ย้อน push ล่าสุด", "ย้อนการ merge", "เว็บพัง ย้อนกลับ", "ขอย้อนคืน", "เปลี่ยนใจ ขอเว็บแบบเดิม", "/undo", "undo", "rollback", or any similar request to revert the most recent update on the main branch. Safe rollback using git revert (creates a new commit that undoes the previous one — doesn't rewrite history, safe for already-pushed code). Auto-detects whether the last commit is a merge or a regular commit and handles each correctly. Built for absolute beginners — shows what will be undone before doing it, asks for confirmation, then pushes the revert to GitHub automatically.
---

# undo — ย้อนการเปลี่ยนแปลงล่าสุดบนเว็บจริง ⏪

ย้อน commit ล่าสุดบน main (ทั้ง merge commit จาก draft-mode หรือ commit ธรรมดา) ให้เว็บจริงกลับไปเหมือนเดิม โดยใช้ `git revert` ที่ปลอดภัย (ไม่ rewrite history)

---

## กฎหลัก

- **ภาษาไทยเรียบง่ายเสมอ** — ห้ามใช้ "revert", "commit", "HEAD", "merge"
- **แสดงสิ่งที่จะย้อนก่อนเสมอ** — บอกนักเรียนว่าจะย้อนอะไร พร้อมไฟล์ที่จะเปลี่ยน
- **ยืนยันก่อนทำ** — ห้ามย้อนโดยไม่ถาม
- **ใช้ revert ไม่ใช่ reset** — revert ปลอดภัยกว่าเพราะไม่ rewrite history (เว็บที่ deploy แล้วใช้งานได้ปกติ)
- **Windows** → `PowerShell` / **macOS** → `Bash`

---

## ขั้นตอนที่ 1 — ตรวจ state

รัน:
- `git branch --show-current` → ควรเป็น `main` (ถ้าอยู่ draft branch แจ้งสุภาพ + แนะนำ)
- `git log -1 --format="%H|%s|%P"` → ดู commit ล่าสุด (hash, message, parents)

**ตรวจประเภท commit:**
- จำนวน parent มี 2 ตัว (`%P` มี space คั่น) = **merge commit** (จาก draft-mode)
- 1 parent = **commit ธรรมดา** (push ตรงๆ)

### Edge cases

| สถานการณ์ | การจัดการ |
|----------|----------|
| อยู่ใน draft branch | "ตอนนี้คุณอยู่ในฉบับร่าง ไม่ใช่เว็บจริง ถ้าอยากย้อนเว็บจริง พิมพ์ `/draft-mode` เลือก 'ทิ้ง' ฉบับร่างนี้ก่อน" |
| commit ล่าสุดเป็น commit แรกของ repo (ไม่มี parent) | "ไม่มีอะไรให้ย้อนคะ/ครับ — นี่คือเริ่มต้นของ project" |
| main อยู่หลัง origin/main (ยังไม่ pull) | `git pull origin main --no-edit` ก่อน |

---

## ขั้นตอนที่ 2 — แสดงสิ่งที่จะย้อน

รัน:
- `git log -1 --format="%h %s (%ar)"` → header สั้นๆ
- `git show --stat HEAD` → list ไฟล์ที่เปลี่ยน

แสดงให้นักเรียน:

> "🔍 **กำลังจะย้อนการเปลี่ยนแปลงนี้:**
>
> 📝 **ชื่อ:** [commit message]
> 🕐 **เมื่อ:** [N นาทีที่แล้ว / กี่ชั่วโมงที่แล้ว]
> 📁 **ไฟล์ที่จะกลับเป็นเหมือนเดิม:**
>   • [file 1]
>   • [file 2]
>   • [file 3]
>
> ⚠️ หลังย้อนแล้ว เว็บจริงจะกลับไปเหมือนก่อนการเปลี่ยนแปลงนี้
>
> ✅ ยืนยันย้อนเลยไหมคะ/ครับ? (ตอบ 'ใช่' หรือ 'ยกเลิก')"

---

## ขั้นตอนที่ 3 — ทำ revert

ถ้านักเรียนยืนยัน:

### เตรียม commit message ภาษาไทย

อ่านชื่อ commit เดิมไว้ก่อน revert (เพราะหลัง revert HEAD จะเปลี่ยน) **เก็บใน variable ตาม OS**

**macOS (Bash)**
```bash
ORIGINAL_MSG=$(git log -1 --format=%s HEAD)
```

**Windows (PowerShell)**
```powershell
$ORIGINAL_MSG = (git log -1 --format=%s HEAD)
```

**กฎ pattern:** หลัง revert ต้อง **amend commit message** ทันที เพื่อให้เป็นไทย — เพราะ `git revert` ไม่รับ flag `--message` (`-m` ของ revert = mainline number)

### 3.A — ถ้าเป็น merge commit (2 parents)

**macOS**
```bash
git revert -m 1 HEAD --no-edit
git commit --amend -m "ย้อนกลับ: $ORIGINAL_MSG"
```

**Windows**
```powershell
git revert -m 1 HEAD --no-edit
git commit --amend -m "ย้อนกลับ: $ORIGINAL_MSG"
```

- `-m 1` = บอก revert ฝั่ง main ไว้ (mainline)
- `--no-edit` = ไม่เปิด editor
- `--amend` = แก้ commit message ที่เพิ่งสร้างให้เป็นไทย

### 3.B — ถ้าเป็น commit ธรรมดา (1 parent)

**macOS**
```bash
git revert HEAD --no-edit
git commit --amend -m "ย้อนกลับ: $ORIGINAL_MSG"
```

**Windows**
```powershell
git revert HEAD --no-edit
git commit --amend -m "ย้อนกลับ: $ORIGINAL_MSG"
```

**สำคัญ** ทั้ง 2 OS ใช้ `$ORIGINAL_MSG` ใน double-quoted string ได้ — Bash expand `$VAR` ตามปกติ PowerShell expand `$VAR` ใน double quote เช่นเดียวกัน → command เดียวกันใช้ได้แต่ต้อง set variable ตาม syntax OS ในขั้นแรก

### 3.C — ถ้า revert มี conflict

ส่งต่อไป conflict handler ใน `draft-mode` (logic เดียวกัน — ใช้แบบเก่า/ใหม่/ทีละจุด/ลองรวมให้) — เพราะ logic ซ้ำกัน

---

## ขั้นตอนที่ 4 — Push ขึ้น GitHub

```
git push origin main
```

ผลลัพธ์ที่คาด:
- ✅ push สำเร็จ → ไปขั้น 5
- ❌ `rejected` → `git pull origin main --no-edit` แล้ว push ใหม่
- ❌ network error → แจ้ง "เน็ตมีปัญหา ลองใหม่นะคะ/ครับ"

---

## ขั้นตอนที่ 5 — Verification (ห้ามข้าม)

รัน `git status` → ต้องเห็น `up to date with 'origin/main'` และ `nothing to commit, working tree clean`

ถ้าไม่ผ่าน → ย้อนกลับไปขั้น 4

---

## ขั้นตอนที่ 6 — แจ้งสำเร็จ + meta-undo hint

> "✅ ย้อนเรียบร้อยแล้วค่ะ/ครับ! ⏪
>
> 🏠 **เว็บจริง:** กลับไปเหมือนก่อนการเปลี่ยนแปลงล่าสุดแล้ว
> 💾 **บันทึก:** อัพขึ้น GitHub เรียบร้อย
>
> 💡 *ถ้าเปลี่ยนใจอีกครั้ง อยากเอาของที่เพิ่งย้อนกลับมาใช้ พิมพ์ `/undo` อีกครั้งจะย้อน 'การย้อน' นี้ได้*"

---

## สิ่งที่ต้องระวัง

- **ห้ามใช้ `git reset --hard`** เด็ดขาด — rewrite history = อันตราย (เว็บที่ deploy แล้วอาจ break)
- **ห้ามย้อนหลายขั้นพร้อมกัน** ใน MVP — รุ่นนี้ย้อนแค่ commit ล่าสุด ถ้านักเรียนอยากย้อนเก่ากว่านั้น → "ลองย้อนทีละขั้น พิมพ์ `/undo` อีกครั้งหลังย้อนรอบแรกเสร็จ"
- **ห้าม force push** ไม่ว่ากรณีใด
- ถ้าเจอ error ที่ skill นี้ไม่ครอบคลุม → อธิบายเป็นไทย + ให้นักเรียน 2-3 ทางเลือก ไม่โยน raw error
- ถ้านักเรียนเปลี่ยนใจกลางทาง (ตอบยกเลิก) → ไม่ทำอะไร แจ้ง: "ยกเลิกแล้วค่ะ/ครับ ไม่มีอะไรเปลี่ยน"
