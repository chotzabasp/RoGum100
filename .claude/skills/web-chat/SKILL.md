---
name: web-chat
description: Use when the student wants to add a simple chat assistant (a chat bubble in the corner) to their existing website that answers common customer questions and hands warm leads off to LINE or phone. This is a SCRIPTED button-driven assistant (a "fake" chatbot) NOT real AI and NOT a live human. It needs NO backend NO API key NO secret and costs nothing because it is pure static HTML/CSS/JS. The customer taps preset question chips (ราคา เปิดกี่โมง จองยังไง) gets the right canned answer every time then the menu loops back and every screen has a ทักไลน์/โทร handoff so the chat never dead-ends and the bot is never wrong. Content is drafted from CLAUDE.md (services hours price FAQ channels) with generate-then-confirm and real facts are never fabricated. The widget reads the student brand colors from the CLAUDE.md web-design block plus design tokens and component DNA from styles.css so the bubble and panel match THEIR brand automatically and it is stamped data-cnc-widget="chat" so later web-quality-audit runs preserve it. Triggers include "เพิ่มแชทบอท", "อยากมีแชทบอท", "ทำแชทบอท", "ผู้ช่วยตอบคำถาม", "แชทมุมจอ", "กล่องแชท", "ปุ่มแชทลอย", "แชทตอบลูกค้าอัตโนมัติ", "live chat", "chat bubble", "chatbot", "web-chat", or any similar request to add an automated question-answer chat helper. Does NOT connect to any AI/API and does NOT build or wire native forms (that is web-connect). Built for absolute beginners with zero coding knowledge works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-chat ผู้ช่วยตอบคำถามมุมจอ (แชทบอทแบบกดปุ่ม)

นักเรียนอยากมี "แชทบอท" มุมจอที่ตอบคำถามลูกค้าได้เอง แล้วส่งต่อให้ทักไลน์ web-chat สร้างกล่องแชทลอยที่มุมขวาล่าง ลูกค้ากดปุ่มคำถามที่เตรียมไว้ บอทตอบคำตอบที่ถูกต้องเสมอ แล้ววนกลับเมนู ทุกหน้าจอมีปุ่มทักไลน์/โทรให้คุยกับคนจริงต่อ

skill นี้สร้าง **แชทบอทแบบกดปุ่ม (scripted)** ไม่ใช่ AI ไม่ต่อ API ไม่มี key ไม่มี backend จึง **ฟรี 100%** เป็นไฟล์ static ล้วนเหมือนทั้งเว็บ

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## ความจริงสำคัญ นี่คือผู้ช่วยตอบคำถาม ไม่ใช่ AI ไม่ใช่คนจริง

แชทบอทตัวนี้ทำงานด้วย **ชุดคำถาม-คำตอบที่เตรียมไว้ล่วงหน้า** ลูกค้า **กดปุ่มเลือกคำถาม** ไม่ใช่พิมพ์อิสระ ทำไมออกแบบแบบนี้

1. **บอทไม่มีทางตอบผิด** ลูกค้ากดได้แค่คำถามที่เรามีคำตอบจริง จึงได้คำตอบถูกต้องเสมอ ไม่มั่ว ไม่หลอน
2. **ไม่มีช่องพิมพ์** เพราะถ้ามีช่องพิมพ์ ลูกค้าจะพิมพ์สิ่งที่บอทตอบไม่ได้ แล้วดูพัง การกดปุ่มทำให้บอทดูฉลาดและน่าเชื่อถือเสมอ
3. **หน้าที่จริงคือกรองคำถามง่ายๆ แล้วส่งต่อให้คนจริง** ทุกหน้าจอมีปุ่มทักไลน์/โทร บอทตอบเรื่องพื้นฐาน (ราคา เวลา ที่ตั้ง วิธีจอง) แล้วโยน lead อุ่นๆ ให้นักเรียนปิดการขายเอง

**ห้ามทำให้ลูกค้าเข้าใจผิดว่าคุยกับคน** ตั้งชื่อว่า "ผู้ช่วยตอบคำถาม" หรือชื่อแบรนด์ + "บอท" ใส่ "พิมพ์..." (typing) สั้นๆ เป็น UX ได้ แต่ห้ามบอกว่ามีพนักงานกำลังตอบทั้งที่ไม่มี

---

## กฎหลัก (lock ไว้ตั้งแต่ต้น)

1. **กดปุ่มอย่างเดียว ไม่มีช่องพิมพ์** chip คำถามที่เตรียมไว้เท่านั้น (predictable บอทไม่มีทางตอบผิด)
2. **วนกลับเมนูเสมอ + มีปุ่มทักไลน์/โทรทุกหน้าจอ** chat ห้าม dead-end ทุกคำตอบจบด้วยตัวเลือก "ถามอย่างอื่น" + "ทักไลน์/โทร"
3. **เนื้อหาจาก CLAUDE.md generate-then-confirm** ร่างคำถาม-คำตอบจากข้อมูลเว็บก่อน ให้นักเรียนยืนยัน/แก้ **ข้อเท็จจริงจริง (ราคา เวลา ที่อยู่) ห้ามแต่ง** ถ้าไม่มีข้อมูล เว้นช่องให้เติม
4. **เข้ากับแบรนด์อัตโนมัติ** อ่าน design token + DNA จาก styles.css (เหมือน web-add) ใช้ `--w-*` ฟอง+กล่องแชทหน้าตาเข้ากับเว็บ
5. **CSP-clean ไม่มี API** JS เขียนลง scripts.js (`'self'`) ไม่มี inline ไม่โหลดของนอก ไม่ต่อ API **ไม่ต้องลงทะเบียน domain ใดๆ** ข้าม best-practices ได้เลย
6. **ไม่หลอกว่าเป็นคน/AI** label เป็นผู้ช่วยตอบคำถาม
7. **ภาษาไทยเรียบง่าย** ห้ามโชว์ชื่อ tag attribute ชื่อไฟล์ในรายงานนักเรียน

---

## หัวใจ marker `data-cnc-widget="chat"`

ทุก element ที่ web-chat ใส่เข้าเว็บ **ติด `data-cnc-widget="chat"`** ทั้งฟองแชท ทั้งกล่อง panel และครอบ JS ใน scripts.js ด้วยคอมเมนต์ `/* widget:chat */ ... /* end widget:chat */`

marker นี้ทำให้ (สัญญาเดียวกับ web-add)

- รัน web-chat ซ้ำ **รู้ว่ามีแชทแล้ว** ไม่ใส่ซ้ำ (idempotent)
- **performance** ไม่แตะ ไม่ defer JS ของแชท
- **accessibility / seo** เห็น marker แล้วเพิ่ม aria ได้แต่ห้าม rewrite/ลบ
- **web-quality-audit** เก็บ widget ไว้ทั้งหมดตอน re-run

---

## โหมดการทำงาน

```
นักเรียนพูด "อยากมีแชทบอท" / "ผู้ช่วยตอบคำถาม"
   → Step 0 ตรวจความพร้อม
   → Step 1 อ่านสีแบรนด์ + DNA (เหมือน web-add)
   → Step 2 ร่างชุดคำถาม-คำตอบจาก CLAUDE.md (generate-then-confirm)
   → Step 3 ต่อปลายทาง CTA จริง (LINE/โทร/ฟอร์ม/จอง)
   → Step 4 ฝัง HTML ฟอง + panel ติด marker + failsafe
   → Step 5 ฝัง CSS ลง styles.css ใช้ --w-*
   → Step 6 ฝัง JS engine ลง scripts.js ใส่ tree จริง
   → Step 7 preview localhost
   → Step 8 รายงาน + next step (+ บอกทางอัพเกรด AI อนาคต)
```

ไม่มี Step ลงทะเบียน CSP เพราะแชทไม่โหลดของนอกเลย

---

## Step 0 ตรวจความพร้อม

| ต้องเจอ | ถ้าไม่เจอ |
|---------|----------|
| `index.html` ที่ root | "ยังไม่มีไฟล์เว็บนะคะ/ครับ ทำ /web-import ก่อน" จบ skill |
| `styles.css` ที่มี `:root` | ใช้หาสี + DNA ถ้าไม่มีเลย ใช้ neutral default เตือนว่าสีอาจไม่ตรงแบรนด์เป๊ะ |
| `scripts.js` (หรือไฟล์ JS ของเว็บ) | ถ้าไม่มี สร้าง `scripts.js` ใหม่แล้ว `<script src="scripts.js" defer>` ก่อน `</body>` ทุกหน้า |
| `CLAUDE.md` ที่มี `web-design:v1` + `web-scope:v1` | แหล่งสี + แหล่งร่างคำถาม ถ้าไม่มีใช้ CSS แทนสี + ถามนักเรียนตรงๆ เรื่องคำถาม |

ถ้าเว็บมี `pages/` หลายหน้า แชทควรอยู่ **ทุกหน้า** (ฟองลอยติดทุกหน้า) ใส่ HTML ฟอง+panel ในทุกหน้า JS ตัวเดียวใน scripts.js คุมหมด

ถ้าเจอ `data-cnc-widget="chat"` อยู่แล้ว = มีแชทแล้ว ถามว่าจะ **แก้คำถาม-คำตอบ** (ไป Step 2 แก้ tree) หรือ **เอาออก** อย่าใส่ซ้ำ

---

## Step 1 อ่านสีแบรนด์ + DNA (ยืมจาก web-add)

ใช้วิธีเดียวกับ web-add Step 2 เป๊ะ เพื่อให้แชทเข้ากับเว็บ

1. **สี** อ่าน `web-design:v1` ใน CLAUDE.md เอา hex 3 ตัว (`Color 60%` = bg `Color 30%` = surface `Color 10%` = accent) ถ้าไม่มี block นี้ fallback ไปอ่าน `:root` ใน styles.css (`--color-bg`/`--bg` `--color-surface`/`--surface` `--color-accent`/`--accent`/`--brand`/`--primary`) resolve `var()` indirection จนได้ hex เติม text/muted จาก `:root` (`--color-text`/`--text` และ `--color-text-muted`/`--muted`)
2. **DNA** อ่าน component จริงใน styles.css จับ radius (border-radius ของ card/button ข้าม `50%`) + card edge (1px hairline / 2px+ หนา / shadow)
3. **ถ้ายังไม่มี normalization block `[data-cnc-widget]` ใน styles.css** (เว็บนี้ยังไม่เคยเพิ่ม widget) เขียนต่อท้าย styles.css ครั้งเดียว

```css
/* widget tokens สีจาก CLAUDE.md เป็นหลัก live CSS เป็น fallback + DNA */
[data-cnc-widget] {
  --w-bg:      BGHEX;
  --w-surface: SURFACEHEX;
  --w-accent:  ACCENTHEX;
  --w-text:    var(--color-text, var(--text, TEXTHEX));
  --w-muted:   var(--color-text-muted, var(--muted, MUTEDHEX));
  --w-radius:  RADIUS;
  --w-card-border: CARDBORDER;
}
```

ถ้ามี block นี้อยู่แล้ว (เคยเพิ่ม widget ผ่าน web-add) **ข้าม** ใช้ของเดิม spacing/font ใช้ `var(--s*)` `var(--font-*)` แบบ alias + fallback เหมือน web-add

**สำคัญ font alias** CSS ของแชทใช้ `var(--font-display)` กับ `var(--font-body)` แต่บางเว็บ (เช่นเว็บที่ Claude Design / Path B สร้าง) **ไม่มีชื่อนี้** ใช้ชื่ออื่นเช่น `--serif` `--sans` ถ้าเว็บไม่มี `--font-display`/`--font-body` ใน `:root` ให้เพิ่ม alias 2 บรรทัดนี้ใน block `[data-cnc-widget]` (scope เฉพาะ widget ไม่กระทบเว็บ) ไม่งั้นหัวข้อแชทจะตกไปใช้ฟอนต์ default

```css
  --font-display: var(--serif, var(--font-heading, inherit));
  --font-body:    var(--sans, var(--font, inherit));
```

(ลองชื่อจริงของเว็บก่อน เช่นเว็บนี้ใช้ `--serif`/`--sans` ก็ map ตามนั้น ถ้าเว็บมี `--font-display` อยู่แล้วข้ามขั้นนี้)

---

## Step 2 ร่างชุดคำถาม-คำตอบ (generate-then-confirm หัวใจของ skill)

**ห้ามถามจากศูนย์ ห้ามแต่งข้อมูล** อ่าน CLAUDE.md (archetype business services ราคา เวลา ที่ตั้ง channels จาก web-scope + web-writing) แล้ว **ร่างคำถามที่ธุรกิจแบบนี้โดนถามบ่อย 4-6 ข้อ** พร้อมคำตอบจากข้อมูลจริง

ตัวอย่างคำถามยอดฮิตตาม archetype (เลือกที่เหมาะ)

- ราคา/แพ็กเกจเท่าไหร่
- เปิดกี่โมง วันไหนบ้าง
- อยู่ที่ไหน มีที่จอดรถไหม
- จอง/นัด/สั่งยังไง
- มือใหม่/ครั้งแรกทำได้ไหม เตรียมตัวยังไง
- ชำระเงินช่องทางไหน

**ขั้นยืนยันเป็นด่านบังคับ หยุดรอจริง** ต้องโชว์ draft ทั้งชุดให้นักเรียนดูก่อนเสมอ แล้ว **หยุดรอ ห้ามเขียนไฟล์ (Step 4 ขึ้นไป) ก่อนนักเรียนตอบ ตกลง** สิ่งที่ต้องโชว์ให้ครบ

1. **ทุกคำถามกับคำตอบ** ที่ร่างไว้
2. **ปุ่มแต่ละอันพาไปไหน** (ทักไลน์ / เลื่อนไปส่วนไหนของหน้า / กลับเมนู)
3. **จุดที่ยังเป็น `[เติม...]`** ที่ต้องให้นักเรียนเติมเอง (ราคา เวลา ฯลฯ ที่เว็บไม่มีข้อมูล)

แล้วถามตรงๆ ว่า **อยากเพิ่ม แก้ หรือลบคำถามไหนไหม** รอจนนักเรียนยืนยัน ค่อยไป Step 4

โชว์ draft ทั้งชุดให้นักเรียนยืนยัน บอกชัด

```
🤖 ผมร่างชุดคำถาม-คำตอบให้แล้ว ลองตรวจดูนะคะ/ครับ
   ตรงไหนผิดแก้ได้เลย ตรงไหน [เติมข้อมูล] ช่วยเติมให้ด้วย

1. ราคาเท่าไหร่
   → แพ็กเกจเริ่มต้น [เติมราคา] บาท ...
2. เปิดกี่โมง
   → ทุกวัน 9 โมง ถึง 2 ทุ่ม   (จากข้อมูลเว็บ ถ้าไม่ตรงแก้ได้)
3. อยู่ที่ไหน
   → [เติมที่อยู่]
...

ถ้าโอเคพิมพ์ตกลง ถ้าจะเพิ่ม/ลดคำถามบอกได้เลย
```

- **ราคา เวลา ที่อยู่ = ข้อเท็จจริงจริง** ถ้า CLAUDE.md ไม่มี เว้น `[เติม...]` **ห้าม finalize คำตอบที่เดาเอง**
- คำตอบสั้น 1-3 บรรทัด อ่านบนมือถือง่าย ยาวไปไม่เหมาะกับฟองแชท
- 4-6 คำถามกำลังดี เยอะไปเมนูรก
- **ทุกคำตอบต้องมีตัวเลือกต่อ** อย่างน้อย "ถามอย่างอื่น" (กลับเมนู) + 1 ปุ่ม CTA (ทักไลน์/โทร/ดูราคา)

---

## Step 3 ต่อปลายทาง CTA จริง (ยืมหลักจาก web-connect)

แชทต้องจบที่ช่องทางจริง อ่าน CLAUDE.md (`web-scope:v1` ปุ่มชวนกด + รับข้อมูล) เดาช่องทางหลักก่อนแล้วให้นักเรียนยืนยัน

| action ในแชท | กลายเป็น |
|--------------|----------|
| `line` | เปิด `https://line.me/ti/p/~ไอดี` หรือ `https://lin.ee/XXXX` แท็บใหม่ |
| `tel` | `tel:+66XXXXXXXXX` (แปลง 08X เป็น +668X) |
| `form` | เลื่อนไปฟอร์มติดต่อในหน้า (`scroll:#contact`) หรือเปิดลิงก์ Google Form |
| `booking` | เลื่อนไป section จอง (`scroll:#booking`) ถ้ามี widget booking อยู่ |
| `scroll:#id` | เลื่อนไป section นั้นในหน้า (เช่น `#pricing` `#gallery`) |
| `url` | เปิดลิงก์ภายนอก (เพจ FB/IG) แท็บใหม่ |

- **ห้ามเดาเบอร์/ไอดีไลน์** ถ้านักเรียนยังไม่ให้ ใส่ปุ่มไว้แต่บอกให้มาเติมทีหลัง
- ปุ่มออกนอกเว็บ (line/url) เปิดแท็บใหม่ `target="_blank" rel="noopener"`

---

## Step 4 ฝัง HTML ฟอง + panel (ติด marker + failsafe)

วาง **ก่อน `</body>`** ของทุกหน้า ฟองเป็น `<a href>` ชี้ไลน์ไว้ก่อน (failsafe ถ้า JS ปิด กดแล้วไปไลน์เลย) JS จะ upgrade เป็นเปิด panel แทน panel เริ่มต้น `hidden` JS เป็นคนเปิด ไอคอนเป็น inline SVG (ไม่โหลดของนอก)

```html
<!-- widget:chat -->
<a href="LINE_URL" class="cnc-chat-fab" id="cncChatFab" data-cnc-widget="chat"
   aria-label="เปิดผู้ช่วยตอบคำถาม" target="_blank" rel="noopener">
  <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor"
       stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path d="M21 11.5a8.38 8.38 0 0 1-8.5 8.5 8.5 8.5 0 0 1-3.8-.9L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5z"></path>
  </svg>
</a>
<div class="cnc-chat-panel" id="cncChatPanel" data-cnc-widget="chat" role="dialog"
     aria-label="ผู้ช่วยตอบคำถาม" aria-modal="false" hidden>
  <div class="cnc-chat-head">
    <span class="cnc-chat-head__name">ผู้ช่วยตอบคำถาม</span>
    <button class="cnc-chat-head__close" id="cncChatClose" type="button" aria-label="ปิด">&times;</button>
  </div>
  <div class="cnc-chat-log" id="cncChatLog" aria-live="polite" aria-atomic="false"></div>
  <div class="cnc-chat-chips" id="cncChatChips"></div>
</div>
<!-- end widget:chat -->
```

(`LINE_URL` = ช่องทางหลักจาก Step 3 เป็น failsafe ชื่อหัว panel เปลี่ยนเป็นชื่อแบรนด์ + "บอท" ได้ ห้ามทำให้เข้าใจว่าเป็นคน)

---

## Step 5 ฝัง CSS ลง styles.css (ใช้ --w-* + DNA)

ต่อท้าย styles.css self-contained ใช้ `--w-*` ฟองใช้ accent กล่องใช้ surface/bg เข้ากับแบรนด์ทุกเว็บ ใส่ `prefers-reduced-motion` กัน animation รบกวน

```css
/* widget:chat */
.cnc-chat-fab {
  position: fixed; right: 18px; bottom: 18px; z-index: 9998;
  width: 58px; height: 58px; border-radius: 999px;
  background: var(--w-accent); color: var(--w-bg);
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 8px 24px -8px color-mix(in srgb, var(--w-accent) 70%, transparent);
  cursor: pointer; transition: transform .2s ease;
}
.cnc-chat-fab:hover { transform: scale(1.06); }
.cnc-chat-panel {
  position: fixed; right: 18px; bottom: 86px; z-index: 9999;
  width: min(360px, calc(100vw - 36px)); max-height: min(70vh, 560px);
  display: flex; flex-direction: column; overflow: hidden;
  background: var(--w-bg); color: var(--w-text);
  border: var(--w-card-border); border-radius: var(--w-radius);
  box-shadow: 0 18px 50px -16px rgba(0,0,0,.45);
  animation: cnc-chat-in .22s ease;
}
.cnc-chat-panel[hidden] { display: none; }
@keyframes cnc-chat-in { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: translateY(0); } }
.cnc-chat-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--s3) var(--s4); background: var(--w-accent); color: var(--w-bg);
}
.cnc-chat-head__name { font-family: var(--font-display); font-weight: 700; }
.cnc-chat-head__close { background: none; border: 0; color: var(--w-bg); font-size: 24px; line-height: 1; cursor: pointer; padding: 0 4px; }
.cnc-chat-log {
  flex: 1; overflow-y: auto; padding: var(--s4);
  display: flex; flex-direction: column; gap: var(--s3);
}
.cnc-chat-msg {
  max-width: 85%; padding: var(--s3) var(--s4); line-height: 1.55;
  border-radius: var(--w-radius); font-family: var(--font-body);
}
.cnc-chat-msg--bot { align-self: flex-start; background: color-mix(in srgb, var(--w-text) 7%, var(--w-bg)); color: var(--w-text); }
.cnc-chat-msg--user { align-self: flex-end; background: var(--w-accent); color: var(--w-bg); }
.cnc-chat-chips {
  display: flex; flex-wrap: wrap; gap: var(--s2);
  padding: var(--s3) var(--s4); border-top: var(--w-card-border);
}
.cnc-chat-chip {
  border: 1px solid var(--w-accent); background: none; color: var(--w-accent);
  border-radius: 999px; padding: 8px 14px; font-family: var(--font-body); font-size: 14px;
  cursor: pointer; transition: background .15s ease, color .15s ease;
}
.cnc-chat-chip:hover, .cnc-chat-chip:focus-visible { background: var(--w-accent); color: var(--w-bg); }
.cnc-chat-chip--cta { background: var(--w-accent); color: var(--w-bg); font-weight: 700; }
@media (prefers-reduced-motion: reduce) { .cnc-chat-panel { animation: none; } }
/* failsafe ถ้า JS ไม่ทำงาน ฟองยังเป็นลิงก์ไลน์ที่กดได้ (panel ซ่อนอยู่แล้ว) */
@media (scripting: none) { .cnc-chat-panel { display: none !important; } }
```

ฟองเป็น `position: fixed` ตั้งใจ (ต้องลอยติดจอ) z-index สูงกว่าทุกอย่าง mobile panel กว้างเต็มจอลบขอบ

### กันชนแถบ CTA ติดล่าง (sticky bottom bar) บนมือถือ สำคัญ

หลายเว็บจาก Claude Design มี **แถบปุ่มติดล่างจอบนมือถือ** (sticky CTA เช่น `.stickyCta` ของ yoga) ฟอง bottom 18px จะ **ทับแถบนั้นมุมขวาล่าง** เพราะทั้งคู่ยึดก้นจอ ตรวจก่อน

- มองหาใน styles.css element ที่ `position: fixed` + `bottom: 0` (ชื่อบ่อย `.stickyCta` `.sticky-cta` `.mobile-cta` `.bottom-bar`) ดูด้วยว่ามันโชว์เฉพาะมือถือไหม (มัก `@media (min-width:768px){ ...{display:none} }`)
- ถ้าเจอ เพิ่ม media query นี้ต่อท้าย block chat **ยก FAB กับ panel ขึ้นเหนือแถบ** (ปรับ 88px/156px ตามความสูงแถบจริงของเว็บนั้น)

```css
/* เว็บนี้มีแถบ CTA ติดล่างบนมือถือ ยก FAB+panel ขึ้นเหนือแถบกันทับ */
@media (max-width: 767px) {
  .cnc-chat-fab { bottom: 88px; }
  .cnc-chat-panel { bottom: 156px; }
}
```

ถ้าเว็บ **ไม่มี** แถบติดล่าง ข้าม media query นี้ (ฟอง bottom 18px พอ)

---

## Step 6 ฝัง JS engine ลง scripts.js (ใส่ tree จริงของเว็บนี้)

ต่อท้าย scripts.js ครอบด้วย `/* widget:chat */ ... /* end widget:chat */` **`CNC_CHAT_TREE` คือชุดคำถาม-คำตอบจริงจาก Step 2-3** node `start` คือเมนูแรก แต่ละ option มี `next` (ไป node อื่น) หรือ `do` (ทำ action CTA) ทุก node ที่เป็นคำตอบให้มี option "ถามอย่างอื่น" กลับ `start` + อย่างน้อย 1 ปุ่ม CTA

```js
/* widget:chat */
(function () {
  var fab = document.getElementById('cncChatFab');
  var panel = document.getElementById('cncChatPanel');
  if (!fab || !panel) return;
  var log = document.getElementById('cncChatLog');
  var chips = document.getElementById('cncChatChips');
  var closeBtn = document.getElementById('cncChatClose');

  /* ===== ชุดคำถาม-คำตอบจริงของเว็บนี้ (แก้ที่นี่) ===== */
  var CNC_CHAT_TREE = {
    start: {
      bot: 'สวัสดีค่ะ อยากรู้เรื่องไหนดีคะ',
      options: [
        { label: 'ราคาเท่าไหร่', next: 'price' },
        { label: 'เปิดกี่โมง', next: 'hours' },
        { label: 'อยู่ที่ไหน', next: 'place' },
        { label: 'ทักไลน์เลย', do: 'line' }
      ]
    },
    price: {
      bot: 'แพ็กเกจเริ่มต้น [เติมราคา] บาท สนใจแพ็กไหนทักมาคุยได้เลยค่ะ',
      options: [
        { label: 'ดูราคาทั้งหมด', do: 'scroll:#pricing' },
        { label: 'ทักไลน์สอบถาม', do: 'line' },
        { label: 'ถามอย่างอื่น', next: 'start' }
      ]
    },
    hours: {
      bot: 'เปิดทุกวัน [เติมเวลา] ค่ะ',
      options: [
        { label: 'ทักไลน์', do: 'line' },
        { label: 'ถามอย่างอื่น', next: 'start' }
      ]
    },
    place: {
      bot: 'ร้านอยู่ที่ [เติมที่อยู่] ค่ะ',
      options: [
        { label: 'ดูแผนที่', do: 'scroll:#map' },
        { label: 'ถามอย่างอื่น', next: 'start' }
      ]
    }
  };
  var CNC_CHANNELS = {
    line: 'LINE_URL',
    tel:  'tel:+66XXXXXXXXX'
  };
  /* ===== จบส่วนที่แก้ ===== */

  var opened = false;
  function addMsg(text, who) {
    var d = document.createElement('div');
    d.className = 'cnc-chat-msg cnc-chat-msg--' + who;
    d.textContent = text;
    log.appendChild(d);
    log.scrollTop = log.scrollHeight;
  }
  function doAction(act) {
    if (act === 'line') { window.open(CNC_CHANNELS.line, '_blank', 'noopener'); return; }
    if (act === 'tel')  { window.location.href = CNC_CHANNELS.tel; return; }
    if (act.indexOf('scroll:') === 0) {
      var el = document.querySelector(act.slice(7));
      if (el) { closePanel(); el.scrollIntoView({ behavior: 'smooth' }); }
      return;
    }
    if (act.indexOf('url:') === 0) { window.open(act.slice(4), '_blank', 'noopener'); }
  }
  function render(nodeId) {
    var node = CNC_CHAT_TREE[nodeId];
    if (!node) return;
    addMsg(node.bot, 'bot');
    chips.innerHTML = '';
    (node.options || []).forEach(function (opt) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'cnc-chat-chip' + (opt.do ? ' cnc-chat-chip--cta' : '');
      b.textContent = opt.label;
      b.addEventListener('click', function () {
        addMsg(opt.label, 'user');
        if (opt.do) doAction(opt.do);
        else if (opt.next) setTimeout(function () { render(opt.next); }, 220);
      });
      chips.appendChild(b);
    });
  }
  function openPanel(e) {
    if (e) e.preventDefault();
    panel.hidden = false;
    fab.setAttribute('aria-expanded', 'true');
    if (!opened) { opened = true; render('start'); }
    closeBtn.focus();
  }
  function closePanel() {
    panel.hidden = true;
    fab.setAttribute('aria-expanded', 'false');
    fab.focus();
  }
  fab.addEventListener('click', openPanel);
  closeBtn.addEventListener('click', closePanel);
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !panel.hidden) closePanel(); });
})();
/* end widget:chat */
```

- แทน `CNC_CHAT_TREE` ด้วย tree จริงจาก Step 2 (คำถาม-คำตอบที่นักเรียน confirm) แทน `CNC_CHANNELS.line`/`.tel` ด้วยช่องทางจริงจาก Step 3 ให้ `LINE_URL` ใน HTML ฟอง (failsafe) ตรงกัน
- เปิดครั้งแรก render `start` ครั้งเดียว กดวนได้ไม่จำกัด
- ปุ่มที่มี `do` (CTA) ทำ action ปุ่มที่มี `next` ไป node ถัดไป (หน่วง 220ms เหมือนบอทคิด)
- Esc ปิด focus วิ่งจากฟอง → ปิด → กลับฟอง (keyboard ใช้ได้)
- ถ้าเว็บไม่มี section ที่ `scroll:#id` ชี้ไป (เช่นไม่มี `#pricing`) เปลี่ยน action นั้นเป็น `line` แทน อย่าให้กดแล้วเงียบ

---

## Step 7 preview localhost

**เช็คพอร์ตว่างก่อน start เสมอ** (กฎเดียวกับ web-add/web-connect)

```
PY: macOS ใช้ python3 เสมอ (ห้าม python เปล่า) / Windows ลอง python ก่อน ไม่มีค่อยใช้ py
```

1. หาพอร์ตว่างตัวแรกจาก 8000 8080 8888 3000
   - Windows `(Test-NetConnection localhost -Port <p> -WarningAction SilentlyContinue).TcpTestSucceeded` (true = ไม่ว่าง)
   - macOS/Linux `lsof -i :<p>` (เจอผล = ไม่ว่าง)
2. start จาก project root `$PY -m http.server <พอร์ตว่าง> --directory .`
3. verify ด้วย curl ว่าได้ 200 และเป็นเว็บนี้
4. บอกนักเรียนเปิดลิงก์ด้วยพอร์ตที่ start จริง

บอกนักเรียนกดฟองมุมขวาล่าง ลองกดคำถามดู เช็คว่าตอบถูก + ปุ่มทักไลน์เปิดไลน์จริง

---

## Step 8 รายงาน + next step

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ เพิ่มผู้ช่วยตอบคำถามให้เว็บแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ฟองแชทมุมขวาล่าง กดแล้วเด้งเมนูคำถาม
✅ ตอบ [N] คำถามยอดฮิต ราคา เวลา ที่ตั้ง วิธีจอง
✅ ทุกคำตอบมีปุ่มทักไลน์/โทร ส่งลูกค้าให้คุณปิดการขายต่อ
✅ หน้าตาเข้ากับแบรนด์เว็บคุณอัตโนมัติ

👀 เปิดดูได้ที่ http://localhost:[พอร์ตที่ start จริง]
   กดฟองมุมขวาล่างลองเล่นดู

ℹ️ บอทตัวนี้ตอบจากชุดคำถามที่เตรียมไว้ ฟรี 100% ไม่มีค่าใช้จ่าย
   อยากแก้คำถาม-คำตอบ บอกได้เลยเดี๋ยวปรับให้

ต่อไป
1. /save-work    เซฟขึ้น GitHub
2. deploy        เอาขึ้นเว็บจริง
```

ปิดท้ายด้วยภาษาคน ห้ามโชว์ชื่อ tag attribute ในรายงาน

---

## Edge cases

- **มีแชทแล้ว (`data-cnc-widget="chat"`)** ไม่ใส่ซ้ำ ถามว่าจะแก้คำถาม-คำตอบ (แก้ `CNC_CHAT_TREE` ใน scripts.js) หรือเอาออก
- **นักเรียนยังไม่มีไลน์/เบอร์** ใส่ปุ่มไว้แต่เว้นปลายทาง บอกให้มาเติม ห้ามเดา
- **นักเรียนอยากให้พิมพ์ได้** อธิบายว่าเวอร์ชันนี้กดปุ่มเพื่อให้ตอบถูกเสมอ ไม่มีช่องพิมพ์ตั้งใจ บอทจึงไม่มีทางตอบผิด
- **เว็บหลายหน้า** ใส่ HTML ฟอง+panel ทุกหน้า JS ตัวเดียวใน scripts.js คุมหมด (มี guard `if (!fab) return;`)
- **JS ปิด** ฟองยังเป็นลิงก์ไลน์กดได้ (failsafe) panel ซ่อน

---

## FYI สำหรับนักเรียน

แชทตัวนี้ตอบจากชุดคำถาม-คำตอบที่เตรียมไว้ **ฟรี 100% ไม่มีค่าใช้จ่าย** ไม่ต้องต่อ API ไม่ต้องมีบัญชีอะไรเพิ่ม

อยากแก้คำถาม-คำตอบทีหลัง บอกได้เลย หรือเปิดดู `CNC_CHAT_TREE` ใน scripts.js แก้ข้อความในนั้นได้ตรงๆ

อยากเพิ่มคำถามใหม่ ก็เพิ่ม node กับปุ่มเข้าไปในชุดเดิมได้ ทุกคำตอบควรมีปุ่ม "ถามอย่างอื่น" กลับเมนู + ปุ่มทักไลน์/โทร เสมอ
