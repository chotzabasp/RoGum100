---
name: best-practices
description: ตั้งระบบความปลอดภัยให้เว็บนักเรียนด้วยการสร้างไฟล์ `_headers` สำหรับ Cloudflare Pages ที่มี security headers พื้นฐาน (HSTS X-Frame-Options X-Content-Type-Options Referrer-Policy Permissions-Policy Content-Security-Policy) กันการโจมตีพื้นฐานอย่าง clickjacking MIME sniffing protocol downgrade และการขอสิทธิ์ camera/mic/location ที่เว็บไม่ได้ใช้. มี 2 mode คือ Mode A สร้าง _headers ใหม่ (default) และ Mode B merge domain เพิ่มเข้า CSP ที่มีอยู่ (เรียกจาก widget skill ที่ embed ของจากภายนอกเช่น Calendly chat pixel หรือเมื่อนักเรียนเจอ console error refused to load). Triggers include "ทำความปลอดภัย", "ตั้ง security", "ใส่ security headers", "ทำ headers", "ป้องกัน clickjacking", "ตั้งระบบความปลอดภัยเว็บ", "เพิ่ม domain", "อัพเดต security policy", "merge csp", "console error refused to load", "browser block widget", "security audit", "best practices", "best-practices", or any similar request to harden the site or to register a new external domain. Writes/edits one file `_headers` at project root with sensible defaults that work for Claude Design output + Cloudflare Web Analytics + Google Forms (Day 2 modules). Auto-create silently in Mode A. Idempotent merge in Mode B. No npm no audit no DOMPurify because students have no backend no user input no build pipeline. Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# best-practices ตั้งระบบความปลอดภัยให้เว็บ

ภารกิจเดียว เขียนไฟล์ `_headers` ที่ project root เพื่อบอก Cloudflare ให้ใส่ security headers ในทุก request ที่ visitor เข้ามา

ทำไมแค่ไฟล์เดียว เพราะ stack ของคอร์สนี้ HTML/CSS + Cloudflare Pages ไม่มี backend ไม่มี database ไม่มี user input ไม่มี npm ดังนั้นช่องโหว่ส่วนใหญ่ของเว็บแอปทั่วไป (SQL injection XSS จาก user backend dependency vulnerability) **ไม่มีโอกาสเกิดเลย** ที่เหลือคือป้องกัน visitor ของเว็บนักเรียนจากการโดน scammer ใช้เว็บนักเรียนเป็นช่องทางโจมตี

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก

- **ภาษาไทยเรียบง่าย** นักเรียนไม่รู้จัก CSP HSTS iframe
- **อธิบายเป็นภาษาคน** ห้ามโชว์ technical header name ในรายงาน
- **Auto-create** ถ้าไม่มี `_headers` สร้างให้เลยไม่ถาม (default ปลอดภัยและทำงานกับ stack ของคอร์ส)
- **เคารพ `_headers` ที่มีอยู่แล้ว** ถ้านักเรียนเคยสร้างเอง ห้ามทับ แจ้งให้รู้แทน
- **ใช้ default ที่ test แล้วกับ stack** Claude Design + Cloudflare Web Analytics + Google Forms ทำงานได้หมด
- **Cloudflare/Netlify only** ไฟล์ `_headers` ทำงานเฉพาะ host ที่อ่านไฟล์นี้ (Cloudflare Pages, Netlify) แจ้งนักเรียนถ้าเขาใช้ host อื่นในอนาคต

---

## โหมดการทำงาน (อ่านก่อนเริ่ม)

best-practices มี 2 mode

### Mode A สร้าง _headers ใหม่ (default)
- trigger ตรงเช่น "ทำ security" "ตั้งความปลอดภัย" หรือ orchestrator เรียกครั้งแรก
- ทำตาม Step 1 → Step 5

### Mode B Merge domain เพิ่มเข้า CSP เดิม (ใช้เมื่อ widget skill เพิ่มของจากภายนอก)
- trigger มาในรูป "เพิ่ม domain X ใน directive Y" หรือ "ติด widget Z เพิ่ม domain ที่ widget นั้นต้องการ" หรือนักเรียน paste console error "Refused to load..."
- ข้ามไป Step 6
- จุดประสงค์ คือไม่ต้อง rewrite _headers ใหม่ทั้งไฟล์ แค่เพิ่ม domain ที่ widget ใหม่ต้องการ

ตรวจ trigger จาก caller ก่อนเลือก mode

---

## Step 1 ตรวจไฟล์พร้อมไหม

อ่าน project root

| สิ่งที่ต้องเจอ | ถ้าไม่เจอ |
|----------------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `_headers` (optional) | ถ้ามีอยู่ไปขั้น 2 ถ้าไม่มีไปขั้น 3 |

---

## Step 2 ถ้ามี _headers อยู่แล้ว ตรวจไม่ทับ

ถ้าเจอไฟล์ `_headers` ที่ root แสดงว่ามีอยู่แล้ว
- อ่านดูว่ามี header อะไรอยู่แล้ว
- **ห้ามทับ** แค่แจ้งนักเรียนว่ามีอยู่แล้ว
- เสนอ
  > "เจอไฟล์ _headers ที่มีอยู่แล้วนะคะ/ครับ ตอนนี้มี [list header ที่มี]
  > อยากให้ผม
  > A. เก็บไว้แบบเดิม ไม่แตะ
  > B. เพิ่ม header ที่ยังขาด (เก็บของเดิม + เพิ่มของใหม่)
  > C. ทับด้วย default ใหม่ทั้งหมด (ของเดิมหาย)"
- ถ้าตอบ A จบ skill
- ถ้าตอบ B เพิ่มเฉพาะ header ที่ยังไม่มี
- ถ้าตอบ C ทำตาม Step 3

---

## Step 3 สร้าง _headers ด้วย default ปลอดภัย

สร้างไฟล์ `_headers` ที่ project root ด้วยเนื้อหานี้

```
/*
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()
  Content-Security-Policy: default-src 'self'; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com; style-src 'self' https://fonts.googleapis.com; style-src-attr 'unsafe-inline'; script-src 'self' https://static.cloudflareinsights.com; script-src-attr 'none'; connect-src 'self' https://cloudflareinsights.com; form-action 'self' https://docs.google.com; frame-ancestors 'none'; base-uri 'self'; upgrade-insecure-requests
```

`/*` หมายถึงใช้กับทุกหน้าในเว็บ (Cloudflare Pages syntax)

### ทำไม CSP ตั้งแบบนี้

| ส่วนของ CSP | อนุญาตอะไร | ทำไม |
|-------------|------------|------|
| `default-src 'self'` | resource จากเว็บตัวเองเท่านั้น | base ปลอดภัยที่สุด |
| `img-src 'self' data: https:` | รูปจากเว็บตัวเอง + base64 (data:) + https ทุก domain | Claude Design ใช้ base64 inline ในบางจุด + นักเรียนอาจใส่ลิงก์รูป external |
| `font-src ... https://fonts.gstatic.com` | font จาก Google Fonts | Claude Design ใช้ Google Fonts (IBM Plex Sans Thai Sarabun) |
| `style-src 'self' https://fonts.googleapis.com` | CSS จากเว็บตัวเอง + Google Fonts CSS | strict ไม่อนุญาต inline `<style>` (web-finish แยกออกเป็น styles.css แล้ว) |
| `style-src-attr 'unsafe-inline'` | inline `style="..."` attribute บน element | Claude Design ใช้บ่อย attribute ไม่มี script ได้ ปลอดภัย |
| `script-src 'self' https://static.cloudflareinsights.com` | JS จากเว็บตัวเอง + Cloudflare Web Analytics | strict ไม่อนุญาต inline `<script>` (web-finish แยกออกเป็น scripts.js แล้ว) Day 2 ใช้ Cloudflare Analytics |
| `script-src-attr 'none'` | ห้าม inline event handler (onclick onload) | Claude Design ไม่ใช้ inline event ปิดได้เลย |
| `connect-src 'self' https://cloudflareinsights.com` | fetch ไปได้แค่ตัวเอง + Cloudflare Analytics reporting | กัน fetch หลุดไปที่อื่น |
| `form-action 'self' https://docs.google.com` | form ส่งไปได้แค่ตัวเอง + Google Forms | Day 2 ใช้ Google Form รับ lead |
| `frame-ancestors 'none'` | ห้ามใครเอาเว็บไปฝังใน iframe | กัน clickjacking |
| `upgrade-insecure-requests` | บังคับ HTTPS ทุก resource | กัน mixed content |

### ตรวจ domain จริงที่เว็บใช้ ก่อน finalize (รองรับทุกที่มาของเว็บ)

default ด้านบนครอบคลุม Google Fonts + Cloudflare Analytics ซึ่งเว็บส่วนใหญ่ใช้ทั้ง Path A (Claude Design) และ Path B (Claude Code) แต่อย่า assume ว่าใช้แค่นี้เสมอ ก่อนเขียน `_headers` ให้สแกน `<head>` ของทุกหน้าหา external resource domain จริง

- `<link rel="stylesheet" href="https://...">` หรือ `@import` → domain ของ CSS/font (เช่น `fonts.googleapis.com` ปกติ แต่บางเว็บอาจ self-host หรือใช้ host อื่น)
- `<link href="https://...gstatic.com">` `<link rel="preconnect">` → font file domain
- `<script src="https://...">` → JS domain
- `<img src="https://...">` `url(https://...)` ใน CSS → ปกติครอบใน `img-src https:` แล้ว

ถ้าเจอ domain ที่ยังไม่อยู่ใน default CSP ให้เพิ่มเข้า directive ที่ตรงประเภท (font → `font-src`, CSS → `style-src`, JS → `script-src`) ด้วย merge logic เดียวกับ Mode B ถ้าใช้ Google Fonts ตาม default อยู่แล้วไม่ต้องเพิ่มอะไร

---

## Step 4 รายงานนักเรียน

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔒 ตั้งระบบความปลอดภัยให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ สร้างไฟล์ความปลอดภัย (_headers) แล้ว
   เปิด HTTPS บังคับ (ห้ามดาวน์เกรดเป็น http)
   ปิด iframe ห้ามใครเอาเว็บคุณไปฝัง (กัน clickjacking)
   browser ไม่เดาประเภทไฟล์เอง (กันรันโค้ดผิดประเภท)
   ปิดสิทธิ์ camera mic location payment (เว็บคุณไม่ได้ใช้)
   ตั้งกฎว่า resource ดึงมาจากที่ไหนได้บ้าง (กันโค้ดแปลกปลอม)

ℹ️ บอกไว้ให้รู้
   1. ไฟล์ _headers ทำงานตอน deploy บน Cloudflare เท่านั้น
      ทดสอบบน localhost จะไม่เห็นผล ปกติแล้ว
   2. ทดสอบหลัง deploy ได้ที่ https://securityheaders.com
      paste URL เว็บคุณลงไป ควรได้เกรด A หรือ A+
   3. ถ้าอนาคตอยากเพิ่มของ external (เช่น TikTok pixel Google Analytics
      Facebook chat widget) ต้องเพิ่ม domain ใน _headers ก่อน
      ไม่อย่างนั้น browser จะ block ทำงานไม่ได้ บอกผมแก้ให้
```

### ตารางแปลเป็นภาษาคน

| ส่วนที่ตั้ง | บอกนักเรียนว่า |
|------------|----------------|
| HSTS | "เปิด HTTPS บังคับ ห้ามดาวน์เกรดเป็น http" |
| X-Frame-Options DENY + frame-ancestors none | "ปิด iframe ห้ามใครเอาเว็บคุณไปฝัง" |
| X-Content-Type-Options nosniff | "browser ไม่เดาประเภทไฟล์เอง" |
| Referrer-Policy strict-origin | "ไม่บอกเว็บอื่นว่าคนมาจาก URL เต็มของคุณ" |
| Permissions-Policy | "ปิดสิทธิ์ camera mic location ที่เว็บไม่ใช้" |
| Content-Security-Policy | "ตั้งกฎว่า resource ดึงมาจากที่ไหนได้บ้าง" |
| upgrade-insecure-requests | "บังคับ HTTPS ทุก resource" |

---

## Step 5 ปิดท้าย

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 ความปลอดภัยเรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ สรุป
- ไฟล์ _headers พร้อม (security headers 7 ตัว)
- ปกป้อง visitor จาก clickjacking และโจมตีพื้นฐาน

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ตอน deploy แล้ว ลอง https://securityheaders.com เพื่อดูเกรด
```

---

## Step 6 Mode B Merge domains เข้า CSP เดิม (idempotent)

ใช้เมื่อ widget skill (Calendly chat pixel GTM ฯลฯ) เพิ่งเพิ่มของจากภายนอกเข้าเว็บ และต้องเพิ่ม domain ใน CSP ให้ browser ยอมโหลด

### Input ที่ caller ส่งมา

caller (widget skill หรือ orchestrator หรือคำขอจากนักเรียน) ระบุชุด pair `(directive, domain)` เช่น

```
script-src:     https://assets.calendly.com
style-src:      https://assets.calendly.com
frame-src:      https://calendly.com
connect-src:    https://*.calendly.com
```

หรือถ้านักเรียน paste console error เช่น
```
Refused to load the script 'https://assets.calendly.com/...' because it
violates the following Content Security Policy directive: "script-src 'self'..."
```
ดึง directive (`script-src`) + domain (`https://assets.calendly.com`) จาก message

### ขั้นตอน

1. อ่าน `_headers` ปัจจุบัน
   - ถ้าไม่มี → switch ไป Mode A (Step 3) สร้างไฟล์ใหม่พร้อม domain ที่ขอเพิ่มเข้าไปเลย
2. หา CSP line ใน `_headers`
3. แยกเป็น directive แต่ละตัว เช่น
   ```
   default-src 'self'
   script-src 'self' https://static.cloudflareinsights.com
   style-src 'self' https://fonts.googleapis.com
   ...
   ```
4. สำหรับแต่ละ pair `(directive, domain)` ที่ caller ขอ
   - ถ้า directive **ไม่มีในไฟล์** → เพิ่ม directive ใหม่ทั้งบรรทัดพร้อม `'self'` + domain ใหม่
     (เช่นไม่เคยมี `frame-src` มาก่อน เพราะ default-src ครอบ แต่อยากระบุชัดๆ ก็เพิ่มได้)
   - ถ้า directive **มีอยู่ + domain ยังไม่อยู่** → append domain ต่อท้าย directive นั้น
   - ถ้า domain **อยู่แล้ว** → ข้าม (idempotent) ไม่ duplicate
5. เขียน `_headers` กลับ (รักษา indent + format เดิม)
6. แจ้งนักเรียน

### Report (Mode B)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 อัพเดต security policy ให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ เพิ่มสิทธิ์ให้ [widget name หรือ domain]
   - <domain 1> โหลดได้แล้ว
   - <domain 2> โหลดได้แล้ว
   [list domain ที่เพิ่ม + directive ที่เพิ่มเข้าไป]

ℹ️ ต้อง deploy ใหม่ก่อนเห็นผล (ไฟล์ _headers ทำงานบน Cloudflare เท่านั้น)
ℹ️ ถ้า browser ยัง block console error อาจมี domain เพิ่มที่ต้องเพิ่มอีก ส่ง error ให้ผมดูได้
```

### Idempotent

เรียกซ้ำกี่ครั้ง domain ไม่ duplicate ดังนั้น
- widget skill เรียก best-practices merge mode ทุกครั้งที่ apply widget ใหม่ ปลอดภัย
- ถ้านักเรียน revert + เพิ่ม widget เดิมใหม่ ไม่ต้อง dedupe เอง

### Common widget → CSP map (อ้างอิงสำหรับ widget skill ใหม่)

| Widget | script-src | style-src | frame-src | connect-src | form-action |
|--------|-----------|-----------|-----------|-------------|-------------|
| Calendly inline embed | https://assets.calendly.com | https://assets.calendly.com | https://calendly.com | https://*.calendly.com | — |
| Crisp chat | https://client.crisp.chat | — | — | wss://client.relay.crisp.chat https://client.crisp.chat | — |
| Google Tag Manager | https://www.googletagmanager.com | — | — | https://www.google-analytics.com | — |
| GA4 (via GTM) | https://www.googletagmanager.com | — | — | https://www.google-analytics.com https://*.analytics.google.com | — |
| Instagram embed | https://www.instagram.com | — | https://www.instagram.com | — | — |
| TikTok pixel | https://analytics.tiktok.com | — | — | https://analytics.tiktok.com | — |
| YouTube embed | — | — | https://www.youtube.com https://www.youtube-nocookie.com | — | — |
| Facebook Pixel | https://connect.facebook.net | — | — | https://www.facebook.com | — |
| Mailchimp embed | https://*.list-manage.com | — | — | https://*.list-manage.com | https://*.list-manage.com |
| Hotjar | https://static.hotjar.com https://script.hotjar.com | — | — | https://*.hotjar.com wss://*.hotjar.com | — |
| Stripe Checkout | https://js.stripe.com | — | https://js.stripe.com https://hooks.stripe.com | https://api.stripe.com | — |
| LINE Login | https://static.line-scdn.net | — | — | https://api.line.me | — |
| Cloudflare Turnstile | https://challenges.cloudflare.com | — | https://challenges.cloudflare.com | — | — |

ตารางนี้ widget skill ใหม่ใช้ดูได้ ถ้า widget ไม่อยู่ในตาราง ดูจาก documentation ของ widget นั้น หรือ deploy ทดสอบแล้วดู console error

---

## Edge cases

### นักเรียนใช้ host ที่ไม่ใช่ Cloudflare/Netlify

ถ้า CLAUDE.md ระบุ host อื่น (Vercel GitHub Pages) แจ้ง
> "ไฟล์ _headers นี้ใช้ได้กับ Cloudflare Pages และ Netlify เท่านั้น
> ถ้าคุณใช้ host อื่นบอกผมนะคะ/ครับ จะตั้งให้แบบที่ host นั้นรองรับ
> (Vercel = vercel.json, GitHub Pages = ทำไม่ได้)"

### นักเรียนเพิ่ม external script ภายหลัง

ถ้านักเรียนบอกว่า embed TikTok / Google Analytics / Facebook chat แล้ว console error CSP block
- หา domain ที่ต้องเพิ่ม
- แก้ `_headers` เพิ่ม domain ใน `script-src` หรือ `connect-src` ตามประเภท
- แจ้งนักเรียนแก้แล้วต้อง deploy ใหม่ค่อยเห็นผล

---

## สิ่งที่ต้องระวัง

- **ห้ามทับ `_headers` เดิม** ถ้านักเรียนเคยตั้งเอง ถามก่อนทุกครั้ง
- **CSP เป็น strict (ไม่มี `'unsafe-inline'` ใน style-src/script-src)** ต้องการให้ web-finish แยก inline `<style>` และ `<script>` ออกเป็น styles.css + scripts.js ก่อน ถ้า web-finish ยังไม่ได้ทำ (เช่นนักเรียน skip หรือ revert) browser จะ block ทุก inline block หน้าเว็บจะเสีย ตรวจก่อนเสมอว่ามี styles.css + scripts.js + ไม่มี inline `<style>`/`<script>` block ใน HTML แล้วจริง
- **Fallback ถ้า extraction ล้มเหลว** ถ้า web-finish บอกว่า extraction = partial (เช่น script ใช้ document.write) ต้องเพิ่ม `'unsafe-inline'` กลับมาเฉพาะ script-src หรือ style-src ที่จำเป็น และ comment เหตุผลใน `_headers` ให้รู้ว่าทำไม
- **inline `style="..."` attribute** ยังอนุญาตด้วย `style-src-attr 'unsafe-inline'` เพราะ Claude Design ใช้บ่อย และ attribute ไม่สามารถมี script ได้ ปลอดภัย
- **localhost จะไม่เห็น header ทำงาน** Cloudflare อ่าน `_headers` ตอน serve เว็บจริงเท่านั้น อย่ารายงานว่าใช้ได้จาก localhost
- **อย่าใช้ technical term กับนักเรียน** ไม่ใช้คำว่า HSTS CSP MIME sniff XSS clickjacking (พูดว่า "บังคับ HTTPS" "ตั้งกฎ resource" "browser ไม่เดาประเภทไฟล์" "ไม่ให้ฝัง iframe")
- **CSP test แล้วกับ Claude Design + Cloudflare Web Analytics + Google Forms** ของ 3 อย่างนี้ทำงานด้วย default ที่ตั้งไว้
- **ถ้านักเรียนเพิ่ม external service** (TikTok GA Tag Manager Hotjar Crisp chat) ต้องเพิ่ม domain ใน CSP เอง อย่าลืมเช็ค console error
- **ห้าม reset CSP ทับ domain ที่ widget ลงทะเบียนไว้** นี่คือ invariant ข้อสำคัญ widget skill (web-add) เขียน domain ของ Calendly Maps ฯลฯ ลง `_headers` ผ่าน Mode B ตอนติดตั้ง เวลา re-run จาก orchestrator (Mode A) เจอ `_headers` ที่มีอยู่แล้ว **ห้ามเขียนทับกลับเป็น default** ต้องรักษา domain ทุกตัวที่มีอยู่ (Step 2 default ไปทาง merge/เก็บของเดิม) ไม่อย่างนั้น widget ที่นักเรียนเพิ่มไว้จะกลับมาโดน browser block หน้าเว็บพัง `_headers` คือแหล่งความจริงเดียวของรายชื่อ domain ที่อนุญาต การแก้ทุกครั้งเป็น merge เท่านั้น
