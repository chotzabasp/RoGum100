# บันทึกการปรับ UI และคู่มือส่งต่องาน Gum100

เอกสารนี้เป็นจุดเริ่มต้นสำหรับผู้พัฒนาเว็บที่รับงานต่อ บันทึกจากการตรวจ diff จริงเทียบกับโค้ดตอนเริ่มงาน ไม่ใช่รายการสิ่งที่วางแผนจะทำ

> **สถานะสุดท้าย (2026-09-26):** งานปรับ UI ชุดนี้เสร็จแล้ว รวมเข้า main ที่ commit `ee0913f` และขึ้นเว็บจริง gum100.com แล้ว ผู้ใช้ยืนยันว่าไม่แก้ UI ต่อ เอกสารนี้เก็บไว้เป็นประวัติ ไม่ได้อัปเดตต่อ (ดูข้อ 55) ส่วน “สถานะ” ด้านล่างเป็นข้อมูล ณ วันที่เขียน

## สถานะ ณ 25 กันยายน 2569 (2026-09-25)

- Repository: https://github.com/chotzabasp/RoGum100
- โฟลเดอร์ทำงาน: `C:\Users\chot-\OneDrive\Desktop\Gum100UI`
- สาขาในเครื่อง: `ui/polish-existing`
- Commit ฐานก่อนงานชุดนี้: `ea5e476c0fec88e2c99a413efd4617225afb568d`
- Tag สำรองที่มีอยู่ก่อนเริ่ม: `before-redesign-2026-09-25` (คนละจุดกับ commit ฐานด้านบน)
- การแก้ชุดนี้ยังเป็น working-tree changes: ยังไม่ได้ commit, push หรือ deploy โดยงานนี้
- ธีม: คงธีมมืด ภาพ Ragnarok ฟอนต์เดิม และระบบเมนูเดิม เน้นเก็บรายละเอียดและความกระชับ
- ข้อยกเว้นจากงานตกแต่งล้วน: เพิ่มสถานะอ่านแล้วของหัวกลุ่ม “ขายหมดแล้ว” ใน JavaScript ตามคำขอเรื่อง New

## เปิดไฟล์ไหนก่อน

| ไฟล์ | สิ่งที่แก้/เพิ่ม |
| --- | --- |
| `assets/app.css` | เพิ่มชุด CSS ท้ายไฟล์ เริ่มที่คอมเมนต์ `UI polish: preserve the original Gum100 artwork and layout` ครอบคลุมปุ่ม ฟอร์ม ประวัติ และ New |
| `assets/app.js` | เพิ่ม `soldNewSeen` สำหรับจำว่าเปิดหัวกลุ่มขายหมดแล้ว; แยกหมวดประวัติด้วย `historyCategoryRowsHtml` และเพิ่มรูปย่อผ่านระบบโหลดรูปเดิม |
| `index.html` | เปลี่ยนเฉพาะ query version ของ CSS/JS เพื่อป้องกัน cache เก่า ไม่มีการย้าย DOM หรือเปลี่ยน hook เดิม |
| `preview/merchant.html` | หน้าแสดงฟอร์มด้วยข้อมูลสมมติ ไม่เชื่อม backend และไม่บันทึกข้อมูล |
| `preview/history.html` | หน้าตัวอย่างประวัติ มีสคริปต์สาธิตการพับ/กางและการหายของ New ไม่ใช่ระบบรายการจริง |
| `tests/history-new-badges.cjs` | ทดสอบตรรกะ New โดยดึงโค้ด production บางส่วนมารันใน VM พร้อม dependencies จำลอง |
| `AGENTS.md` | กติกาสำหรับผู้ช่วยเขียนโค้ด: อัปเดตเอกสารนี้ทันทีหลังจบแต่ละชุดการแก้ |

CSS เดิมมีหลายชั้นที่ override กัน งานนี้เพิ่มชุดท้ายไฟล์เพื่อรักษากฎเดิม โดยใช้ selector เจาะจงส่วนที่แก้ หากปรับต่อควรแก้ในบล็อกของงานชุดนี้ก่อนเพิ่ม override ซ้ำอีกชั้น ตรวจ media/container query ที่อยู่ถัดลงมาด้วย

## แผนที่โค้ด CSS

เลขบรรทัดอ้างอิงวันที่จัดทำเอกสาร อาจเลื่อนเมื่อแก้ต่อ ให้ค้นชื่อคอมเมนต์หรือ selector เป็นหลัก

| จุดเริ่มโดยประมาณ | คอมเมนต์/คำค้น | ขอบเขต |
| --- | --- | --- |
| 2562 | `UI polish` / `Banner account actions` | ปุ่มเข้าสู่ระบบและสมัครสมาชิก |
| 2603 | `Shared controls` | ขนาดปุ่ม โฟกัสคีย์บอร์ด hover เมนู และหยุด ticker เมื่อโฟกัสอยู่ภายใน |
| 2629 | `Trading workspace` | ระยะในแผงรายการซื้อ–ขาย ช่องกรอก ปุ่มเพิ่มรายการ |
| 2653 | `Category selector` | แท็บ M / ไอเทม / อื่น ๆ |
| 2684 | `Merchant form` | การจัดลำดับข้อมูล สีซื้อ/ขาย ช่องกรอก แนบรูป ยอดรวม ปุ่มบันทึก |
| 2774 | `Desktop density` | ลดความสูงเฉพาะจอคอม ตั้งแต่ 761px |
| 2795 | `Trading history:` | การ์ดประวัติระดับไอเทม ตัวเลขและป้าย New |
| 2850 | `Expanded history:` | หัววันที่และแถวรายการซื้อ/ขายย่อย |
| 2906 | `Sold-out archive:` | แถบขายหมดแล้วและรายการซ้อนด้านใน |
| 2944 | `Unread badges` | animation `history-new-pulse` และ reduced-motion |
| 2956 | `Dialog actions` และ media queries ถัดไป | ปุ่ม dialog ข้อความแพ็กเกจยาว safe area และสรุปยอดมือถือ |

## รายการแก้ย้อนหลังตามลำดับคำขอ

รายการ 01–09 จัดทำย้อนหลังจากประวัติการทำงานและ diff ในวันที่ 2026-09-25 ไม่มีการอ้างเวลาทำงานรายนาทีที่ไม่ได้บันทึกไว้

### 01 — เก็บรายละเอียดธีมเดิม

- ไฟล์: `assets/app.css`, `index.html`
- ทำระยะในฟอร์มและปุ่มให้สม่ำเสมอ เพิ่ม `--control-height`, `--focus-ring`, `--polish-divider`
- ปรับกรอบ focus โดยเฉพาะปุ่มเสียงที่กฎเดิมลบ outline, hover ของเมนู/ปุ่ม, ขนาดปุ่มปิด auth modal และปุ่ม dialog
- จัดสรุปยอดบนมือถือให้ label และยอดอยู่ในแถวเดียวกัน พร้อมเก็บภาพ Poring เดิม
- บนมือถือแยกหัวข้อกับแท็บฟอร์มและจัดช่องอัตราแลกเปลี่ยนไม่ให้หน่วยเบียด
- แก้ชื่อแพ็กเกจยาวให้ขึ้นบรรทัดใหม่ เพิ่มพื้นที่ล่างตาม safe area
- ตรวจ: หน้า guest ที่เข้าถึงได้ที่ 320px, หน้าหลักที่ 375px, แนวนอน 812×375, จอคอม และการเปิดหน้าต่าง login/register; การเลือกตั้งค่าใน guest เปิด auth modal จึงยังไม่ใช่การทดสอบหน้าตั้งค่าหลังล็อกอิน
- เวอร์ชัน CSS: `20260925i` → `20260925-polish1`

### 02 — ปุ่มเข้าสู่ระบบ / สมัครสมาชิก

- ไฟล์: `assets/app.css`, `index.html`
- Selector: `#guestAuthButtons`, `#guestLoginBtn`, `#guestRegisterBtn`
- เข้าสู่ระบบใช้พื้นน้ำเงินเข้ม สมัครสมาชิกไล่น้ำเงิน–ม่วง ขอบบาง มุมโค้ง 12px และเงานุ่ม
- เพิ่ม hover/pressed/focus และปิด transition เมื่อ reduced-motion
- ตรวจ: ภาพจอคอมและ 375px; ปุ่มมือถือกว้างเท่ากันและไม่ล้น
- เวอร์ชัน CSS: `20260925-polish2`

### 03 — แท็บ M / ไอเทม / อื่น ๆ

- ไฟล์: `assets/app.css`, `index.html`
- Selector: `#mrCategoryToggle .seg-btn`
- เปลี่ยนแถบ pill เป็นพื้น navy มุมโค้ง 14px ปุ่มด้านใน 10px; active ไล่น้ำเงิน–ม่วง ตัวอักษรขาว
- เพิ่ม hover/focus และคง `.active` ที่ระบบเดิมใช้
- ตรวจ: ภาพจริงและขนาดปุ่มมือถือ 44px, ไม่ล้นกรอบ
- เวอร์ชัน CSS: `20260925-polish3`

### 04 — ออกแบบแผงรายการซื้อ–ขายให้สะอาด

- ไฟล์: `assets/app.css`, `index.html`; เพิ่ม `preview/merchant.html`
- Selector หลัก: `#mrEntryPanel`; ส่วนย่อย `.mr-type-btn`, `.mr-item-row`, `.mr-entry-details`, `.mr-total`, `#mrConfirm`
- ใช้พื้นเรียบ ขอบนุ่ม ช่องกรอกพื้นเข้ม เพิ่มลำดับหัวข้อ/คำแนะนำ ปรับสีซื้อ–ขายให้นุ่มแต่แยกกันชัด
- ลดกรอบของยอดรวม ขยายยอดหลัก จัดพื้นที่แนบรูปและปุ่มบันทึก
- คงสถานะ guest/read-only และ hooks เดิม
- ตรวจ: ฟอร์มข้อมูลสมมติบนจอคอม, 320px และ 375px; ตรวจหน้าหลักแบบ guest ด้วย
- เวอร์ชัน CSS: `20260925-polish4`

### 05 — ย่อฟอร์มสำหรับจอคอม

- ไฟล์: `assets/app.css`, `index.html`, `preview/merchant.html`
- บล็อก `Desktop density`, media query `min-width:761px`
- หัวข้อกับแท็บอยู่แถวเดียวกัน ซ่อนคำแนะนำบนจอคอม ลด padding/gap และวางคำว่า “รูปภาพ” กับปุ่มแนบรูปในแถวเดียวกัน
- คงช่องกรอกประมาณ 46px และปุ่มบันทึกอย่างน้อย 48px; มือถือยังแยกแถวตามเดิม
- ตรวจ: ภาพตัวอย่างที่ 1920×1080 เห็นถึงปุ่มบันทึกโดยไม่เลื่อน **สำหรับฟอร์มหนึ่งรายการในหน้าตัวอย่าง** ไม่ใช่คำรับรองว่าหน้าหลักที่มี banner หรือหลายรายการจะพอดีทุกจอ
- เวอร์ชัน CSS: `20260925-polish5`

### 06 — การ์ดประวัติซื้อ–ขาย

- ไฟล์: `assets/app.css`, `index.html`; เพิ่ม `preview/history.html`
- Selector: `#mrHistoryList .mr-it-row.mr-ic`, `.mr-ic-head`, `.mr-it-cell`
- ลด gradient/แสงเรือง จัดหัวข้อกับหมวดและ New; แยกข้อมูลหลักกับค่าเฉลี่ย/ทุนค้าง เพิ่มความอ่านง่ายของข้อความรอง
- คงความหมายสีซื้อ ขาย คงเหลือ กำไร และขาดทุน; แสดงสี่คอลัมน์หรือสองคอลัมน์ตามพื้นที่
- New ในขั้นนี้หยุด animation ชั่วคราว ก่อนผู้ใช้ขอให้กระพริบในข้อ 09
- ตรวจ: ภาพ desktop/mobile 375px, การกางตัวอย่าง และไม่ล้นแนวนอน
- เวอร์ชัน CSS: `20260925-polish6`

### 07 — หัววันที่และรายการย่อย

- ไฟล์: `assets/app.css`, `index.html`, `preview/history.html`
- Selector: `.mr-ic-day-head`, `.mr-ic-day-tot`, `.mr-tx`, `.mr-del`
- หัววันที่พื้นเข้มเรียบ ยอดซื้อ/ขายและจำนวนรายการจัดเป็นกลุ่ม ป้าย New ไม่ลอยเกินขอบ
- แถวรายการใช้เส้นสีด้านซ้ายแทนกรอบหนัก จัดเวลา สูตรคำนวณ และยอดเงิน ปุ่มลบมีพื้นที่กดชัดขึ้น
- เมื่อพื้นที่ประวัติไม่เกิน 480px ใช้รายการสองแถว เพื่อไม่ให้ยอดเงินเบียด; รองรับแถวที่มี `.mr-tx-time` ด้วย
- ตรวจ: พับ/กางหัววันที่ในตัวอย่าง, ภาพ desktop/mobile และความกว้างแถวไม่ล้นที่ 375px
- เวอร์ชัน CSS: `20260925-polish7`

### 08 — กลุ่มขายหมดแล้วและรายการด้านใน

- ไฟล์: `assets/app.css`, `index.html`, `preview/history.html`
- Selector: `.mr-it-group-wrap`, `#mrItSoldToggle`, `.mr-it-group-profit`, `#mrItSoldList`
- เปลี่ยนเส้นประเป็นขอบบาง พื้นเรียบ จัด New ต่อจากชื่อกลุ่ม กำไรรวมชิดขวาบนจอคอมและลงแถวใหม่เมื่อพื้นที่แคบ
- ใช้ container `sold-history` ปรับการ์ดซ้อนตามความกว้างจริง คงสไตล์หัววันที่และแถวรายการด้านใน
- ตรวจ: พับ/กางสามระดับ (กลุ่ม → การ์ด → วัน), ขนาด 320px ไม่ล้นและ `[hidden]` ซ่อนจริง
- เวอร์ชัน CSS: `20260925-polish8`

### 09 — New กระพริบจนกดเปิด

- ไฟล์: `assets/app.css`, `assets/app.js`, `index.html`, `preview/history.html`; เพิ่ม `tests/history-new-badges.cjs`
- CSS: `history-new-pulse` วนทุก 1.8 วินาที ปรับ opacity/เงา ไม่ขยับ layout; ถ้าผู้ใช้เลือก reduced-motion จะแสดงป้ายคงที่
- ครอบคลุม `.mr-ic-new-badge` ในหัวการ์ด หัววันที่ หัวขายหมดแล้ว และ `.mr-tx-new-badge`
- การ์ด/วันใช้ตรรกะอ่านแล้วเดิมของระบบ ส่วนหัวขายหมดแล้วเพิ่มสถานะแยกเพื่อไม่ล้าง New ของลูกทั้งหมด
- ตรวจ: `node --check assets/app.js`, `node tests/history-new-badges.cjs` ผ่าน; ตรวจ computed animation และการหายแยกแต่ละระดับใน browser ตัวอย่าง
- เวอร์ชัน CSS ล่าสุด: `20260925-polish9`; JS: `20260925t` → `20260925-new-badges`

#### ตรรกะ New ที่ผู้พัฒนาต้องรู้

| การกระทำ | ผล |
| --- | --- |
| เปิดหัวขายหมดแล้ว | บันทึกว่าเห็นหัวกลุ่มแล้ว ป้ายหัวกลุ่มหาย แต่ New ของการ์ด/วันด้านในยังอยู่ |
| เปิดการ์ดไอเทม | ล้าง `recentNewGroupIds` เฉพาะ key นั้น |
| เปิดหัววันที่ | ล้าง `recentNewTxIds` เฉพาะรายการในวันนั้น |
| บันทึกรายการใหม่ | ตั้ง New ของการ์ด/transaction และลบ acknowledgement ของกลุ่มที่เกี่ยวข้อง ให้หัวขายหมดแล้วมี New ได้อีก |

คำค้นใน `assets/app.js`: `DataKeys`, `loadUserData`, `soldNewSeen`, `saveSoldNewSeen`, `soldHasNew`, `delete soldNewSeen[histKey]`, `#mrItSoldToggle`

เพิ่ม localStorage key `mvpwatch_soldnewseen_<email>` เป็น object ที่เก็บ group key → `true` แยกต่อบัญชี โหลดกลับเมื่อเข้าใช้บัญชีนั้น ไม่ได้เพิ่มตารางฐานข้อมูลหรือระบบ sync การอ่านข้ามอุปกรณ์

หมายเหตุ: การเปิดหัวขายหมดแล้วพิจารณากลุ่มที่คืนมาจาก `computeHistoryItemGroups()` และเข้าเงื่อนไขขายหมด ไม่ได้ล้างสถานะการ์ด/วันลูก การ auto-open กลุ่มตามพฤติกรรมเดิมไม่ถือว่าเป็นการคลิกอ่านหัวกลุ่ม

### 10 — เอกสารส่งต่องานและกติกาบันทึกต่อเนื่อง

- วันที่: 2026-09-25
- คำขอ: รวบรวมทุกการแก้ และบันทึกทันทีหลังงานถัดไปเสร็จ
- เพิ่ม `UI_CHANGELOG.md` (ไฟล์นี้), `AGENTS.md`; เพิ่มลิงก์ใน `README.md`
- เทียบ `git diff` กับ commit ฐานเพื่อยืนยันรายชื่อไฟล์ จุดแก้ CSS/JS และเวอร์ชัน cache
- ไม่เปลี่ยน UI หรือพฤติกรรมแอปในชุดงานเอกสารนี้

### 11 — แยก Zeny / ไอเทม / อื่น ๆ ให้อ่านง่าย

- วันที่: 2026-09-25
- คำขอ: การ์ดคล้ายกันเกินไป ต้องแยก Zeny ที่มีใบเดียวต่อเซิร์ฟเวอร์ และรองรับไอเทมจำนวนมาก ผู้ใช้อนุมัติแบบก่อนลงมือ
- ต่อจากข้อ 06–09: คงธีมกรมท่า สีตัวเลข และ New เดิม แต่แยกหัวหมวดพร้อมจำนวนรายการ จัด Zeny ก่อน ไอเทม แล้วอื่น ๆ ทั้งรายการคงเหลือและภายในขายหมดแล้ว
- ไฟล์: `assets/app.js`, `assets/app.css`, `index.html`, `preview/history.html`, `preview/merchant.html`; เพิ่ม `tests/history-categories.cjs`
- JS จุดค้นหา: `historyCategoryIcon`, `historyCategoryRowsHtml`, `historyItemRowHtml`, `renderHistoryItemView` เพิ่ม class `mr-history-zeny/item/other`; หัวหมวดเป็น sibling ของการ์ด ไม่ครอบการ์ดเพิ่ม จึงรักษา parent/child และ delegated click เดิม
- ลำดับล่าสุดยังคงอยู่ภายในหมวด ไม่รวมกลุ่มคนละเซิร์ฟเวอร์ ไม่เปลี่ยน group key สูตร FIFO การค้นหา ช่วงเวลา หรือสถานะอ่าน New; จำนวนหัวหมวดนับเฉพาะกลุ่มที่ผ่านตัวกรองเดิม
- Zeny ใช้พื้นอมฟ้า เส้นบนฟ้า ไอคอนเหรียญ ป้ายสกุลเงิน และเน้นยอดคงเหลือ; ถ้าขายหมดจะยังอยู่ในกลุ่มขายหมดแล้วตามเงื่อนไขเดิม ไม่สร้างการ์ดซ้ำหรือเปลี่ยนยอด
- ไอเทม/อื่น ๆ ลด padding และซ่อนเฉพาะ `.mr-it-avg` เมื่อพับ เปิดการ์ดแล้วเห็นค่าเฉลี่ยเดิมครบ; ไม่ซ่อนคำเตือนขายเกินที่ซื้อ
- รูปไอเทมที่มี path เพิ่ม thumbnail ใน hook ดูรูปเดิม ใช้ `hydrateItemThumbs(list)` และ signed URL/cache เดิม; เมื่อยังไม่มี URL ใช้ไอคอนเดิม ไม่มีรูปใช้ SVG หมวด ไม่เปลี่ยนการอัปโหลด/สิทธิ์ storage
- CSS จุดค้นหา: `History category hierarchy` และ `.mr-history-*`; หมวดอื่น ๆ มีเส้นม่วงบาง ไม่ใช้สีแทนชื่อหมวดเพียงอย่างเดียว
- Preview เพิ่มตัวอย่างครบสามหมวดและไอเทมหลายใบ เป็นข้อมูลสมมติ ไม่ใช่การดึงรายการจริง
- ตรวจผ่าน: `node --check assets/app.js`, `node tests/history-new-badges.cjs`, `node tests/history-categories.cjs`, `git diff --check` (มีคำเตือน LF/CRLF ไม่ใช่ error)
- Browser: ตรวจภาพหน้าตัวอย่างที่ขนาดปกติ และ 320×800; ที่ 320px body scrollWidth 305px ไม่เกิน viewport, hiddenLeaks 0; เปิดหัวขายหมดแล้ว New หัวหายแต่ลูกยังอยู่ คืนค่า viewport หลังตรวจ
- ยังไม่ได้ตรวจ end-to-end หลังล็อกอิน หรือโหลดรูปจริงจาก storage; tests ใช้ VM/dependencies จำลอง ไม่ใช่ backend verification
- เวอร์ชัน cache: CSS `20260925-polish10` ใน index และ preview ทั้งสอง; JS `20260925-history-groups` ใน index
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 12 — แถวสรุปกระชับและแบ่งหน้าประวัติ

- วันที่: 2026-09-25
- คำขอ: หมวดทั้งหมด/ไอเทมยาวเมื่อรายการเยอะ ผู้ใช้อนุมัติแถวสรุปและแบ่งหน้า
- ต่อจากข้อ 11: ไอเทม/อื่น ๆ ที่พับแสดงชื่อ รูป คงเหลือ กำไร และ New; เปิดแล้วแสดงยอดซื้อ–ขาย ค่าเฉลี่ย และประวัติเดิมครบ Zeny ยังคงการ์ดสรุป
- คำเตือนขายเกินที่ซื้อยังแสดงในแถวสรุป และรักษาสีขาดทุน ไม่ซ่อนคำเตือนในรายละเอียดอย่างเดียว
- ไฟล์/จุดค้นหา: `assets/app.js` — `historyPaging`, `resetHistoryPagingForFilters`, `historyPageWindow`, `historyPagerHtml`, `historyCategoryRowsHtml`, `.mr-compact-metrics`, delegated click/change ใน `mrHistoryList`
- Pagination ฝั่ง client เริ่ม 10 รายการต่อหมวด เลือก 10/20/50 ได้; แยก page/size ของ active-item, active-other, sold-item, sold-other; ไม่แบ่งหน้า Zeny
- แสดงช่วงรายการและหน้าปัจจุบัน ปิดปุ่มก่อนหน้า/ถัดไปเมื่อสุดขอบ; เปลี่ยนขนาดกลับหน้าแรก ลบรายการจนหน้าเดิมเกินขอบจะปรับเป็นหน้าสุดท้ายที่มีจริง
- เปลี่ยนบัญชี เซิร์ฟเวอร์ หมวด ช่วงเวลา หรือคำค้น จะ reset หน้าทุกหมวด โดยเทียบ filter signature; ค้นหา/กรองและคำนวณ FIFO ก่อน slice หน้า จึงยังค้นเจอรายการนอกหน้าปัจจุบัน และกำไรรวมขายหมดแล้วรวมทุกหน้า
- การเปลี่ยนหน้าไม่ล้าง New หรือ expanded state; กดปุ่มเปลี่ยนหน้าแล้วโฟกัสหัวหมวดและเลื่อนเท่าที่จำเป็น ไม่เพิ่ม scrollbar ซ้อน
- CSS: `Compact inventory summaries and independent category pagination` ใน `assets/app.css`; ปุ่ม/select อย่างน้อย 44px, มือถือจัดยอดเป็นแถวถัดไป ไม่มีการเปลี่ยนสูตรบัญชี/ฐานข้อมูล
- Preview: `preview/history.html` เพิ่มข้อมูลจำลอง 24 ไอเทมและ pagination สาธิต ไม่เชื่อม backend; ฝั่ง production render เฉพาะการ์ดในหน้าที่เลือก ส่วน demo ใช้ hidden กับการ์ดจำลอง
- เพิ่ม `tests/history-pagination.cjs`; ปรับ tests เดิมให้รองรับ scope ขายหมดแล้วและ listener change ที่เพิ่มใหม่
- ตรวจ: node syntax, tests ทั้งสามชุด, git diff --check; VM ตรวจหน้าแรก/สุดท้าย ขนาด 10/20/50 หมวดขายหมดแยกกัน clamp หลังลบ reset filters/account ยอดรวมไม่ถูกตัดตามหน้า และ summary คงคำเตือน/New
- Browser preview: ตรวจ 1–10 → 11–20 → 21–24 และปุ่มถัดไป disabled, เปลี่ยนเป็น 20 กลับหน้าแรก; กางแถวแล้วเห็นข้อมูลครบและ New หาย; 320×800 ไม่ล้น (body scrollWidth 305, viewport 320), hiddenLeaks 0; คืน viewport หลังตรวจ
- ข้อจำกัด: ยังไม่ได้ทดสอบบัญชีจริงแบบ end-to-end หรือโหลดรูปจริง; การแบ่งหน้านี้ลดจำนวนการ์ดที่ render แต่ยังคำนวณจากข้อมูลประวัติทั้งหมด ไม่ใช่ server-side pagination
- Cache: CSS `20260925-polish11` ใน index และ preview ทั้งสอง; JS `20260925-history-pages`
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 13 — จัดชื่อเซิร์ฟเวอร์เข้ากับหัวการ์ด และย่อป้ายเป็น M

- วันที่: 2026-09-25
- คำขอ: Sv. ดูลอย และเปลี่ยนคำว่า “สกุลเงิน” เป็น “M”
- ต่อจากข้อ 11–12: ย้ายชื่อเซิร์ฟเวอร์จากป้ายหมวดมาเป็นข้อความรองใต้ชื่อรายการ มี label “เซิร์ฟเวอร์” และเอากรอบ pill ของชื่อ Sv. ออกเฉพาะในหัวการ์ดประวัติ; ป้ายหมวด Zeny เปลี่ยนเป็น M
- ไฟล์/จุดค้นหา: `assets/app.js` — `historyItemRowHtml`, `.mr-history-server`; `assets/app.css` — `Server belongs to the item identity`; `preview/history.html` เพิ่มชื่อเซิร์ฟเวอร์จำลอง
- คงเงื่อนไข showServer เดิม (แสดงเมื่อเลือกทุกเซิร์ฟเวอร์) ไม่เปลี่ยนตัวกรอง ข้อมูล การคำนวณ หรือ New; ครอบคลุมการ์ดในขายหมดแล้วด้วย renderer เดียวกัน
- Cache: CSS `20260925-polish12` ใน index และ preview ทั้งสอง; JS `20260925-server-meta` ใน index
- ตรวจ: node syntax และ tests ทั้งสามชุดผ่าน; git diff --check ผ่านโดยมีคำเตือน LF/CRLF; browser preview ยืนยันป้าย M และชื่อเซิร์ฟเวอร์ใต้ชื่อรายการ ข้อมูลจริงหลังล็อกอินยังไม่ได้ตรวจในชุดนี้
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 14 — ย้ายเซิร์ฟเวอร์ต่อจาก M ในแถวเดียวกัน

- วันที่: 2026-09-25
- คำขอ: ย้ายชื่อเซิร์ฟเวอร์ขึ้นแถวเดียวกับป้าย M
- แทนที่ตำแหน่งในข้อ 13 เฉพาะการ์ด Zeny: `.mr-history-zeny .mr-history-server` ใน `assets/app.css` เปลี่ยน flex-basis เป็น auto และเอา padding ซ้ายออก จึงวางต่อจาก M; เมื่อพื้นที่ไม่พอยังขึ้นบรรทัดได้ ไม่บังคับให้ล้นมือถือ
- ไม่เปลี่ยนตำแหน่งข้อมูลรองของไอเทม/อื่น ๆ หรือ JavaScript
- Cache CSS: `20260925-polish13` ใน `index.html`, `preview/history.html`, `preview/merchant.html`
- ตรวจ browser preview: กรอบตำแหน่ง M และเซิร์ฟเวอร์อยู่แถวเดียวกัน และเซิร์ฟเวอร์อยู่ทางขวา; git diff --check ผ่าน (คำเตือน LF/CRLF)
- สถานะ: แก้ในเครื่อง ยังไม่ได้ deploy; ไม่ได้ทดสอบบัญชีจริงในชุดนี้

### 15 — ลดขนาดการ์ดไอเทมตอนพับ

- วันที่: 2026-09-25
- คำขอ: ลดขนาดการ์ดไอเทมสามใบในภาพให้เล็กลงอีก
- ไฟล์: `assets/app.css` บล็อก `Smaller collapsed item cards`; ปรับเฉพาะ `.mr-history-item:not(.open)` ทั้งรายการปกติและขายหมดแล้ว
- ลด padding เป็น 4px 12px, margin-top 3px, รูป/ไอคอนจาก 32px เป็น 28px, มุม 10px; คงหัวปุ่มอย่างน้อย 44px และขนาดข้อความเดิม ไม่ย่อ Zeny/อื่น ๆ หรือรายละเอียดตอนกาง
- ต่อจากข้อ 12: แถวชื่อบรรทัดเดียวไม่มีเซิร์ฟเวอร์มีความสูงขั้นต่ำประมาณ 54px; preview ที่มีชื่อเซิร์ฟเวอร์บรรทัดรองวัดได้ประมาณ 58.8px ไม่ล็อกความสูงเพื่อให้ชื่อยาวขึ้นบรรทัดได้
- ตรวจ browser preview ภาพจอปกติและวัดสามการ์ดแรก; 320×800 scrollWidth 305px ไม่ล้น และ hiddenLeaks 0; คืน viewport แล้ว; git diff --check ผ่านพร้อมคำเตือน LF/CRLF
- Cache CSS: `20260925-polish14` ใน index และ preview ทั้งสอง ไม่มีการเปลี่ยน JS/ข้อมูล
- สถานะ: แก้ในเครื่อง ยังไม่ได้ deploy; ไม่ได้ทดสอบบัญชีจริงในชุดนี้

### 16 — เปลี่ยนไอคอนหนังสือเป็นพ่อค้าบาโฟ

- วันที่: 2026-09-25
- คำขอ: ใช้ภาพ `พ่อค้าบาโฟ.png` ที่ผู้ใช้แนบแทนหนังสือ พร้อมลดขนาดไฟล์
- เพิ่ม `assets/merchant-baphomet.webp`: ใช้ Sharp trim ขอบโปร่งใส, resize fit inside 128×128, WebP quality 82 / alphaQuality 90 / effort 6; ผล 81×128px โปร่งใส 5,980 bytes จากต้นฉบับ 995,104 bytes (ลดประมาณ 99.4%) ไม่แก้/ลบต้นฉบับใน Downloads
- `index.html`: เปลี่ยนรูปในหัวข้อรายการซื้อ–ขาย ประวัติซื้อ–ขาย และกราฟเงินสุทธิ คง class `dashboard-book-icon` และ decorative alt/aria-hidden เดิม
- `assets/app.css`: บล็อก `Supplied merchant mascot` ใช้กรอบ 36×44px, object-fit contain, จัดกึ่งกลางแนวตั้งและเงาบาง ไม่มี animation เพิ่ม
- เปลี่ยนรูปใน `preview/merchant.html` และเพิ่มรูปหัวข้อใน `preview/history.html`; เก็บ `assets/Bible.png` เดิมไว้ ไม่ลบไฟล์เก่า
- Cache CSS: `20260925-polish15` ใน index และ preview ทั้งสอง; ไม่เปลี่ยน JS/ข้อมูล
- ตรวจ browser preview: รูปโหลดสำเร็จ naturalWidth 81 / naturalHeight 128 และตรวจภาพหัวข้อ; git diff --check ผ่าน (คำเตือน LF/CRLF); ยังไม่ได้ตรวจทุกหัวข้อในบัญชีจริง
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 17 — ปรับหน้าต่างวิธีใช้ให้อ่านง่าย

- วันที่: 2026-09-25
- คำขอ: ปรับ UI หน้าต่างวิธีใช้ให้ทันสมัยและอ่านง่าย
- `assets/app.css` บล็อก `Readable help dialog`: เปลี่ยนจาก width max-content/nowrap เป็นหน้าต่างกว้างไม่เกิน 720px, ข้อความ wrap, พื้นกรมท่าและเส้นแบ่งหัวข้อ, หัวหน้าต่างอยู่คงที่และเลื่อนเฉพาะเนื้อหา ปุ่มปิด 44px รองรับมือถือและ focus-visible
- `assets/app.js`: `HOWTO_CONTENT.home` เปลี่ยนหัวข้อเพิ่มเติม I–IV เป็นชื่อที่สื่อเนื้อหา; `openHowto` แยกเลขขั้นตอนจากข้อความเป็นช่องนำสายตา ใช้ h4 สำหรับหัวข้อย่อย คงข้อความคำแนะนำทั้งหมด ไม่เปลี่ยนกฎการทำงาน
- รูปแบบหน้าต่างใช้ร่วมกับวิธีใช้คลัง/ฟาม/จับเวลาบอสด้วย คงสีคำเตือนแยกชัด
- `index.html`: เพิ่ม role dialog, aria-modal, aria-labelledby และ region ของเนื้อหา; JS เพิ่มเปิดด้วย Enter/Space, โฟกัสปุ่มปิดเมื่อเปิด, Tab/Shift+Tab วนปุ่มปิดกับพื้นที่เลื่อน, Esc ปิดและพยายามคืน focus ไปยังจุดเดิม
- Cache CSS `20260925-polish16` ใน index/preview ทั้งสอง; JS `20260925-howto`
- ตรวจจริงในหน้าหลักแบบ guest: เปิดวิธีใช้บัญชีนักลงทุนและตรวจภาพ; 320×800 dialog สูง 720px, เนื้อหา clientWidth/scrollWidth เท่ากัน 283px ไม่ล้นแนวนอนและเลื่อนแนวตั้งได้; Tab เข้า howtoBody และ Esc ซ่อน dialog สำเร็จ; คืน viewport แล้ว
- ตรวจ node syntax, tests ประวัติเดิมสามชุด และ git diff --check; ไม่ได้ตรวจทุกหน้าวิธีใช้หลังล็อกอินหรือ screen reader จริง
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 18 — ฟอร์มต้นทุนต่อกั้มสไตล์เดียวกับรายการซื้อ–ขาย

- วันที่: 2026-09-26
- คำขอ: ปรับต้นทุนต่อกั้มให้สะอาด ทันสมัยเหมือนฟอร์มรายการซื้อ–ขาย
- `assets/app.css` บล็อก `Farm cost form`: ใช้พื้นกรมท่าเรียบ ขอบบาง 14px ช่องกรอกเข้มสูง 44px และ focus ชัด; แยกส่วนต้นทุน ยอดรวม ไอเทมหายาก ยอดฟาร์ม; ปุ่มบันทึก gradient 48px
- `index.html`: เพิ่มหัวข้อ “รายการต้นทุน”, แยกหัวไอเทมหายากกับคำแนะนำ และใช้ label ผูกช่องเรท/แผนที่ฟาร์ม; รักษา id/class และตำแหน่ง hook ของ inputs/รายการเดิม
- ใช้ container farm-entry: พื้นที่ไม่เกิน 440px แยกชื่อไอเทมและจำนวน/ราคา/หน่วยเป็นสองแถว; พื้นที่กว้างใช้แถวเดียว มือถือใช้ฟอนต์ input 16px
- ไม่แก้ assets/app.js ไม่เปลี่ยน OC, สูตรต้นทุน, แปลงเรท, บันทึก/แก้ไข/ยกเลิก หรือ disabled/read-only; hidden ของข้อความพักเซิร์ฟเวอร์/คำเตือนยังคงเดิม
- เพิ่ม `preview/farm.html` ดึงเฉพาะ markup ฟอร์มจาก index แล้วใส่ข้อมูลจำลองและปุ่มเพิ่มแถวสาธิต ไม่มี backend/การคำนวณจริง ปุ่มบันทึกแจ้งว่าเป็นตัวอย่าง
- Cache CSS `20260926-polish17` ใน index และ preview ทั้งสาม
- ตรวจภาพ preview จอปกติและ 320×800, เพิ่มต้นทุนได้ 2 แถว; ที่ 320px scrollWidth 305 และ hiddenLeaks 0; คืน viewport หลังตรวจ; git diff --check และ tests ประวัติสามชุดผ่าน
- ข้อจำกัด: ยังไม่ได้ทดสอบบันทึก/คำนวณด้วยบัญชีจริง หรือทุกสถานะหลังล็อกอิน; ผล preview ไม่ใช่ backend verification
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 19 — ย่อฟอร์มต้นทุนต่อกั้มบนจอคอม

- วันที่: 2026-09-26
- คำขอ: ฟอร์มยังใหญ่เกินไป โดยเฉพาะเมื่อมีต้นทุนหลายแถว
- ต่อจากข้อ 18: เพิ่มบล็อก `Desktop density: keep long cost lists compact` ใน `assets/app.css` เฉพาะ viewport ตั้งแต่ 761px และ pointer:fine
- ลด padding แผง 18→14px, gap 14→9px, ช่องกรอก 44→36px, ปุ่มเพิ่ม 40→32px และบันทึก 48→40px; วางชื่อแผนที่ข้างช่องกรอก และหัวไอเทมหายากกับคำแนะนำในแถวเดียวเมื่อพื้นที่พอ
- มือถือ/อุปกรณ์สัมผัสคงขนาดเดิม ไม่ซ่อนรายการ ไม่เปลี่ยน JavaScript/การคำนวณ
- Cache CSS `20260926-polish18` ใน index และ preview ทั้งสาม
- ตรวจ preview เพิ่มต้นทุนเป็น 5 แถว วัดความสูงแผงประมาณ 721px และช่องกรอก 36px พร้อมตรวจภาพ; git diff --check ผ่าน (คำเตือน LF/CRLF); ความสูงจริงขึ้นกับข้อมูลและความกว้าง ไม่รับประกันพอดีทุกหน้าจอ
- สถานะ: แก้ในเครื่อง ยังไม่ได้ deploy และไม่ได้ทดสอบบันทึกบัญชีจริง

### 20 — ประวัติฟาร์มสะอาดขึ้นโดยเน้นสีแยกวัน

- วันที่: 2026-09-26
- คำขอ: ปรับประวัติฟาร์มให้ทันสมัย โดยเน้นให้ต่างวันและพื้นหลังแยกกันชัด ห้ามทำให้กลมกลืน
- `assets/app.css` บล็อก `Farm history: preserve alternating DAY colors`: กลุ่มม่วงใช้พื้น #252841 / หัว #363858 / ขอบ #a79bd9; กลุ่มน้ำเงินใช้พื้น #172f43 / หัว #24475e / ขอบ #70b5d8; ขอบซ้าย 4px และระยะระหว่างวัน 16px
- ใช้ :has(.farm-history-alt-even) อ่าน class วันที่เดิม ไม่แก้การจัดกลุ่มใน JS ทุกใบวันเดียวกันใช้พื้นเดียวกัน และยังคงสีหลังพับรายการ
- ลดกรอบ/เงาภายใน ปรับสามคอลัมน์ตัวเลข ลบเส้นประใต้ยอดแต่คง underline ตอน hover เพื่อบอกว่าดูรายละเอียดได้; เฉลี่ยต่อกั้มมีแถบสรุปของตัวเอง ปุ่มแก้/ลบแยกชัด แสดงกรอบทองเมื่อ editing
- มือถือใช้ข้อมูลแถว label/value ตามความกว้าง container; ปุ่มแก้/ลบและพับวัน 44px เมื่อกลุ่มกว้างไม่เกิน 460px; คงสีรายได้ ต้นทุน กำไร/ขาดทุน และหน่วยเดิม
- เพิ่ม `preview/farm-history.html` ข้อมูลสมมติสองวัน วันละสองรายการ กดพับได้ แต่ปุ่มแก้/ลบไม่มีผล ไม่ใช่ข้อมูลบัญชีจริง
- Cache CSS `20260926-polish19` ใน index และ preview ทั้งหมด; ไม่เปลี่ยน assets/app.js สูตรคำนวณหรือข้อมูล
- ตรวจภาพสองวันและ computed colors ยืนยันพื้น/ขอบต่างกัน และแต่ละวันมีสีการ์ดย่อยเหมือนกันหลังพับ; 320×800 scrollWidth 305px ไม่ล้น, hiddenLeaks 0; คืน viewport หลังตรวจ
- ตรวจ git diff --check และ tests ประวัติเดิมทั้งสามผ่าน; ยังไม่ได้ทดสอบธุรกรรมแก้/ลบหรือ tooltip ด้วยบัญชีจริงในชุดนี้
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 21 — ภาพปาร์ตี้หน้าข้อความจำนวนสมาชิก

- วันที่: 2026-09-26
- คำขอ: ใส่ภาพ partyboss.png หน้าข้อความสมาชิกในปาร์ตี้ บีบอัดไฟล์ได้
- เพิ่ม `assets/party-boss.webp` จากไฟล์ที่ผู้ใช้แนบ: Sharp trim threshold 20, resize fit inside 240×180, WebP quality 82 / alphaQuality 90 / effort 6; ได้ภาพโปร่งใส 240×156px ขนาด 25,024 bytes จากต้นฉบับ 1,794,690 bytes เก็บต้นฉบับไว้
- `index.html`: เพิ่ม `.party-member-identity` จัดภาพกับ `#partyPanelSummary` โดยคง id ของข้อความเดิมและปุ่มจัดการปาร์ตี้ รูป alt ว่าง/aria-hidden เพราะใช้ตกแต่ง
- `assets/app.css`: บล็อก `Supplied party artwork` ภาพ 72×47px บนคอม / 60×39px บนมือถือ จัดชิดหน้าจำนวนสมาชิก และอนุญาตแถบ wrap เมื่อจอแคบ
- ไม่เปลี่ยน app.js: จำนวนสมาชิกยังอัปเดตด้วย textContent เดิม ไม่ลบรูปที่เป็น sibling ของข้อความ
- Cache CSS ใน index: `20260926-polish20`; หน้าตัวอย่างเดิมไม่มีแผงปาร์ตี้ จึงไม่เปลี่ยน cache ใน preview
- ตรวจหน้าจับเวลาบอสแบบ guest: ภาพโหลดสำเร็จและข้อความ 0 คนยังแสดง; ที่ 320px กลุ่มภาพ/ข้อความกว้างประมาณ 160px ในแผง 281px; คืน viewport แล้ว; git diff --check ผ่าน (คำเตือน LF/CRLF)
- ข้อจำกัด: ยังไม่ได้ตรวจปาร์ตี้บัญชีจริง 2 คนหรือเปลี่ยนสมาชิกจริง; ไม่กดจัดการหรือเปลี่ยนข้อมูลปาร์ตี้
- สถานะ: แก้ในเครื่อง ยังไม่ได้ deploy

### 22 — เก็บรายละเอียดการ์ดสรุปจับเวลาบอสสี่ใบ

- วันที่: 2026-09-26
- คำขอ: ชอบธีมเดิม ให้ปรับความสมดุลภาพและข้อมูลเฉพาะการ์ดสรุป
- `assets/app.css` บล็อก `Four timer summaries`: จัด grid หัว/ข้อมูล/ลิงก์ ให้ดูทั้งหมดอยู่ฐานเดียวกัน; ลด padding, ไอคอนหัว 28px, ตัวเลข 1.5rem, ลด gradient/เงาเรืองและยกตัวตอน hover
- คงภาพและสีสี่ใบเดิม: thumbnail บอส 52×60px, ไอเทม 36×36px ลดการขยายภาพต้นฉบับเล็ก; ภาพยอดขาย/ส่วนแบ่ง 52×56px ยกเลิก scale เพิ่ม ข้อมูลเงินสองบรรทัดจัดระยะสม่ำเสมอ
- ไม่มีการเปลี่ยน app.js สูตรคำนวณ การดึงภาพล่าสุด หรือ data-open-history; ไม่สร้างภาพใหม่/ไม่แก้ไฟล์ภาพเดิม
- เพิ่ม `preview/timers-summary.html` ใช้ markup จริงและยอดจำลอง; ไม่ดึงภาพบอส/ไอเทมล่าสุดจากบัญชี สองใบแรกจึงไม่มีภาพใน preview นี้ ปุ่มดูทั้งหมดไม่มีผล
- Cache CSS ใน index และ preview ใหม่ `20260926-polish21`; preview เดิมไม่แสดงสี่การ์ดนี้จึงไม่เปลี่ยนเวอร์ชัน
- ตรวจ preview ข้อมูลจำนวน/ยอดต่างกัน: ทุกใบสูง 192px ลิงก์มีค่า top เท่ากัน; มือถือ 320px scrollWidth 320 ไม่ล้น, hiddenLeaks 0; คืน viewport หลังตรวจ; git diff --check ผ่าน (คำเตือน LF/CRLF)
- ยังไม่ได้ตรวจภาพล่าสุด/เปิดประวัติด้วยบัญชีจริงในชุดนี้ ไม่อ้างว่าลดขนาดแล้วภาพต้นฉบับจะคมขึ้นเสมอ
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 23 — หน้าแพ็กเกจแบบ minimal ในธีมเดิม

- วันที่: 2026-09-26
- คำขอ: ลดความรก/ขนาดการ์ด โดยคงรายละเอียดแพ็กเกจทั้งหมด
- `assets/app.css` บล็อก `Minimal pricing comparison`: พื้นกรมท่า #1b283c ทุกใบ ขอบบาง 14px ไม่ยก/ขยายการ์ดเมื่อ hover; 4 in 1 เน้นเส้นบน ป้ายและปุ่มทองแทนพื้นทองเรือง
- ชื่อ 1.55rem ราคา 2.35rem จัดชิดซ้าย; จัดหัวและกลุ่มราคาให้เทียบกันง่าย แถวสิทธิ์เป็นรายการเรียบมีเส้นคั่นแทนกล่องซ้อน; สิทธิ์แพ็กฟรียังอ่านได้ สถานะใช้งานแยกจากปุ่ม
- `assets/app.js` / `renderPricingPage`: ใช้ wrapper หัวเดียวกันทุกใบและตัดขีดยาวตกแต่งเฉพาะชื่อที่แสดง ไม่เปลี่ยน PRICING_PLANS ราคา โปรโมชั่น สิทธิ์ ลำดับ หรือเงื่อนไขซื้อ/ต่ออายุ/รายละเอียด
- Responsive: 3 คอลัมน์จอกว้าง, 2 เมื่อ viewport ไม่เกิน 1100px, 1 เมื่อไม่เกิน 640px; ไม่ล็อกความสูง/ตัดข้อความ ปุ่มอย่างน้อย 44px
- Cache index: CSS `20260926-polish22`, JS `20260926-pricing-minimal`
- เพิ่ม `tests/pricing-presentation.cjs` รับ app.js จาก baseline Git ทาง stdin แล้วเทียบข้อความและ button hooks กับ renderer ปัจจุบัน ผ่าน 24 กรณีรายเดือน/ปี โปรโมชั่นเปิด/ปิด สถานะยังไม่ซื้อ/ไม่จำกัดเวลา/มีวันหมดอายุ และรายละเอียดพับ/กาง; ไม่เรียกเครือข่ายหรือ payment handlers
- คำสั่งทดสอบ: `git show ea5e476c0fec88e2c99a413efd4617225afb568d:assets/app.js | node tests/pricing-presentation.cjs` (PowerShell ต้องใช้ OutputEncoding UTF-8); node syntax และ tests ประวัติสามชุดผ่าน; git diff --check ผ่าน มีคำเตือน LF/CRLF
- Browser หน้าจริงแบบ guest 1280×720: การ์ดแถวแรกสูงเท่ากัน 666.6px แถวสิทธิ์เริ่มแนวเดียวกัน; เปิดรายละเอียดแล้วแสดงครบทั้งหกใบ สลับรายปีได้ยอด 990 / 990 / 1,750 / 0 / 99 / 149 ตามเดิม และคืนรายเดือน
- มือถือ 320×800 ขณะกางรายละเอียด: scrollWidth 305px ไม่ล้น การ์ดกว้าง 281px, hiddenLeaks 0; คืน viewport หลังตรวจ ไม่มีการทดสอบซื้อ/ต่ออายุจริงหรือบัญชีล็อกอิน สถานะ owned ตรวจเฉพาะ renderer จำลอง
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 24 — ภาพเคลื่อนไหว Wounded Morocc บนแพ็กจับเวลาบอส

- วันที่: 2026-09-26
- คำขอ: ใช้ GIF ที่ผู้ใช้แนบ เพิ่มในแพ็กจับเวลาบอส ปรับขนาด/บีบอัดได้
- เพิ่ม `assets/pricing-morocc.webp` Animated WebP และ `assets/pricing-morocc-still.webp` ภาพนิ่ง จาก Downloads โดยไม่แก้ต้นฉบับ; Sharp resize 120px quality 75 alphaQuality 100 effort 6 คง 6 เฟรมและจังหวะเดิม
- `renderPricingPage` เพิ่มภาพเฉพาะ key timers ขนาดแสดง 80×80px ด้านขวาของหัวเดิม มีปุ่มหยุด/เล่น 44px และสถานะ `pricingArtworkPaused` เฉพาะ session; ไม่แตะราคา/สิทธิ์/การซื้อหรือหน้าจับเวลาบอสจริง
- `<picture>` เลือกภาพนิ่งเมื่อ prefers-reduced-motion; ซ่อนปุ่มเล่นในโหมดนี้ ภาพเป็นของตกแต่ง alt ว่าง; CSS บล็อก `Supplied Morocc animation` จองพื้นที่ไม่ให้ข้อความทับภาพ
- Cache index: CSS `20260926-polish23`, JS `20260926-pricing-morocc`; ปรับ test presentation ให้ไม่นับปุ่มตกแต่งใหม่ในการเทียบ purchase hooks
- ไฟล์เคลื่อนไหว 37,698 bytes จาก GIF 64,979 bytes (ลดประมาณ 42%); ภาพนิ่ง 6,514 bytes เก็บ transparency/6 เฟรม 150ms เดิม
- เพิ่มเฉพาะ `#pricingGrid .pricing-artwork-toggle` ใน GUEST_VIEW_ALLOW เพื่อให้ guest หยุดภาพได้โดยไม่เปิดล็อกอิน; ไม่เพิ่มสิทธิ์ข้อมูลหรือการซื้อ
- ตรวจ renderer 24 กรณีและ node syntax ผ่าน; browser guest ตรวจภาพโหลด 120px และปุ่มสลับ animated/still ได้จริง; desktop สามการ์ดแรกยังสูง 666.6px เท่าเดิม มือถือ 320×800 scrollWidth 305px หัวข้อความไม่ทับรูป (ขอบชื่อ 186px / รูปเริ่ม 194px); คืน viewport และเล่นภาพหลังตรวจ
- reduced-motion ตรวจจาก picture media/CSS เท่านั้น ยังไม่ได้ทดสอบเปลี่ยน setting ระบบจริง; ไม่ทดสอบซื้อ/ต่ออายุบัญชีจริง
- สถานะ: แก้ในเครื่อง ยังไม่ได้ commit/push/deploy

### 25 — เอาปุ่มหยุด/เล่นภาพบอสออก

- วันที่: 2026-09-26
- คำขอ: เอาปุ่มใต้ภาพบอสออกตามภาพแนบ แทนที่ส่วนปุ่มในข้อ 24
- `assets/app.js`: ลบ markup ปุ่ม, pricingArtworkPaused, listener และ guest allow เฉพาะปุ่มนี้; คง Animated WebP และ picture ภาพนิ่งสำหรับ prefers-reduced-motion
- `assets/app.css`: ลบกฎปุ่มที่ไม่ใช้ ไม่เปลี่ยนขนาด/ตำแหน่งภาพหรือข้อมูลแพ็กเกจ; ไม่ลบไฟล์รูป
- `tests/pricing-presentation.cjs`: กลับมาเทียบทุก button hook กับ baseline โดยไม่มีข้อยกเว้นปุ่มภาพ
- Cache index: CSS `20260926-polish24`, JS `20260926-pricing-artwork-only`
- การตรวจ: node syntax, renderer 24 กรณี และ git diff --check ผ่าน; reload หน้า guest พบปุ่มภาพ 0 ตัวและ Animated WebP โหลด naturalWidth 120px; ไม่มีการเปลี่ยนข้อมูลหรือซื้อจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 26 — ขยายบอสเต็มพื้นที่ว่างด้านขวา

- วันที่: 2026-09-26
- คำขอ: ทดลองขยายบอสประมาณ 130–150px โดยไม่ทับชื่อ/ราคา ไม่เพิ่มความสูงการ์ด
- `assets/app.css` / `Supplied Morocc`: ขยายจาก 80px เป็นสูงสุด 150px ปรับตามพื้นที่การ์ด โดยกันข้อความราคา 140px; ย้ายลงใต้ชื่อ/คำอธิบายที่ top 60px ไม่เบียดหัวข้อ มือถือย่ออัตโนมัติ
- เพิ่มภาพ `pricing-morocc-large.webp` และ `pricing-morocc-large-still.webp` สร้างจาก GIF ต้นฉบับ 223×223px ด้วย Sharp WebP quality 78 alphaQuality 100 effort 6; คงภาพเดิม/ต้นฉบับ ไม่ลบไฟล์ และยังรองรับ reduced-motion
- `renderPricingPage` เปลี่ยนเฉพาะ asset และ intrinsic dimensions; ไม่เปลี่ยนข้อมูล ราคา หรือเพิ่มปุ่ม
- Cache CSS `20260926-polish25`, JS `20260926-pricing-artwork-large`
- การตรวจ: ภาพ desktop 1280px บอสแสดงประมาณ 138px ไม่ทับชื่อ/ราคา การ์ดยังคงสูง 666.6px; ที่ 320px บอสย่อเป็น 103px และ scrollWidth 305px ไม่ล้น คืน viewport แล้ว; syntax, renderer 24 กรณี และ diff --check ผ่าน (คำเตือน LF/CRLF)
- ไฟล์ใหม่ animated 66,774 bytes / still 11,370 bytes ยอมเพิ่มขนาดจากรุ่นย่อเพื่อความละเอียด ไม่อ้างว่ารุ่นนี้เล็กกว่าต้นฉบับ GIF; ไม่ได้ทดสอบซื้อจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 27 — GIF พ่อค้าส่ายหัวในการ์ด 2 in 1

- วันที่: 2026-09-26
- คำขอ: ทำ PNG พ่อค้าเป็น GIF ส่ายหัวแล้วใส่แพ็ก 2 in 1
- ใช้ imagegen built-in สร้างท่าศีรษะ เลือกสองท่าที่ไม่กลับด้าน ทำ GIF 8 เฟรม 180×240px ด้วย `scripts/build-pricing-merchant.cjs`; รายละเอียดวิธีและ prompt ใน `docs/pricing-merchant-animation.md`
- เพิ่ม `assets/pricing-merchant-sway.gif` และภาพนิ่ง WebP; เป็นภาพวาดใหม่จาก reference ไม่ใช่ rig ต้นฉบับสมบูรณ์ ใช้ short dissolve และล็อกส่วนล่าง ไม่หมุนทั้งภาพ
- `renderPricingPage`: ใส่เฉพาะ accountItems; CSS `.pricing-artwork-merchant` อยู่ช่องว่างด้านขวา รองรับมือถือและ prefers-reduced-motion ไม่มีปุ่มควบคุมตามข้อ 25 ไม่แก้ข้อมูล/การซื้อ
- Cache CSS `20260926-polish26`, JS `20260926-pricing-merchant-sway`
- GIF ขนาด 191,429 bytes; ตรวจ metadata มี 8 เฟรม 180×240px delay รวม 1.3 วินาที loop 0 (วนต่อเนื่อง) และ alpha โปร่งใส
- ตรวจ guest desktop 1280×720: รูปโหลด naturalWidth 180 แสดงในกรอบ 130×130px ไม่ทับราคา; มือถือ 320×800 กรอบรูป 103px อยู่ขวาราคา (ราคา right 155.8 / รูป left 179), scrollWidth 305px, hiddenLeaks 0; คืน viewport แล้ว
- Node syntax และ renderer 24 กรณีผ่าน; ไม่ได้ตรวจการตั้งค่า reduced-motion ระบบจริงหรือซื้อ/ต่ออายุจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 28 — ลดอาการตาลายของ GIF พ่อค้า

- วันที่: 2026-09-26
- คำขอ: ขยับแบบทื่อ ๆ ได้ ไม่ต้องสมจริง เพราะภาพเดิมดูตาลาย
- แทนที่ animation ข้อ 27: `scripts/build-pricing-merchant.cjs` ใช้เฉพาะสองท่าคมชัด ค้างท่าละ 900ms ตัดเฟรม dissolve ระหว่างท่าทั้งหมด จาก 8 เหลือ 2 เฟรม รอบ 1.8 วินาที; ไม่สร้างท่า AI เพิ่ม
- สร้าง `assets/pricing-merchant-sway.gif` ใหม่จาก sheet เดิม คงขนาด ตำแหน่ง ภาพนิ่ง reduced-motion และข้อมูลแพ็กเกจ
- Cache: GIF `?v=2`, JS `20260926-pricing-merchant-stepped`; CSS ไม่เปลี่ยน
- การตรวจ: metadata ยืนยัน 2 เฟรม delay [900,900] ขนาด 180×240px; browser โหลด URL ?v=2 สำเร็จ naturalWidth 180; node syntax และ diff --check ผ่าน; ยังไม่ได้ deploy

### 29 — GIF ไนท์ต่อสู้ในการ์ด 1 in 1

- วันที่: 2026-09-26
- คำขอ: ประกอบ PNG ไนท์ทั้ง 5 ภาพที่ผู้ใช้ทำไว้เป็น GIF ต่อสู้แล้วใส่แพ็ก 1 in 1
- `scripts/build-pricing-knight.cjs`: อ่านต้นฉบับ Downloads/ไนท์ขยับ โดยไม่แก้ไฟล์เดิม; ลำดับ image (39) → (36) → (38) → (37) → (40) → วนกลับ เป็นตั้งท่า/เตรียม/เหวี่ยง/แทง/กลับท่า
- ไม่มี AI redraw, morph หรือ dissolve; ทุกเฟรมใช้ canvas/scale เดียวกัน 220×220px ไม่ trim แยกเฟรม; delay [700,240,180,220,450] ms รวม 1.79 วินาที
- เพิ่ม `assets/pricing-knight-battle.gif` และภาพนิ่ง `pricing-knight-battle-still.webp`; `renderPricingPage` เพิ่มเฉพาะ key farm, CSS `.pricing-artwork-knight` ขวาของราคา สูงสุด 130px ย่อตามพื้นที่
- คงภาพนิ่งเมื่อ prefers-reduced-motion ไม่เพิ่มปุ่ม ไม่เปลี่ยนข้อความ ราคา สิทธิ์ หรือการซื้อแพ็ก
- Cache CSS `20260926-polish27`, JS `20260926-pricing-knight`
- การตรวจ: GIF metadata 5 เฟรม delay ตรงตามสคริปต์ โปร่งใส ขนาด 75,982 bytes; node syntax และ pricing renderer 24 กรณีผ่าน
- Browser guest desktop ตรวจภาพแถวล่างและเปิด/ปิดรายละเอียดได้; มือถือ 320px รูปโหลด naturalWidth 220 กรอบ 103px อยู่ขวาราคา (ราคา right 132.3 / รูป left 179), scrollWidth 305px ไม่ล้น; คืน viewport หลังตรวจ ไม่ทดสอบซื้อจริง/การตั้งค่า reduced-motion ระบบจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 30 — ไนท์เหลือสองจังหวะตามภาพที่เลือก

- วันที่: 2026-09-26
- คำขอ: ลดจำนวนท่า เหลือ image (39) และ image (37) เท่านั้น
- แทนที่ animation ข้อ 29: `scripts/build-pricing-knight.cjs` ใช้ [39,37] ตั้งรับ 700ms / แทง 500ms วน 1.2 วินาที ไม่มีเฟรมละลายหรือท่าอื่น
- สร้าง `assets/pricing-knight-battle.gif` ใหม่ คงขนาด 220×220px ตำแหน่งการ์ดและภาพนิ่ง reduced-motion เดิม ไม่ลบต้นฉบับ
- Cache GIF `?v=2`, JS `20260926-pricing-knight-two-poses`; CSS ไม่เปลี่ยน
- การตรวจ: metadata ยืนยัน 2 เฟรม 220×220px delay [700,500], node syntax และ diff --check ผ่าน; browser โหลด GIF ?v=2 สำเร็จ naturalWidth 220; ไม่ทดสอบธุรกรรมจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 31 — GIF โนวิซเดินในการ์ดฟรี

- วันที่: 2026-09-26
- คำขอ: รวม PNG เดินสองภาพจาก Downloads/โนวิดเดิน แล้วใส่การ์ดฟรี
- `scripts/build-pricing-novice.cjs`: ใช้ image (36) → (38) วนตรง ค้างเฟรมละ 450ms รอบละ 0.9 วินาที ไม่มี redraw หรือ dissolve คง canvas เดียวกัน ไม่แก้ต้นฉบับ
- เพิ่ม `assets/pricing-novice-walk.gif` 220×220px และ `pricing-novice-walk-still.webp` สำหรับ prefers-reduced-motion
- `renderPricingPage` เพิ่มเฉพาะ key free; CSS `.pricing-artwork-novice` กรอบสูงสุด 130px ด้านขวาราคา ย่อตามพื้นที่ ไม่เปลี่ยนราคา สิทธิ์ ปุ่มฟรี หรือความสูงการ์ด
- Cache CSS `20260926-polish28`, JS `20260926-pricing-novice`
- การตรวจ: metadata ยืนยัน 2 เฟรม 220×220px delay [450,450] โปร่งใส; syntax, pricing renderer 24 กรณี และ diff --check ผ่าน; browser guest desktop ตรวจภาพในการ์ดฟรีและรายละเอียดพับ/กาง มือถือ 320px รูปโหลด naturalWidth 220 กรอบ103px scrollWidth305 ไม่ล้น คืน viewport แล้ว; ไม่ทดสอบธุรกรรมจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 32 — เปลี่ยน 2 in 1 เป็นภาพนิ่งพ่อค้าบาโฟ

- วันที่: 2026-09-26
- คำขอ: ใช้ PNG พ่อค้าบาโฟที่แนบแทน GIF ในการ์ด 2 in 1
- เพิ่ม `assets/pricing-merchant-static.webp` จาก PNG ต้นฉบับด้วย Sharp trim threshold20 / resize fit inside240×260 / quality85 alphaQuality100 effort6 ได้165×260px 17,574 bytes โปร่งใส ไม่แก้ต้นฉบับ
- `renderPricingPage` เฉพาะ accountItems เปลี่ยน picture/GIF เป็น img ภาพนิ่ง ทุกโหมดใช้ภาพใหม่; คงกรอบและ CSS เดิม ไม่เปลี่ยนภาพแพ็กอื่น ราคา สิทธิ์ หรือการซื้อ
- เก็บ GIF/สคริปต์ก่อนหน้าไว้เพื่อย้อนดู ไม่ลบไฟล์ แต่การ์ดนี้ไม่โหลด GIF แล้ว; แทนที่ภาพเคลื่อนไหวข้อ27–28
- Cache JS `20260926-pricing-merchant-static`; CSS ไม่เปลี่ยน
- การตรวจ: browser โหลด pricing-merchant-static.webp สำเร็จ naturalWidth165; node syntax, pricing renderer24กรณี และ diff --check ผ่าน ไม่ทดสอบธุรกรรมจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 33 — ภาพนิ่ง 2 in 1 แบบมีรถเข็น

- วันที่: 2026-09-26
- คำขอ: เปลี่ยนเป็นภาพนิ่ง image (35).png พ่อค้าพร้อมรถเข็นที่แนบมา แทนภาพข้อ32
- เพิ่ม `assets/pricing-merchant-cart-static.webp` จากต้นฉบับด้วย Sharp trim threshold20 / resize inside260×260 / quality85 alphaQuality100 effort6 ได้243×260px 24,244 bytes โปร่งใส ไม่สร้างภาพใหม่หรือแก้ต้นฉบับ
- `renderPricingPage` เปลี่ยนเฉพาะ img ของ accountItems คง CSS กรอบ130px ตำแหน่งเดิม และทุกข้อมูล/ปุ่ม; ไม่ลบภาพเก่า
- Cache JS `20260926-pricing-merchant-cart-static`; CSS ไม่เปลี่ยน
- การตรวจ: node syntax และ diff --check ผ่าน; browser โหลด pricing-merchant-cart-static.webp สำเร็จ naturalWidth243; ไม่ทดสอบธุรกรรมจริง
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

### 34 — ภาพหมวกสามชิ้นในการ์ดไอเทมขายแล้ว

- วันที่: 2026-09-26
- คำขอ: ใช้ all.png แทนโลโก้ในการ์ดสรุปไอเทมขายแล้ว ให้เห็นชัดขึ้น
- เพิ่ม `assets/timers-sold-headgear.webp` จากต้นฉบับด้วย Sharp trim threshold20 / resize inside240×240 / quality85 alphaQuality100 effort6 ได้240×207px 17,148 bytes โปร่งใส ไม่แก้ต้นฉบับ/ไม่ลบภาพเก่า
- `assets/app.css` / `Supplied three-headgear artwork`: เปลี่ยน background-image เฉพาะ .stat-main:has(#statItemsSold)::after; จาก52×56 เป็นกว้างตามพื้นที่44–88px สูง76px opacity1 และ contain เห็นภาพครบ ไม่มีกรอบ/เงาเพิ่ม
- คงตัวเลข ยอดเงิน ลิงก์ดูทั้งหมด สีธีมและภาพการ์ดอื่น ไม่แก้ JS/ข้อมูล
- Cache CSS index และ preview/timers-summary: `20260926-polish29`
- มือถือไม่เกิน480px ย้ายภาพใต้ข้อมูลชิดขวา64×56px เฉพาะการ์ดไอเทมขายแล้ว เพื่อไม่บีบตัวเลขให้แตกบรรทัด
- การตรวจ: preview ข้อมูลจำลอง desktop1280และmobile320px ภาพใหม่แสดงครบ และ scrollWidth320ไม่ล้น; ตรวจซ้ำหลังปรับมือถือยอด1,000,000 Z / 10,000 ฿ ของการ์ดนี้อยู่ครบแต่ละบรรทัด คืนviewportแล้ว; ไม่ได้ตรวจยอดบัญชีจริง การ์ดส่วนแบ่งอื่นอยู่นอกขอบเขตชุดนี้
- สถานะ: ในเครื่อง ยังไม่ได้ commit/push/deploy

## วิธีตรวจและดูตัวอย่าง

จากรากโปรเจกต์:

```powershell
git status --short
git diff -- assets/app.css assets/app.js index.html
git diff --check
node --check assets/app.js
node tests/history-new-badges.cjs
node tests/history-categories.cjs
node tests/history-pagination.cjs
```

ไฟล์ใหม่ที่ยัง untracked เช่น `preview/`, `tests/` และเอกสารจะไม่ปรากฏใน `git diff` ปกติ ต้องดูร่วมกับ `git status --short` และเปิดไฟล์เหล่านั้น

ระหว่างงานใช้ local static server ชั่วคราวที่พอร์ต 4173:

- `http://localhost:4173/#home` — หน้าหลัก ใช้ backend เดิม
- `http://localhost:4173/preview/merchant.html` — ฟอร์มจำลอง ปุ่มไม่บันทึก
- `http://localhost:4173/preview/history.html` — ประวัติจำลอง มีเฉพาะ interaction สาธิต

ไม่มีการเพิ่มสคริปต์เริ่ม server ถาวรใน repository เซิร์ฟเวอร์ชั่วคราวอาจหยุดเมื่อปิด session ให้ใช้ static server ของทีม serve โฟลเดอร์ `Gum100UI` เมื่อต้องการเปิดใหม่

พบว่า `localhost:8080` มี server ของงานเดิมอยู่และตอบกลับ CSS version เดิม (`20260925i`) จึงไม่ใช่หลักฐานว่า UI ในโฟลเดอร์นี้ไม่เปลี่ยน ระหว่างตรวจเคยเริ่ม server ทดลองบน 8080 แล้วหยุดเฉพาะตัวที่เริ่มเพิ่มไว้ โดยคง server เดิมของผู้ใช้

## ขอบเขตการทดสอบและสิ่งที่ยังต้องตรวจจริง

- ตรวจด้วยภาพและการวัด DOM ตามขนาดที่ระบุในแต่ละรายการ ไม่ได้ทำ visual regression อัตโนมัติครบทุกหน้า/ทุกบัญชี
- แบบทดสอบ New ใช้โค้ด production บางส่วนกับ dependencies จำลอง ตรวจการอ่านแยกระดับ การเรียก persist และการตั้ง New ครั้งใหม่ ไม่ได้ทดสอบ Supabase/ฐานข้อมูลหรือ reload บัญชีจริงแบบ end-to-end
- พบ CAPTCHA ใน browser แจ้ง `300030` ระหว่างลองล็อกอิน ไม่ได้ปิด CAPTCHA เปลี่ยน site key หรือปรับสิทธิ์เพื่อข้ามปัญหานี้
- ยังต้องใช้บัญชีทดสอบตรวจซื้อ–ขายจริง แนบรูป ขายจากคลัง แก้/ลบรายการ การคำนวณหลังบันทึก และความคงอยู่ของ New หลัง reload/เปลี่ยนบัญชี
- ยังไม่ได้ยืนยันทุกหน้าในสถานะ admin, บัญชีหมดอายุ, ข้อมูลยาวมาก และการซูมทุกระดับ
- งานนี้ไม่ได้แก้สูตรคำนวณ, backend, ฐานข้อมูล, สิทธิ์, การชำระเงิน หรือ CAPTCHA
- CSS บางส่วนเป็นส่วนกลาง เช่น `.btn`, focus, dialog และชื่อแพ็กเกจ จึงควรตรวจหน้ารองก่อน deploy ไม่ใช่เฉพาะหน้าซื้อ–ขาย
- `preview/` เป็นข้อมูลสมมติสำหรับตรวจดีไซน์ หาก deploy ทั้ง repository จะมี URL ตัวอย่างด้วย ให้ผู้ดูแลเลือกว่าจะรวมไฟล์ตัวอย่างหรือไม่

### 35 — ภาพพื้นหลังโปร่งใสสำหรับ 3 in 1

- วันที่: 2026-09-26; คำขอ: ลบพื้นหลังรูปตัวละครสวมมงกุฎ แล้วใส่การ์ด 3 in 1
- ใช้ imagegen built-in แบบ background-extraction จาก `C:/Users/chot-/Downloads/ChatGPT Image Sep 26, 2026, 01_58_00 AM.png`; ไม่แก้ต้นฉบับ
- Prompt: Remove ONLY the cobblestone background and ground shadow, producing genuinely transparent alpha. Preserve the full-body character, winged gold crown/red jewel, face, hair, white/gold robe, arms, shoes, pose, colors, proportions and pixel-art edges. Keep crown tips and feet visible. No redesign, text, border, glow or ground.
- ไฟล์ใหม่ `assets/pricing-bundle-crown.webp` 145×360px, 27,176 bytes, alpha 4 channels; ย่อ/บีบอัดด้วย Sharp จากผล imagegen
- `renderPricingPage` เพิ่มภาพนิ่งเฉพาะ key bundle; CSS `.pricing-artwork-bundle` อยู่ช่องขวาของราคา สูง128px top80px ไม่ชนคำอธิบาย ไม่เปลี่ยนราคา สิทธิ์ หรือปุ่มเดิม
- Cache: CSS `20260926-polish30` ใน index และ preview/timers-summary; JS `20260926-pricing-bundle-crown`
- การตรวจ: node --check ผ่าน, pricing-presentation 24 กรณีผ่าน, git diff --check ผ่าน (มีคำเตือน LF/CRLF เดิม); browser localhost ภาพโหลด naturalWidth145; ตรวจ desktop1280 และ mobile320×800 ปรับระยะภาพหลังพบชิดคำอธิบาย และตรวจ screenshot มือถือรอบสุดท้ายไม่ทับข้อความ/ราคา ไม่ล้นแนวนอน
- ข้อจำกัด: ตรวจหน้าราคา guest ในเครื่อง ไม่ทดสอบธุรกรรม/backend; ภาพตัดพื้นหลังด้วย AI ไม่รับรอง pixel-identical กับต้นฉบับ
- สถานะ: แก้ในเครื่อง ยังไม่ commit/push/deploy

### 36 — ย่อภาพนักธนูแทน GIF ใน 1 in 1

- วันที่: 2026-09-26; ผู้ใช้ส่งภาพใหม่ให้ลดขนาดและใส่ 1 in 1 แทนภาพอัศวินข้อ29–30
- เพิ่ม `assets/pricing-farm-archer-static.webp` จาก clipboard-4367e00e-f88c-4bbf-94f9-224b1d364d9f.png ด้วย Sharp resize inside260×300, WebP quality85 effort6; ผล200×300px 23,318 bytes คง alpha ของต้นฉบับ ไม่ลบหรือสร้างพื้นหลังใหม่ ไม่แก้ต้นฉบับ
- `renderPricingPage` key farm เปลี่ยนจาก GIF เป็นภาพนิ่ง; `.pricing-artwork-archer img` สูง120px desktop และ100px ที่จอ<=640px ปรับ top76px บนมือถือเพื่อไม่เลยเข้ารายการฟีเจอร์; เก็บ GIF เก่าไว้
- ไม่เปลี่ยนข้อมูล ราคา สิทธิ์ ปุ่ม หรือแพ็กอื่น
- Cache CSS `20260926-polish31` ใน index/preview timers-summary; JS `20260926-pricing-farm-archer`
- ตรวจจริง: node syntax ผ่าน, pricing-presentation 24กรณีผ่าน, diff --check ผ่านพร้อมคำเตือน line ending เดิม; localhost desktop1280×720 และ mobile320×800 ภาพโหลด naturalWidth200 ไม่มีล้นแนวนอน; แก้ระยะมือถือแล้วตรวจ screenshot ซ้ำไม่ชนรายการฟีเจอร์
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy; ไม่ได้ทดสอบการซื้อจริง/backend

### 37 — เปลี่ยน 1 in 1 เป็นอัศวินภาพนิ่ง

- วันที่: 2026-09-26; แทนภาพนักธนูข้อ36 ด้วย `Downloads/ไนท์ขยับ/image (37).png` ตามคำขอล่าสุด
- เพิ่ม `assets/pricing-farm-knight-static.webp` ย่อด้วย Sharp trim20/inside260×260/WebP quality85 alphaQuality100 effort6: 260×193px, 16,560 bytes มี alpha; เก็บไฟล์ต้นฉบับและภาพเก่าไว้
- `renderPricingPage` key farm เปลี่ยนเฉพาะ src และขนาด intrinsic เป็นภาพนิ่ง ใช้ตำแหน่ง/การย่อตามพื้นที่เดิม ไม่เปลี่ยนราคา สิทธิ์ หรือปุ่ม
- JS cache ใน index: `20260926-pricing-farm-knight-static`; CSS ไม่เปลี่ยน
- ตรวจ: node --check และ pricing-presentation 24กรณีผ่าน; git diff --check ผ่าน มีคำเตือน LF/CRLF เดิม; screenshot localhost แสดงอัศวินใหม่ในการ์ด1 in1 ไม่ทับราคา
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy; ไม่ทดสอบธุรกรรมจริง

### 38 — ภาพนิ่งในการ์ดฟรี

- วันที่: 2026-09-26; แทน GIF เดินข้อ31 ด้วยภาพนิ่ง `Downloads/โนวิดเดิน/image (36).png` ตามคำขอ
- เพิ่ม `assets/pricing-free-static.webp` 220×220px, 6,864 bytes มี alpha; Sharp resize contain220×220/WebP quality85 alphaQuality100 effort6 คง canvas และตำแหน่งเดิม ไม่แก้ต้นฉบับหรือเอาภาพเก่าออก
- `renderPricingPage` key free เปลี่ยน picture/GIF เป็น img ภาพนิ่ง; ขนาดและ CSS เดิม ไม่เปลี่ยนราคา สิทธิ์ ปุ่ม หรือการ์ดอื่น
- Cache JS ใน index: `20260926-pricing-free-static`; CSS ไม่เปลี่ยน
- ตรวจจริง: node --check ผ่าน, pricing-presentation24กรณีผ่าน, git diff --check ผ่าน (คำเตือน line ending เดิม); browser localhost โหลด src ใหม่ naturalWidth220 และ screenshot แสดงภาพในการ์ดฟรี
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy; ไม่ทดสอบธุรกรรม/backend

### 39 — จัดระเบียบหน้าแอดมิน

- วันที่: 2026-09-26; ตามภาพผู้ใช้: แยกเมนูหลัก ตัวกรอง และผลลัพธ์ โดยคงธีมและการทำงานเดิม
- `index.html` เพิ่ม `.admin-filter-card`, label ค้นหา/ช่วงเวลา และชื่อกลุ่มสถานะ; คง id/data-admin-tab เดิมทั้งหมด ไม่แก้ JS ธุรกรรมหรือสิทธิ์
- `assets/app.css` scoped `#view-admin`: เมนูไม่จำกัด560pxและไม่ตัดคำบน desktop, เส้นแยกเมนู, กล่องค้นหา/สถานะ, selected underline, กรอบสถานะว่าง/โหลด/ข้อผิดพลาดแบบเป็นกลาง; แบบฟอร์มจัดการกว้างสุด760pxและระยะสม่ำเสมอ
- <=640px เมนู/สถานะสองคอลัมน์ ช่องค้นหาและช่วงเวลาเรียงลง ปุ่มอย่างน้อย44px; รักษา hidden ไม่เพิ่ม motion
- แนวทาง ui-ux-pro-max: ใช้ลำดับตัวอักษรและระยะห่างสม่ำเสมอ พร้อม label ที่มองเห็น; ไม่เพิ่ม breadcrumbs เพราะหน้าไม่มีลำดับชั้นลึก
- Cache CSS ใน index: `20260926-polish32`; เพิ่ม preview/admin.html ใช้ CSS เดียวกันและ markup จาก index พร้อมข้อมูลสมมติ ไม่มีการโหลด admin-panel.js หรือเชื่อมระบบบัญชี
- ตรวจจริง: screenshot preview1280×720/375×800; mobile scrollWidth360 <=375, hidden panels display:none; tests/admin-layout.cjs เทียบ HEAD ยืนยัน id/tab hooks เดิมทั้งหมดและ labelใหม่ ผ่าน; node --check admin-panel.js และ git diff --check ผ่าน (คำเตือนline endingเดิม)
- ข้อจำกัด: ตรวจหน้าตัวอย่างรายการว่าง ไม่ได้ล็อกอินแอดมินหรือทดสอบอนุมัติ/เติม/หักเงินจริงและแท็บอื่นแบบ end-to-end; คำสั่งตรวจ id ครั้งแรกมีปัญหา shell quoting จึงแทนด้วยไฟล์ทดสอบที่ผ่านด้านบน
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 40 — เพิ่มตัวละครพร้อมออร่าในการ์ด 4 in 1

- วันที่: 2026-09-26; นำภาพ `Downloads/ChatGPT Image Sep 26, 2026, 02_38_07 AM.png` ใส่เฉพาะ key all ตามคำขอ
- เพิ่ม `assets/pricing-all-crown-aura.webp` จาก Sharp trim20/resize inside260×300/WebP quality85 alphaQuality100 effort6:186×300px,22,340 bytes มี alpha คงออร่าสีฟ้าและต้นฉบับ
- `renderPricingPage` เพิ่ม img ภาพนิ่ง decorative; CSS headingของall position relative/min-height94 ใช้กรอบภาพเดียวกับ3in1 สูง128px top80px ไม่แก้ราคา สิทธิ์ ปุ่ม หรือรูปของ3in1
- Cache CSS index `20260926-polish33`; JS `20260926-pricing-all-crown`
- ตรวจจริง: node --check ผ่าน, pricing-presentation24กรณีผ่าน, git diff --check ผ่านพร้อมคำเตือนline endingเดิม; browser screenshot เห็นภาพบนการ์ด4in1ข้างราคา; mobile320ตรวจรูปโหลด naturalWidth186และscrollWidth305ไม่ล้นแนวนอน (ไม่ได้จับภาพการ์ด4in1เต็มใบในmobile)
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy; ไม่ได้ทดสอบธุรกรรมจริง

### 41 — จัดภาพทั้งหกแพ็กให้ใช้กรอบและแนวเดียวกัน

- วันที่: 2026-09-26; แก้ความไม่สม่ำเสมอของขนาด/ตำแหน่งภาพตามคำขอ ต่อจากข้อ24–40
- `renderPricingPage` ย้ายภาพออกจาก heading เข้า `.pricing-media-row` คู่กับราคา; CSS ใช้สองคอลัมน์แยกกัน จึงไม่ทับราคา ทุกภาพชิดฐานล่าง/กลางกรอบเดียวกัน สูง140px desktop และ128px mobile ไม่ยืดอัตราส่วน ไม่ตัดตัวละคร
- heading ทุกแพ็กmin-height94px; mobile media row min-height144px เผื่อราคา/โปรที่ตัดบรรทัด; รักษา reduced-motion ของMorocc และภาพนิ่งของแพ็กอื่น
- เพิ่ม `assets/pricing-free-trimmed.webp`120×300px14,606bytes จากPNGผู้ใช้ด้วยSharp trim20 เพื่อตัดขอบใสส่วนเกิน แก้ตัวฟรีเล็กเกินเมื่อเทียบกรอบ (เก็บไฟล์เดิม)
- แนวทาง frontend-design ใช้โครงร่วมเพื่อจัดแนว โดยคงธีม ตัวอักษร ราคา สิทธิ์และปุ่มเดิม ไม่เพิ่มของตกแต่ง
- CSS cache index `20260926-polish34`; JS `20260926-pricing-aligned-art`
- ตรวจ: node --check และ pricing-presentation24กรณีผ่าน; diff --checkผ่านพร้อมคำเตือนเดิม; browser1280วัดกรอบทั้ง6เท่ากัน111×140px และy159pxจากขอบการ์ด;320pxกรอบ97×128pxทั้ง6 ไม่ทับราคา scrollWidth305 ไม่ล้น (เพิ่มmin-heightmobile144หลังวัดพบแถวมีโปรต่างกัน1px)
- สถานะ: ในเครื่อง ยังไม่commit/push/deploy; ไม่ทดสอบธุรกรรมbackendจริง

### 42 — ลดขนาดภาพฟรีและ 2 in 1

- วันที่: 2026-09-26; ปรับต่อจากข้อ41ตามคำขอให้ภาพสองใบเล็กลง
- `assets/app.css` selector `.pricing-card:is([data-plan-key="free"],[data-plan-key="accountItems"]) .pricing-media-row .pricing-artwork img`: width/height100% →85% ย่อ15% โดยคงกรอบเดิม กึ่งกลางแนวนอนและฐานล่าง ไม่เปลี่ยนสัดส่วน รูปอื่น ราคา หรือข้อมูล
- ใช้แนวทาง UI/UX คงพื้นที่ layout เพื่อลดภาพโดยไม่ขยับส่วนอื่น; CSS cache index `20260926-polish35`
- ตรวจ: git diff --checkผ่าน (คำเตือนline endingเดิม); browser localhost วัดscaleX/scaleY0.85เฉพาะfree/accountItems ส่วนอีก4ใบ1.00 และฐานล่างตรงกรอบทั้ง6; screenshotเห็นภาพ2in1เล็กลง
- สถานะ: ในเครื่อง ยังไม่commit/push/deploy; ไม่ทดสอบธุรกรรมbackend

### 43 — กรอบกรอกโค้ดโปรโมชันแบบใหม่

- วันที่: 2026-09-26; ผู้ใช้ต้องการช่องใส่codeที่ดูทันสมัยขึ้น คงธีมฟ้า–ม่วงเดิม
- `index.html` เพิ่ม `.promo-code-field` และ visible label ผูก `stPromoCodeInput`; ย่อ placeholderเป็น “กรอกรหัสโค้ด” เพิ่ม aria-describedbyไปยังerror และ aria-live polite; คงid/class/button type/maxlength/autocompleteเดิม
- `assets/app.css` scoped `#view-settings`: กรอบร่วมพื้นเข้ม ขอบ1px มุม12px ช่องและปุ่มสูง44px; inputตัวอักษร16px ขอบfocusชัด; errorว่างไม่กินพื้นที่และข้อความยาวตัดบรรทัดได้; mobileเต็มความกว้าง ไม่เพิ่มmotionเมื่อprefers-reduced-motion
- ใช้แนวทาง ui-ux-pro-max ผลค้นหา Input Labels/Focus States; ตรวจ hookแบบread-onlyโดยผู้ช่วยอีกagent ยืนยันไม่มีparent/sibling dependency และไม่เปลี่ยนredeem handler/สถานะbusyหรือข้อมูล
- Cache CSS index `20260926-polish36`; เพิ่ม `preview/promo-code.html` markupจากproductionแต่ไม่มีapp.js/backend ใช้ข้อความข้อมูลสมมติและจำลองerrorเท่านั้น
- ตรวจจริง: git diff --checkผ่านพร้อมคำเตือนline endingเดิม, node --check assets/app.jsผ่าน; preview1280×720และ320×800 ช่องและปุ่มสูง44px scrollWidth320เท่าหน้าจอ; screenshotfocusชัดและAXแสดงlabel/error “กรุณากรอกโค้ด” หลังคลิกปุ่มในpreview
- ข้อจำกัด: ไม่ทดสอบแลกโค้ดหรือสถานะบัญชีจริง; patchรอบแรกถูกปฏิเสธเพราะระบุindexซ้ำในชุดpatch จึงรวมรายการแล้วแก้สำเร็จ ไม่มีไฟล์เสียหาย
- สถานะ: ในเครื่อง ยังไม่commit/push/deploy

### 44 — จัดหน้า Settings ให้กระชับและอ่านง่ายขึ้น

- วันที่: 2026-09-26; ผู้ใช้อนุมัติปรับจากภาพหน้า Settings: จัดแนวการ์ด/ปุ่ม แยกข้อมูลบัญชี ทำสถานะเลือกเซิร์ฟเวอร์และประวัติให้ชัด โดยคงธีมเดิม
- `index.html` เพิ่ม class `.settings-profile` และ `.settings-history` บนการ์ดเดิม; คง IDs, class tokens, data hooks, labels, hidden/read-only/disabled และโครงสร้างที่ handler ใช้ ไม่แก้ JavaScript ของ Settings
- `assets/app.css` บล็อก “Settings polish” scoped `#view-settings`: การ์ดข้อมูลบัญชีและความปลอดภัยยืดสูงเท่ากัน ปุ่มอยู่ฐานเดียวกัน; ข้อมูลอ่านอย่างเดียวรวมในแถบพื้นเข้มอ่อน; ระยะการ์ด/ฟอร์มสม่ำเสมอ
- ปุ่มเลือกเซิร์ฟเวอร์จากชิปเล็กเป็นพื้นที่กดสูงอย่างน้อย44px ช่องไฟ8px สถานะเลือกมีสี/ขอบชัดและคงเครื่องหมายถูก; ลดความเด่นการ์ดเซิร์ฟเวอร์เก่า; ประวัติแยกหัวข้อ วันเวลา ยอด และสถานะ แท็บ4คอลัมน์บนคอม/2คอลัมน์บนมือถือ ข้อความยาวตัดบรรทัดได้
- ใช้แนวทาง ui-ux-pro-max เรื่องพื้นที่กด ระยะห่าง และ text reflow; ไม่เปลี่ยนข้อมูลบัญชี รหัสผ่าน การเลือกเซิร์ฟเวอร์จริง ระบบบันทึก หรือธุรกรรม
- เพิ่ม `preview/settings.html` ดึง markup จาก index พร้อมข้อมูลบัญชี/เซิร์ฟเวอร์/ประวัติสมมติ; ไม่มี app.js/backend ปุ่มบันทึกไม่ส่งข้อมูล มีเพียงการสลับแท็บและเซิร์ฟเวอร์จำลองสำหรับตรวจ UI
- เพิ่ม `tests/settings-layout.cjs`: ทดสอบผ่านโดยส่ง `git show HEAD:index.html` ทาง stdin ยืนยัน50 IDs,4 history tab mappings, class/attributes/labels/hidden เดิม; `git show HEAD:assets/app.js | node tests/settings-layout.cjs --check-js` ผ่าน ยืนยันส่วน business code ของ Settings ไม่เปลี่ยน
- ตรวจจริง: node --check ของ app.js และไฟล์ทดสอบผ่าน; git diff --check ผ่าน มีคำเตือน LF/CRLF เดิม; preview1280×1050 วัดการ์ดบัญชี/ความปลอดภัยสูง417.19pxเท่ากัน ปุ่มสูง44pxและฐานตรงกัน; screenshot375×850และตรวจ320×800ไม่มีช่องกรอก/ปุ่มล้นแนวนอน (scrollWidth360และ305ตามลำดับ)
- ตรวจ preview: hidden elements ยัง display:none, server chips สูง44px, selected/disabled ชัด, สลับแท็บซื้อแพ็ก/โค้ด/เติมแต้มและเลือกเซิร์ฟเวอร์สมมติได้; คืน viewport1280×720 หลังตรวจ
- Cache CSS index และ preview/settings, preview/promo-code: `20260926-polish37` ต่อจากข้อ43; JS cacheไม่เปลี่ยน
- ข้อจำกัด: ทดสอบ UI/interaction ด้วยข้อมูลสมมติและ source checks ไม่ได้เปลี่ยนรหัสผ่าน บันทึกบัญชี/เซิร์ฟเวอร์จริง หรือทดสอบ backend end-to-end
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 45 — ปรับแดชบอร์ดภาพรวมแอดมินให้อ่านง่ายและกระชับ

- วันที่: 2026-09-26; ผู้ใช้อนุมัติข้อเสนอจากภาพ dashboard: เพิ่มความอ่านง่าย เน้นตัวเลขหลัก ย่อการ์ดแพ็กเกจ แยกช่วงเวลา และนำสรุปข้อผิดพลาดขึ้นมาเห็นเร็ว
- แก้หน้า `admin.html` (แดชบอร์ดภาพรวมแยกไฟล์ ไม่ใช่แท็บจัดการเติมเงินข้อ39): CSS inline เปลี่ยน `.card-title`, `.kpi-label`, `th` จากตัวอักษร mono เล็ก/เว้นห่างเป็นฟอนต์ UI หัวข้อประมาณ15px; เพิ่มขนาดข้อความรองและ tick กราฟ10→12px คงตัวเลขหลักแบบ mono และธีมกรมท่าเดิม
- ปรับ token `--text-mute` จาก #7f8ca3→#9baac1; คำนวณ contrast ของข้อความรองกับพื้นทั้งสามระดับได้อย่างน้อย5.96:1; ปุ่มช่วงเวลา/รีเฟรชสูงอย่างน้อย44px; KPI แต่ละใบสูงเท่ากันและรายละเอียดอยู่ฐานเดียวกัน
- `.plan-head` วางชื่อและจำนวนคนในแถวเดียว ยอมตัดแถวเมื่อข้อความ/ตัวเลขยาว; `.plan-meta` ย่อข้อมูลขาย/แต้มเป็นแถวกระชับ เก็บทั้ง5แพ็กและแถบสัดส่วนเดิม; `renderPlans` เปลี่ยนคำ “ว่าง” เป็น “ยังไม่มีผู้ใช้งาน” โดยไม่เปลี่ยนการรวมยอด
- หัวข้อแพ็กเกจแยกป้าย “ผู้ใช้งาน · ตอนนี้” และ `#plansNote` “ยอดขาย · N วันล่าสุด”; ย้ายคำอธิบายการนับ4in1ไปบรรทัดหมายเหตุ ไม่เปลี่ยนช่วงเวลาเริ่มต้นหรือความหมาย KPI
- เพิ่ม `#errorSummary` ใต้ KPI พร้อมยอด/ช่วงเวลาและลิงก์ไป `#dashboardErrors`; `renderDevicesErrors` ใช้ยอดและสถานะเดียวกับ `#errorsTotal` ไม่คำนวณแยก; `renderTraffic` ซ่อนสรุปเมื่อข้อมูลไม่มีหรือโหลดไม่สำเร็จเพื่อไม่แสดงยอดเก่าค้าง; รักษาข้อความผิดพลาดและ hidden ของส่วนเดิม
- แนวทาง ui-ux-pro-max เรื่อง readability/contrast ช่วยกำหนดลำดับหัวข้อและข้อความรอง; ไม่เพิ่มภาพตกแต่งหรือ motion ไม่เปลี่ยน authentication/RPC/สูตรคำนวณ/การชำระเงิน
- เพิ่ม `preview/dashboard.html`: โหลดเฉพาะ markup/styles และช่วงฟังก์ชันแสดงผลจากหน้า production; ข้อมูลสมมติ3สถานะ มีข้อมูล/ศูนย์/การเข้าชมไม่พร้อมใช้งาน พร้อมเลือกช่วงเวลาและรีเฟรชจำลอง; ไม่โหลด Supabase ไม่อ่านบัญชีหรือ storage ไม่มีการเรียก backend ปิดลิงก์ออกนอก preview และใช้ CSP จำกัดการเชื่อมต่อ
- เพิ่ม `tests/dashboard-presentation.cjs`; `git show HEAD:admin.html | node tests/dashboard-presentation.cjs` ผ่าน21กรณี:53 IDs/ช่วงเวลาเดิม ยอดแพ็กที่มี keys ซ้ำ ข้อมูลกราฟ การตรวจสิทธิ์ โหลด/รีเฟรช/ผิดพลาด สรุปยอด error ตรงกันและซ่อนเมื่อข้อมูลไม่พร้อม; dependencies และ RPC เป็น mock ทั้งหมด
- ตรวจจริง: inline JS syntax ทั้ง admin/preview และ syntax ไฟล์ทดสอบผ่าน; admin-layout test เทียบ HEAD:index ผ่าน; git diff --check ผ่านพร้อมคำเตือน LF/CRLF เดิม
- Browser preview1280×1000/1280×900: หัวข้อ15.04px การ์ดแพ็กทั้ง5สูง114px; ลิงก์สรุปไปตาราง error โดยหัวข้อไม่ถูก topbar บัง ยอดสรุป/ตารางตรงกัน19ครั้ง; ตรวจ375×850และ320×800 scrollWidth360/305 ไม่ล้น viewport การ์ดไม่เลยจอ hidden ยัง display:none และปุ่มช่วงเวลา/รีเฟรช44px
- ตรวจ preview ช่วง7/30วัน ป้ายยอดขาย/error เปลี่ยนตามกัน; สถานะศูนย์แสดง0และข้อความว่างถูกต้อง; สถานะการเข้าชมไม่พร้อมซ่อน summary/body/details แต่ dashboard ส่วนอื่นยังแสดง; คืน viewport ค่าเริ่มต้นและเก็บแท็บตัวอย่างไว้
- Cache: CSS/JS ของหน้านี้เป็น inline ไม่เปลี่ยน app.css/app.js version; เพิ่ม query `admin.html?v=20260926-dashboard-polish1` ที่ลิงก์ใน index และ fetch ของ preview
- ข้อจำกัด: ทดสอบหน้าตัวอย่างและ source/VM regression ไม่ได้ล็อกอินแอดมินหรือทดสอบ RPC กับฐานข้อมูลจริง ไม่ได้ตรวจทุกขนาดจอ/ระดับซูม
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 46 — เปลี่ยนรูปการ์ด 1 in 1 เป็นอัศวินขี่นก

- วันที่: 2026-09-26; ตามรูปใหม่ `Downloads/ChatGPT Image Sep 26, 2026, 03_08_42 AM.png` แทนรูปอัศวินถือหอกข้อ37 เฉพาะแพ็ก farm (1 in 1)
- เพิ่ม `assets/pricing-farm-mounted-knight.webp` จาก PNG1089×1444px ขนาด1,108,974bytes ด้วย Sharp trim threshold0/resize inside260×300/WebP quality88 alphaQuality100 effort6; ผล211×300px 26,318bytes มี alpha ไม่วาดภาพใหม่ ไม่แก้ต้นฉบับ และเก็บรูปเก่าไว้
- `assets/app.js` ใน `renderPricingPage` เปลี่ยนเฉพาะ src และ intrinsic width/height ของรูป farm; คง class, alt/aria-hidden และ shared frame ของข้อ41–42 ไม่เปลี่ยน CSS ราคา สิทธิ์ ปุ่ม หรือภาพแพ็กอื่น
- ตรวจแนวทาง ui-ux-pro-max; ผลค้นหาเรื่องขนาดภาพไม่ตรงประเด็นหลังลองเจาะจงแล้ว จึงใช้หลักทั่วไปและโครงเดิมของโปรเจกต์: สำรองพื้นที่ภาพ คงสัดส่วนด้วย contain และชิดฐานเดิม
- Cache JS ใน index: `20260926-pricing-mounted-knight`; CSS versionไม่เปลี่ยน ไม่มี preview ที่อ้าง app.js ต้องแก้เพิ่ม
- ตรวจจริง: node --check app.js ผ่าน; pricing-presentation24กรณีผ่านหลังแก้ (monthly/yearly/promo/ownership/disclosure); git diff --check ผ่านพร้อมคำเตือน LF/CRLF เดิม; เปิดดู WebP แล้วเห็นตัวละครครบพร้อมพื้นหลังใส
- Browser localhost/#pricing สถานะ guest: screenshot1280×900 เห็นรูปใหม่ใน1in1 กรอบ111.06×140px ไม่ทับราคา; DOM ที่320×800 ยืนยันรูปโหลด natural211×300 กรอบ97.19×128px contain อยู่ในการ์ด ไม่ทับราคา scrollWidth305ไม่ล้น; คืน viewportค่าเริ่มต้น
- ข้อจำกัด: ตรวจหน้าแพ็กเกจในเครื่องและ regression แบบจำลอง ไม่ได้ซื้อแพ็กเกจหรือทดสอบธุรกรรม/backendจริง
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 47 — ย่อช่องกรอกซื้อ–ขายเป็น mini แบบต้นทุนต่อกั้ม

- วันที่: 2026-09-26; ตามคำขอให้ช่องกรอกฟอร์มรายการซื้อ–ขายกระชับเหมือนต้นทุนต่อกั้ม
- `assets/app.css`: เพิ่มกฎเฉพาะ `#view-home #mrEntryPanel .mr-item-row input/select` เมื่อ viewport ตั้งแต่761pxและ pointer:fine; ความสูงขั้นต่ำ46→36px, padding .65rem .75rem→6px 8px, font16→13.6px เทียบกับขนาดช่องใน `.panel-farm-cost`; ลด gap ของ `.mr-item-row-main` เป็น .5rem และ `.mr-entry-field` เป็น .25rem
- คงขนาดมือถือ/จอสัมผัสเดิมตามแนวทาง ui-ux-pro-max; ไม่เปลี่ยน JavaScript การคำนวณ ปุ่มบันทึก hooks หรือสถานะ hidden/disabled/read-only
- `preview/merchant.html`: เปลี่ยน fixture เป็นไอเทมและชื่อ/จำนวน/ราคาต่อชิ้นตามภาพผู้ใช้ เป็นข้อมูลสมมติไม่มี app.js/backend ปุ่มไม่บันทึกข้อมูลจริง
- Cache CSS ใน index และ preview/merchant เปลี่ยนเป็น `20260926-polish38`; JS versionไม่เปลี่ยน
- ตรวจจริง: preview1280×900 ช่องทั้ง4สูง36px/font13.6px, hidden suggestion ยัง display:none และปุ่มลบยัง disabled; screenshot375×850 ช่องสูง46–46.78px/font16px; ตรวจ320×800 scrollWidth305 และ375px scrollWidth360 ไม่มีแนวนอนล้น; คืน viewportค่าเริ่มต้นหลังตรวจ; git diff --check ผ่านพร้อมคำเตือน LF/CRLF เดิม
- ข้อจำกัด: ตรวจด้วยหน้าตัวอย่างในเครื่อง ไม่ได้บันทึกรายการซื้อ–ขายจริงหรือทดสอบ backend
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 48 — แยกสีประวัติซื้อ–ขายและจัดคอลัมน์คงเหลือ/กำไร

- วันที่: 2026-09-26; ผู้ใช้อนุมัติปรับสี และเพิ่มการจัดคงเหลือ/กำไรให้ตรงกันพร้อมลดป้าย Item/กรอบซ้อน ไม่อนุมัติเปลี่ยนการแบ่งหน้าหรือแยกออฟเป็นบรรทัดใหม่ จึงคงส่วนเหล่านั้นไว้; ต่อจากงานประวัติ/หมวดและแถว compact เดิมข้อ12–15
- `assets/app.css`: เพิ่ม tokens เฉพาะ `.panel:has(#mrHistoryList)` พื้นนอกเป็น #121a26 แทน gradient กรมท่า; แถวใช้งาน #1a263b→#253247, Zeny #1b304a→#233c52, หมวดขายหมดแล้ว #152135→#181c24 และแถวภายใน #19263a→#242a34; ข้อความรองเปลี่ยนเป็นเทาอ่อน #bac1cc คงสีซื้อ/ขาย/กำไร/ขาดทุนและโครงสร้างข้อมูลเดิม
- ลดกรอบซ้อนด้วย border-transparent ของ `.mr-it-group-wrap` และกรอบไอคอนรูป โดยคงพื้นที่1px/รัศมี/พื้นที่กดเดิม; ลดเส้นขอบพื้นนอกและเอาเงากรอบซ้อนออก ไม่ลบขอบการ์ดรายการหรือ focus/hover/open states
- แถว compact ใช้ grid หัวการ์ด20px/ชื่อยืดหยุ่น/metrics15.5rem; `.mr-compact-metrics` เป็นสองคอลัมน์กว้างเท่ากัน ใช้ตัวเลข tabular และชิดขวา; แถว New แยกตำแหน่งจาก metrics ไม่ดันคอลัมน์; จอแคบตาม container เดิม520px ย้าย metrics ลงใต้ชื่อ และที่440px วาง label เหนือตัวเลขเพื่อรองรับยอดยาว ไม่ซ่อนหรือย่อตัวเลข
- `assets/app.js` เปลี่ยนเฉพาะ markup ใน `historyItemRowHtml`: เพิ่ม `.mr-compact-remaining`/`.mr-compact-profit`, เปลี่ยน label ย่อเป็น “คงเหลือ”; ไม่สร้างป้าย Item ในหมวดไอเทมและคง `.mr-it-tags` wrapper พร้อม hidden; ไม่แตะป้าย M/อื่น ๆ/เซิร์ฟเวอร์ รูปภาพ New warnings สูตรจำนวน/ต้นทุน/กำไร การพับรายการ หรือ paging
- `preview/history.html`: อัปเดตให้ใช้พื้น panel แบบเดียวกับ production และแถว/ป้าย/คอลัมน์ใหม่; ข้อมูลสมมติ3ไอเทมพร้อมกำไรบวก/ลบ/ยังไม่ขายและขายหมดแล้ว; มี checkbox ทดสอบตัวเลขระดับพันล้าน/ป้าย New เฉพาะ preview ไม่มี app.js/backend หรือการบันทึกบัญชีจริง
- ใช้แนวทาง ui-ux-pro-max เรื่อง Color Contrast/Contrast Readability; คำนวณคอนทราสต์จาก6สีข้อความหลัก/รอง/สถานะกับ6สีการ์ดปกติ/hover รวม36คู่ ค่าต่ำสุด5.12:1 (ไม่ใช่การรับรองทุก element ทั้งหน้า)
- เพิ่ม `tests/history-readability.cjs` โดยผู้ช่วย; รันผ่านหลังปรับ expectation ให้ตรงกับ label spans: production renderer + fixtures ยืนยันตัวเลข สถานะกำไร warning/New/server/image/disclosure hooks การเอาออกเฉพาะ Item counts ยอด sold รวมและ paging; `history-pagination.cjs`, `history-categories.cjs`, `history-new-badges.cjs` ผ่าน; node syntax ของ app.js/ไฟล์ทดสอบ/inline preview ผ่าน; git diff --check ผ่านพร้อมคำเตือน LF/CRLF เดิม
- Browser preview desktop1280px: แถวไอเทมทั้ง3มี metricsกว้าง248px, คงเหลือ x676.5/กำไร x808.5 ตรงกัน แม้ชื่อ/ตัวเลขยาว; ภาพ375×850และตรวจ320×800ไม่มีแนวนอนล้น (scrollWidth360/305); ทดสอบยอด1,234,567,890และNewไม่มี metrics/name overflow; hiddenยังdisplay:none; เปิดรายละเอียดแล้วaria-expanded=true/bodyแสดงและcompactซ่อน; หมวดขายหมดแล้วเปิดได้และสีแยกจากแถวใช้งาน; คืน viewportค่าเริ่มต้น/ค่าตัวเลขปกติแล้ว
- Cache: CSS index และ preview/history เป็น `20260926-polish39`; JS index เป็น `20260926-history-readability`
- ข้อจำกัด: ทดสอบ UI ในหน้าตัวอย่างและ renderer แบบจำลอง ไม่ได้บันทึกซื้อ–ขายหรือทดสอบ backend/บัญชีจริง และไม่ได้ทดสอบทุกระดับซูม
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 49 — ย้ายรายละเอียด Slot ลงใต้ชื่อไอเทม

- วันที่: 2026-09-26; ผู้ใช้ขอให้ Slot เริ่มอีกบรรทัด แทนการต่อท้ายชื่อ จึงต่อยอด/แทนที่ข้อ48เฉพาะการจัดบรรทัด Slot
- `assets/app.css` scoped `#view-home #mrHistoryList .mr-it-name`: `.mr-item-slots-inline` จาก inline เป็น block พร้อมช่องไฟ .1rem และสีข้อความรองเดิม; จัดชื่อกับไอคอนด้วย flex ทั้งกรณีมี `.item-img-hover` และไม่มีรูป ให้ Slot ชิดแนวเริ่มชื่อและตัดบรรทัดได้ด้วย min-width:0/overflow-wrap:anywhere ตามแนวทาง UI/UX Long Token Wrapping
- ไม่แก้ `itemNameWithSlots`, app.js, ข้อมูล Slot, ชื่อไอเทมในหน้าอื่น หรือคอลัมน์คงเหลือ/กำไรเดิม; คง hooks รูปภาพและการเปิดรายละเอียด ผู้ช่วยตรวจ selector แบบ read-only ยืนยันครอบคลุมโครงทั้งมีรูป/ไม่มีรูปและไม่กระทบหน้าคลัง
- `preview/history.html`: เพิ่ม markup Slot จริงแบบเดียวกับ helper ในแถวสมมติทั้งมีรูป/ไม่มีรูป สำหรับตรวจตำแหน่ง ไม่เชื่อม backend หรือบันทึกข้อมูลจริง
- Cache CSS index และ preview/history `20260926-polish40`; JS versionไม่เปลี่ยน
- ตรวจจริง: preview desktop1280px screenshot ยืนยัน Slot อยู่ใต้ชื่อ/ชิดซ้ายเดียวกันทั้งสองกรณี และคอลัมน์คงเหลือ x676.5/กำไร x808.5 ของทั้งสามแถวยังตรงกัน; ที่320×800 Slot ทั้งสองแบบยังอยู่ใต้ชื่อและไม่ล้น scrollWidth305; คืน viewportค่าเริ่มต้นแล้ว
- ตรวจ inline preview syntax, tests/history-readability.cjs และ git diff --check ผ่าน (คำเตือน LF/CRLF เดิม); ไม่ได้ทดสอบธุรกรรมหรือ backend จริง
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 50 — บัญชีหมดอายุเปลี่ยนหน้าประวัติซื้อ–ขายได้

- วันที่: 2026-09-26; พบจากการตรวจรวมก่อน commit (แก้ต่อจากข้อ12)
- ปัญหา: ปุ่มก่อนหน้า/ถัดไปและตัวเลือก “ต่อหน้า” ของ `.mr-history-pager` ไม่อยู่ใน `RO_ALLOW` ใน `assets/app.js` ตัวดัก click/change/mousedown ของบัญชีหมดอายุจึงบล็อก บัญชีหมดอายุที่มีเกิน 10 รายการเห็นแค่หน้าแรก ขณะที่ก่อนมีการแบ่งหน้าเคยเห็นครบ
- แก้: เพิ่ม `'.mr-history-pager'` ใน `RO_ALLOW` บรรทัดเดียวกับ `#mrItSoldToggle`/`.mr-ic-head` (เป็นการดูอย่างเดียว ไม่เปลี่ยนข้อมูล)
- Cache JS ใน index: `20260926-ro-pager`; CSS ไม่เปลี่ยน
- ตรวจ: node --check ผ่าน, tests/history-pagination.cjs และ history-readability.cjs ผ่าน; ยังไม่ได้ทดสอบด้วยบัญชีหมดอายุจริง
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 51 — ไฟล์ที่เก็บไว้เฉพาะในเครื่อง ไม่ขึ้นเว็บ

- วันที่: 2026-09-26; ผู้ใช้อนุมัติให้ไม่รวมไฟล์ที่ไม่ได้ใช้/ไม่ควรเป็นลิงก์สาธารณะไว้ใน commit (GitHub Pages เผยแพร่ทุกไฟล์ใน repository)
- ใส่ไว้ใน `.git/info/exclude` (ตัวกรองเฉพาะเครื่องนี้ ไม่แก้ `.gitignore`): `preview/`, `docs/`, `scripts/` และรูปรุ่นก่อนที่โค้ดไม่เรียกแล้ว 12 ไฟล์ — `pricing-farm-archer-static.webp`, `pricing-farm-knight-static.webp`, `pricing-free-static.webp`, `pricing-knight-battle(.gif/-still.webp)`, `pricing-merchant-static.webp`, `pricing-merchant-sway(.gif/-still.webp)`, `pricing-morocc(.webp/-still.webp)`, `pricing-novice-walk(.gif/-still.webp)`
- ไฟล์ทั้งหมดยังอยู่ในโฟลเดอร์ Gum100UI ไม่ได้ลบ; คนที่ clone จาก GitHub จะไม่มีหน้า preview ที่อ้างถึงในเอกสารนี้
- ตรวจ: รูปใหม่ที่เหลือใน commit ถูกเรียกใช้จาก index/app.js/app.css ครบทุกไฟล์; tests ไม่พึ่งโฟลเดอร์ที่กันออก

### 52 — ทดสอบจริงหลังล็อกอิน (บัญชีทดสอบ ClaudeTest, role admin)

- วันที่: 2026-09-26; เว็บในเครื่อง localhost:4173 ต่อ Supabase จริง ผู้ใช้ล็อกอินเอง (ปิด captcha ชั่วคราว) ไม่มีการแก้โค้ดในชุดนี้
- บัญชีนักลงทุน: บันทึกซื้อ M 100 × 10 และซื้อไอเทม 11 แถวในรายการเดียว (TEST-01…11 ยอด 2,310 ถูก) ขาย TEST-01 แบบพิมพ์ชื่อ 2 × 150; ยอดสรุป/กราฟถูก (−3,310 → −3,010), กำไรรวมขายหมดแล้ว +100 ถูก
- แบ่งหน้า: 1–10 จาก 11 → ถัดไป 11–11 หน้า 2/2 ปุ่มถัดไป disabled; เปลี่ยน 20 ต่อหน้าแสดง 1–11 และ focus อยู่ที่ select; กลุ่มขายหมดแล้วมี pager แยก; ไม่มีล้นแนวนอน
- New: เปิดการ์ด TEST-11 ป้ายการ์ดหายแต่ป้ายวันยังอยู่; เปิดหัวขายหมดแล้ว ป้ายหัวหายแต่การ์ด TEST-01 ยังมี; reload แล้วสถานะทั้งสามคงเดิม (ขนาดหน้ากลับเป็น 10 เพราะจำเฉพาะ session ตามที่ออกแบบ)
- หลังลบรายการซื้อ แถวสรุป TEST-01 แสดงคำเตือน “ขายเกินที่ซื้อ 2 ชิ้น” ถูกต้อง
- ยอดนักฟาม: label ของเรท/แผนที่ผูกช่องถูก; บันทึกยอด 500,000 − ทุน 100,000 = 400,000 z ≈ 4 บ ที่เรท 10 ถูก; เข้าโหมดแก้ไขแล้วยกเลิกได้
- จับเวลาบอส: ภาพปาร์ตี้โหลด ข้อความ “สมาชิกในปาร์ตี้ 1 คน” อัปเดต; ปุ่มจัดการปาร์ตี้เปิด/ปิดได้; การ์ดสรุปสี่ใบปกติ
- แพ็กเกจ: หกการ์ดสูงเท่ากัน รูปโหลดครบ สถานะ “ใช้งานอยู่ (ไม่จำกัดเวลา)” ของแอดมินแสดง (ไม่ได้กดซื้อ/ต่ออายุ)
- ตั้งค่า: กดใช้โค้ดว่างแสดง “กรุณากรอกโค้ด”; สลับแท็บประวัติได้ทั้งสี่; ไม่ได้บันทึกข้อมูลบัญชี/รหัสผ่าน/เซิร์ฟเวอร์
- แอดมิน: ช่องค้นหา/ช่วงเวลา/ชิปสถานะกรองได้ รายการแสดงปกติ (ไม่ได้กดยืนยัน/ปิด/เติม/หักแต้ม); แดชบอร์ด admin.html สรุปข้อผิดพลาดตรงกับตาราง (6 ครั้ง) และป้ายช่วงเวลาเปลี่ยนตาม 7/30 วัน
- ข้อความ “บันทึกขึ้นคลาวด์ไม่ได้” ครั้งหนึ่งหลังล็อกอินเกิดจาก PGRST303 JWT issued at future (นาฬิกาเซิร์ฟเวอร์) ระบบส่งซ้ำสำเร็จเองภายในไม่กี่วินาที ไม่เกี่ยวกับโค้ดชุดนี้
- พบพฤติกรรมเดิม (ไม่ได้มาจากงานนี้): หลังลบรายการซื้อ M ช่อง “คงเหลือตอนนี้” ในฟอร์มยังแสดงค่าก่อนลบจนกว่าจะ render ใหม่ ข้อมูลจริงถูกต้อง
- ยังไม่ได้ทดสอบ: บัญชีหมดอายุจริง (ข้อ50), รูปย่อไอเทมจากที่เก็บรูปจริง (ไม่ได้แนบรูป), การซื้อแพ็กเกจ
- ล้างข้อมูลทดสอบแล้ว: ลบรายการซื้อ–ขายทั้งสามและยอดฟามผ่านปุ่มลบในเว็บ คืนค่าเรท/แผนที่/แถวต้นทุนเป็นว่าง reload ยืนยันว่าไม่เหลือ

### 53 — ทดสอบบัญชีฟรี/หมดอายุ รูปย่อจริง และการซื้อแพ็กเกจ (บัญชี test)

- วันที่: 2026-09-26; ผู้ใช้สมัครบัญชี test (role user) และเติมแต้ม 1,000 ให้ ล็อกอินเอง
- รูปย่อไอเทม: บันทึกซื้อ TEST-IMG แนบรูป PNG ทดสอบ → รูปย่อขึ้นในประวัติ; reload แล้วโหลดจาก Storage ผ่าน signed URL (`/storage/v1/object/sign/item-images/…`) ขนาด 26×26 และกดเปิด lightbox ได้
- บัญชีหมดอายุ (ผู้ใช้รัน SQL ตั้ง expires_at ของ test ให้ผ่านไปแล้ว): ป้าย/หน้าต่างหมดอายุขึ้น; คลิกจริงปุ่ม “ถัดไป” ได้ 11–12 จาก 12 ไม่มี toast บล็อก; เปลี่ยน “ต่อหน้า” ด้วยคีย์บอร์ดได้ (ข้อ50 ยืนยันแล้ว) — dropdown ของเบราว์เซอร์ทดสอบคลิกเลือกด้วยเมาส์ไม่ได้ คลิกนั้นทะลุไปโดนพื้นหลังจึงขึ้น toast ไม่ใช่บั๊ก
- ซื้อแพ็กเกจ: จับเวลาบอส 99 แต้มสำเร็จ (1,000 → 901, ใช้งานถึง 26 ต.ค. 2569); **1 in 1 และ 2 in 1 ล้มเหลว “แพ็กเกจไม่ถูกต้อง”** แต้มไม่ถูกหัก — ไม่เกี่ยวกับงาน UI (โค้ดซื้อใน app.js ไม่ได้แก้)
- ต้นเหตุ: pg_get_functiondef ของ buy_plan ในฐานข้อมูลจริงเป็นเวอร์ชันเก่ายุคแรก (bundle/timers เท่านั้น ราคาตายตัว ไม่เช็ค promo_active ไม่บันทึก package_purchases) ไม่ตรงกับ repo (hardening_round2) → 4 in 1 ก็ซื้อไม่ได้ และหลังโปรหมดจะยังหักราคาโปร
- เตรียม `supabase/migrations/20260926000100_restore_buy_plan.sql` (คัดลอกฟังก์ชันจาก hardening_round2 ตรงตัว + สิทธิ์ authenticated เท่านั้น) และ SQL ตรวจก่อนรัน; ยังไม่ได้รัน — ผู้ใช้เป็นคนรัน
- สถานะ: ในเครื่อง ยังไม่ commit/push/deploy

### 54 — รันตัวแก้ buy_plan แล้ว และทดสอบซื้อซ้ำ

- วันที่: 2026-09-26; ผู้ใช้รัน precheck (promo_active/is_active มี, package_purchases 8 คอลัมน์, entitlements 3 คอลัมน์ + unique, anon ไม่มีสิทธิ์) ผ่าน แล้วรัน `20260926000100_restore_buy_plan.sql`; ผลตรวจ knows_farm/knows_all/uses_promo/logs_purchase/auth_exec = true, anon_exec = false
- บัญชี test: 1 in 1 สำเร็จ (901 → 802) และ 2 in 1 สำเร็จ (802 → 653) การ์ดขึ้น “ใช้งานอยู่ ถึง 26 ต.ค. 2569”; หน้าตั้งค่า “ประวัติการซื้อแพ็กเกจ” แสดงทั้งสองรายการ (แพ็กจับเวลาบอสที่ซื้อก่อนแก้ไม่มีประวัติ เพราะฟังก์ชันเก่าไม่บันทึก)
- คืน expires_at ของ test เป็น 2099-12-31 แล้ว (ผู้ใช้รัน) ป้ายหมดอายุหายหลัง reload
- ล้างข้อมูลทดสอบ: ลบรายการซื้อ TEST-IMG และ TEST-01…11 ผ่านปุ่มลบในเว็บ reload แล้วประวัติว่าง คลัง 0; แพ็กที่ซื้อทดสอบและแต้มคงเหลือ 653 ยังอยู่ในบัญชี test
- สถานะ: ฐานข้อมูลจริงแก้แล้ว (มีผลกับเว็บจริงทันที); ไฟล์ migration และโค้ดยังไม่ commit/push/deploy

### 55 — ปิดงาน UI และเลิกใช้กติกาบันทึก

- วันที่: 2026-09-26; ข้อ 01–54 รวมเข้า main ที่ `ee0913f` และขึ้นเว็บจริงแล้ว (ตรวจ gum100.com โหลด CSS `20260926-polish40` / JS `20260926-ro-pager`); ผู้ใช้แจ้งว่าไม่แก้ UI ต่อ
- ตามคำสั่งผู้ใช้: ลบ `AGENTS.md` (กติกาให้ผู้ช่วยเขียนโค้ดอัปเดตเอกสารนี้ทุกครั้ง) และแก้หัวข้อใน `README.md` ให้ชี้มาที่เอกสารนี้ในฐานะประวัติ
- หลังจากนี้ไม่อัปเดตเอกสารนี้แล้ว งานใหม่ดูจากข้อความ commit; ส่วน “วิธีเพิ่มบันทึกครั้งต่อไป” ด้านล่างเก็บไว้เป็นประวัติเท่านั้น
- ไม่มีการเปลี่ยนโค้ดเว็บหรือฐานข้อมูลในข้อนี้

## วิธีเพิ่มบันทึกครั้งต่อไป

เพิ่มรายการต่อจากหมายเลขล่าสุดทันทีหลังจบการแก้แต่ละชุด ก่อนแจ้งผู้ใช้ว่างานเสร็จ ไม่ลบประวัติเก่า หากแทนที่ดีไซน์ก่อนหน้าให้บอกหมายเลขที่แทนที่

```markdown
### NN — ชื่อการเปลี่ยนแปลง

- วันที่: YYYY-MM-DD
- คำขอ/เหตุผล:
- ไฟล์และจุดค้นหา: path, selector หรือชื่อฟังก์ชัน
- ก่อน → หลัง:
- ผลต่อพฤติกรรม/ข้อมูล/สถานะเดิม:
- การตรวจ: คำสั่ง ผล และขนาดจอที่ตรวจจริง
- ยังไม่ได้ตรวจ/ข้อจำกัด:
- เวอร์ชัน cache (ถ้ามี):
- สถานะ: ในเครื่อง / commit / push / deploy (ระบุเฉพาะที่ทำจริง)
```
