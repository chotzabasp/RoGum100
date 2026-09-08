---
name: web-style
description: Use when the student wants to change how a PART of their site looks without changing its color or content. The thing that makes two students sites feel the same is not the color it is the component anatomy (every button is the same fill every form the same underline). web-style is a catalog of concrete style treatments for the core components (button input choice-control eyebrow heading divider badge card stat index) and the student picks a treatment by taste not by archetype. Color stays exactly as they chose only the treatment changes (a solid button becomes an outline button or a hard-offset block in the SAME accent color). Built on the token+treatment split so the same recipe renders on-brand for every student automatically. Triggers include "เปลี่ยนสไตล์ปุ่ม", "เปลี่ยนหน้าตาปุ่ม", "ปุ่มแบบอื่น", "อยากได้ปุ่มทรงอื่น", "เปลี่ยนสไตล์ฟอร์ม", "เปลี่ยนช่องกรอก", "ทำให้ไม่เหมือนคนอื่น", "เว็บดูเหมือนคนอื่น", "เปลี่ยนสไตล์หัวข้อ", "เปลี่ยนเส้นคั่น", "เปลี่ยน badge", "เปลี่ยนการ์ด", "restyle", "change button style", "change the look", "web-style", or any similar request to restyle a component while keeping the color. Does NOT change color (that is web-design / edit-plan) does NOT change content (that is web-finish / edit-plan) does NOT touch widgets marked data-cnc-widget (web-add owns those and mirrors the core anyway). Writes only external CSS keeps semantic markup keeps focus states and stamps a data-cnc-style marker so a web-quality-audit re-run preserves it. Built for absolute beginners with zero design knowledge shows a live preview of the options in their own colors so they pick from a picture not from words. Works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-style เปลี่ยนสไตล์ component โดยไม่เปลี่ยนสี

นักเรียนรู้สึกว่าเว็บตัวเองหน้าตาเหมือนคนอื่น ปัญหาไม่ใช่สี (สีนักเรียนเลือกเองตั้งใจแล้ว) แต่เป็น **ทรงของ component** ปุ่มทุกคนเป็นบล็อกทึบเหมือนกัน ฟอร์มทุกคนเป็นเส้นใต้เหมือนกัน web-style ให้นักเรียนเลือก **treatment** (ทรง) ของแต่ละ component จากแคตตาล็อก โดย **สีไม่เปลี่ยน** ปุ่มบล็อกทึบกลายเป็นปุ่มเส้นขอบ หรือปุ่มเงาแข็งเหลื่อม ในสี accent เดิมเป๊ะ

skill นี้คือ **เครื่องยนต์ + library ของ treatment** (`library.css` ข้างไฟล์นี้) นักเรียนเลือกด้วยสายตาจาก preview จริงในสีตัวเอง

---

## กฎเด็ดขาด Thai content

ห้าม em dash (—) ห้าม comma (,) แยก clause ใน Thai text ใช้ space เท่านั้น

---

## หัวใจ token + treatment (ทำไมถึงเข้าแบรนด์เองทุกเว็บ)

ทุก recipe ใน `library.css` อ้างแค่ตัวแปร `--cs-accent` `--cs-ink` `--cs-bg` `--cs-radius` ไม่ระบุสีตรงๆ web-style เติมตัวแปรพวกนี้จาก **brand token จริงของนักเรียน** (Step 2) ผลคือ recipe เดียวกัน (เช่น ปุ่มเงาแข็งเหลื่อม) ออกมาเป็น terracotta บนครีมสำหรับเว็บหนึ่ง crimson บนดำสำหรับอีกเว็บ อัตโนมัติ **สีคงเดิม เปลี่ยนแค่ treatment**

นี่คือหลักการเดียวกับ component DNA ที่ web-add ใช้ ([[web-add-architecture]]) แค่เอามาให้นักเรียน **เลือกเอง**

---

## กฎหลัก (lock ไว้)

1. **ไม่เปลี่ยนสี** treatment ทุกตัวใช้ token สีเดิม ห้ามแนะนำสีใหม่ (สีเป็นงานของ web-design / edit-plan)
2. **ไม่เปลี่ยน content** ไม่แตะ headline copy ข้อความ (งานของ web-finish / edit-plan)
3. **เลือกด้วยสายตา ไม่ใช่คำ** เสมอ generate preview จริงในสีนักเรียนแล้วให้เลือกเป็นเลข ([[anti-slop-only-ai-fingerprints]] เลือกตาม taste ไม่ใช่ archetype กัน archetype ผลิตความเหมือน)
4. **ข้าม widget** element ใต้ `data-cnc-widget` เป็นของ web-add ห้ามแตะ (web-add mirror core DNA ให้เองอยู่แล้ว)
5. **เพิ่ม CSS ภายนอกเท่านั้น ห้ามแก้แบบลบ** append block ที่ติด marker ต่อท้าย `styles.css` re-run = แทนที่ block เดิม ไม่รื้อ CSS ของนักเรียน
6. **ภาษาไทยเรียบง่าย** ห้ามโชว์ชื่อ class property ในรายงานนักเรียน

---

## marker `data-cnc-style`

ทุก element ที่ restyle ติด attribute `data-cnc-style="<component>:<treatment>"` (เช่น `button:offset`) และ CSS ที่ append ครอบด้วย `/* cnc-style:button */ ... /* end cnc-style:button */`

marker นี้ทำให้

- **re-run idempotent** หา block เดิมแล้วแทนที่ ไม่ซ้อน
- **audit ปลอดภัย** performance accessibility best-practices เห็นแล้ว preserve ไม่ undo (หลักเดียวกับ `data-cnc-widget` `data-cnc-form`)

---

## invariant ความปลอดภัย (ทำให้ web-quality-audit re-run ผ่านเสมอ)

| ด้าน | web-style ทำยังไง |
|------|--------------------|
| **CSP / best-practices** | เขียน CSS ลง `styles.css` (external) เท่านั้น ไม่มี JS ไม่มี inline `<style>` ไม่มี domain ใหม่ → `_headers` ไม่ต้องแตะ เกรดคงเดิม |
| **performance** | CSS ล้วน (bg border shadow transition) ไม่มี request ใหม่ → Core Web Vitals ไม่กระทบ |
| **accessibility** | restyle ด้วย CSS เท่านั้น เก็บ markup เดิม (`<button>` `<input type=radio>` `<label>`) ห้ามลบ `:focus-visible` ห้ามย่อ tap target ต่ำกว่า 44px |
| **seo** | visual ล้วน ไม่แตะ content → ไม่กระทบ |
| **audit จำได้** | `data-cnc-style` marker → audit preserve ไม่ undo |

**a11y watch** treatment ที่ลด affordance (`button:link` `input:underline` แบบบางมาก) ต้องเหลือ focus state ชัด เตือนนักเรียนว่า "ทรงนี้มินิมอลมาก เหมาะแบรนด์เรียบ" ก่อนใช้

---

## แคตตาล็อก (recipe อยู่ใน `library.css`)

| component | นักเรียนพูด | จำนวนทรง | ตัวอย่างชื่อทรง |
|-----------|-------------|----------|------------------|
| `button` | ปุ่ม | 20 | solid pill outline gradient elevated link offset glow sweep ticket ... |
| `input` | ช่องกรอก | 10 | underline boxed filled ring inset pill heavy float draw |
| `choice` | ตัวเลือก/ปุ่มเลือก | 8 | list cards blocks chips seg tags tabs select |
| `eyebrow` | หัวข้อย่อยนำ | 7 | caps rule num bracket badge dot bar |
| `heading` | หัวข้อใหญ่ | 7 | plain word underline mark big rule mono |
| `divider` | เส้นคั่น | 6 | hair thick dash dot fade label |
| `badge` | ป้ายเล็ก | 6 | solid outline mono dot tint bracket |
| `card` | กล่องเนื้อหา | 8 | hair heavy filled shadow offset left top num |
| `stat` | ตัวเลขเด่น | 6 | stacked accent rule box side mono |
| `index` | เลขลำดับ | 6 | mono circle fill ghost bracket square |

รวม 84 ทรง ทุกทรงเป็น treatment-only overlay (ไม่แตะ layout padding font ของนักเรียน)

---

## flow

```
นักเรียนพูด "เปลี่ยนสไตล์ปุ่ม" หรือ "เว็บดูเหมือนคนอื่น"
   → Step 0 ตรวจความพร้อม
   → Step 1 เลือก component ที่จะเปลี่ยน + หา element/selector จริง
   → Step 2 resolve brand token → เขียน --cs-* normalization (ครั้งเดียวต่อเว็บ)
   → Step 3 generate preview ทุกทรงของ component นั้น ในสีนักเรียน เปิด localhost
   → Step 4 นักเรียนเลือกเลข (+ free-text ปรับเองได้)
   → Step 5 apply append recipe block ที่ติด marker + ใส่ class/attr บน element
   → Step 6 preview ผลจริง + รายงาน
```

---

## Step 0 ตรวจความพร้อม

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` + `styles.css` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ |
| `library.css` ข้างไฟล์ skill | core ของ skill อ่านไม่ได้แจ้ง error |

มี `pages/` หลายหน้า restyle ทุกหน้าที่มี component นั้น (class เดียวกัน CSS เดียว ครอบทุกหน้าอยู่แล้ว)

---

## Step 1 เลือก component + หา selector จริง

**จาก trigger ถ้าชัดอยู่แล้ว ข้ามเมนูไปเลย** (เหมือน web-add)

- "เปลี่ยนสไตล์ปุ่ม" → `button` ตรงไป Step 2 ไม่ต้องถาม
- "เปลี่ยนช่องกรอก / ฟอร์ม" → `input` หรือ `choice`
- "เปลี่ยนหัวข้อ" → `heading` ฯลฯ

**ถ้า trigger กว้าง** ("เว็บดูเหมือนคนอื่น" "อยากเปลี่ยนสไตล์" "ทำให้ไม่ซ้ำใคร") โชว์เมนู แต่ **scan ก่อนแล้วโชว์เฉพาะ component ที่เว็บนี้มีจริง** (ไม่มี badge ในเว็บก็ไม่ต้องโชว์ข้อ badge) ใส่จำนวนทรงในวงเล็บ

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎨 อยากเปลี่ยนสไตล์ส่วนไหนดีคะ/ครับ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
(สีไม่เปลี่ยนนะ เปลี่ยนแค่ทรง)

🔘 ปุ่มและฟอร์ม
   1. ปุ่ม (20 ทรง)
   2. ช่องกรอก (10 ทรง)
   3. ปุ่มตัวเลือก (8 ทรง)

🏷️ หัวข้อและป้าย
   4. หัวข้อใหญ่ (7 ทรง)
   5. หัวข้อย่อยนำ (7 ทรง)
   6. ป้ายเล็ก badge (6 ทรง)

📦 เนื้อหา
   7. กล่องเนื้อหา (8 ทรง)
   8. ตัวเลขเด่น (6 ทรง)
   9. เลขลำดับ (6 ทรง)
   10. เส้นคั่น (6 ทรง)

พิมพ์เลข หรือบอกมาเป็นคำพูดก็ได้
```

(โชว์เฉพาะข้อที่เว็บมีจริง ตัด numbering ให้ต่อเนื่อง) นักเรียนพิมพ์เลขหรือคำพูด → ได้ component id

แล้ว **หา selector จริงของนักเรียน** scan `index.html` + `pages/*.html`

- `button` → `.btn` `.btn--primary` `<button>` `<a class="...btn...">` ที่ **ไม่ได้อยู่ใต้ `data-cnc-widget`**
- `input` → `.field__input` `.input` `<input type=text>`
- `choice` → `.radio-group` `.exp-options` กลุ่ม `<input type=radio>`
- ฯลฯ (ดูชื่อ class จริงจาก styles.css ของนักเรียน ไม่ fix ชื่อ)

**ข้าม element ใต้ `data-cnc-widget` เด็ดขาด** ถ้าปุ่มอยู่ใน Calendly/pricing widget ไม่แตะ

ถ้าเจอหลาย selector (ปุ่ม primary กับ ghost) ถามว่าจะเปลี่ยนอันไหน หรือทั้งคู่

---

## Step 2 resolve brand token → เขียน --cs-* normalization

อ่าน brand token แบบเดียวกับ web-add ([[web-add-architecture]] Step 2)

1. **สีหลัก** จาก CLAUDE.md `<!-- web-design:v1 -->` (Color 60% = bg, 30% = surface/ink, 10% = accent) เป็น hex จริงเชื่อได้
2. **text** จาก `:root` ใน styles.css (`--color-text` `--text` `--fg` ...) resolve เป็น hex ถ้าไม่เจอ derive จาก bg
3. **radius** อ่าน `border-radius` ของ card/button ในเว็บ (ค่าที่เจอบ่อย) ถ้าไม่เจอ fallback `6px`

เขียน normalization block ครั้งเดียวต่อเว็บ ต่อท้าย `styles.css` (ถ้ามีแล้วข้าม)

```css
/* cnc-style tokens (web-style) */
[data-cnc-style]{
  --cs-accent:  ACCENTHEX;
  --cs-accent-d: ACCENTDARKHEX;   /* accent เข้มลง ~12% สำหรับ hover */
  --cs-ink:     INKHEX;
  --cs-bg:      BGHEX;
  --cs-radius:  RADIUS;
}
```

ถ้าเว็บเคยรัน web-add แล้วมี `--w-accent` ฯลฯ อยู่แล้ว ใช้ `var(--w-accent)` แทน hex ตรงๆ ได้ (token เดียวกัน) ไม่ต้องซ้ำ

---

## Step 3 generate preview ทุกทรง ในสีนักเรียน

สร้างไฟล์ preview ชั่วคราว (เช่นใน temp) ที่

- link `styles.css` ของนักเรียน (หรือเฉพาะ token) + `library.css`
- render **ทุกทรงของ component ที่เลือก** เป็น grid โชว์ทรงในสี accent จริงของนักเรียน (เหมือนหน้าแคตตาล็อกตัวอย่าง) ใส่ตัวอย่าง content ของนักเรียนถ้ามี (ข้อความปุ่มจริง)
- แต่ละทรงมีเลขกำกับ

เปิด preview บน localhost **เช็คพอร์ตว่างก่อน bind** (กฎเดียวกับ web-finish/web-add)

```
PY: macOS ใช้ python3 เสมอ (ห้าม python เปล่า มักไม่มีบน Mac) / Windows ลอง python ก่อน ไม่มีค่อยใช้ py
หาพอร์ตว่างตัวแรกจาก 8000 8080 8888 3000
  Windows (Test-NetConnection localhost -Port <p> -WarningAction SilentlyContinue).TcpTestSucceeded
  macOS   lsof -i :<p>
start จาก project root ใช้ $PY -m http.server <พอร์ต> --directory . (กัน path มีเว้นวรรค)
verify ด้วย path จริงได้ 200 แล้วบอกพอร์ตที่ start จริง
```

บอกนักเรียน "เปิดดูทรงปุ่มทั้งหมดในสีคุณได้ที่ลิงก์นี้ ชอบเบอร์ไหนบอกเลข"

---

## Step 4 นักเรียนเลือก (+ free-text override)

นักเรียนตอบเลข หรือชื่อทรง หรือบอกเอง

- เลือกทรง → ไป Step 5
- **free-text** "เอาเบอร์ 7 แต่มุมมนหน่อย" → ใช้ recipe เบอร์ 7 เป็นฐานแล้วปรับ property ที่ขอ (เช่น เพิ่ม `border-radius`) เก็บเป็น recipe เฉพาะ
- ทรงที่ลด affordance (`button:link` input บางมาก) เตือนสั้นๆ ก่อนใช้

---

## Step 5 apply (append marked block + ใส่ class/attr)

หลักการ **เพิ่ม override block ติด marker ต่อท้าย styles.css** ไม่รื้อ CSS เดิม specificity สูงกว่าด้วย attribute selector จึงชนะ cascade

1. ใส่บน element จริง `data-cnc-style="<component>:<treatment>"` (ทุก element ของ selector นั้น เช่นทุกปุ่ม primary)
2. copy recipe ที่ตรงจาก `library.css` มา append ต่อท้าย `styles.css` โดย **bind กับ selector จริงของนักเรียน + attribute** เพื่อ override

```css
/* cnc-style:button:offset */
.btn[data-cnc-style^="button"]{
  background:var(--cs-accent); color:#fff; border:2px solid var(--cs-ink);
  border-radius:0; box-shadow:5px 5px 0 0 var(--cs-ink);
}
.btn[data-cnc-style^="button"]:hover{ transform:translate(2px,2px); box-shadow:3px 3px 0 0 var(--cs-ink); }
/* end cnc-style:button:offset */
```

(แทน `.btn` ด้วย selector จริง property มาจาก recipe ใน library.css ที่เลือก ใช้ `--cs-*` token เสมอ)

3. **re-run / เปลี่ยนทรง** หา block `/* cnc-style:button:* */ ... /* end */` เดิม **แทนที่ทั้ง block** + อัปเดต attribute ไม่ append ซ้อน (idempotent)

### structural treatment ที่ต้องแตะ markup เล็กน้อย

ส่วนใหญ่เป็น treatment-only overlay (ใส่ class/attr พอ) แต่บางทรงต้องมี element เสริม **ทำเท่าที่จำเป็น ห้ามแตะ content**

- `heading:word/underline/mark` ต้องมี `<span class="hl">` ครอบคำที่เน้น (ถามนักเรียนว่าจะเน้นคำไหน)
- `input:float` `input:draw` ต้องมี wrapper + ลำดับ label/input เฉพาะ (ดู treatments ในหน้า catalog)
- `choice:*` เปลี่ยนกลไก (เช่น เป็น segmented) จัด layout ใหม่บนกลุ่ม radio เดิม **เก็บ `<input type=radio>` + `<label>` ครบ** ห้ามเปลี่ยนเป็น div (กัน a11y พัง)
- `button:split` `button:siderule` มี element/ลูกศรเสริม

ทรงที่ไม่ต้องแตะ markup (solid pill outline gradient elevated offset glow ... card/badge/divider/stat/index ส่วนใหญ่) = ใส่ attribute + append CSS พอ

---

## Step 6 preview ผล + รายงาน

เปิด preview เว็บจริง (port-safe เหมือน Step 3) ให้นักเรียนเห็นผลในหน้าจริง

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ เปลี่ยนสไตล์ [ปุ่ม] ให้แล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ เปลี่ยน [ปุ่ม] เป็นทรง [ชื่อทรงภาษาคน เช่น เงาแข็งเหลื่อม] แล้ว
   สีเดิมของคุณไม่เปลี่ยน เปลี่ยนแค่ทรง

👀 เปิดดูได้ที่ http://localhost:[พอร์ตจริง]

ℹ️ อยากลองทรงอื่น บอกได้เลย เปลี่ยนกี่รอบก็ได้
   อยากเปลี่ยน component อื่น (ฟอร์ม หัวข้อ การ์ด) บอกได้

ต่อไป
1. /save-work    เซฟขึ้น GitHub
2. /web-quality-audit ตรวจคุณภาพ (สไตล์ใหม่ผ่าน audit ปลอดภัย)
```

ห้ามโชว์ชื่อ class/property ในรายงาน พูดเป็นภาษาคน

---

## Edge cases

- **ทรงเดิมอยู่แล้ว** เจอ block `cnc-style:<comp>` เดิม = เคยเปลี่ยนแล้ว แทนที่ block ไม่ append ซ้อน
- **หลาย element (primary + ghost)** ถามว่าเปลี่ยนอันไหน หรือทั้งคู่ ใส่ attribute ตามที่เลือก
- **component อยู่ใน widget** (`data-cnc-widget`) ข้าม บอกนักเรียนว่าอันนั้นเป็นของ widget ปรับผ่าน web-add
- **เว็บไม่มี component นั้น** (เช่นไม่มี badge) บอกตรงๆ ว่าเว็บนี้ยังไม่มี ถ้าอยากเพิ่มเป็นเรื่องของ web-add
- **อยากกลับทรงเดิม** ลบ block marker + attribute ออก เว็บกลับไปใช้ CSS เดิมของนักเรียน (เพราะเราแค่ override ไม่ได้ลบของเดิม)
- **focus หาย** ถ้า treatment ทับ outline ใส่ `:focus-visible{outline:2px solid var(--cs-accent);outline-offset:2px}` กลับให้

---

## FYI

- treatment ทั้งหมดเป็น CSS ล้วน เปลี่ยนกี่ครั้งก็ไม่กระทบความปลอดภัยหรือความเร็ว
- web-add widget จะ mirror DNA ของ core อยู่แล้ว เปลี่ยนปุ่ม core แล้ว widget รุ่นใหม่จะเข้ากันเอง
- อยากได้ทรงที่ไม่มีใน 84 บอกได้ ใช้ free-text override จาก recipe ที่ใกล้สุด
