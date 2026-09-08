---
name: web-page
description: Use when the student wants to add a whole new page to their site (about page services portfolio FAQ contact etc.) not just edit text (web-update) or restyle (web-style) or add a widget to an existing page (web-add). On a no-build static site the hard part is that the nav and footer are copied into every page with no templating so adding a page means updating the nav on every existing page too. web-page handles that. New pages live in the pages/ folder (matches what seo web-finish accessibility already scan) and all cross-page links are root-relative (leading slash) so the same nav markup works on every page with no ../ path fragility. The new page clones the head nav footer and component classes from index so it is on-brand automatically then gets on-brand starter content generated from the CLAUDE.md scope and writing for that page type which the student refines. Triggers include "เพิ่มหน้า", "เพิ่มหน้าใหม่", "อยากมีหน้า about", "ทำหน้าเกี่ยวกับเรา", "เพิ่มหน้าผลงาน", "ทำหน้า portfolio", "เพิ่มหน้า FAQ", "ทำหน้าบริการ", "เพิ่มหน้าติดต่อ", "หลายหน้า", "add a page", "new page", "about page", "web-page", or any similar request to add a page and a nav link. Keeps the nav consistent across all pages writes only external CSS keeps strict CSP and gives each page its own SEO title and description. Built for absolute beginners with zero coding knowledge works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-page เพิ่มหน้าใหม่ + เมนูให้ครบทุกหน้า

นักเรียนอยากมีหน้าใหม่ (about ผลงาน FAQ บริการ ติดต่อ) web-page สร้างหน้าใหม่ที่เข้ากับแบรนด์อัตโนมัติ แล้ว **อัปเดตเมนูให้ทุกหน้าตรงกัน** เพราะเว็บ static ไม่มี template เมนูถูก copy ไว้ในทุกไฟล์ เพิ่มหน้าใหม่ = ต้องแก้เมนูในทุกหน้า web-page จัดการให้

---

## กฎเด็ดขาด Thai content

ห้าม em dash (—) ห้าม comma (,) แยก clause ใน Thai text ใช้ space เท่านั้น

---

## โครงสร้าง (ตัดสินใจแล้ว lock ไว้)

1. **หน้าใหม่อยู่ใน `pages/`** เช่น `pages/about.html` `pages/faq.html` ตรงกับที่ seo web-finish accessibility สแกน (`index.html` + `pages/*.html`) หน้าใหม่จึงโดน audit อัตโนมัติ
2. **ลิงก์ข้ามหน้าใช้ root-relative (ขึ้นต้นด้วย /)** เช่น `/` (หน้าแรก) `/pages/about.html` ลิงก์แบบนี้ทำงานเหมือนกันทุกหน้า **ไม่ต้องใช้ `../`** ที่นักเรียน (และ AI) มักพลาด เมนูจึงเป็น markup เดียวกันเป๊ะทุกหน้า
3. **asset ของหน้าใหม่ก็ root-relative** `/styles.css` `/scripts.js` `/assets/...` ทำงานจาก `pages/` ได้เลยไม่ต้อง `../`

นี่คือ good practice ที่ทำให้ nav-sync ไม่เปราะ

---

## หัวใจที่ยากที่สุด nav-sync (เมนูตรงกันทุกหน้า)

เว็บ static ไม่มี server-side include เมนู+footer ถูก copy ในทุกไฟล์ ถ้าเพิ่มหน้าแล้วแก้เมนูแค่หน้าเดียว หน้าอื่นจะไม่มีลิงก์ไปหน้าใหม่ = เมนูเพี้ยน

web-page แก้ด้วย **canonical link list + เขียนเมนูบล็อกเดียวกันลงทุกหน้า**

- เก็บรายการหน้าเป็น list เดียว (หน้าแรก + ทุกหน้าใน pages/)
- แต่ละลิงก์เป็น root-relative ลิงก์ชุดเดียวใช้ได้ทุกหน้า
- เขียนเมนูบล็อกเดียวกันลง **ทุกหน้า** (index + ทุก pages/*.html)
- mark เมนูด้วย `data-cnc-nav` เพื่อให้ run ครั้งหน้าหาเจอ + แทนที่ทั้งบล็อก (idempotent)

---

## marker `data-cnc-nav`

stamp บน nav element ที่ web-page ดูแล (`<nav data-cnc-nav>` หรือ element เมนูหลัก) ครั้งแรก แล้วทุก run จัดการเฉพาะรายการลิงก์ภายใน marker นี้ ไม่แตะส่วนอื่นของ header

---

## invariant ความปลอดภัย + คุณภาพ

| ด้าน | web-page ทำยังไง |
|------|--------------------|
| **CSP / best-practices** | หน้าใหม่ใช้ `/styles.css` `/scripts.js` external เท่านั้น ไม่มี inline `<style>`/`<script>` → CSP เดิมครอบได้ ไม่ต้องแตะ `_headers` |
| **on-brand** | clone head + component class จาก index ใช้ token + class เดิม (`.btn` `.section` `.cd` heading) หน้าใหม่จึงหน้าตาเข้าชุดเอง |
| **accessibility** | หน้าใหม่มี `lang` viewport heading order ที่ถูก nav เป็น `<nav>` ลิงก์มี text มี skip link เหมือน index |
| **seo** | ทุกหน้ามี title + description ของตัวเอง (Step 6) audit สแกน pages/*.html เจอเอง |
| **audit จำได้** | `data-cnc-nav` marker → nav-sync ทำซ้ำได้ ไม่ซ้อน |

---

## flow

```
นักเรียนพูด "เพิ่มหน้า about"
   → Step 0 ตรวจความพร้อม
   → Step 1 ถามชนิดหน้า + ชื่อหน้า + ป้ายเมนู + slug
   → Step 2 clone chrome (head + nav + footer) จาก index แปลงเป็น root-relative
   → Step 3 generate เนื้อหา starter เข้าแบรนด์ (reuse component + CLAUDE.md)
   → Step 4 สร้างไฟล์ pages/<slug>.html
   → Step 5 nav-sync เพิ่มลิงก์หน้าใหม่ในเมนู เขียนลงทุกหน้า
   → Step 6 SEO ของหน้าใหม่ (title description)
   → Step 7 preview localhost
   → Step 8 รายงาน + next
```

---

## Step 0 ตรวจความพร้อม

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ |
| `styles.css` ที่ root | ใช้ token + component class จากที่นี่ |
| เมนู/nav ใน index | ถ้าไม่มี nav เลย web-page สร้าง nav ใหม่เล็กๆ (Home + หน้าใหม่) ใส่ใน header |

---

## Step 1 ถามชนิดหน้า + ชื่อ + ป้ายเมนู + slug

```
📄 เพิ่มหน้าใหม่ให้ค่ะ/ครับ

หน้านี้เกี่ยวกับอะไร
1. เกี่ยวกับเรา (about)
2. บริการ/คอร์ส (services)
3. ผลงาน (portfolio)
4. คำถามที่พบบ่อย (FAQ)
5. ติดต่อ (contact)
6. อื่นๆ บอกมาได้เลย

อยากให้ชื่อหน้า (ที่โชว์ในเมนู) ว่าอะไร เช่น "เกี่ยวกับเรา"
```

- จากชนิด + ชื่อ ตั้ง **slug** เป็นอังกฤษสั้น (about services portfolio faq contact) → ไฟล์ `pages/<slug>.html`
- slug ชนกับหน้าเดิม เติมเลขหรือถามชื่อใหม่
- ป้ายเมนู = ชื่อไทยที่นักเรียนบอก

---

## Step 2 clone chrome จาก index → root-relative

อ่าน `index.html` ดึง 3 ส่วนมาเป็นโครงหน้าใหม่

1. **`<head>`** meta charset viewport `lang` ลิงก์ฟอนต์ + `<link rel="stylesheet" href="/styles.css">` (root-relative) + `<script src="/scripts.js">` ถ้ามี
2. **header/nav** ก๊อปเมนู (เดี๋ยว Step 5 sync ให้ตรง)
3. **footer** ก๊อป footer เดิม

**แปลง path ทุกอันเป็น root-relative** `styles.css` → `/styles.css` `assets/x.jpg` → `/assets/x.jpg` เพราะหน้าอยู่ใน `pages/` ลิงก์ relative เดิมจะหาไฟล์ไม่เจอ root-relative ใช้ได้เลย

---

## Step 3 generate เนื้อหา starter เข้าแบรนด์ (generate-then-confirm)

อ่าน CLAUDE.md (`web-scope` `web-writing`) + ดู component class **จริง** ที่ index ใช้ใน styles.css แล้ว **ร่างเนื้อหาหน้านั้นจากของที่มี** ไม่เริ่มจากศูนย์ ใช้ section + heading + ปุ่ม + การ์ด ด้วย **ชื่อ class จริงที่ index ใช้** อย่า assume ว่าเป็น `.btn` `.cd` เสมอ (เว็บที่ Claude Code สร้างเอง Path B อาจใช้ `.btn--primary` `.card3d` หรือชื่ออื่น) อ่านชื่อจริงจาก index + styles.css แล้วใช้ให้ตรงกัน

ตัวอย่างโครงตามชนิด

- **about** เรื่องราว/ที่มา + จุดยืน + รูป + CTA
- **services** list บริการ/คอร์ส (ใช้ card class เดิม) + ราคา (ถ้ามีใน CLAUDE.md) + CTA
- **portfolio** แกลเลอรี/ผลงาน (ถ้ามีรูปจริง ไม่มีเก็บ slot)
- **FAQ** `<details>`/`<summary>` (เหมือน web-add faq) + CTA
- **contact** ช่องทางจริงจาก web-scope (LINE โทร ฟอร์ม)

**ข้อเท็จจริง (ราคา เวลา ที่อยู่ คำพูดลูกค้า) ห้ามแต่ง** เว้น placeholder ให้เติม โชว์ draft ให้นักเรียนยืนยัน/แก้ก่อน finalize ภาษาไทยตามกฎ ห้าม em dash ห้าม comma แยก clause

---

## Step 4 สร้างไฟล์ pages/<slug>.html

ประกอบ head (Step 2) + nav (Step 5) + เนื้อหา (Step 3) + footer เป็นไฟล์ `pages/<slug>.html` โครง HTML ครบ (`<!DOCTYPE html>` `<html lang>` `<head>` `<body>`)

---

## Step 5 nav-sync เขียนเมนูตรงกันทุกหน้า (หัวใจ)

1. หาเมนูหลักใน index (`<nav>` `<header>` `.bar` `.nav` ตามจริง) ถ้ายังไม่มี marker stamp `data-cnc-nav` บน element เมนู
2. สร้าง **canonical link list** root-relative
   ```
   หน้าแรก        /
   เกี่ยวกับเรา    /pages/about.html
   [หน้าใหม่]      /pages/<slug>.html
   ```
   (ดึงหน้าเดิมจาก `pages/*.html` ที่มีอยู่ + เพิ่มหน้าใหม่)
3. เขียน **บล็อกเมนูเดียวกันเป๊ะ** (ลิงก์ root-relative ชุดเดียว) ลงในเขต `data-cnc-nav` ของ **ทุกไฟล์** index + ทุก pages/*.html
   - ลิงก์ปัจจุบันของแต่ละหน้า mark `aria-current="page"` ได้ (ตัวช่วย a11y)
4. ถ้าเมนูเดิมเป็น anchor ของหน้าเดียว (`#join`) เก็บ anchor ไว้สำหรับหน้าแรก (แปลงเป็น `/#join` ถ้าอยากให้กดจากหน้าอื่นได้) + เพิ่มลิงก์ระดับหน้า (Home + pages) เข้าไป อย่าทิ้งของเดิม

ผล ทุกหน้ามีเมนูเหมือนกัน กดไปมาได้ครบ idempotent (run อีกรอบแทนที่บล็อกเดิม)

---

## Step 6 SEO ของหน้าใหม่

ใส่ `<title>` + `<meta name="description">` เฉพาะของหน้านั้น (ไม่ก๊อป title หน้าแรกมาเฉยๆ) ดึงจากชนิดหน้า + CLAUDE.md ถ้าอยากครบ og/canonical เรียก `seo` ให้ทำหน้าใหม่ด้วย (seo สแกน pages/*.html เจอเอง)

---

## Step 7 preview localhost

เปิด preview **เช็คพอร์ตว่างก่อน bind** (กฎเดียวกับ skill อื่น)

```
PY: macOS ใช้ python3 เสมอ (ห้าม python เปล่า มักไม่มีบน Mac) / Windows ลอง python ก่อน ไม่มีค่อยใช้ py
หาพอร์ตว่างตัวแรกจาก 8000 8080 8888 3000
  Windows (Test-NetConnection localhost -Port <p> -WarningAction SilentlyContinue).TcpTestSucceeded
  macOS   lsof -i :<p>
start จาก project root ใช้ $PY -m http.server <พอร์ต> --directory .
verify ทั้งหน้าแรกและ /pages/<slug>.html ได้ 200 + กดเมนูไปมาได้
```

ให้นักเรียนกดเมนูสลับหน้าดูว่าครบและไม่หลุดสไตล์

---

## Step 8 รายงาน + next

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ เพิ่มหน้า [ชื่อหน้า] ให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ สร้างหน้า [ชื่อหน้า] เข้ากับสีและสไตล์เว็บคุณ
✅ ใส่ลิงก์ในเมนูครบทุกหน้าแล้ว กดไปมาได้

👀 เปิดดูได้ที่ http://localhost:[พอร์ตจริง]
   ลองกดเมนูสลับหน้าดู

ℹ️ อยากแก้ข้อความในหน้านี้ /web-update
   อยากเปลี่ยนทรง component /web-style

ต่อไป
1. /save-work    เซฟขึ้น GitHub
2. deploy        เอาขึ้นเว็บจริง
```

---

## Edge cases

- **เว็บไม่มี nav เลย** สร้าง nav เล็กๆ (Home + หน้าใหม่) ใส่ใน header ของทุกหน้า stamp `data-cnc-nav`
- **เมนูเดิมเป็น anchor หน้าเดียว** เก็บ anchor (แปลง `/#section`) + เพิ่มลิงก์ระดับหน้า ไม่ทิ้งของเดิม
- **slug ชนหน้าเดิม** เติมเลขหรือถามชื่อใหม่ ไม่ทับไฟล์เดิม
- **ลบหน้า** (อนาคต) ลบไฟล์ + เอาลิงก์ออกจาก canonical list + sync ทุกหน้า (ตอนนี้โฟกัสเพิ่มก่อน)
- **หน้าใหม่ต้องใช้รูป** เรียก web-images เก็บ slot ถ้ายังไม่มีรูปจริง
- **หน้า contact มีฟอร์ม** ฟอร์มต่อปลายทางด้วย web-connect (คนละ skill)
- **path เดิมใน index เป็น relative** หน้าใหม่ใช้ root-relative ของตัวเอง ไม่ต้องแก้ index (ทั้งคู่ทำงานได้) แต่ลิงก์เมนูที่ sync ลง index ใช้ root-relative

---

## FYI

- เพิ่มกี่หน้าก็ได้ เมนูจะตรงกันเสมอเพราะ nav-sync
- หน้าใหม่ใช้ token + component เดิม เปลี่ยนทรงทีหลังด้วย web-style ได้ครอบทุกหน้า
- ทุกหน้าโดน /web-quality-audit ตรวจเพราะอยู่ใน pages/
