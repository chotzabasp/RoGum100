---
name: web-design
description: Use when the student is ready to design their website visually after finishing web-scope and web-writing triggers include "ออกแบบเว็บ", "design เว็บ", "ทำหน้าตาเว็บ", "ทำ prompt ให้ Claude Design", "เริ่มออกแบบ", "web-design", or any similar request to generate a Claude Design prompt. Reads web-scope and web-writing blocks from CLAUDE.md confirms the goal asks 4 simple questions (creative dials color reference remix numeral preference) generates a SHORT prompt and points to the universal cnc-design-system codebase at the repo root. The student attaches the codebase folder and pastes the prompt into claude.ai/design to produce a unique on-brand mobile-first HTML/CSS landing page. The skill does NOT generate HTML itself. Built for absolute beginners with zero design experience writes in pure Thai without em dash or comma between Thai clauses.
---

# web-design สร้าง prompt + codebase สำหรับ Claude Design

ช่วยนักเรียนสร้าง 2 สิ่งสำหรับ claude.ai/design

1. **codebase folder** (universal design system เหมือนกันทุก student) ลากเข้า Claude Design
2. **short prompt** (เฉพาะ project) paste เข้า Claude Design

Architecture นี้แยก
- **Universal rules** (mobile-first anti-slop tokens) อยู่ใน codebase
- **Per-project** (content color dials remix) อยู่ใน prompt

ทำให้ทุก student ได้เว็บที่ mobile-friendly + on-brand + ไม่ซ้ำกัน

---

## กฎเด็ดขาด Thai content

ห้าม em dash (—) ห้าม comma (,) แยก clause ใน Thai text ใช้ space เท่านั้น

---

## กฎหลักอื่นๆ

- **ภาษาไทยเรียบง่าย** student ไม่เคยออกแบบเว็บ
- **ถาม 4 คำถามเท่านั้น** dials + color + remix + numerals
- **ไม่ generate HTML เอง** หน้าที่คือทำ prompt + copy codebase
- **codebase เหมือนกันทุก student** ห้ามแก้ per-project (per-project อยู่ใน prompt)

---

## Step 1 อ่าน CLAUDE.md

| Block | จำเป็น | ใช้ทำอะไร |
|-------|--------|----------|
| `<!-- web-scope:v1 -->` | ✅ | archetype business audience CTA channels |
| `<!-- web-writing:v1 -->` | ✅ | headline sections CTA framework tone |

| ผลลัพธ์ | การจัดการ |
|---------|----------|
| มีทั้ง 2 block | ✅ ไปต่อ |
| ขาด web-scope | แจ้ง "ต้องทำ `/web-scope` ก่อนนะ" จบ |
| ขาด web-writing | แจ้ง "ต้องทำ `/web-writing` ก่อนนะ" จบ |

---

## Step 2 Recap + Confirm Goal + เริ่มถาม

recap สิ่งที่รู้ + **confirm goal จาก web-scope** (primary action) ไม่ถามซ้ำ แค่ยืนยัน

> "ผมเห็นว่าคุณทำ [business] เนื้อหาแบบ [framework] น้ำเสียง [tone]
>
> เป้าหมายหลักของเว็บคือให้ลูกค้า **[primary action จาก web-scope เช่น ทักไลน์ / กรอกฟอร์ม / โทร]** ใช่ไหมคะ/ครับ
>
> ถ้าใช่ ผมจะถาม 4 คำถามสั้นๆ เพื่อสร้าง prompt + design system ให้ paste ใน Claude Design นะคะ/ครับ"

ถ้า student แก้ goal → update ใน prompt GOAL section

---

## Step 3 คำถามที่ 1 Creative Dials

> "อยากให้เว็บมีความรู้สึกแบบไหน (ตอบเป็นเลข 1-10 แต่ละข้อ หรือบอกแบบกว้างๆ ก็ได้)
>
> 🎨 **ความกล้า/สร้างสรรค์** (Variance)
>    1 = ปลอดภัย เรียบ คาดเดาได้
>    10 = กล้า แปลก experimental
>
> ⚡ **ความเคลื่อนไหว** (Motion)
>    1 = นิ่ง สงบ
>    10 = animation เยอะ พลังสูง
>
> 📦 **ความแน่น** (Density)
>    1 = โล่ง whitespace เยอะ minimal
>    10 = แน่น ข้อมูลเยอะ packed"

### Default ถ้า student ไม่แน่ใจ (แนะนำตาม tone)

| Tone จาก web-writing | Variance | Motion | Density |
|----------------------|----------|--------|---------|
| เป็นกันเอง อบอุ่น | 6 | 4 | 4 |
| มืออาชีพ น่าเชื่อถือ | 5 | 4 | 5 |
| ตรง พูดแบบช่าง bold | 8 | 7 | 8 |
| นุ่มนวล calm wellness | 6 | 2 | 3 |
| กวนๆ มีเอกลักษณ์ | 9 | 6 | 6 |

ปรับ Density เพิ่มตาม Visual จาก web-scope
- Visual = text-heavy → Density +1 หรือ +2 (ข้อมูลเยอะ)
- Visual = gallery → Density +1 (รูปเยอะ)
- Visual = minimal → Density -1 หรือ -2 (โล่ง)

---

## Step 4 คำถามที่ 2 Color

> "เรื่องสีของเว็บ เลือก 1 ข้อ
>
> (A) มี brand color อยู่แล้ว บอกสีหลักมาเลย (ภาษาไทยหรือ hex ก็ได้)
> (B) ยังไม่มี อยากให้ผมแนะนำตามธุรกิจ"

### ถ้าเลือก A

ถามต่อ "สีหลัก (พื้นหลัง) สีรอง สีปุ่มเน้น เป็นอะไรบ้าง บอกแบบเรียบง่ายเช่น ดำ-ขาว-แดง"
แปลงเป็น hex 60-30-10

### ถ้าเลือก B แนะนำตาม tone จาก web-writing

| Tone | 60% | 30% | 10% accent |
|------|-----|-----|------------|
| เป็นกันเอง อบอุ่น | #FAF6F1 cream | #4A4A4A dark grey | #D4A574 soft amber |
| มืออาชีพ น่าเชื่อถือ | #FFFFFF white | #0A1F44 navy | #FF6B35 orange |
| ตรง พูดแบบช่าง bold | #0F0F0F near-black | #F5F1EB off-white | #E63946 crimson |
| นุ่มนวล calm wellness | #F5F0E8 cream | #2B3A2E forest sage | #C97B5B terracotta |
| กวนๆ มีเอกลักษณ์ | #FFFFFF white | #000000 black | #FFE600 electric yellow |

โชว์ palette ที่แนะนำ + ขอ confirm หรือให้ปรับ

---

## Step 5 คำถามที่ 3 Reference Remix

> "อยากให้เว็บมี vibe คล้ายแบรนด์ไหน (เลือก 1 หรือบอกเองได้)
> ระบบจะผสม 2 แบรนด์เพื่อให้ได้ความรู้สึกเฉพาะตัว ไม่ลอกใคร"

แนะนำตาม archetype พร้อมคำอธิบายไทย (student ไม่ต้องรู้จักแบรนด์)

| Archetype + tone | Reference remix | อธิบายไทย |
|------------------|-----------------|-----------|
| Local Business bold | Berghain + Off-White | ดิบ industrial เท่ ตัวอักษรหนา |
| Local Business warm | Aesop + Muji | สะอาด อบอุ่น เรียบหรู |
| Personal Brand editorial | Kinfolk + Aesop | นิตยสาร สงบ refined |
| Solopreneur coach energetic | Nike + Barry's | พลังสูง สปอร์ต กระแทกใจ |
| Solopreneur coach calm | Headspace + Aesop | นุ่ม สบาย wellness |
| Validator tech | Linear + Stripe | minimal สะอาด tech |
| Freelancer portfolio | A24 + Criterion | หนัง indie มีระดับ |
| Personal Brand creator | Bandcamp + Are.na | ดิบ indie ใต้ดิน |

โชว์ตัวเลือก + คำอธิบายไทย ให้ student เลือกหรือบอกเอง

---

## Step 6 คำถามที่ 4 Numerals

> "เลขในเว็บอยากให้เป็นแบบไหน
> (A) เลขอาราบิค (1 2 3 21 100) อ่านง่ายทุกคน
> (B) เลขไทย (๑ ๒ ๓ ๒๑ ๑๐๐) refined วัฒนธรรม
> 💡 ไม่แน่ใจเลือก A"

---

## Step 7 ตรวจ Codebase ที่ Project Root

`codebase/` folder อยู่ที่ **project root** อยู่แล้ว (มาพร้อม repo ตอน `/connect-repo`)
student เห็นได้ทันทีเมื่อเปิด project (ไม่ต้องขุดลึกใน .claude)

### ตรวจว่ามีไหม

```powershell
# Windows
if (Test-Path "codebase\styles.css") { "codebase OK" } else { "MISSING" }
```

```bash
# macOS
[ -f codebase/styles.css ] && echo "codebase OK" || echo "MISSING"
```

### ถ้าไม่มี (student ลบหรือ clone ไม่ครบ)

แจ้ง student "ไม่เจอ folder codebase ใน project ลอง `/connect-repo` ใหม่ หรือ pull repo ล่าสุด"

codebase เป็น universal เหมือนกันทุก student ไม่ต้อง generate ใหม่
per-project ทั้งหมดอยู่ใน prompt

---

## Step 8 Generate Short Prompt

ใช้ data ทั้งหมด (web-scope + web-writing + 4 คำตอบ) สร้าง prompt ตาม template

### Prompt Template

```
GOAL
[1-2 lines what the page does + primary action จาก web-scope]

REFERENCE REMIX
Tone should feel a mix of [ref1] + [ref2]
[vibe descriptor 1 line]

CONTENT (use EXACTLY as written)

[ทุก content จาก web-writing verbatim
headline sub sections CTA form testimonials
keep [bracket placeholders] as-is]

COLOR PALETTE override design system defaults
60% dominant [hex] [name]
30% secondary [hex] [name]
10% accent [hex] [name]

CREATIVE DIALS
Variance [N] ([descriptor])
Motion [N] ([descriptor])
Density [N] ([descriptor])

Numerals [Arabic/Thai]

Apply ALL rules from attached cnc-design-system codebase.
Before generating propose 3 STRUCTURALLY DIFFERENT approaches from different
categories in the codebase structural pattern library.
Pick the most distinctive that fits [vibe] not the safest.
```

### กฎการ generate

- **Content verbatim** จาก web-writing ห้ามแก้
- **keep placeholders** `[ชื่อร้าน]` `[LOGO]` etc
- **Color จาก Step 4** (ที่ student เลือกหรือ confirm)
- **No em dash** ใน Thai content
- **prompt สั้น** อย่ายัด technical rules (codebase จัดการแล้ว)

---

## Step 9 โชว์ผล + Edit Loop

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎨 พร้อมออกแบบใน Claude Design แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ผมเตรียม 2 สิ่งให้

1️⃣ codebase folder
   อยู่ที่ project ของคุณแล้ว (folder ชื่อ codebase)

2️⃣ Prompt ด้านล่าง

[short prompt ทั้งหมด]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ขั้นตอนใน Claude Design
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. ไป https://claude.ai/design
2. คลิก "Skills and design systems" (มุมบนซ้าย)
3. คลิก "Attach codebase"
4. ลาก folder "codebase" จาก project เข้าไป
5. Copy prompt ด้านบน paste ในช่องพิมพ์
6. Submit รอ Claude Design สร้าง

💡 ถ้าผลออกมาอยากปรับ ใช้ Tweaks slider ใน Claude Design
   หรือพิมพ์ comment ตรงๆ ไม่ต้องเริ่มใหม่
```

### Edit loop

ถาม "อยากปรับ dials หรือ remix หรือสีไหม" ถ้าแก้ regenerate prompt loop จนพอใจ

---

## Step 10 เขียนลง CLAUDE.md

**ตรวจ plan mode** ถ้าอยู่ใน plan mode ExitPlanMode ก่อน

หา `<!-- web-design:v1 -->` แทนที่ block ถ้ามี ไม่มี append

```markdown
<!-- web-design:v1 -->
## Web Design

### Inputs
- **Variance:** [N]
- **Motion:** [N]
- **Density:** [N]
- **Reference remix:** [ref1 + ref2]
- **Numerals:** [Arabic/Thai]
- **Color 60%:** [hex]
- **Color 30%:** [hex]
- **Color 10%:** [hex]

### Generated Prompt
```
[short prompt ทั้งหมด]
```

### ตัดสินใจวันที่
[DD-MM-YYYY]
<!-- /web-design -->
```

---

## Step 10.5 เสนอตัวอย่างจาก Claude Code (offer-first)

หลังบันทึก CLAUDE.md เสนอ student สร้างตัวอย่างหน้าเว็บด้วย Claude Code ไว้ดูระหว่างรอ Claude Design
เป็นการเสนอของแถม ไม่ใช่บังคับเลือก A หรือ B (beginner ตอบ Y/N กับของแถมได้ แต่เลือก engine เองไม่ได้)

> "อยากให้ Claude Code ลองออกแบบหน้าเว็บอีกแบบให้ดูเลยตอนนี้ระหว่างรอ Claude Design ไหมคะ/ครับ
>  อันนี้จะเป็นแบบ **กล้าและครีเอทีฟกว่า** ลูกเล่นเยอะกว่า ส่วน Claude Design จะเป็นแบบเรียบ on-brand ปลอดภัยกว่า
>  คุณจะได้ 2 สไตล์ไว้เทียบกัน เป็นตัวอย่างฟรี เก็บไว้ในฉบับร่าง ถ้าชอบเอาไปใช้แทนได้ ถ้าไม่ชอบลบทิ้งง่ายๆ (Y/N)"

ถ้า **N** → ข้ามไป Step 11 ทำ Path A อย่างเดียว
ถ้า **Y** → ทำต่อด้านล่าง

### เงื่อนไขก่อนทำ

ต้องอยู่ใน git repo (`git remote -v` ไม่ว่าง) ถ้าไม่ใช่ แจ้ง student ว่าตอนนี้ทำ Path A ก่อน
ต่อ GitHub ด้วย `/connect-repo` ทีหลังแล้วค่อยลองตัวอย่าง Claude Code ได้ แล้วข้ามไป Step 11

### ขั้นตอน (ห้ามใช้คำว่า branch กับ student เรียก "ฉบับร่าง")

1. ถ้ามีงานค้าง commit ก่อน
   - Win `git add -A ; if ($?) { git commit -m "เซฟก่อนสร้างตัวอย่าง" --allow-empty }`
   - Mac `git add -A && git commit -m "เซฟก่อนสร้างตัวอย่าง" --allow-empty`
2. จำ branch ปัจจุบันไว้ (ปกติ main) แล้วสร้างฉบับร่าง
   `git checkout -b draft/<YYYY-MM-DD>-claude-code-design`
3. invoke `Skill(web-generate)` รอจนสร้าง index.html styles.css scripts.js เสร็จ (Path B ครีเอทีฟเต็มที่ บังคับ prompt ตรงๆ ไม่อ่าน codebase)
4. commit ลงฉบับร่าง
   - Win `git add -A ; if ($?) { git commit -m "ตัวอย่างหน้าเว็บจาก Claude Code" }`
   - Mac `git add -A && git commit -m "ตัวอย่างหน้าเว็บจาก Claude Code"`
5. สลับกลับฉบับจริง `git checkout main`

**สำคัญ** หลัง Step 10.5 ต้องอยู่บน main เสมอ (main คือเลนของ Path A ต้องสะอาดจนกว่า student จะเลือก)
ตัวอย่าง B อยู่ในฉบับร่างเงียบๆ ไม่กระทบ main

---

## Step 11 ปิดท้าย

### ถ้า student ไม่ได้สร้างตัวอย่าง B (ตอบ N ใน Step 10.5 หรือยังไม่ได้ต่อ git)

> "เสร็จแล้วค่ะ/ครับ 🎉
>
> ขั้นตอนต่อไป
> 1. ลาก folder codebase + paste prompt ใน claude.ai/design
> 2. (optional) drop รูปจริงใน slot ของ preview
> 3. Export zip กลับมา project
> 4. พิมพ์ /web-import แล้วลาก zip เข้ามา
>
> 💡 prompt + design system บันทึกใน CLAUDE.md แล้ว
>    ถ้าอยากออกแบบใหม่ด้วยค่าอื่น พิมพ์ /web-design อีกครั้งได้"

### ถ้า student สร้างตัวอย่าง B แล้ว (ตอบ Y ใน Step 10.5) โชว์ 2 ทางให้เลือก

> "ได้ดีไซน์ 2 สไตล์ให้เทียบกันแล้วค่ะ/ครับ 🎉
>
> 🅰️ **Claude Design แบบเรียบ on-brand ปลอดภัย**
> ตรงตาม design system คุมโทนแบรนด์เป๊ะ คาดเดาผลได้
> 1. ไป https://claude.ai/design
> 2. ลาก folder codebase + paste prompt ด้านบน
> 3. Export zip กลับมา แล้วพิมพ์ /web-import
> (ฉบับจริงของคุณพร้อมรับทาง A อยู่แล้ว)
>
> 🅱️ **Claude Code แบบกล้าและครีเอทีฟกว่า**
> ลูกเล่นเยอะกว่า มีเอกลักษณ์กว่า ผมออกแบบให้แล้วเก็บไว้ในฉบับร่าง
> พิมพ์ /draft-mode แล้วเลือก กลับไปทำต่อ เพื่อเปิดดู
>
> 🤔 **เลือกยังไง**
> อยากได้แบบเรียบ คุมแบรนด์เป๊ะ เลือก A พิมพ์ /web-import ตามปกติ (ผมจะถามว่าจะลบตัวอย่าง B ทิ้งไหม)
> อยากได้แบบกล้า มีเอกลักษณ์ เลือก B พิมพ์ /draft-mode เลือก ใช้เลย แล้วผมเก็บงานต่อให้ด้วย /web-finish อัตโนมัติ
>
> 💡 prompt + design system บันทึกใน CLAUDE.md แล้ว ออกแบบใหม่ด้วยค่าอื่นพิมพ์ /web-design อีกครั้งได้"

**กฎสำคัญ** อย่าทำ /web-import ลง main จนกว่า student จะเลือก main ต้องสะอาดไว้เพื่อให้ merge ตัวอย่าง B
ได้แบบไม่ชนกัน (ถ้าเลือก A แล้ว import คือการเลือก A และจะลบ B ทิ้ง ถ้าเลือก B จะ merge B แล้วข้าม import)

---

## สิ่งที่ต้องระวัง

- **codebase universal** เหมือนกันทุก student อย่าแก้ per-project
- **prompt สั้น** ห้ามยัด technical rules (codebase มีแล้ว)
- **content verbatim** จาก web-writing ห้ามแต่ง
- **No em dash** ใน Thai content ของ prompt
- **Copy codebase ทุกครั้ง** เผื่อ student ยังไม่มีใน project root หรือ codebase update
- **บอก URL ชัด** https://claude.ai/design ไม่ใช่ claude.ai
- **เปลี่ยน dials/remix = regenerate prompt** ใหม่
- **Plan mode aware** ExitPlanMode ก่อนเขียนไฟล์ + copy
