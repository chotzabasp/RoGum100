---
name: web-import
description: Use when the student has exported a zip file from Claude Design (claude.ai/design) and needs to bring those files into the project with proper folder structure triggers include "import zip", "วาง zip", "เอา zip มาใส่", "ใส่ไฟล์จาก Claude Design", "web-import", or any similar request after the student exports from Claude Design. Extracts zip places HTML at root organizes assets into proper folders updates script paths and creates a clean scalable project structure ready for Cloudflare Pages deployment. The student drops the zip file into the chat (drag-drop or @ reference) the skill handles the rest. Built for absolute beginners works on both Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-import วาง zip จาก Claude Design เข้า project

ช่วยนักเรียนเอาไฟล์ zip ที่ได้จาก claude.ai/design มาวางใน project ด้วยโครงสร้างที่ถูกต้อง พร้อม deploy ขึ้น Cloudflare Pages

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

ใช้ space เป็นตัวคั่นหลัก line break เบรกหนัก full stop จบประโยค

---

## กฎหลักอื่นๆ

- **ภาษาไทยเรียบง่าย** student ไม่เคย deploy web มาก่อน
- **ห้ามให้ student เห็น error** แก้เองก่อนเสมอ
- **Cross-platform** ทำงานได้ทั้ง Windows (PowerShell) และ macOS (Bash)
- **Best practice structure** วางไฟล์ให้เป็น standard static site
- **อย่าทับไฟล์ที่มีอยู่โดยไม่ถาม** ถ้าเจอ index.html อยู่แล้ว ถามก่อนเสมอ

---

## กฎเด็ดขาด end-of-skill behavior

**Skill นี้ MUST จบด้วยการ auto-invoke `web-finish` เสมอ** (เหมือน Step 11 ที่ auto-invoke web-images)

web-finish จะเก็บงานภาษาไทย + mobile ให้อัตโนมัติ แล้วเป็นคนแสดง link localhost + ถามค่าจริง student จึงเห็นหน้าเว็บที่เก็บงานแล้ว ไม่ใช่หน้าเว็บดิบที่สระทับกัน

### ห้าม

- ❌ ใช้ Claude Code built-in preview sidebar (`mcp__Claude_Preview__*` tools)
- ❌ ใช้ tool ที่ render เว็บใน sidebar ของ Claude Code
- ❌ จบ skill โดยให้ student พิมพ์คำสั่งเองเพื่อดู preview หรือเพื่อเก็บงาน
- ❌ แสดง link localhost เองแล้วจบ โดยไม่ได้เรียก web-finish

### ที่ถูกต้อง

- ✅ extract เสร็จ spin server (Step 12) แล้ว **เรียก web-finish ทันทีไม่ต้องรอ student ขอ**
- ✅ web-finish reuse server ตัวเดิม (share pid/port) แล้วแสดง 👉 http://localhost:[PORT] ให้เอง
- ✅ Student คลิก link เปิดใน browser ของเขาเอง (Chrome Safari Firefox)

**ทำไม** student ต้องเรียนรู้การเปิด localhost ใน browser จริง ไม่ใช่ sidebar ของ Claude Code
production deploy บน Cloudflare Pages = browser จริงเท่านั้น และหน้าเว็บต้องถูกเก็บงานก่อน student เห็นครั้งแรกเสมอ

**Step 12 (spin server) เป็น MANDATORY** ห้ามข้าม ถ้า Python install fail ใช้ fallback ตาม Step 12 Last resort
**Step 13 (invoke web-finish) เป็น MANDATORY** ห้ามข้าม

---

## โครงสร้างปลายทาง (Best Practice)

หลัง import สำเร็จ project ต้องมีโครงสร้างนี้

```
project-root/
├── index.html              หน้าหลักของเว็บ
├── assets/
│   ├── images/             รูปของ student ใส่ที่นี่
│   ├── js/
│   │   └── image-slot.js   ถ้า Claude Design ใส่มา
│   └── css/                ถ้ามี CSS แยก
├── pages/                  สำหรับหน้าเพิ่มในอนาคต (สร้างไว้เผื่อ)
├── README.md               (สร้างถ้ายังไม่มี)
├── CLAUDE.md               (มีอยู่แล้วจาก web-scope)
└── .gitignore              (สร้างถ้ายังไม่มี)
```

---

## Step 0 ตรวจสถานการณ์ Path A หรือ Path B ก่อนเริ่ม

ตั้งแต่ web-design มี 2 ทาง student อาจมาที่ web-import ด้วยเจตนาต่างกัน ตรวจก่อน route ห้ามด่วนขอ zip

1. มีตัวอย่าง Path B ค้างไหม (เฉพาะถ้าอยู่ใน git repo คือ `git remote -v` ไม่ว่าง)
   `git branch --list "draft/*-claude-code-design"`
2. student แนบ zip มาในข้อความไหม (มี path ลงท้าย `.zip` ดู Step 1)

| มี zip ไหม | มี B branch ไหม | route |
|------------|------------------|-------|
| มี zip | มีหรือไม่ก็ตาม | **Path A** ไป Step 1 ตามปกติ (ถ้ามี B branch จะถามลบทีหลังหลัง import สำเร็จ Step 10.5) |
| ไม่มี zip | มี B branch | **น่าจะอยากใช้ Path B** ถามก่อน อย่าด่วนขอ zip |
| ไม่มี zip | ไม่มี B branch | ขอ zip ตามปกติ ไป Step 1 |

### ถ้าไม่มี zip แต่มีตัวอย่าง Path B ค้าง ถามก่อน

> "คุณมี 2 ทางให้เลือกนะคะ/ครับ
>  🅰️ ถ้าออกแบบที่ Claude Design มาแล้ว ลาก zip เข้ามาได้เลย ผมจะ import ให้
>  🅱️ ถ้าจะใช้ตัวอย่างที่ Claude Code ทำไว้ ไม่ต้อง import พิมพ์ /draft-mode แล้วเลือก ใช้เลย
>     ผมจะเอาขึ้นเว็บจริงแล้วเก็บงานให้อัตโนมัติ
>  จะเอาทางไหนดีคะ/ครับ"

- เลือก A → ไป Step 1 (ขอ zip)
- เลือก B → แนะนำพิมพ์ `/draft-mode` แล้ว **จบ skill นี้ ไม่ import** (draft-mode จะ merge ตัวอย่าง B + เรียก web-finish ให้เอง)

**สำคัญ** ต้องอยู่บน main ตอน import ถ้าเผลออยู่ในฉบับร่าง ให้ `git checkout main` ก่อน
ถ้า student แนบ zip มาตั้งแต่แรกแล้ว ข้ามคำถามนี้ ถือว่าเลือก A ชัดเจน ไป Step 1 ได้เลย

---

## Step 1 รับ zip จาก student

### ถ้า student ส่ง zip path มาในข้อความ

ตรวจหา pattern ใน user message
- `@"path/to/file.zip"` (drag-drop style)
- `@path/to/file.zip`
- `"path/to/file.zip"`
- ใดๆ ที่ลงท้ายด้วย `.zip`

ใช้ path นั้นเป็นต้นทาง

### ถ้า student ไม่ได้ส่ง path

ถาม

> "ลาก zip file จาก Claude Design เข้ามาในแชทเลยนะคะ/ครับ
>
> วิธี
> 1. ใน File Explorer (Windows) หรือ Finder (Mac) หาไฟล์ zip ที่ download มา
> 2. ลากไฟล์เข้ามาในช่องพิมพ์ของ Claude Code
> 3. กด Enter
>
> ผมจะเริ่ม import ให้อัตโนมัติ"

---

## Step 2 Extract zip ลง temp folder

### Windows (PowerShell)

```powershell
$zip = "PATH_FROM_STUDENT"
$temp = "$env:TEMP\web-import-$(Get-Random)"
New-Item -ItemType Directory -Force $temp | Out-Null
Expand-Archive -Path $zip -DestinationPath $temp -Force
Get-ChildItem -Recurse $temp | Select-Object FullName
```

### macOS (Bash)

```bash
ZIP="PATH_FROM_STUDENT"
TEMP=$(mktemp -d)
unzip -q "$ZIP" -d "$TEMP"
find "$TEMP" -type f
```

### ถ้า extract fail

| Error | สาเหตุ | แก้ |
|-------|--------|-----|
| `not a zip file` | ไฟล์ไม่ใช่ zip จริง | "ไฟล์นี้ไม่ใช่ zip ลองตรวจดูว่า download ครบไหม ลองใหม่อีกครั้งนะ" |
| `path not found` | path ผิด | "หาไฟล์ไม่เจอ ลองลาก zip เข้ามาใหม่อีกครั้งนะ" |
| `permission denied` | สิทธิ์ | Win: `Unblock-File -Path $zip` แล้ว retry / Mac: `chmod +r "$ZIP"` |

---

## Step 3 ตรวจโครงสร้างจาก Claude Design

ที่คาดหวัง (จาก claude.ai/design)

```
[some-name]/
├── README.md              Claude Design handoff doc (จะลบทิ้ง)
└── project/
    ├── index.html         หรือชื่ออื่น .html
    ├── image-slot.js      ถ้ามี
    └── ... (อื่นๆ)
```

### ถ้าไม่เจอ project folder

แจ้ง

> "zip นี้โครงสร้างไม่เหมือนของ Claude Design นะ
> Claude Design จะมี folder ชื่อ project ข้างใน
> ลองตรวจว่า download มาจาก claude.ai/design ถูกต้องไหม"

แล้วจบ skill

### ถ้าเจอแล้ว

จด path ของ
- HTML file (index.html landing.html หรืออื่น)
- image-slot.js (ถ้ามี)
- ไฟล์อื่นๆ ใน project/

---

## Step 4 ตรวจว่า project root พร้อมรับไฟล์ไหม

```
ls (Mac) หรือ dir (Win) ใน project root
```

| สถานการณ์ | การจัดการ |
|-----------|----------|
| มี `index.html` อยู่แล้ว | ถาม "เจอ index.html อยู่แล้ว ทับเลย หรือเก็บไฟล์เก่าไว้เป็น index-old.html" |
| มี `assets/` อยู่แล้ว | merge เข้าไป ไม่ทับของเก่า |
| ว่างเปล่า | สร้างทุก folder + import ได้เลย |

---

## Step 5 สร้าง folder structure

```
project-root/
├── assets/
│   ├── images/   (สร้างใหม่ถ้ายังไม่มี)
│   ├── js/       (สร้างใหม่ถ้ายังไม่มี)
│   └── css/      (สร้างใหม่ถ้ายังไม่มี)
├── pages/        (สร้างใหม่ถ้ายังไม่มี)
```

### Windows

```powershell
$dirs = @("assets", "assets\images", "assets\js", "assets\css", "pages")
foreach ($d in $dirs) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
}
```

### macOS

```bash
mkdir -p assets/images assets/js assets/css pages
```

---

## Step 6 ย้ายไฟล์เข้าที่ถูกต้อง

| ไฟล์ใน zip | ปลายทาง |
|-----------|---------|
| HTML file (ใดก็ตาม) | `index.html` ที่ root (rename ถ้าจำเป็น) |
| `image-slot.js` | `assets/js/image-slot.js` |
| รูปภาพ (.jpg .png .svg .webp) | `assets/images/[ชื่อเดิม]` |
| CSS file (.css) | `assets/css/[ชื่อเดิม]` |
| Claude Design `README.md` | **ลบทิ้ง** ไม่ใช่ของเรา |
| ไฟล์อื่น | ถามก่อนย้าย หรือเก็บใน `assets/` |

### Claude Design artifacts ที่ต้องลบทิ้ง (สำคัญ)

Claude Design copy codebase ที่ attach + ไฟล์ scratch เข้า output zip ด้วย
ต้องลบทิ้งเพราะไม่ใช่ส่วนของเว็บจริง

| Folder/file ใน zip | จัดการ |
|--------------------|--------|
| `uploads/` (codebase ที่เรา attach) | **ลบทิ้งทั้ง folder** |
| `_ref/` (reference copy) | **ลบทิ้งทั้ง folder** |
| `scraps/` (`.napkin` sketch files) | **ลบทิ้งทั้ง folder** |
| `codebase/` (ถ้า copy มาใน output) | **ลบทิ้ง** (มีที่ project root แล้ว) |
| `.image-slots.state.json` | เก็บไว้ให้ web-images จัดการ (Step 11) |

```powershell
# Windows ลบ artifacts
foreach ($junk in @("uploads","_ref","scraps","codebase")) {
  $p = Join-Path $temp "*\project\$junk"
  Get-ChildItem $p -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}
```

```bash
# macOS ลบ artifacts
rm -rf "$TEMP"/*/project/uploads "$TEMP"/*/project/_ref "$TEMP"/*/project/scraps "$TEMP"/*/project/codebase 2>/dev/null || true
```

**ทำก่อนย้ายไฟล์** เพื่อไม่ให้ artifacts ปนเข้า project

### Windows

```powershell
Move-Item "$temp\*\project\*.html" -Destination ".\index.html" -Force
Move-Item "$temp\*\project\image-slot.js" -Destination ".\assets\js\" -Force -ErrorAction SilentlyContinue
```

### macOS

```bash
mv "$TEMP"/*/project/*.html ./index.html
mv "$TEMP"/*/project/image-slot.js ./assets/js/ 2>/dev/null || true
```

---

## Step 7 แก้ path ใน HTML

ใน Claude Design HTML reference ไฟล์ผ่าน relative path เช่น

```html
<script src="image-slot.js"></script>
```

หลังย้ายไป assets/js/ ต้องแก้เป็น

```html
<script src="assets/js/image-slot.js"></script>
```

### วิธีแก้

Read index.html หา pattern `src="image-slot.js"` หรือ `src='./image-slot.js'` ใช้ Edit tool แก้เป็น `src="assets/js/image-slot.js"`

ตรวจหา pattern อื่นๆ ที่อาจมี
- `href="style.css"` → `href="assets/css/style.css"`
- `src="logo.png"` → `src="assets/images/logo.png"`
- (เฉพาะถ้ามีไฟล์เหล่านั้นจริง)

---

## Step 8 สร้างไฟล์ที่ยังไม่มี

### `.gitignore` (ถ้ายังไม่มี)

```
node_modules/
.DS_Store
Thumbs.db
*.log
.env
.env.local
.vscode/
.idea/
dist/
build/
```

### `README.md` (ถ้ายังไม่มีหรือเป็นของ Claude Design)

ถ้ามี CLAUDE.md ที่ root อ่าน web-scope block หา business description แล้วสร้าง README

```markdown
# [ชื่อ project จาก CLAUDE.md หรือ folder name]

[business description จาก web-scope]

## Live site
[จะ deploy ที่ Cloudflare Pages]

## Structure
- `index.html` หน้าหลัก
- `assets/images/` รูปของเว็บ
- `assets/js/` JavaScript
- `assets/css/` CSS (ถ้ามี)
- `pages/` หน้าเว็บอื่นๆ (เผื่ออนาคต)

## Built with Claude
- web-scope กำหนดขอบเขต
- web-writing เขียนเนื้อหา
- web-design ออกแบบใน Claude Design
- web-import วางไฟล์
```

---

## Step 9 Cleanup

```
ลบ temp folder
ลบ Claude Design README.md ถ้ายัง copy มา
```

### Windows

```powershell
Remove-Item -Recurse -Force $temp
```

### macOS

```bash
rm -rf "$TEMP"
```

---

## Step 10 Verify ทุกอย่างพร้อม

ตรวจ checklist

```
✅ index.html อยู่ที่ root
✅ assets/images/ folder มี
✅ assets/js/image-slot.js (ถ้า Claude Design ใส่มา)
✅ <script src="assets/js/image-slot.js"> ใน HTML ถูกต้อง
✅ .gitignore มี
✅ CLAUDE.md ไม่โดนทับ (ของ web-scope/web-writing/web-design)
✅ ไม่มี temp folder เหลือ
✅ ไม่มี Claude Design handoff README ที่ project root
```

ถ้าครบทุกข้อ ไปขั้น 11

---

## Step 10.5 ลบตัวอย่าง Path B หลัง import A สำเร็จ

ถึงตรงนี้ Path A วางลง main เรียบร้อยแล้ว (เลือก A ชัดเจน) ถ้ามีตัวอย่าง Path B ค้างในฉบับร่าง ถามว่าจะลบไหม
ทำหลัง import สำเร็จเท่านั้น ห้ามลบก่อน เผื่อ import พลาดตัวอย่าง B จะยังอยู่

ตรวจ (เฉพาะถ้าอยู่ใน git repo)

```
git branch --list "draft/*-claude-code-design"
```

ถ้าเจอ ถาม student

> "คุณเลือกใช้ดีไซน์จาก Claude Design แล้วนะคะ/ครับ
>  ตัวอย่างจาก Claude Code ที่เคยทำไว้จะจัดการยังไงดี
>  (A) ลบทิ้ง ไม่ใช้แล้ว
>  (B) เก็บไว้ดูก่อน"

- (A) → `git branch -D <branch>` (ใช้ `-D` เพราะตัวอย่าง B ไม่ได้ merge) แจ้งว่าลบเรียบร้อย
- (B) → ปล่อยไว้ แจ้งว่าเปิดดูทีหลังได้ผ่าน `/draft-mode`

ไม่เจอ branch หรือไม่ได้อยู่ใน git repo ข้ามไป Step 11

---

## Step 11 ตรวจ + Invoke web-images ถ้ามี state.json

ก่อน spin server ตรวจว่ามี Claude Design state.json ไหม ถ้ามี invoke `web-images` skill เพื่อแปลงเป็น production format

### 11.1 ตรวจ state.json

```powershell
# Windows
$stateFile = ".image-slots.state.json"
if (Test-Path $stateFile) {
  $size = (Get-Item $stateFile).Length
  Write-Output "STATE_JSON_FOUND:$size"
}
```

```bash
# macOS
if [ -f .image-slots.state.json ]; then
  size=$(stat -f%z .image-slots.state.json 2>/dev/null || stat -c%s .image-slots.state.json)
  echo "STATE_JSON_FOUND:$size"
fi
```

### 11.2 ถ้ามี invoke Skill(web-images) Mode A

แจ้ง student ก่อน

```
เจอรูปจาก Claude Design preview ใน project [จำนวน] รูป
ขนาดรวม [size] กำลังแปลงเป็นไฟล์ jpg + optimize ให้
```

แล้ว invoke

```
Skill(web-images)
   context "Extract base64 images from .image-slots.state.json in current project
            Optimize each via Pillow and replace <image-slot> elements with <img> tags
            Clean up state.json and image-slot.js after extraction"
```

รอ web-images ทำงานจนจบ web-images จะ
- ตรวจ Python + auto-install Pillow ถ้าไม่มี
- decode base64 → save .jpg/.webp ใน assets/images/
- replace HTML
- ลบ state.json + image-slot.js
- report ขนาด before/after

### 11.3 ถ้าไม่มี state.json

ปกติ ข้ามไปไม่ทำอะไร placeholder ยังอยู่ใน HTML

แจ้ง student (เพิ่มใน final report Step 12)

```
💡 รูปยังเป็น placeholder อยู่
   ถ้าอยากใส่รูปจริง 2 วิธี
   
   A. กลับไป claude.ai/design double-click slot แล้ว drop รูป
      Export zip ใหม่ → /web-import ใหม่
   
   B. เซฟรูปลงโฟลเดอร์โปรเจกต์ (หรือลากไฟล์ให้ path ขึ้น) แล้วพิมพ์ /web-images
      ผมจะ optimize + ใส่ slot ที่คุณเลือก
      (วางภาพในแชทเฉยๆ ใช้ไม่ได้ ต้องเป็นไฟล์จริงบนเครื่อง)
```

### 11.4 ถ้า web-images fail

(เช่น Python install ไม่ได้)

แจ้ง student

```
ไม่สามารถ optimize รูปอัตโนมัติได้ตอนนี้
แต่เว็บยังใช้งานได้นะ ใช้ image-slot.js ของ Claude Design แทน
ถ้าอยาก optimize ทีหลังพิมพ์ /web-images
```

แล้วไปต่อ Spin server (ใช้ state.json ตามที่ Claude Design ให้มา)

---

## Step 12 Spin Up Local Server (ใหม่)

### ตรวจ Python

ลำดับ try

1. **Mac**: `python3 --version`
2. **Win**: `python --version`
3. **Win**: `py --version`

ถ้าเจอ version ใด ข้าม install ใช้ command นั้นต่อ

### Auto-install ถ้าไม่มี (ไม่ต้องถาม student)

**Windows**

```powershell
# install ผ่าน winget
winget install Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
# reload PATH ใน session นี้
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
# verify
python --version
```

**macOS**

```bash
# macOS 10.15+ ปกติมีอยู่แล้ว ถ้าไม่มีจริงๆ
brew --version  # ตรวจ brew
# ถ้าไม่มี brew install ก่อน
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install python3
```

### Fallback ถ้า install fail

ลอง Node `npx http-server -p 8000`

```powershell
# Windows
winget install OpenJS.NodeJS -e --source winget --accept-package-agreements
```

```bash
# Mac
brew install node
```

### Last resort

ถ้าทั้ง Python และ Node install ไม่ได้ ข้าม spin-up server แจ้ง student

```
ผมติดตั้ง local server ไม่สำเร็จ
แต่ไฟล์ทุกอย่างวางเรียบร้อยแล้ว

ลองติดตั้ง Python จาก https://python.org/downloads
แล้วพิมพ์ /web-import ใหม่อีกครั้ง ผมจะลอง spin server ให้

หรือถ้าอยาก push ขึ้น GitHub ก่อน พิมพ์ /save-work
```

**ห้ามแนะนำ /web-finish ในที่นี้** /web-finish ไม่ใช่ทางออกสำหรับ spin server fail

### Spin up server (background)

**ต้องหาพอร์ตว่างก่อน bind** อย่า bind 8000 ดื้อๆ เพราะถ้ามี server อื่นครองพอร์ตอยู่ (โปรเจกต์อื่น หรือรอบก่อน) `Start-Process -WindowStyle Hidden` / `> /dev/null &` จะกลืน error แล้ว curl ไปโดน server ตัวอื่นได้ 200 = นักเรียนเปิดมาเจอเว็บผิดตัว เช็คว่าพอร์ตว่างจริงก่อน start แล้วเลือกตัวแรกที่ว่างจาก 8000 → 8080 → 8888 → 3000

**Windows**

```powershell
# resolve interpreter inline (shell variables ไม่ข้าม tool call ต้องหาในบล็อกเดียวกัน)
$PY = "python"; python --version 2>$null; if (-not $?) { $PY = "py" }
$port = $null
foreach ($p in 8000,8080,8888,3000) {
  if (-not (Test-NetConnection localhost -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded) { $port = $p; break }
}
$proc = Start-Process -FilePath $PY -ArgumentList "-m","http.server",$port,"--directory","." -WindowStyle Hidden -PassThru
$proc.Id | Out-File -FilePath "$env:TEMP\cnc-web-server-pid.txt" -Encoding utf8
"$port" | Out-File -FilePath "$env:TEMP\cnc-web-server-port.txt" -Encoding utf8
```

**macOS**

```bash
for p in 8000 8080 8888 3000; do
  if ! lsof -i :$p > /dev/null 2>&1; then PORT=$p; break; fi
done
python3 -m http.server $PORT --directory . > /dev/null 2>&1 &
echo $! > /tmp/cnc-web-server-pid
echo $PORT > /tmp/cnc-web-server-port
```

ใช้ `run_in_background: true` เก็บพอร์ตที่ start จริงไว้ใช้ตอน verify + แสดง link

### Verify server

```
# ลอง curl
Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 3
# หรือ Mac
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT
```

ถ้าตอบกลับมา 200 → server พร้อม
ถ้า fail → ลอง port อื่น เก็บ port ที่ใช้จริงไว้

### ทำไมต้องเซฟ pid + port

skill `/web-finish` จะอ่านไฟล์เหล่านี้ ถ้าเจอ server ที่รันอยู่แล้ว ใช้ตัวเดิมไม่ต้อง spin ใหม่

---

## Step 13 แจ้ง import เสร็จ แล้ว auto-invoke web-finish (MANDATORY)

แจ้งสั้นๆ ว่า import เสร็จ แล้ว **เรียก web-finish ทันที** อย่ารอ student ขอ อย่าแสดง link เองแล้วจบ

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ จัดไฟล์เข้าที่เรียบร้อย
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 index.html + assets/ + pages/ พร้อมแล้ว
⏳ เดี๋ยวผมเก็บงานหน้าเว็บให้ก่อนเปิดดูนะคะ/ครับ
```

จากนั้น **invoke skill `web-finish` ทันที** (ใช้ Skill tool เหมือนที่ Step 11 invoke web-images)
- web-finish จะ reuse server ที่ Step 12 เปิดไว้ (share pid/port file เดียวกัน)
- web-finish ข้าม Step 1 ของมันได้ เพราะ web-import ตรวจ index.html ให้แล้ว เริ่มที่ Step 2 (อ่าน + เก็บงานภาษาไทย/mobile)
- web-finish เป็นคนแสดง link 👉 http://localhost:[PORT] + ถามค่าจริงแทน placeholder เอง

**สำคัญ** ห้าม invoke `mcp__Claude_Preview__*` tools หรือ tool ที่ render ใน sidebar
ให้ web-finish พา student เปิด link ใน browser ของเขาเอง

---

## Edge cases

### Student ส่ง zip ไม่ใช่จาก Claude Design

```
zip ที่ส่งมาไม่มี folder ชื่อ project ข้างใน
→ แจ้ง "zip นี้ไม่ใช่จาก Claude Design นะ
   ลอง download จาก claude.ai/design ใหม่
   จะมี folder ชื่อ project ข้างใน"
→ จบ skill
```

### Student ส่งไฟล์ HTML เดี่ยวๆ (ไม่ใช่ zip)

```
ถ้า path ลงท้ายด้วย .html ไม่ใช่ .zip
→ ถาม "ส่งไฟล์ HTML เดี่ยวมาเหรอ ผมรองรับเฉพาะ zip จาก Claude Design นะ
   ถ้าอยากให้ copy ไฟล์นี้เข้า project ลำพัง บอกผมได้
   หรือถ้ามี zip ของ Claude Design ส่งมาแทน"
```

### มี index.html อยู่แล้วใน project root

```
ถาม student
"เจอ index.html อยู่แล้วใน project นะ
(A) ทับเลย ใช้ของใหม่จาก Claude Design
(B) เก็บอันเก่าไว้เป็น index-backup.html ใช้ของใหม่
(C) ยกเลิก ผมจะดูก่อน"
```

### Plan mode

ถ้าอยู่ใน plan mode call `ExitPlanMode` พร้อมแสดง file operations ที่จะทำ รอ approve ค่อยทำจริง

---

## สิ่งที่ต้องระวัง

- **Cross-platform** ทดสอบทั้ง PowerShell และ Bash ก่อนใช้
- **ห้ามทับไฟล์ของ student โดยไม่ถาม** index.html ที่มีอยู่ assets/images ที่มีอยู่
- **อย่าลืมแก้ script path ใน HTML** ถ้าย้าย image-slot.js ไปแล้ว HTML ต้องอ้างถูก
- **ห้าม copy Claude Design README.md** มาเป็น README ของ project (มันคือ handoff doc ไม่ใช่ของ project)
- **ทุก operation idempotent** student รันซ้ำ skill นี้ได้ ไม่พัง
- **Cleanup temp folder ทุกครั้ง** ก่อนจบ skill แม้ error
- **ถ้า student ไม่ส่ง zip มา ห้ามเดา path** ถาม student ทุกครั้ง
- **Step 12 spin server เป็น MANDATORY** ห้ามข้าม web-finish จะ reuse server ตัวนี้
- **Step 13 auto-invoke web-finish เป็น MANDATORY** ห้ามจบ skill โดยไม่เรียก web-finish ห้ามให้ student พิมพ์คำสั่งเอง
- **web-finish เป็นคนแสดง preview + ถาม placeholder** web-import แค่จัดไฟล์ + เปิด server แล้วส่งต่อ
