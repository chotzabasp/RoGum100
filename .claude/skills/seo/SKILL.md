---
name: seo
description: ตรวจ + เพิ่ม SEO ให้เว็บนักเรียนเพื่อให้คนหาเจอบน Google และลิงก์ดูสวยตอนแชร์ใน LINE Facebook IG ทำงาน 2 โหมด auto-fix ส่วนที่มีคำตอบถูกแบบเดียว (lang viewport charset robots sitemap canonical og:type og:locale) และถามนักเรียนเฉพาะส่วนที่ต้องรู้ความตั้งใจ (title description รูป preview ตอนแชร์ LINE FB). Triggers include "ตรวจ seo", "ทำ seo", "seo เว็บ", "เพิ่ม og tags", "ทำให้ google หาเจอ", "ลิงก์แชร์สวย", "แชร์ไลน์ให้สวย", "แชร์เฟสให้สวย", "share preview", "open graph", "seo", or any similar request to make the site findable on Google and look good when shared. Reads index.html + pages/*.html directly no Node no Lighthouse needed creates robots.txt + sitemap.xml automatically. Auto-fixes deterministic meta tags silently and for the parts that need student intent (title description preview image) it offers 3 generated options pre-built from CLAUDE.md scope and writing so the student can pick instead of writing from blank. Built for absolute beginners with zero coding knowledge writes in pure Thai without em dash or comma between Thai clauses.
---

# seo ทำให้คนหาเจอ + ลิงก์แชร์สวย

ภารกิจ 2 อย่าง

1. **Google หาเจอ** ใส่ meta tag + sitemap + robots.txt ที่จำเป็น
2. **ลิงก์แชร์สวย** ใส่ Open Graph + Twitter Card ให้ ตอนนักเรียน paste ลิงก์ใน LINE Facebook IG จะมีรูป + ชื่อ + คำอธิบายขึ้นเรียบร้อย สำหรับ audience ไทยอันนี้สำคัญกว่า Google อีก

ทำงาน 2 mode

- **Auto-fix** ส่วนที่มีคำตอบถูกแบบเดียว เช่น lang viewport charset robots.txt sitemap.xml og:type og:locale ทำให้เลยไม่ต้องถาม
- **ถามนักเรียน** ส่วนที่ต้องรู้ความตั้งใจ เช่น title คำอธิบาย รูป preview ตอนแชร์

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลัก

- **ภาษาไทยเรียบง่าย** นักเรียนไม่รู้จัก HTML meta tag og:image
- **อธิบายเป็นภาษาคน** ห้ามโชว์ technical term หรือ tag code ในรายงาน
- **Fix ก่อน ถามทีหลัง** สิ่งที่มีคำตอบถูกแบบเดียว แก้เลยไม่ต้องขอ approve
- **ห้ามแต่งค่า** ที่ต้องการความตั้งใจของนักเรียน (title คำอธิบาย รูป LocalBusiness ที่อยู่ เบอร์) ห้ามเดาเอง ถามเสมอ
- **เคารพ tag ที่มีอยู่แล้ว** ถ้านักเรียนหรือ Claude Design ใส่ tag ไว้แล้ว อย่าทับ ทับเฉพาะถ้าเป็น placeholder
- **เคารพ web-finish** ที่เพิ่ม viewport ไปแล้วบ่อยครั้ง ตรวจก่อนเพิ่ม
- **Static-files-only** เขียนแค่ไฟล์ที่ทำงานได้ทุก host (robots.txt sitemap.xml meta tag) ไม่ต้องใช้ server config คอร์สนี้ใช้ Cloudflare Pages เป็น default และ HTTPS + redirects ถูกจัดการให้แล้ว ถ้านักเรียนใช้ host อื่นก็ยังใช้งานได้ skill เพราะไฟล์ที่สร้างเป็น standard ทั้งหมด
- **อ่าน CLAUDE.md ถ้ามี** เอา archetype + ชื่อร้าน + URL จาก scope/writing blocks ใช้ตอนเสนอค่า

---

## Step 1 ตรวจไฟล์พร้อมไหม

อ่าน project root

| สิ่งที่ต้องเจอ | ถ้าไม่เจอ |
|----------------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `CLAUDE.md` (optional) | อ่าน archetype + ชื่อร้าน + URL ถ้ามี |

---

## Step 2 อ่าน HTML ทุกหน้า

อ่าน `index.html` + ทุกไฟล์ใน `pages/*.html`

เก็บข้อมูล
- `<title>` ปัจจุบันของแต่ละหน้า (มี placeholder `[ชื่อร้าน]` ไหม)
- meta tag ที่มีอยู่แล้ว (description viewport charset OG Twitter canonical)
- ข้อความ hero/lead ของแต่ละหน้า ใช้เสนอ description
- รายชื่อรูปใน `assets/images/` ใช้เสนอ og:image
- placeholder `[...]` ที่ยังไม่ได้แทนค่า ถ้ามี ย้ำให้นักเรียนแทนก่อนตรวจ seo (เรียก /web-finish)

---

## Step 3 Auto-fix เทคนิคพื้นฐาน (เงียบๆ)

แก้ตรงนี้โดยไม่ต้องถาม เพราะมีคำตอบถูกแบบเดียว

### 3.1 lang charset viewport ใน <head>

| ถ้าไม่มี | เพิ่ม |
|---------|------|
| `<html lang="...">` หรือ lang ไม่ถูก | ตั้ง `<html lang="th">` (เนื้อหาเว็บเป็นภาษาไทย) |
| `<meta charset="UTF-8">` | เพิ่มเป็นบรรทัดแรกใน head |
| `<meta name="viewport">` | เพิ่ม `<meta name="viewport" content="width=device-width,initial-scale=1">` (web-finish น่าจะเพิ่มไปแล้ว ตรวจซ้ำกันพลาด) |

### 3.2 Canonical URL

ถ้ารู้ URL ของเว็บ (จาก CLAUDE.md หรือ `git remote get-url origin` หรือถาม) ใส่ใน <head>
```html
<link rel="canonical" href="https://yoursite.pages.dev/">
```
ถ้ายังไม่มี URL จริง ข้ามไป Step 5 จะถามตอนนั้น

### 3.3 robots.txt

ถ้าไม่มีไฟล์ `robots.txt` ที่ project root สร้างให้
```
User-agent: *
Allow: /

Sitemap: https://yoursite.pages.dev/sitemap.xml
```
แทน `yoursite.pages.dev` เป็น URL จริงถ้ารู้ ถ้ายังไม่รู้ ใส่ placeholder ไว้ก่อนแล้วแจ้ง student ตอน Step 7 ให้แก้ตอน deploy

### 3.4 sitemap.xml

สร้างจาก index.html + ทุกหน้าใน pages/ ที่เจอ
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://yoursite.pages.dev/</loc></url>
  <url><loc>https://yoursite.pages.dev/about/</loc></url>
</urlset>
```

---

## Step 4 Auto-fix Open Graph + Twitter (เงียบๆ ส่วนที่ทำได้)

ใส่ meta tag พื้นฐานเข้า <head> ของทุกหน้า ส่วนที่ต้องถามทำใน Step 5

```html
<meta property="og:type" content="website">
<meta property="og:locale" content="th_TH">
<meta property="og:site_name" content="<ชื่อร้านจาก CLAUDE.md หรือจาก title ปัจจุบัน>">
<meta property="og:url" content="https://yoursite.pages.dev/">

<meta name="twitter:card" content="summary_large_image">
```

ส่วน `og:title` `og:description` `og:image` ทำใน Step 5 (ต้องถามนักเรียน)

---

## Step 5 ถามนักเรียน 3 อย่างที่ต้องการความตั้งใจ

### 5.1 ชื่อเว็บ (title)

อ่าน CLAUDE.md (scope + writing block) + headline ของหน้า → สร้าง **3 options** ให้นักเรียนเลือก

หลักการเขียน
- 50-60 ตัวอักษร
- ขึ้นต้นด้วย keyword ที่คนค้นหา (ที่นักเรียนระบุใน scope)
- ตามด้วยชื่อร้าน (อ่านจาก CLAUDE.md หรือจาก placeholder ที่ web-finish แทนแล้ว)
- แต่ละ option ใช้ angle ต่างกัน เพื่อให้นักเรียนเห็นตัวเลือกที่หลากหลาย

แสดงนักเรียน

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✏️ ตั้งชื่อเว็บ (ขึ้นใน tab + Google)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ผมแนะนำ 3 แบบ เลือกแบบที่ชอบ หรือพิมพ์ของตัวเองก็ได้นะคะ/ครับ

A. เครื่องเสียงรถยนต์ติดตั้งโดยมืออาชีพ | ตูนคาร์ออดิโอ
   (เน้นคำที่คนค้นหา + ชื่อร้าน)

B. ตูนคาร์ออดิโอ ร้านเครื่องเสียงรถยนต์ที่อยู่กับรถมา 10+ ปี
   (เน้นความน่าเชื่อถือ ปีประสบการณ์)

C. ร้านเครื่องเสียงรถยนต์ เสียงนุ่ม ฟังเพลิน | ตูนคาร์ออดิโอ
   (เน้น benefit ที่ลูกค้าจะได้)

ตอบ A B หรือ C
หรือพิมพ์ของตัวเองได้เลย (ไม่เกิน 60 ตัวอักษร)
```

ถ้านักเรียนพิมพ์ของตัวเองเกิน 60 ตัวอักษร แจ้ง "ยาวไปนิดนะคะ/ครับ Google จะตัดส่วนปลาย ลองสั้นกว่านี้นะคะ/ครับ" แล้วเสนอเวอร์ชันสั้นกว่าจากที่นักเรียนพิมพ์

### 5.2 คำอธิบายเว็บ (meta description)

อ่าน hero + section ปัญหา + benefit + CTA → สร้าง **3 options** angle ต่างกัน

หลักการเขียน
- 150-160 ตัวอักษร
- ขึ้นต้นด้วยสิ่งที่ลูกค้าจะได้ ไม่ใช่ feature ของร้าน
- ลงท้ายด้วย call-to-action เบา ๆ (โทรหาเรา ปรึกษาฟรี ดูเมนู ฯลฯ)

แสดงนักเรียน

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✏️ คำอธิบายเว็บ (ขึ้นใต้ชื่อใน Google)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ผมแนะนำ 3 แบบ เลือกแบบที่ชอบ หรือพิมพ์ของตัวเองก็ได้นะคะ/ครับ

A. [ดึงประโยคแรก-สองจาก hero มาเขียนใหม่ให้ 150-160 ตัวอักษร]
   (สั้น ตรงประเด็น เหมาะถ้า hero สื่อความชัดอยู่แล้ว)

B. [รวม benefit จาก section ปัญหา/วิธีแก้ 150-160 ตัวอักษร]
   (เน้นปัญหา + วิธีแก้ เหมาะสำหรับบริการที่ต้องอธิบาย)

C. [เน้น proof point + CTA 150-160 ตัวอักษร เช่น "10+ ปีประสบการณ์ ติดตั้งมาแล้ว 500 คัน ปรึกษาฟรีโทร 02-xxx"]
   (เน้นความน่าเชื่อถือ + ปุ่มชวน)

ตอบ A B หรือ C
หรือพิมพ์ของตัวเองได้เลย (ไม่เกิน 160 ตัวอักษร)
```

ถ้านักเรียนพิมพ์ของตัวเองเกิน 160 ตัวอักษร เสนอเวอร์ชันตัดให้สั้นกว่า แทนการ reject

### 5.3 รูป preview ตอนแชร์ลิงก์ (og:image)

ถามว่าอยากใช้รูปไหน

> "ตอนคุณ paste ลิงก์เว็บลง LINE หรือ Facebook ระบบจะเอารูป + ชื่อ + คำอธิบายขึ้นแสดงให้
> อยากใช้รูปไหนเป็น preview?
>
> 1. โลโก้ร้าน
> 2. รูป hero (รูปใหญ่ตอนเปิดเว็บ)
> 3. รูปสินค้า/ผลงานเด่น
> 4. ส่งรูปใหม่เป็นไฟล์ (ลากไฟล์ให้ path ขึ้น หรือเซฟลงโฟลเดอร์ก่อน วางภาพในแชทเฉยๆ ใช้ไม่ได้) ผมเรียก web-images ให้ crop ให้ขนาดถูก
> 5. ข้ามไปก่อน (ถ้ายังไม่ได้ deploy เลย ผมเก็บ slot ไว้ ตอน deploy แล้วเรียก /seo ใหม่ ผมใส่ให้)
>
> ขนาดที่ดีที่สุดคือ 1200 x 630 px ผมจะ crop ให้เองถ้ารูปที่เลือกขนาดต่าง"

### ถ้านักเรียนเลือก 5 ข้ามไปก่อน

- ใส่ `og:title` + `og:description` ที่นักเรียนเลือกแล้ว
- **ไม่ใส่ `og:image` `og:image:width` `og:image:height`** (ปล่อยให้รอบหน้ามาใส่ตอนมี URL จริงและรูปจริง)
- บันทึก marker ใน FYI section "og:image รอใส่ตอน deploy แล้ว" เพื่อให้นักเรียนรู้ว่าต้องเรียกซ้ำ
- เว็บใช้งานได้ปกติ แต่ตอนแชร์ลิงก์ LINE/FB จะไม่มีรูป preview จนกว่าจะใส่

ใส่ใน <head>
```html
<meta property="og:title" content="<title ที่ใช้>">
<meta property="og:description" content="<description ที่ใช้>">
<meta property="og:image" content="https://yoursite.pages.dev/assets/images/og-image.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="<คำอธิบายรูปสั้นๆ>">

<meta name="twitter:title" content="<title>">
<meta name="twitter:description" content="<description>">
<meta name="twitter:image" content="https://yoursite.pages.dev/assets/images/og-image.jpg">
```

ถ้า og:image ต้อง crop เป็น 1200x630 เรียก /web-images ให้จัดการ ห้าม resize เอง

---

## Step 6 LocalBusiness JSON-LD (เฉพาะร้านท้องถิ่น)

อ่าน archetype จาก CLAUDE.md ถ้าเป็น `local_business` หรือเจอ contact section ที่มีที่อยู่ + เบอร์ เสนอ

> "ผมเสนอใส่ข้อมูลร้านแบบที่ Google เข้าใจให้ด้วยไหมคะ/ครับ จะช่วยให้คนหาเจอตอนค้นใกล้ฉัน ขอข้อมูลพวกนี้
> - ที่อยู่ร้าน
> - เบอร์โทร
> - เวลาเปิด-ปิด
> - ลิงก์ Google Maps (ถ้ามี)"

ถ้านักเรียนตอบ ใส่ JSON-LD ใน <head>
```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "<ชื่อร้าน>",
  "image": "https://yoursite.pages.dev/assets/images/og-image.jpg",
  "telephone": "<เบอร์>",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "<ที่อยู่>",
    "addressCountry": "TH"
  },
  "openingHours": "<เช่น Mo-Fr 09:00-18:00>",
  "url": "https://yoursite.pages.dev/"
}
</script>
```

ถ้านักเรียนยังไม่อยากใส่ตอนนี้ ข้ามได้ ใส่ทีหลังก็ได้

สำหรับ archetype อื่น (solopreneur freelancer personal_brand validator) ใช้ `Person` หรือ `Organization` schema แทน หรือข้ามไปก็ได้ ไม่ critical เท่า OG tags

---

## Step 7 รายงานนักเรียน (3 buckets)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 ตรวจ SEO ให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ แก้ให้อัตโนมัติแล้ว [N] จุด
   [list จาก Step 3 + 4 แปลเป็นภาษาคน ตามตารางด้านล่าง]

✏️ ใส่ให้แล้วจากที่คุณตอบ
   - ชื่อร้านใน title และ og:title
   - คำอธิบายเว็บ (description)
   - รูป preview ตอนแชร์ลิงก์ (1200x630)
   [+ LocalBusiness JSON-LD ถ้าใส่]

ℹ️ บอกไว้ให้รู้
   - ลองแชร์ลิงก์เว็บใน LINE chat ตัวเองดู preview ควรขึ้นรูป + ชื่อ + คำอธิบายแล้ว
   - ถ้ายังไม่มี URL จริงตอนนี้ ผมใส่ placeholder ไว้ ตอน deploy ขึ้น Cloudflare แล้ว แจ้งให้ผมแก้เป็น URL จริงนะคะ/ครับ
   - (Day 2) ตอน deploy แล้ว ใส่เว็บใน Google Search Console เพื่อให้ Google เก็บไป
```

### ตารางแปลเป็นภาษาคน

| สิ่งที่แก้ | บอกนักเรียนว่า |
|-----------|----------------|
| lang="th" | "บอก browser ว่าเว็บเป็นภาษาไทย" |
| charset UTF-8 | "บอก browser ให้อ่านภาษาไทยถูก" |
| viewport | (web-finish ใส่ไปแล้วปกติ ไม่ต้องบอกซ้ำ) |
| canonical | "บอก Google ว่า URL หลักของเว็บคืออันนี้" |
| robots.txt | "บอก Google ว่าให้เข้ามาเก็บข้อมูลได้" |
| sitemap.xml | "ส่งรายชื่อหน้าทั้งหมดให้ Google" |
| og:type og:locale og:site_name | "เตรียมข้อมูล preview พื้นฐานสำหรับ LINE/FB" |
| twitter:card | "ให้ Twitter/X แสดง preview แบบรูปใหญ่" |
| og:image og:title og:description | "preview ที่ขึ้นตอนคนแชร์ลิงก์" |
| LocalBusiness JSON-LD | "ให้ Google เข้าใจว่าร้านอยู่ที่ไหน เบอร์อะไร เวลาเปิด-ปิด" |

---

## Step 8 ปิดท้าย

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 SEO เรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ สรุป
- meta tag พื้นฐาน [N] ตัว
- robots.txt + sitemap.xml พร้อม
- preview ตอนแชร์ (LINE FB) พร้อม
[+ LocalBusiness JSON-LD ถ้าใส่]

ต่อไป
1. /save-work       เซฟขึ้น GitHub
2. ตอน deploy แล้ว ลองแชร์ลิงก์ใน LINE chat ตัวเองดู preview
3. (Day 2) Google Search Console submit sitemap
```

---

## สิ่งที่ต้องระวัง

- **ห้ามแต่งค่า** ที่ต้องการความตั้งใจของนักเรียน (title description รูป LocalBusiness ที่อยู่ เบอร์ เวลาเปิด-ปิด)
- **เคารพ tag ที่มีอยู่แล้ว** ถ้านักเรียนหรือ Claude Design ใส่ไว้แล้ว ห้ามทับ ทับเฉพาะถ้าเป็น placeholder
- **og:image ต้องเป็น absolute URL** (ขึ้นต้น https://) ไม่ใช่ relative path เพราะ LINE FB อ่านจากภายนอก
- **og:image ขนาด 1200x630** ถ้ารูปที่นักเรียนเลือกผิดขนาด เรียก /web-images ห้าม resize เอง
- **robots.txt + sitemap.xml ต้องใส่ URL จริง** ถ้ายังไม่รู้ ใส่ placeholder + แจ้งให้แก้ตอน deploy
- **อย่าใช้ technical term กับนักเรียน** ไม่ใช้คำว่า crawl index canonical schema slug ใช้ภาษาคน "Google เก็บข้อมูล" "URL หลัก" "ข้อมูลที่ Google เข้าใจ"
- **JSON-LD ใส่ใน <head> ก่อน </head>** ไม่ใช่ใน body
- **web-finish เป็นคนใส่ viewport ไปแล้วบ่อยครั้ง** ตรวจก่อนเพิ่มซ้ำ
- **CLAUDE.md ถ้ามีให้อ่านก่อน** archetype + ชื่อร้าน + url อยู่ใน scope/writing blocks เอามาใช้ตอนเสนอค่าจะเร็วกว่าถามใหม่
- **ถ้าหน้าเว็บมี placeholder `[...]` ค้าง** เตือนนักเรียนเรียก /web-finish ใส่ค่าจริงก่อน เพราะ description/title จาก placeholder จะไม่ make sense
- **sitemap ต้องครอบคลุมหน้าใหม่** สร้าง sitemap.xml จาก `index.html` + ทุก `pages/*.html` ที่เจอจริงตอนรัน ถ้านักเรียนเพิ่มหน้าใหม่ระหว่างทาง การรัน seo ซ้ำจะ regenerate sitemap ให้รวมหน้าใหม่เอง
- **element ที่มี `data-cnc-widget` ห้าม rewrite/ลบ** widget ที่ web-add ฝังไว้ติด marker นี้ seo เพิ่ม meta/JSON-LD ใน head ได้ปกติ แต่ห้ามแตะ markup ของ widget ในเนื้อหน้า
