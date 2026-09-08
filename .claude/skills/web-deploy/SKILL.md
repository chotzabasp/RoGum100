---
name: web-deploy
description: Use when the student is ready to publish their website to the internet via Cloudflare Pages (or new unified Workers + Pages) triggers include "deploy เว็บ", "เอาเว็บขึ้น", "publish เว็บ", "ทำเว็บให้ online", "ทำเว็บให้คนเข้าได้", "ขึ้น cloudflare", "เชื่อม cloudflare", "ต่อ domain", "เพิ่ม domain", "custom domain", "web-deploy", or any similar request to put the site live or add a custom domain. Detects state from a marker block in CLAUDE.md and routes to one of three modes — first-time setup (no marker), offer custom domain (marker exists no domain), status check (marker + domain both present). Accepts both .pages.dev (legacy) and .workers.dev (current unified) URL formats. Skill does not automate the Cloudflare dashboard clicks because there is no CLI for the connect-to-GitHub flow but it does open the right URL at the right moment guide step by step in Thai verify the live URL with HTTP 200 and write the result into CLAUDE.md so future runs know the state. Cloudflare changes UI often — skill tells student to send screenshot when guide does not match. Windows verify command sets TLS 1.2/1.3 to avoid SSL channel errors on PowerShell 5.1. Prerequisite is git remote already connected via /connect-repo. Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# web-deploy — เอาเว็บขึ้น Cloudflare Pages

ทำให้เว็บนักเรียนคนทั้งโลกเข้าได้จริง ๆ ผ่าน Cloudflare Pages

## กฎหลัก
- **สื่อสารภาษาไทยเสมอ** ห้ามให้นักเรียนเห็น error ดิบ แก้เองก่อนเสมอ
- **ตรวจผลลัพธ์จริงทุกคำสั่ง** ก่อนไปต่อ ห้ามรายงานสำเร็จโดยไม่ตรวจ
- **Windows** ใช้ `PowerShell` tool ห้ามใช้ `&&` รันแยกทีละคำสั่ง
- **macOS** ใช้ `Bash` tool ใช้ `&&` และ `cd` ได้ปกติ
- **ห้าม automate dashboard clicks** เพราะ Cloudflare Pages connect-to-Git ไม่มี CLI ใช้วิธี guide แทน
- **ไม่ต้องเช็ค git install** เพราะนักเรียนต้องผ่าน `/connect-repo` มาก่อนแล้ว

---

## ขั้นตอนที่ 0 — Prerequisite check

**0.1 ตรวจว่าอยู่ที่ root ของโปรเจ็คจริง** รัน `git rev-parse --show-toplevel`

เทียบผลลัพธ์กับ cwd ปัจจุบัน (normalize path: ตัด trailing slash, แปลง `\` เป็น `/`, lowercase บน Windows)

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| toplevel = cwd | ✅ ผ่าน ไป 0.2 |
| toplevel ≠ cwd (อยู่ใน subfolder ของ repo อื่น) | **หยุด** แจ้ง "ตอนนี้ folder ที่เปิดอยู่เป็น subfolder ของโปรเจ็คอื่นนะคะ/ครับ (root อยู่ที่ `<toplevel>`) ขอเปิด Claude Code ที่ folder โปรเจ็คของคุณตรง ๆ แล้วพิมพ์ deploy เว็บ ใหม่นะคะ/ครับ" |
| `not a git repository` | **หยุด** แจ้ง "ยังไม่ได้เชื่อมกับ GitHub เลยนะคะ/ครับ พิมพ์ `/connect-repo <ลิงก์ repo>` ก่อนนะคะ/ครับ deploy ต้องมี GitHub repo ก่อนถึงจะทำได้" |

**0.2 ตรวจ remote** รัน `git remote -v`

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| เห็น `origin https://github.com/...` | ✅ ผ่าน ไป 0.3 |
| ว่าง | **หยุด** แจ้ง "ยังไม่ได้ผูก remote GitHub นะคะ/ครับ พิมพ์ `/connect-repo <ลิงก์ repo>` ก่อนนะคะ/ครับ" |

**0.3 ตรวจว่าอยู่บนฉบับจริง (main)** รัน `git branch --show-current`

Cloudflare Pages deploy จาก `main` เท่านั้น ถ้านักเรียนเผลออยู่ในฉบับร่าง (`draft/*`) deploy จะไม่ได้ของที่เห็นตรงหน้า

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| `main` | ✅ ผ่าน ไปขั้น 1 |
| ขึ้นต้น `draft/` (โดยเฉพาะ `draft/*-claude-code-design` คือตัวอย่างจาก Claude Code ที่ยังไม่ได้เลือกใช้) | **หยุด** แจ้ง "ตอนนี้คุณอยู่ในฉบับร่าง [ชื่อ] ยังไม่ใช่เว็บจริงนะคะ/ครับ ถ้าจะใช้ดีไซน์นี้จริง พิมพ์ `/draft-mode` แล้วเลือก ใช้เลย ก่อน แล้วค่อยพิมพ์ deploy เว็บ อีกที (Cloudflare เอาขึ้นจากฉบับจริงเท่านั้น)" |

---

## ขั้นตอนที่ 1 — ตรวจสถานะ deploy

อ่าน `CLAUDE.md` ที่ git toplevel (ค่าที่ได้จากขั้น 0.1) หา marker block

```
<!-- web-deploy:start -->
...
<!-- web-deploy:end -->
```

แล้วเลือก mode

| สถานะ | Mode | ไปที่ |
|-------|------|-------|
| ไม่มี marker block | A — First-time setup | ขั้น 2 |
| มี marker block แต่ Custom domain = `(ยังไม่มี)` | B — Add custom domain | ขั้น 8 |
| มี marker block และมี custom domain ครบแล้ว | C — Status check | ขั้น 12 |

**กรณีไม่มีไฟล์ `CLAUDE.md`** ให้ถือว่าเป็น Mode A

---

# Mode A — First-time setup

## ขั้นตอนที่ 1.5 — สร้างหน้า 404 ให้แบรนด์ (ครั้งเดียว idempotent)

Cloudflare Pages โชว์หน้า 404 ของตัวเอง (หน้าตาแปลก) เวลาคนพิมพ์ URL ผิด ทำหน้า `404.html` ให้แบรนด์เองได้ Cloudflare จะ serve ให้อัตโนมัติ ทำ **ก่อน** เช็ค GitHub (ขั้น 2) ไฟล์จะได้ถูก push ไปด้วย

**ถ้ามี `404.html` ที่ root อยู่แล้ว ข้าม** (อาจเป็นของนักเรียนเอง) ห้ามทับ

ถ้ายังไม่มี สร้าง `404.html` ที่ root **CSP-clean** (ลิงก์ `/styles.css` external ไม่มี inline style/script ลิงก์ทุกอันเป็น root-relative ทำงานได้ทุก path ที่ 404)

```html
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ไม่เจอหน้านี้</title>
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<main class="cnc-404">
  <p class="cnc-404__code">404</p>
  <h1 class="cnc-404__title">ไม่เจอหน้านี้</h1>
  <p class="cnc-404__text">หน้าที่คุณหาอาจถูกย้ายหรือไม่มีอยู่</p>
  <a class="cnc-404__home" href="/">กลับหน้าแรก</a>
</main>
</body>
</html>
```

แล้ว append บล็อกนี้ต่อท้าย `styles.css` (ครั้งเดียว ถ้ามี `cnc-404` แล้วข้าม) ใช้ token ของนักเรียนพร้อม fallback chain (รองรับทั้ง `--color-accent` และ `--accent`)

```css
/* cnc-404 */
.cnc-404{min-height:80vh;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:12px;padding:40px 20px;font-family:var(--font-body,sans-serif);background:var(--color-bg,var(--bg,#fff));color:var(--color-text,var(--ink,#222))}
.cnc-404__code{font-size:64px;font-weight:700;margin:0;color:var(--color-accent,var(--accent,#888))}
.cnc-404__title{font-size:24px;margin:0}
.cnc-404__text{opacity:.7;margin:0}
.cnc-404__home{margin-top:16px;padding:12px 24px;text-decoration:none;border-radius:6px;color:#fff;background:var(--color-accent,var(--accent,#888))}
```

ไม่มี `styles.css` (เว็บแปลก) สร้าง 404.html ได้อยู่ หน้าจะเรียบแต่ใช้งานได้ ลิงก์กลับหน้าแรกทำงาน

---

## ขั้นตอนที่ 2 — เช็คว่าโค้ดล่าสุดอยู่บน GitHub แล้วหรือยัง

รัน `git status --short`

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| ว่าง (clean) | ตรวจต่อ: `git log origin/main..HEAD --oneline` ถ้าว่างทั้งคู่ → ✅ ผ่าน ไปขั้น 3 |
| มีไฟล์เปลี่ยน / มี commit ยังไม่ push | แจ้งนักเรียน "ขอเซฟงานล่าสุดขึ้น GitHub ก่อนนะคะ/ครับ Cloudflare จะดึงโค้ดจาก GitHub" แล้วเรียก skill `save-work` ให้อัตโนมัติ รอจน clean แล้วค่อยไปขั้น 3 |

---

## ขั้นตอนที่ 2.5 — เช็คฟอร์มต่อปลายทางหรือยัง (กันเว็บ live แล้วฟอร์มไม่เก็บข้อมูล)

ก่อนพาขึ้นเว็บจริง สแกน `index.html` + ทุก `pages/*.html` หา `<form>` ที่ **ไม่ได้อยู่ใต้ `data-cnc-widget`** และ **ยังไม่มี `data-cnc-form`** (= ฟอร์มที่กรอกแล้วข้อมูลหายไปเฉยๆ ยังไม่ได้ต่อปลายทาง)

ถ้าเจอ เตือนนักเรียนก่อน deploy

```
เจอฟอร์มกรอกข้อมูลที่ยังไม่ได้ต่อปลายทางนะคะ/ครับ
ตอนนี้ลูกค้ากรอกแล้วข้อมูลจะหายไปเฉยๆ ยังไม่เก็บที่ไหน

อยากให้ผมต่อฟอร์มเข้า Google Sheet ให้ก่อน deploy ไหม
A. ต่อก่อน (แนะนำ) ผมเรียก /web-connect ให้เลย
B. ยังก่อน เอาขึ้นเว็บก่อนแล้วค่อยต่อทีหลัง
```

ถ้าตอบ A เรียก skill `web-connect` ให้เสร็จก่อนแล้วค่อยไปขั้น 3 ถ้าตอบ B ไปต่อได้เลย (ไม่บังคับ) ฟอร์มที่อยู่ใต้ `data-cnc-widget` (เช่น Calendly) ข้ามไม่ต้องเตือน เพราะ widget จัดการเอง

---

## ขั้นตอนที่ 3 — เก็บข้อมูล repo

รัน `git remote get-url origin` → จำ URL ไว้

แยกเอา `<user>/<repo>` ออกจาก URL เช่น `https://github.com/jane/coffee-shop.git` → user=`jane` repo=`coffee-shop` → จำชื่อ repo ไว้ใช้เป็นชื่อ project บน Cloudflare

---

## ขั้นตอนที่ 4 — แจ้งและเปิด dashboard

**4.1 ถามก่อนว่าเคย deploy แล้วหรือยัง**

> "ก่อนจะเริ่ม ขอถามก่อนนะคะ/ครับ
>
> เว็บนี้เคยขึ้น Cloudflare Pages ไปแล้วหรือยังคะ/ครับ?
> 1) ยังไม่เคย เริ่มจาก 0
> 2) เคยแล้ว มี URL `xxxxx.pages.dev` อยู่แล้ว"

**ถ้าเลือก 2** ขอ URL มาเลย ข้ามไปขั้น 6 verify URL

- ถ้า verify ผ่าน 200 → ไปขั้น 7 เขียน marker จบ Mode A
- ถ้า verify fail (404/5xx/connection error) ลองใหม่ 1 ครั้ง ขอ URL ใหม่จากนักเรียน
- ถ้า fail ครั้งที่ 2 → ถามนักเรียน "URL ที่ส่งมายังเข้าไม่ได้นะคะ/ครับ อยากเริ่มจาก 0 ไปด้วยกันมั้ยคะ/ครับ? พิมพ์ `เริ่มใหม่` ถ้าอยากให้พาทำตั้งแต่ต้น หรือลองส่ง URL อีกครั้งก็ได้นะคะ/ครับ"
  - ถ้านักเรียนพิมพ์ `เริ่มใหม่` → ไปขั้น 4.2 (first-time flow)
  - ถ้าส่ง URL ใหม่ → loop verify อีกครั้ง

**ถ้าเลือก 1** ทำขั้น 4.2 ต่อ

**4.2 แจ้งและเปิด dashboard**

แจ้งนักเรียน

> "ตอนนี้จะพานักเรียนไปเอาเว็บขึ้น Cloudflare Pages นะคะ/ครับ 🚀
> หน้าเว็บ Cloudflare จะเปิดขึ้นมา ทำตามขั้นตอนข้างล่างทีละขั้นเลย ไม่ต้องรีบนะคะ/ครับ
>
> **ถ้ายังไม่มีบัญชี Cloudflare** ให้สมัครก่อน (ฟรี ใช้แค่อีเมล) แล้วค่อยกลับมาทำต่อ"

เปิด dashboard ให้

| OS | คำสั่ง |
|----|--------|
| Windows | `Start-Process "https://dash.cloudflare.com/?to=/:account/workers-and-pages/create/pages"` |
| macOS | `open "https://dash.cloudflare.com/?to=/:account/workers-and-pages/create/pages"` |

---

## ขั้นตอนที่ 5 — Guide ทีละขั้น

แสดงให้นักเรียนเห็นเป็น checklist ทีละขั้น (พิมพ์ทั้ง block นี้ออกมาเลย)

```
ทำตามนี้นะคะ/ครับ

1) ที่หน้า Account home (ที่ Cloudflare เปิดมา) ดูกล่องตรงกลางชื่อ
   "Workers and Pages" → กด Start building หรือลูกศรที่หัวกล่อง
   
   📌 ถ้าเข้าจากหน้าอื่นที่ไม่มีกล่องนี้ กด Ctrl+K (mac: Cmd+K)
      แล้วพิมพ์ "workers" ใน Quick search

2) ที่หน้า Workers & Pages กดปุ่ม Create

3) เลือก tab Pages (อาจมี tab Workers/Pages ให้เลือก)
   แล้วกด Connect to Git (หรือ Import an existing Git repository)

4) ถ้าครั้งแรก จะให้ Authorize Cloudflare เข้า GitHub ของเรา
   กด Authorize ได้เลย

5) เลือก repo ชื่อ <repo name จากขั้น 3> แล้วกด Begin setup

6) หน้า Set up builds and deployments ตั้งค่าตามนี้
   • Project name: ปล่อยตามค่าเริ่ม (จะเป็นชื่อ URL ของเรา)
   • Production branch: main
   • Framework preset: None
   • Build command: เว้นว่าง (ไม่ต้องใส่อะไรเลย)
   • Build output directory: เว้นว่าง (ใส่ / ก็ได้)

7) กด Save and Deploy

8) รอประมาณ 1-2 นาที จนเห็นคำว่า Success

9) จะเห็น URL หน้าตา 2 แบบ
   • https://xxxxx.pages.dev (project รุ่นเก่า)
   • https://xxxxx.xxxxx.workers.dev (project รุ่นใหม่ Cloudflare รวม Workers + Pages แล้ว)
   → copy URL มาวางที่นี่ในแชตเลยนะคะ/ครับ ไม่ว่าจะแบบไหน
```

**หยุดรอนักเรียนวาง URL** ห้ามทำต่อจนกว่าจะได้ URL จริง

### ⚠️ ถ้าหน้าจอ Cloudflare ไม่ตรง guide

Cloudflare ปรับ UI บ่อย ถ้านักเรียนเจอจอที่ไม่ตรงกับ checklist ข้างบน บอกนักเรียน

> "Cloudflare เปลี่ยนหน้าตาบ่อยมากนะคะ/ครับ ถ้าเจอจอที่ไม่ตรง guide ให้ส่ง screenshot มาในแชตได้เลย เดี๋ยวจะปรับขั้นตอนให้ตรงกับที่เห็นจริง 📸"

แล้วจริง ๆ ปรับ checklist ให้ตรงกับ UI ที่ student ส่งมา

---

## ขั้นตอนที่ 6 — Verify URL

เมื่อนักเรียนวาง URL มาให้ตรวจว่า

1. ขึ้นต้นด้วย `https://`
2. ลงท้ายด้วย `.pages.dev` **หรือ** `.workers.dev` (Cloudflare รวม Workers + Pages เป็นระบบเดียวแล้ว project ใหม่จะใช้ `.workers.dev`)
3. response HTTP 200

regex validation

```
^https://[a-z0-9-]+(\.[a-z0-9-]+)?\.(pages|workers)\.dev/?$
```

| OS | คำสั่ง verify |
|----|---------------|
| Windows | `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; try { (Invoke-WebRequest -Uri "<url>" -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $_.Exception.Message }` |
| macOS | `curl -s -o /dev/null -w "%{http_code}\n" "<url>"` |

**Windows note:** บรรทัด `Tls12 -bor Tls13` กัน error `Could not create SSL/TLS secure channel` ที่เจอบน PowerShell 5.1 + Windows บางเครื่อง

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `200` | ✅ ผ่าน ไปขั้น 7 |
| `404` | "ดูเหมือนยังไม่ deploy เสร็จนะคะ/ครับ ลองรีหน้า Cloudflare อีกครั้ง เห็น Success แล้วค่อยส่ง URL ใหม่นะคะ/ครับ" |
| `5xx` / timeout | "Cloudflare ยังไม่ตอบนะคะ/ครับ ขอรอ 30 วินาทีแล้วลองใหม่" รอแล้วลองอีก 1 ครั้ง ถ้ายังไม่ผ่าน แจ้งให้รีเฟรชแบบไม่ใช้ cache (ดูตารางด้านล่าง) แล้วเปิด URL ในเบราว์เซอร์ตรง ๆ ถ้าเปิดได้ปกติส่ง URL กลับมาให้ดูอีกครั้ง |
| URL format ผิด | "URL ที่ได้รับยังไม่ถูกต้องนะคะ/ครับ ขอ URL แบบ `https://xxxxx.pages.dev` หรือ `xxxxx.xxxxx.workers.dev` นะคะ/ครับ" |

### Hard-reload (กรณีให้นักเรียนรีเฟรชแบบไม่ใช้ cache)

| OS / Browser | shortcut |
|--------------|----------|
| Windows / Linux (ทุก browser) | `Ctrl + F5` |
| macOS Chrome/Edge/Firefox/Brave | `Cmd + Shift + R` |
| macOS Safari | `Cmd + Option + E` (clear cache) แล้ว `Cmd + R` |

---

## ขั้นตอนที่ 7 — เขียน marker block ลง CLAUDE.md

ดึงวันที่ปัจจุบันจาก context (`Today's date is YYYY-MM-DD`) ไม่ใช้ `Get-Date` / `date` เพราะจะ break การ resume

เปิด `CLAUDE.md` ถ้าไม่มีให้สร้างใหม่ (ไฟล์ว่าง)

ใส่ block นี้ลงท้ายไฟล์ (หรือแทนที่ของเดิมถ้ามี)

```markdown
<!-- web-deploy:start -->
## Deploy

- Platform: Cloudflare Pages
- Project URL: <pages.dev URL ที่ verify แล้ว>
- Connected on: <YYYY-MM-DD จาก context>
- Custom domain: (ยังไม่มี)
<!-- web-deploy:end -->
```

แล้วแจ้งสำเร็จ Mode A

> "เย่ 🎉 เว็บของคุณขึ้นออนไลน์แล้วค่ะ/ครับ!
>
> 🌐 URL: **<pages.dev URL>**
> 📌 URL นี้คงเดิมตลอดไม่ว่าจะ push กี่ครั้ง บันทึกไว้ในที่ที่จำได้ง่าย ๆ ได้เลย
>
> ตั้งแต่นี้เป็นต้นไป ทุกครั้งที่พิมพ์ `เซฟงาน` แล้ว push ขึ้น GitHub Cloudflare จะ deploy ใหม่ให้อัตโนมัติภายใน 1-2 นาทีนะคะ/ครับ ✨
>
> 💡 ถ้าอยากใช้ชื่อโดเมนของตัวเอง (เช่น mysite.com แทน xxxxx.pages.dev) พิมพ์ `ต่อ domain` ได้เลยนะคะ/ครับ"

จบ Mode A

---

# Mode B — Add custom domain

## ขั้นตอนที่ 8 — แสดงสถานะปัจจุบัน + ถามโดเมน

อ่าน Project URL จาก marker block

แจ้งนักเรียน

> "ตอนนี้เว็บของคุณอยู่ที่ **<pages.dev URL>** แล้วนะคะ/ครับ ✅
>
> อยากใช้ชื่อโดเมนของตัวเองแทนใช่มั้ยคะ/ครับ? 🌐
>
> พิมพ์ชื่อโดเมนที่ซื้อมาให้หน่อยนะคะ/ครับ (เช่น `mysite.com` หรือ `www.mysite.com`)
>
> ⚠️ โดเมนนี้ต้อง**ซื้อ**มาแล้วนะคะ/ครับ ถ้ายังไม่มี ซื้อจาก Cloudflare Registrar / Namecheap / GoDaddy ก่อน แล้วค่อยกลับมาทำต่อ"

**หยุดรอ** จนนักเรียนตอบโดเมน

---

## ขั้นตอนที่ 9 — Validate โดเมน

ทำความสะอาด input ก่อน (auto-fix ไม่ต้องถามนักเรียน)

1. ตัด `https://` `http://` `www.` ถ้านำหน้า (เก็บไว้ในใจถ้านักเรียนตั้งใจให้มี www → ใส่กลับตอนกด Set up บน dashboard)
2. ตัด `/` ตามท้าย
3. trim ช่องว่างหน้า-หลัง
4. lowercase

ตรวจรูปแบบหลังทำความสะอาด

- ต้องมีจุดอย่างน้อย 1 จุด เช่น `.com` `.co.th` `.dev`
- ความยาวรวม ≤ 253 ตัว
- แต่ละ label (ส่วนคั่นด้วยจุด) ≤ 63 ตัว
- ใช้ได้แค่ `a-z` `0-9` และ `-` (ห้าม `_` ห้ามอักษรพิเศษ ห้ามภาษาไทย)
- แต่ละ label ห้ามขึ้นต้นหรือลงท้ายด้วย `-`

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| ผ่านทุกข้อ | ไปขั้น 10 |
| มี `_` หรืออักษรพิเศษ | "โดเมนใช้ได้แค่ a-z 0-9 และ - นะคะ/ครับ ขอใหม่นะคะ/ครับ" |
| ไม่มีจุด | "โดเมนต้องมีนามสกุล เช่น `.com` `.co.th` นะคะ/ครับ ขอใหม่นะคะ/ครับ" |
| ยาวเกิน / label ยาวเกิน | "โดเมนยาวเกินไปนะคะ/ครับ ขอแบบสั้นกว่านี้นะคะ/ครับ" |
| มีภาษาไทย / Unicode | "ตอนนี้ Cloudflare รองรับโดเมนภาษาอังกฤษอย่างเดียวนะคะ/ครับ ถ้าซื้อโดเมนภาษาไทยมา ใช้รูปแบบ Punycode (ขึ้นต้นด้วย `xn--`) แทนนะคะ/ครับ" |
| format อื่น ๆ ผิด | "โดเมนที่ใส่มาดูแปลก ๆ นะคะ/ครับ ลองใส่แบบ `mysite.com` หรือ `www.mysite.com` อย่างเดียวนะคะ/ครับ ไม่ต้องใส่ https://" |

---

## ขั้นตอนที่ 10 — Guide ตั้ง custom domain

อ่าน Project URL จาก marker → ดึงชื่อ project (ส่วนแรกของ subdomain)

```python
# pages.dev format    →  coffee-shop.pages.dev               →  project = "coffee-shop"
# workers.dev format  →  coffee-shop.jane-jp.workers.dev     →  project = "coffee-shop"
# ใช้กฎเดียว split('.') แล้วเอา [0]
host = url.replace('https://', '').rstrip('/')
project_name = host.split('.')[0]
```

เปิด Custom domains tab ให้ (ลอง URL pages ก่อน ถ้านักเรียนเป็น workers ใช้ลิงก์ทั่วไป)

| OS | คำสั่ง |
|----|--------|
| Windows (pages) | `Start-Process "https://dash.cloudflare.com/?to=/:account/pages/view/<project name>/domains"` |
| Windows (workers) | `Start-Process "https://dash.cloudflare.com/?to=/:account/workers/services/view/<project name>"` |
| macOS (pages) | `open "https://dash.cloudflare.com/?to=/:account/pages/view/<project name>/domains"` |
| macOS (workers) | `open "https://dash.cloudflare.com/?to=/:account/workers/services/view/<project name>"` |

ถ้าไม่แน่ใจว่า project เป็น pages หรือ workers ดูจาก marker block — ที่บันทึก URL ไว้

**ถ้าหน้าที่เปิดมาไม่ตรง** (Cloudflare ปรับ UI) บอกนักเรียนส่ง screenshot แล้วช่วย navigate ให้

แล้วพิมพ์ checklist

```
ทำตามนี้นะคะ/ครับ

1) ที่หน้า Custom domains กด Set up a custom domain
2) ใส่ <domain ที่นักเรียนพิมพ์> แล้วกด Continue
3) Cloudflare จะตรวจ DNS แล้วบอกว่าให้ทำอะไรต่อ มี 2 แบบ
   
   📌 ถ้าโดเมนซื้อจาก Cloudflare Registrar
      → Cloudflare ตั้งให้อัตโนมัติ กด Activate domain ได้เลย
   
   📌 ถ้าโดเมนซื้อจากที่อื่น (Namecheap / GoDaddy / อื่น ๆ)
      → จะเห็น CNAME record ที่ต้องเอาไปใส่
      → copy ค่า CNAME ไว้ แล้วเข้าไปที่หน้าเว็บที่ซื้อโดเมน
      → หา DNS Settings / DNS Manager / Manage DNS
      → เพิ่ม CNAME record ใหม่ตามที่ Cloudflare บอก
      → กลับมาที่ Cloudflare กด Check again รออาจถึง 15 นาที
4) เมื่อสถานะกลายเป็น Active ✅ ส่ง "ทำเสร็จแล้ว" มาในแชตได้เลยนะคะ/ครับ
```

**หยุดรอ** จนนักเรียนยืนยัน

---

## ขั้นตอนที่ 11 — Verify domain + update marker

verify HTTP 200 ที่ `https://<domain>`

| OS | คำสั่ง |
|----|--------|
| Windows | `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; try { (Invoke-WebRequest -Uri "https://<domain>" -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $_.Exception.Message }` |
| macOS | `curl -s -o /dev/null -w "%{http_code}\n" "https://<domain>"` |

| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `200` | ✅ ผ่าน update marker แล้วไปขั้นแจ้งสำเร็จ |
| `404` / `5xx` | "ดูเหมือน Cloudflare ยังตั้งไม่เสร็จนะคะ/ครับ ขอรออีก 5 นาทีแล้วลองใหม่นะคะ/ครับ DNS บางที่ใช้เวลานานหน่อย" รออีก 1 รอบ ถ้ายังไม่ผ่านแจ้ง "ลองเปิด URL ในเบราว์เซอร์ตรง ๆ ดูก่อนนะคะ/ครับ ถ้าเปิดได้ส่งกลับมาให้ดูใหม่" |
| connection error | "DNS น่าจะยังไม่กระจายทั่ว ปกติใช้เวลา 5-30 นาทีค่ะ/ครับ ลองพิมพ์ `web-deploy` อีกครั้งใน 15 นาทีนะคะ/ครับ" จบ Mode B แบบยังไม่อัพเดต marker |

update marker block ใน `CLAUDE.md` แก้บรรทัด `Custom domain: (ยังไม่มี)` เป็น `Custom domain: <domain>` และเพิ่ม `- Domain added on: <วันที่จาก context>`

แจ้งสำเร็จ Mode B

> "เย่ 🎉 โดเมนของคุณใช้ได้แล้วค่ะ/ครับ!
>
> 🌐 URL ใหม่: **https://<domain>**
> 🔁 URL เดิม **<pages.dev URL>** ก็ยังใช้ได้ปกตินะคะ/ครับ
>
> Cloudflare ทำ HTTPS ให้ฟรีอัตโนมัติแล้ว ✨"

จบ Mode B

---

# Mode C — Status check

## ขั้นตอนที่ 12 — verify ทั้งสอง URL

อ่านจาก marker

- Project URL (.pages.dev)
- Custom domain

verify HTTP 200 ทั้งสอง (คำสั่งเหมือนขั้น 6)

แจ้งสถานะ

> "เว็บของคุณทำงานปกติทั้งสอง URL นะคะ/ครับ ✅
>
> 🌐 โดเมนหลัก: **https://<domain>** (status: 200 OK)
> 🔁 Cloudflare URL: **<pages.dev URL>** (status: 200 OK)
> 📅 เริ่ม deploy เมื่อ: <Connected on จาก marker>
>
> ทุกครั้งที่ `เซฟงาน` Cloudflare จะ deploy ใหม่ให้อัตโนมัตินะคะ/ครับ ✨"

ถ้ามีตัวใดตัวหนึ่ง HTTP ไม่ใช่ 200 ให้แจ้งเฉพาะตัวที่มีปัญหา และแนะนำให้เข้า dashboard เช็ค Deployments tab ดู build error

จบ Mode C
