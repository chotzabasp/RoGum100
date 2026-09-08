---
name: save-work
description: Use whenever the user wants to save their work to GitHub — triggers include "เซฟงาน", "เซฟ", "save", "save work", "commit", "push", "commit and push", "อัพโค้ด", "อัพงาน", "ดันโค้ด", or any similar request to back up progress. Stages all changes, commits with an auto-generated Thai message describing what changed, and pushes to the current branch on GitHub. Built for absolute beginners — never shows raw git errors, fixes problems automatically, and reports success in friendly Thai.
---

# save-work — เซฟงานขึ้น GitHub

เซฟงานของนักเรียนขึ้น GitHub ในคำสั่งเดียว นักเรียนพิมพ์แค่ "เซฟงาน" หรือ "save" ก็พอ

## กฎหลัก
- **สื่อสารภาษาไทยเสมอ** ห้ามให้นักเรียนเห็น error — แก้เองก่อนเสมอ
- **ตรวจผลลัพธ์จริงทุกคำสั่ง** ก่อนไปต่อ ห้ามรายงานสำเร็จโดยไม่ตรวจ
- **Windows** → ใช้ `PowerShell` tool, ห้ามใช้ `&&`, รันแยกทีละคำสั่ง, ใช้ `Set-Location` แทน `cd`
- **macOS** → ใช้ `Bash` tool, ใช้ `&&` และ `cd` ได้ปกติ
- **ห้ามถามนักเรียนว่า "commit message ว่าอะไรดี"** — สร้างเองจากสิ่งที่เปลี่ยน

---

## ขั้นตอนที่ 1 — ตรวจว่าโฟลเดอร์เชื่อม GitHub แล้วหรือยัง

รัน `git remote -v`

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| เห็น `origin https://github.com/...` | ✅ ผ่าน ไปขั้นตอนที่ 2 |
| ว่างเปล่า / `not a git repository` | **หยุด** แจ้งนักเรียน: "โฟลเดอร์นี้ยังไม่ได้เชื่อมกับ GitHub นะคะ/ครับ พิมพ์ `/connect-repo <ลิงก์ repo ของคุณ>` ก่อนนะคะ/ครับ" |

---

## ขั้นตอนที่ 2 — ตรวจว่ามีอะไรให้เซฟไหม

รัน `git status --short`

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| มีบรรทัด เช่น `M file.html`, `?? new.js`, `A file.css` | ✅ มีงานให้เซฟ → จำไฟล์ที่เปลี่ยนไว้ใช้ในขั้นตอน 4 |
| ว่างเปล่า | ตรวจต่อ: รัน `git log origin/main..HEAD --oneline` ถ้ามี commit ค้าง → ข้ามไปขั้นตอน 6 (push) ถ้าว่างทั้งคู่ → แจ้ง "ยังไม่มีอะไรให้เซฟเลยค่ะ/ครับ ทุกอย่างเซฟไว้บน GitHub แล้ว 😊" แล้วจบ |

---

## ขั้นตอนที่ 3 — Stage ทุกไฟล์

รัน `git add .`

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| ไม่มี output | ✅ ผ่าน |
| CRLF warning (Win) | ✅ warning ปกติ ผ่านได้ |
| `unsafe directory` | `git config --global --add safe.directory "<path>"` แล้วรัน `git add .` ใหม่ |
| `permission denied` | Win: `attrib -r "." /s /d` / mac: `chmod -R u+w .` แล้วลองใหม่ |

---

## ขั้นตอนที่ 4 — สร้าง commit message ภาษาไทย

ดูจาก `git status --short` แล้วสร้างข้อความสั้นๆ ภาษาไทยที่บอกว่าทำอะไร ใช้ pattern นี้:

| สิ่งที่เห็น | ตัวอย่าง message |
|------------|-----------------|
| ไฟล์ใหม่ (`??`) | `เพิ่มไฟล์ <ชื่อไฟล์>` |
| ไฟล์ถูกแก้ (`M`) | `แก้ไข <ชื่อไฟล์>` |
| ไฟล์ถูกลบ (`D`) | `ลบ <ชื่อไฟล์>` |
| หลายไฟล์เปลี่ยน | `อัพเดทงาน: <สรุปสั้น 1 บรรทัด>` |
| ไม่แน่ใจ | `เซฟงาน <วันที่ YYYY-MM-DD>` |

ถ้าเดาได้จากชื่อไฟล์/นามสกุลว่ากำลังทำอะไร (เช่น `index.html` = หน้าเว็บ, `style.css` = แต่งหน้าเว็บ) ให้ใส่ในข้อความด้วย เช่น `แก้ไขหน้าเว็บ index.html`

---

## ขั้นตอนที่ 5 — Commit

รัน `git commit -m "<message ที่สร้างในขั้น 4>"`

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `[main <hash>] <message>` | ✅ ผ่าน |
| `nothing to commit` | ✅ ข้ามไปขั้น 6 |
| `Author identity unknown` | ถามชื่อ + อีเมล → `git config --global user.name "ชื่อ"` / `git config --global user.email "อีเมล"` → commit ใหม่ |
| `unsafe directory` | `git config --global --add safe.directory "<path>"` แล้ว commit ใหม่ |

---

## ขั้นตอนที่ 6 — Push ขึ้น GitHub

**6.1 ตรวจ branch ปัจจุบัน:** รัน `git branch --show-current` → จำชื่อ branch ไว้ (ปกติคือ `main`)

**6.2 รัน `git push origin <branch>`**

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `<hash>..<hash>  main -> main` หรือเงียบ ๆ | ✅ ผ่าน |
| `Everything up-to-date` | ✅ ผ่าน |
| `no upstream branch` | รัน `git push -u origin <branch>` แทน |
| `rejected / non-fast-forward` | `git pull origin <branch> --no-edit` → ถ้า merge conflict: `git checkout --theirs .` → `git add .` → `git commit -m "รวมงานล่าสุด"` → push ใหม่ |
| `authentication failed` | `gh auth login --web` → push ใหม่ |
| `Could not resolve host` / timeout | แจ้งนักเรียน "เน็ตมีปัญหานะคะ/ครับ ลองเช็คเน็ตแล้วพิมพ์ `เซฟงาน` อีกครั้งนะคะ/ครับ" |
| `src refspec ... does not match` | กลับไปขั้น 5 ตรวจว่ามี commit จริงไหม |

---

## ขั้นตอนที่ 7 — Verification (ห้ามข้าม)

รัน `git status`

| ต้องเห็น | ถ้าไม่ผ่าน |
|---------|-----------|
| `up to date with 'origin/<branch>'` และ `nothing to commit, working tree clean` | กลับไปทำขั้น 6 ใหม่ |

ผ่าน → ไปขั้น 8

---

## ขั้นตอนที่ 8 — แจ้งสำเร็จ

**ดูชื่อ branch จากขั้น 6.1 ก่อนเลือกข้อความ:**

### ถ้าอยู่บน `main` (ฉบับจริง)

> "เซฟงานเรียบร้อยแล้วค่ะ/ครับ! 🎉
> 📝 ข้อความ commit: *<message ที่ใช้>*
> ✨ งานของคุณบันทึกไว้บน GitHub เรียบร้อย ปลอดภัยแล้วนะคะ/ครับ ทำงานต่อได้เลย! 😊"

### ถ้าอยู่บน `draft/*` (ฉบับร่าง)

> "เซฟงานเรียบร้อยแล้วค่ะ/ครับ! 🎉
> 📝 ข้อความ commit: *<message ที่ใช้>*
> 📝 **เซฟลงฉบับร่าง [ชื่อ branch] นะคะ/ครับ** — ฉบับจริง (เว็บ live) ยังไม่เปลี่ยน
> 💡 พิมพ์ `/draft-mode` เมื่อพร้อมตัดสินใจว่าจะใช้, ทิ้ง, หรือเก็บฉบับร่างนี้ไว้นะคะ/ครับ"

ถ้ารู้ URL ของ repo (จาก `git remote get-url origin`) ใส่ลิงก์ไปด้วย เช่น "ดูได้ที่ <URL>"
