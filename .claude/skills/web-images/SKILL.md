---
name: web-images
description: Use when the student needs to process images for their website convert Claude Design state.json placeholder images into real files optimize uploaded photos resize crop and replace image-slot elements with proper img tags or scan the site for empty image slots when called with no args triggers include "optimize รูป", "ใส่รูปจริง", "ใส่รูปใหม่", "เปลี่ยนรูป", "อัพรูปใหม่", "แก้รูป", "replace image", "แปลง image-slot", "extract state.json", "ตรวจรูป", "เช็ครูป", "เหลือรูปไหนต้องใส่", "web-images", or any similar image-related request (especially when student drags an image file into chat). Also called automatically by web-import skill after a Claude Design zip is extracted to convert base64 images in .image-slots.state.json into optimized files in assets/images/ and replace <image-slot> elements with <img> tags. Has 3 modes — Mode A extracts state.json placeholders, Mode B optimizes a single uploaded photo with interactive ratio-mismatch dialog when diff > 15% (offers center/top/bottom crop or swap slot ratio), Mode C scans HTML for empty image slots and guides student to fill each one. Codebase restricts to STRICT 3 ratios only 16/9 landscape 1/1 square 9/16 portrait. Uses Python Pillow for optimization (auto-installs if missing) handles aspect ratio matching crop EXIF rotation and format conversion. Built for absolute beginners works cross-platform Windows and macOS writes in pure Thai without em dash or comma between Thai clauses.
---

# web-images จัดการรูปในเว็บ

ช่วย student แปลง image-slot placeholder ของ Claude Design เป็น `<img>` จริง + optimize ทุกรูปให้ขนาดเหมาะกับเว็บ ทำงานได้ทั้ง standalone และถูกเรียกจาก `web-import`

---

## กฎเด็ดขาด Thai content

ห้ามใช้ em dash (—) ห้ามใช้ comma (,) แยก clause ใน Thai text

---

## กฎหลักอื่นๆ

- **ภาษาไทยเรียบง่าย** student ไม่รู้จัก aspect-ratio EXIF base64
- **ห้ามใช้ technical term** กับ student
- **Auto-install Pillow** ครั้งแรก ไม่ต้องถาม
- **Cross-platform** Windows + macOS
- **Idempotent** รันซ้ำได้ ไม่พัง
- **เก็บ original ของ student** ไว้ถ้าจำเป็น (สำคัญ ห้ามทำลายไฟล์ของ student)

---

## 3 Mode การทำงาน

### Mode A Extract from state.json (หลัก)

ใช้ตอน `web-import` เสร็จ และเจอ `.image-slots.state.json`

```
Input
   Project root ที่มี
   - index.html
   - .image-slots.state.json
   - assets/js/image-slot.js

Output
   - assets/images/[slot-id].jpg (รูป optimize แล้ว)
   - index.html แทน <image-slot> ด้วย <img>
   - ลบ .image-slots.state.json
   - ลบ <script src="image-slot.js"> ถ้าไม่มี slot เหลือ
   - ลบ assets/js/image-slot.js ถ้าไม่ใช้แล้ว
```

### ⚠️ กฎเรื่องไฟล์รูป (อ่านก่อน Mode B/C)

รูปต้องเป็น **ไฟล์จริงบนเครื่อง** ผมถึงจะ optimize หรือใส่ลงเว็บได้ student ส่งรูปได้ 2 ทาง

1. ลากไฟล์รูปเข้า Claude Code จน **path ของไฟล์ขึ้น** (เช่น `@C:\Users\...\photo.jpg`) หรือพิมพ์ path เอง
2. เซฟรูปลงโฟลเดอร์โปรเจกต์ (เช่น `assets/images/`) ก่อน แล้วบอกชื่อไฟล์

**รูปที่ paste เป็นภาพในแชทเฉยๆ (ภาพ preview) ใช้ไม่ได้** ผมเห็นภาพได้แต่มันไม่ได้กลายเป็นไฟล์บนเครื่อง เซฟ/ประมวลผล/ใส่เว็บไม่ได้ ถ้า student วางภาพมาแบบนั้น บอกให้ส่ง path หรือเซฟลงโฟลเดอร์โปรเจกต์ก่อน

### Mode B Single image optimize

ใช้ตอน student ส่งรูป (เป็น path หรือไฟล์ในโปรเจกต์ ดูกฎเรื่องไฟล์รูปด้านบน) เข้ามาเอง (เรียกจาก web-import หรือ web-finish)

```
Input
   - path to image file
   - target slot id (optional)
   - target aspect ratio (optional auto-detect from slot CSS)

Output
   - optimized file at assets/images/[slot-id].jpg
   - report ขนาด before/after
```

### Mode C Empty slot scan (ใหม่)

ใช้ตอน student เรียก skill ลอย ๆ ไม่มี argument ไม่มี state.json และไม่มีไฟล์รูปแนบมา เพื่อตรวจว่าเว็บยังมีช่องรูปไหนยังไม่ใส่จริง

```
Input
   - index.html (+ pages/*.html ถ้ามี)

Output
   - list ของช่องว่างทุกช่อง พร้อม ratio + alt
   - guided flow ทีละช่อง ขอรูปจาก student แล้วส่งต่อ Mode B
```

#### นิยาม "ช่องรูปว่าง" แบบทั่วไป (รองรับทุกที่มาของเว็บ)

อย่าหาแค่ `<image-slot>` ของ Claude Design (Path A) เท่านั้น เว็บที่ Claude Code สร้างเอง (Path B) หรือเว็บที่ student แก้มือจะใช้ markup แบบอื่น ให้ถือว่าเป็นช่องรูปว่างถ้าเข้าข่ายข้อใดข้อหนึ่ง

1. `<image-slot ...>` (Claude Design)
2. element ที่มี ratio class (`.ratio-landscape/.ratio-square/.ratio-portrait`) หรือ `aspect-ratio` ใน CSS แล้ว **ข้างในยังไม่มี `<img>` จริง** (มีแต่ div placeholder ข้อความ เช่น "ภาพ..." หรือว่างเปล่า)
3. `<img>` ที่ `src` ยังเป็น placeholder (ว่าง `#` `data:` base64 ชื่อไฟล์สมมติที่ไม่มีอยู่จริงใน `assets/images/`)
4. element ที่ class/ชื่อสื่อว่าเป็นที่ใส่รูป (เช่น `img-ph` `placeholder` `photo` `media`) และยังไม่มีรูปจริง

หา ratio + alt จาก context เดียวกันทุกแบบ (ratio class บน element หรือ parent → `aspect-ratio` ใน CSS → snap เข้า 3 ratios) ส่วน alt เดาจาก ข้อความ placeholder section หรือ CLAUDE.md
จากนั้นเดินต่อ guided flow เดียวกันไม่ว่าจะเจอแบบไหน

---

## Step 1 Detect Mode

ลำดับการตรวจ (อันบนชนะอันล่าง)

1. **มี `.image-slots.state.json`** → Mode A (เฉพาะ Claude Design / Path A)
2. **user message มี path ไฟล์ภาพ** (`.jpg .png .webp .heic`) → Mode B
3. **ไม่มีทั้งสองอย่าง** → Mode C scan empty slots (รองรับทุกที่มาของเว็บ ทั้ง `<image-slot>` ของ Path A และ placeholder แบบอื่นของ Path B หรือเว็บที่แก้มือ ดูนิยามช่องรูปว่างใน Mode C)

---

## Step 2 ตรวจ Python + Pillow

### ลำดับ try Python — เก็บ command ที่ใช้ได้ใน variable

**macOS** ส่วนใหญ่มีแค่ `python3` ไม่มี `python`

```bash
python3 --version
PY=python3
```

**Windows** ส่วนใหญ่ใช้ `python` หรือ `py` ได้

```powershell
$PY = $null
python --version 2>$null
if ($?) { $PY = "python" }

# ถ้า python ไม่เจอ ค่อยลอง py
if (-not $PY) {
  py --version 2>$null
  if ($?) { $PY = "py" }
}
```

**ใช้ `$PY` ทุกที่ที่ตามมา ไม่ใช้ python หรือ python3 ตรง ๆ**

### ตรวจ Pillow

**macOS**
```bash
$PY -c "from PIL import Image; print(Image.__version__)"
```

**Windows**
```powershell
& $PY -c "from PIL import Image; print(Image.__version__)"
```

(PowerShell ใช้ `& $PY` เรียก command จาก variable)

### Auto-install ถ้าไม่มี Pillow

**macOS**
```bash
$PY -m pip install --quiet --user Pillow
# ถ้าเจอ error externally-managed-environment (Python จาก Homebrew รุ่นใหม่) ลองซ้ำด้วย
$PY -m pip install --quiet --user --break-system-packages Pillow
```

**Windows**
```powershell
& $PY -m pip install --quiet Pillow
```

### Verify

**macOS**
```bash
$PY -c "from PIL import Image, ImageOps; print('Pillow ready')"
```

**Windows**
```powershell
& $PY -c "from PIL import Image, ImageOps; print('Pillow ready')"
```

ถ้า import ได้ → ไปต่อ
ถ้า fail → fallback: ใช้ macOS `sips` ถ้าอยู่ Mac หรือแจ้ง student install Python

---

## Step 3 Mode A Extract from state.json

### 3.1 อ่าน state.json

```python
import json
with open('.image-slots.state.json', 'r', encoding='utf-8') as f:
    state = json.load(f)

# structure
# {
#   "hero-portrait": {"u": "data:image/webp;base64,...", "s": 1, "x": 0, "y": 0},
#   "testi-1": {"u": "data:image/...", ...},
#   ...
# }
```

### 3.2 สำหรับแต่ละ slot ที่มี dataUrl

#### 3.2.1 หา target aspect ratio

อ่าน index.html หา CSS rule ที่ใช้กับ container ของ slot นั้น

```python
import re

# หา <image-slot id="hero-portrait" ...>
# หา parent class เช่น <div class="hero-art">
# หา CSS rule .hero-art { aspect-ratio: 4/5 }
# extract ratio
```

ตอนนี้ codebase รองรับแค่ 3 ratios เท่านั้น **16/9, 1/1, 9/16** (ดู `codebase/README.md`)

วิธีหา ratio ของ slot ตามลำดับ
1. หา class `.ratio-landscape` / `.ratio-square` / `.ratio-portrait` บน element ช่องรูป หรือ parent ของมัน ใน HTML (ช่องรูป = ตามนิยามทั่วไปใน Mode C ไม่ใช่แค่ `<image-slot>`)
2. ถ้าไม่มี class → หา CSS rule `aspect-ratio:` ใน inline `<style>` แล้ว snap เข้ากลุ่มที่ใกล้ที่สุดใน 3 ratios
3. ถ้าหาไม่เจอเลย default ตามชื่อ slot
   - hero-portrait → 9/16
   - testi-* → 1/1
   - work-* → 16/9
   - bridge-* → 9/16
   - อื่น ๆ → 1/1 (ปลอดภัยที่สุด)

**snap rule** ถ้า CSS เขียน aspect-ratio ที่ไม่ใช่ 3 ตัวนี้ (เช่น 4/5) ให้แปลงโดย**ใช้ orientation เป็นหลัก** (ไม่ใช่ arithmetic distance เพราะจะให้ผลผิดสำหรับ landscape/portrait ที่ยังใกล้ 1.0)

```python
def snap_to_3_ratios(r):
    # r = width / height
    if r >= 1.15:       # landscape: 16/9=1.78, 3/2=1.5, 4/3=1.33
        return (16/9, '16/9 นอน', 'ratio-landscape')
    elif r <= 0.87:     # portrait: 9/16=0.56, 3/4=0.75, 4/5=0.8
        return (9/16, '9/16 ตั้ง', 'ratio-portrait')
    else:               # near-square: 0.87 < r < 1.15
        return (1/1, '1/1 จัตุรัส', 'ratio-square')
```

threshold 1.15 / 0.87 ≈ 8/7 (deadband 15% รอบ 1.0 ตรงกับ mismatch threshold)

**สำคัญ** ถ้า slot เดิมใช้ ratio นอกมาตรฐาน (เช่น 4/5) และต้อง snap → **อัพเดต CSS ของ slot ด้วย** ไม่ใช่แค่ crop รูป

```python
def normalize_slot_ratio(slot_parent_elem, css_files):
    """ถ้า slot ใช้ ratio นอก 3 มาตรฐาน snap แล้วอัพเดต class/CSS"""
    current_ratio = read_aspect_ratio_from_css(slot_parent_elem, css_files)
    if current_ratio in (16/9, 1/1, 9/16):
        return current_ratio  # มาตรฐานอยู่แล้วไม่ต้องแตะ

    snapped = snap_to_3_ratios(current_ratio)
    # ทำ 3 อย่าง
    # 1. ลบ aspect-ratio rule เดิมที่ค่าไม่ใช่ 3 มาตรฐาน (inline หรือ class rule)
    # 2. เพิ่ม class .ratio-landscape/.ratio-square/.ratio-portrait บน parent
    # 3. ensure_ratio_classes_exist (inject ถ้า styles.css ยังไม่มี 3 class นี้)
    add_class_to_parent(slot_parent_elem, snapped[2])
    remove_nonstandard_aspect_ratio(slot_parent_elem, css_files)
    ensure_ratio_classes_exist(html_file, css_files)
    return snapped[0]
```

ผล: หลัง Mode A เสร็จ slot ทุกตัวใช้ 1 ใน 3 มาตรฐาน CSS ตรงกับ ratio ที่ crop ไม่ double-crop ตอน browser render

#### 3.2.2 Decode base64 + optimize

```python
import base64
from io import BytesIO
from PIL import Image, ImageOps

# extract base64 part
data_url = state[slot_id]['u']
# data:image/webp;base64,UklGRu...
mime_match = re.match(r'data:image/(\w+);base64,(.+)', data_url)
ext, b64 = mime_match.group(1), mime_match.group(2)

# decode
binary = base64.b64decode(b64)
img = Image.open(BytesIO(binary))

# fix rotation
img = ImageOps.exif_transpose(img)

# convert mode if needed
if img.mode != 'RGB':
    img = img.convert('RGB')

# target dimensions based on aspect ratio
# 1600px for hero (high-DPI display crisp) 1200px for general
target_ratio = 4/5  # from CSS
target_width = 1600 if slot_id.startswith('hero') else 1200
target_height = int(target_width / target_ratio)

# NEVER upscale check original first
original_width = img.size[0]
if original_width < target_width:
    # ใช้ขนาดเดิมไม่ขยาย (กัน blur)
    target_width = original_width
    target_height = int(target_width / target_ratio)

# smart resize + center crop ใช้ LANCZOS (highest quality downscale)
img = ImageOps.fit(
    img,
    (target_width, target_height),
    Image.LANCZOS,
    centering=(0.5, 0.5)
)

# Save format selection
# WebP = best compression at same quality (10-30% smaller than JPEG)
# JPEG = wider browser support
# PNG = ใช้สำหรับ logo ที่มี transparency
if img.mode == 'RGBA' and slot_id.startswith('logo'):
    output_path = f'assets/images/{slot_id}.png'
    img.save(output_path, 'PNG', optimize=True)
elif ext == 'webp' or original_format == 'WEBP':
    # keep WebP for best quality/size
    output_path = f'assets/images/{slot_id}.webp'
    img.save(output_path, 'WEBP', quality=92, method=6)
else:
    # JPEG quality 92 (visually lossless) + progressive (better perceived load)
    output_path = f'assets/images/{slot_id}.jpg'
    img.save(output_path, 'JPEG', quality=92, optimize=True, progressive=True)
```

#### 3.2.3 เก็บ stats สำหรับ report

```python
stats[slot_id] = {
    'original_size': len(binary),
    'new_size': os.path.getsize(output_path),
    'original_dim': original_img.size,
    'new_dim': img.size,
}
```

### 3.3 Update HTML

หา `<image-slot id="X" placeholder="Y">` และแทนด้วย

```html
<img src="assets/images/X.jpg" alt="Y" class="[copy parent classes if needed]">
```

**สำคัญ** keep parent CSS structure
- parent div ที่มี class เดิม (เช่น `.hero-art`) ยังอยู่
- replace แค่ตัว `<image-slot>` ข้างใน
- CSS rule `.hero-art image-slot { width: 100%; height: 100% }` ไม่ใช้แล้ว แต่ปล่อยไว้ก็ได้

ตัวอย่าง

```html
ก่อน
<div class="hero-art">
  <image-slot id="hero-portrait" placeholder="รูปผู้หญิงไทย"></image-slot>
</div>

หลัง
<div class="hero-art">
  <img src="assets/images/hero-portrait.jpg" alt="รูปผู้หญิงไทย"
       style="width:100%;height:100%;object-fit:cover">
</div>
```

### 3.4 Cleanup

```python
# ลบ state.json (ไม่ต้องใช้แล้ว)
os.remove('.image-slots.state.json')

# ลบ <script src="...image-slot.js"> ใน HTML ถ้าไม่มี image-slot เหลือ
remaining = count_image_slot_elements_in_html()
if remaining == 0:
    remove_script_tag('image-slot.js')
    # ลบ assets/js/image-slot.js
    os.remove('assets/js/image-slot.js')
```

---

## Step 4 Mode B Single image optimize

### 4.1 รับ input

```
input_path: "C:/Downloads/photo.jpg"
target_slot: "hero-portrait" (optional)
```

**ถ้าไม่มี target_slot** auto-trigger Mode C scan ก่อน (Step 4.5)

```
- รัน Mode C scan แสดง list ช่องว่าง
- ถามนักเรียน "รูปนี้จะใส่ช่องไหนคะ/ครับ?"
- หลังนักเรียนเลือกหมายเลข
  - set target_slot = empty_slots[choice-1]['id']
  - กลับมาทำ Step 4.2 ต่อพร้อม target_slot
```

ถ้า Mode C scan ไม่พบช่องว่างเลย แต่นักเรียนยังอยากใส่รูปลง slot ที่มีอยู่แล้ว → ถาม "ช่องไหนต้องการเปลี่ยน?" แสดง list slot ทั้งหมด (เต็มแล้วก็ตาม) ให้เลือก

### 4.2 ตรวจสภาพไฟล์

```python
img = Image.open(input_path)
original_size = os.path.getsize(input_path)
original_dim = img.size
original_format = img.format

# decision matrix
needs_resize = max(img.size) > 1600
needs_compress = original_size > 500_000
needs_format_convert = original_format in ['HEIF', 'HEIC']
needs_rotation_fix = has_exif_rotation(img)
```

### 4.3 Process ตาม Strategy C (quality-first)

| สถานการณ์ | ทำ | Quality target |
|----------|-----|----------------|
| <500KB + <1600px + jpg/webp | Strip EXIF อย่างเดียว ไม่ re-encode | 100% (no loss) |
| 500KB-2MB + dim OK | Light compress quality 92 + strip EXIF | Visually lossless |
| >2MB หรือ >2000px | Resize to 1600px + compress + strip | High quality |
| HEIC | Convert to WebP quality 92 (better than JPEG) | Visually lossless |
| PNG transparency (logo) | Keep PNG with optimize | Lossless |
| Original WebP | Keep WebP quality 92 | High quality |

**กฎสำคัญ**
- JPEG quality NEVER below 90 (90+ = visually lossless for human eye)
- WebP quality 92 default (better than JPEG at same quality)
- NEVER upscale (ทำให้ blur)
- LANCZOS resampling (highest quality downscale algorithm)
- ถ้า original ดีอยู่แล้ว just copy (no re-encode)

### 4.4 ถ้ามี target_slot — ตรวจ ratio mismatch ก่อน crop

**Short-circuit สำหรับ LOGO** logo ratio independent (per codebase) ห้าม crop หรือถาม

```python
is_logo = (target_slot.lower().startswith('logo')
           or 'logo' in get_slot_parent_classes(target_slot).lower())

if is_logo:
    # logo ใช้ ratio ของรูปต้นฉบับ ไม่ crop ไม่ถาม
    # เก็บ transparency ถ้ามี (PNG) ไม่บังคับ JPEG
    optimize_and_save(img, target_slot, preserve_ratio=True, allow_png=True)
    update_html(target_slot)
    return  # ข้าม mismatch dialog
```

**ไม่ใช่ logo** ตรวจ mismatch ตามปกติ

```python
photo_ratio = img.width / img.height
slot_ratio = get_slot_aspect_ratio(target_slot)  # 16/9, 1/1, หรือ 9/16
diff_pct = abs(photo_ratio - slot_ratio) / slot_ratio * 100
```

**ถ้า `diff_pct < 15`** silent center-crop ตามเดิม (รูปกับ slot ใกล้กันมาก crop หายแค่ขอบ ไม่กระทบเนื้อหา)

```python
target_dim = calculate_target_dim(slot_ratio, max_width=1200)
img = ImageOps.fit(img, target_dim, Image.LANCZOS, centering=(0.5, 0.5))
```

**ถ้า `diff_pct >= 15`** หยุดถามนักเรียนก่อน

ก่อนถาม คำนวณ recommended slot ratio ของรูปนักเรียน (snap photo_ratio เข้ากลุ่มที่ใกล้ที่สุดใน 3 ratios)

```python
# use the same snap_to_3_ratios defined in Step 3.2.1 (orientation-based)
photo_snap = snap_to_3_ratios(photo_ratio)
slot_label = describe_slot_ratio(slot_ratio)
```

แสดง dialog ภาษาไทย (เลือกชื่อ orientation จาก slot vs photo เพื่อความชัด)

**ตรวจก่อน** ว่าจะแสดง option 4 หรือไม่

```python
show_swap_option = (photo_snap[0] != slot_ratio)
# ถ้า photo_snap snap กลับมาตรงกับ slot เดิม (เช่น photo 4:3 → snap 16/9, slot 16/9 อยู่แล้ว)
# → option 4 จะเปลี่ยน slot เป็นค่าเดิม = ไร้ประโยชน์ ซ่อนตัวเลือกนี้
```

```
รูปของคุณกับช่องในเว็บไม่เท่ากันนะคะ/ครับ

📷 รูปของคุณ: <orientation รูป เช่น แนวตั้ง 9:16>
🖼️ ช่องในเว็บ: <orientation slot เช่น จัตุรัส 1:1>

เลือกได้นะคะ/ครับ
1) ตัดเก็บส่วนกลาง (default ถ้าไม่เลือก)
2) ตัดเก็บส่วนบน (เช่น เก็บหัว เก็บฟ้า เก็บโลโก้ด้านบน)
3) ตัดเก็บส่วนล่าง (เก็บล่าง เก็บพื้น)
[ถ้า show_swap_option = True เพิ่ม 2 บรรทัดนี้]
4) เปลี่ยนช่องในเว็บให้เป็น <photo_snap orientation> ตามรูป (ไม่ตัด)
   ⚠️ ถ้าช่องนี้อยู่ในกลุ่มกริด เช่น 3 ช่องเรียงกัน อาจทำให้ดูไม่เท่ากัน เลือก 1-3 จะปลอดภัยกว่า
```

**หยุดรอ** นักเรียนเลือก (default 1 ถ้าไม่ตอบใน reasonable time)

```python
if choice == 1:  # center
    img = ImageOps.fit(img, target_dim, Image.LANCZOS, centering=(0.5, 0.5))
elif choice == 2:  # top
    img = ImageOps.fit(img, target_dim, Image.LANCZOS, centering=(0.5, 0.0))
elif choice == 3:  # bottom
    img = ImageOps.fit(img, target_dim, Image.LANCZOS, centering=(0.5, 1.0))
elif choice == 4:  # swap slot ratio
    # 1. ตรวจว่า class ratio ปลายทางมีนิยามใน styles.css หรือ inline <style> หรือยัง
    #    ถ้าขาด inject ก่อนเพื่อไม่ให้ swap แล้วเงียบ
    ensure_ratio_classes_exist(html_file, css_file)

    # 2. ปรับ HTML แทน .ratio-square เป็น .ratio-portrait (ตาม photo_snap)
    # 3. อ่านรูปขนาดเต็มที่ ratio เดิม (ไม่ crop)
    target_dim = calculate_target_dim(photo_snap[0], max_width=1200)
    img = ImageOps.fit(img, target_dim, Image.LANCZOS, centering=(0.5, 0.5))
    swap_slot_class_in_html(target_slot, old_class, new_class=photo_snap[2])


def ensure_ratio_classes_exist(html_file, css_file):
    """Inject 3 ratio utility classes ถ้าขาดใน styles.css หรือ inline <style>"""
    needed = """
.ratio-landscape { aspect-ratio: 16/9; overflow: hidden; }
.ratio-square    { aspect-ratio: 1/1;  overflow: hidden; }
.ratio-portrait  { aspect-ratio: 9/16; overflow: hidden; }
.ratio-landscape > img, .ratio-square > img, .ratio-portrait > img {
    width: 100%; height: 100%; object-fit: cover; display: block;
}
"""
    # check styles.css ก่อน
    if css_file and os.path.exists(css_file):
        css = open(css_file, encoding='utf-8').read()
        if '.ratio-landscape' not in css:
            with open(css_file, 'a', encoding='utf-8') as f:
                f.write('\n/* Injected by web-images for ratio swap */\n' + needed)
            return

    # fallback inject ใน inline <style> ของ HTML
    html = open(html_file, encoding='utf-8').read()
    if '.ratio-landscape' not in html:
        html = html.replace('</style>', needed + '</style>', 1)
        open(html_file, 'w', encoding='utf-8').write(html)
```

### 4.5 Save

```python
output_path = f'assets/images/{target_slot or "image"}.jpg'
img.save(output_path, 'JPEG', quality=85, optimize=True)
```

### 4.6 Update HTML ถ้ามี target_slot

เหมือน Step 3.3

---

## Step 4.5 Mode C Empty slot scan

trigger ตอน student พิมพ์เรียก skill โดยไม่มี state.json และไม่มีไฟล์รูปแนบ

### 4.5.1 หาช่องว่างทุกช่อง

scan `index.html` (และ `pages/*.html` ถ้ามี) **หลาย pattern เพราะ Claude Design ใช้รูปแบบไม่เหมือนกัน**

```python
empty_slots = []

# ────────────────────────────────────────────────────────
# pattern 1: <image-slot> custom element (state.json system)
# ────────────────────────────────────────────────────────
for m in re.finditer(r'<image-slot\s+([^>]+?)>\s*</image-slot>', html, re.IGNORECASE):
    attrs = parse_attrs(m.group(1))
    empty_slots.append({
        'type': 'image-slot',
        'id': attrs.get('id'),
        'placeholder': attrs.get('placeholder', ''),
        'file': path,
    })

# ────────────────────────────────────────────────────────
# pattern 2: <img src=""> หรือ src ชี้ไฟล์ที่ไม่มีจริง
# ────────────────────────────────────────────────────────
for m in re.finditer(r'<img\s+([^>]+?)/?>', html, re.IGNORECASE):
    attrs = parse_attrs(m.group(1))
    src = attrs.get('src', '').strip()
    if not src or (src.startswith('assets/') and not os.path.exists(src)):
        empty_slots.append({
            'type': 'img',
            'id': attrs.get('alt') or attrs.get('id') or 'unnamed',
            'src': src,
            'alt': attrs.get('alt', ''),
            'file': path,
        })

# ────────────────────────────────────────────────────────
# pattern 3: <div class="...img|photo|slot|gallery|hero-art|work__photo...">
#            ที่ "ว่าง" (ไม่มี <img> ลูก ไม่มี text content ที่ไม่ใช่ decorative span)
# ────────────────────────────────────────────────────────
CLASS_HINT_RE = re.compile(
    r'(?:^|\s)('
    r'img-slot|image-slot|photo-slot|'              # explicit
    r'gallery-card|gallery-img|gallery-photo|'      # gallery
    r'hero-art|hero-photo|hero-image|hero-img|'     # hero
    r'work__photo|work-photo|work__img|'            # case study
    r'bridge-art|bridge-photo|bridge-img|'          # bridge sections
    r'card__img|card__photo|card-image|'            # cards
    r'\w+__photo|\w+__img|\w+__image|'              # any BEM block with photo/img
    r'[\w-]*(?:photo|image|img)[\w-]*'              # catch-all heuristic
    r')(?:\s|$)',
    re.IGNORECASE,
)

CONTAINER_TAG_RE = re.compile(
    r'<(div|figure|picture|section|a)\s+([^>]*?class="([^"]+)"[^>]*?)>(.*?)</\1>',
    re.IGNORECASE | re.DOTALL,
)

for m in CONTAINER_TAG_RE.finditer(html):
    tag, attrs_str, class_str, inner = m.groups()
    if not CLASS_HINT_RE.search(class_str):
        continue
    # ข้ามถ้ามี <img> ลูกที่ src ใช้ได้จริง
    img_match = re.search(r'<img\s+[^>]*src="([^"]+)"', inner, re.IGNORECASE)
    if img_match and (not img_match.group(1).startswith('assets/') or os.path.exists(img_match.group(1))):
        continue
    # ข้ามถ้า inner มี <image-slot> (pattern 1 จับไปแล้ว)
    if re.search(r'<image-slot', inner, re.IGNORECASE):
        continue

    attrs = parse_attrs(attrs_str)
    slot_id = attrs.get('id') or class_str.split()[0]
    empty_slots.append({
        'type': 'css-container',
        'id': slot_id,
        'class': class_str,
        'placeholder': extract_decorative_text(inner),  # spans เช่น "01 HONDA CIVIC FE"
        'file': path,
    })

# ────────────────────────────────────────────────────────
# pattern 4 (fallback heuristic): element ที่ CSS ตั้ง aspect-ratio
#           และ inner ว่าง (cross-reference HTML + CSS)
# ────────────────────────────────────────────────────────
# parse styles.css + inline <style> หา selectors ที่ตั้ง aspect-ratio
# จากนั้น match element ใน HTML ที่ใช้ class/id นั้นและ inner ไม่มี <img>
# ใช้เฉพาะถ้า pattern 1-3 รวมกัน < 1 ช่อง (กัน false positive)

def fallback_aspect_ratio_scan(html, css_text):
    selectors_with_ratio = re.findall(
        r'([.#][\w-]+)\s*\{[^}]*aspect-ratio\s*:\s*[^;}]+',
        css_text,
    )
    found = []
    for sel in selectors_with_ratio:
        # หา element ที่ใช้ selector นี้
        class_or_id = sel[1:]
        prefix = 'id' if sel.startswith('#') else 'class'
        pattern = rf'<(div|figure|picture|section)\s+[^>]*{prefix}="[^"]*\b{re.escape(class_or_id)}\b[^"]*"[^>]*>(.*?)</\1>'
        for m in re.finditer(pattern, html, re.IGNORECASE | re.DOTALL):
            inner = m.group(2)
            if '<img' not in inner.lower() and '<image-slot' not in inner.lower():
                found.append({
                    'type': 'css-aspect',
                    'id': class_or_id,
                    'class': class_or_id,
                    'placeholder': '',
                    'file': path,
                })
    return found

if len(empty_slots) == 0:
    empty_slots.extend(fallback_aspect_ratio_scan(html, css_text))

# ────────────────────────────────────────────────────────
# dedup ตาม (file, id, class) — element เดียวอาจถูกจับโดยหลาย pattern
# ────────────────────────────────────────────────────────
seen = set()
deduped = []
for s in empty_slots:
    key = (s['file'], s['id'], s.get('class', ''))
    if key not in seen:
        seen.add(key)
        deduped.append(s)
empty_slots = deduped
```

**กฎความปลอดภัย** ถ้า scan เจอเกิน 20 ช่องในหน้าเดียว → น่าจะ false positive จาก class-hint หลวมเกิน แสดง 20 อันแรกพร้อมแจ้ง "เจอเยอะอาจมีบางอันไม่ใช่ช่องรูปจริง บอกผมถ้าเจออันแปลก"

### 4.5.2 หา ratio ของแต่ละช่อง

ใช้กฎเดียวกับ Step 3.2.1 (class > inline CSS > snap > default ตามชื่อ)

### 4.5.3 แสดง list ให้ student

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🖼️ ตรวจช่องรูปในเว็บ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

เจอช่องว่าง 3 ช่อง

1. hero-portrait
   📐 ตั้ง 9:16
   💬 รูปผู้หญิงไทยกำลังชงกาแฟ (จาก placeholder)
   📍 index.html

2. testi-1
   📐 จัตุรัส 1:1
   💬 รูปลูกค้ายิ้ม
   📍 index.html

3. work-1
   📐 นอน 16:9
   💬 ผลงานก่อน-หลัง
   📍 pages/work.html

อยากใส่รูปช่องไหนก่อนคะ/ครับ?
ลากไฟล์รูปเข้ามาให้ path ขึ้น (หรือบอก path / เซฟลงโฟลเดอร์โปรเจกต์ก่อน) พร้อมบอกหมายเลขช่อง
เช่น "ช่อง 1" (วางภาพ preview ในแชทเฉยๆ ใช้ไม่ได้นะคะ/ครับ ต้องเป็นไฟล์)
```

### 4.5.4 รับ input แล้วส่งต่อ Mode B

เมื่อ student ลากรูป + ระบุช่อง

```python
target_slot = empty_slots[choice - 1]['id']
target_ratio = empty_slots[choice - 1]['ratio']
# เรียก Mode B Step 4.1-4.6 ด้วย input + target_slot
```

ทำต่อจน list หมด หรือ student บอก "พอแล้ว"

### 4.5.5 ถ้าไม่มีช่องว่างเลย

แจ้ง

> "เว็บคุณใส่รูปครบทุกช่องแล้วนะคะ/ครับ ✅
> ถ้าอยากเปลี่ยนรูปช่องไหน ส่งไฟล์รูป (ลากไฟล์ให้ path ขึ้น หรือเซฟลงโฟลเดอร์ก่อน) พร้อมบอกชื่อช่อง เช่น `เปลี่ยน hero-portrait` ได้เลย"

---

## Step 5 รายงาน Student

### Format Plain Thai

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🖼️ ใส่รูปจริงในเว็บแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ รูปที่ 1 hero-portrait
   ต้นฉบับ 4.2 MB (4032×3024)
   ปรับให้พอดี 180 KB (1200×1500)
   ลดลง 96%

✅ รูปที่ 2 testi-1
   ขนาดดีอยู่แล้ว ปรับเล็กน้อยให้ตรง slot
   ปัจจุบัน 320 KB (1200×1200)

[ฯลฯ]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 ไฟล์รูปเก็บไว้ที่
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assets/images/hero-portrait.jpg
assets/images/testi-1.jpg
assets/images/testi-2.jpg
assets/images/testi-3.jpg

ถ้าวันหลังอยากเปลี่ยนรูปไหน แค่เปลี่ยนไฟล์ในนี้
ชื่อเดียวกัน ไม่ต้องแก้ HTML

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ลบสิ่งที่ไม่ต้องการแล้ว
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ลบ .image-slots.state.json (ไม่ต้องใช้แล้ว)
✅ ลบ image-slot.js (ไม่ต้องใช้แล้ว)
✅ HTML สะอาด ใช้ <img> มาตรฐาน

```

---

## Step 6 Verify

ตรวจหลัง process

```
✅ assets/images/ มีไฟล์ครบทุก slot
✅ HTML <img> tag ครบทุก slot
✅ ไม่มี <image-slot> เหลืออยู่
✅ ไม่มี state.json
✅ <script src="image-slot.js"> หายไป
```

---

## Edge cases

### state.json มี slot แต่ไม่มี dataUrl

```python
if not state[slot_id].get('u'):
    # slot ว่าง student ยังไม่ได้ใส่รูป
    # keep <image-slot> ไว้แสดง placeholder
    continue
```

แจ้ง student "slot นี้ยังไม่มีรูป ถ้าอยากใส่ ส่งไฟล์รูป (path หรือเซฟลงโฟลเดอร์ก่อน) แล้ว /web-images ใหม่"

### Pillow install fail

Fallback macOS

```bash
sips -Z 1200 input.jpg --out output.jpg
sips -s formatOptions 85 output.jpg
```

Fallback Win
แจ้ง student "ติดตั้ง Python จาก python.org แล้วลองใหม่"

### รูปเสีย/decode fail

```python
try:
    img = Image.open(BytesIO(binary))
    img.verify()
except Exception as e:
    # log + skip slot
    failed.append(slot_id)
```

แจ้ง student "รูปใน slot [id] เสีย ใช้ไม่ได้ ส่งไฟล์รูปใหม่ (path หรือเซฟลงโฟลเดอร์ก่อน)"

### Plan mode

ถ้า plan mode `ExitPlanMode` ก่อน apply changes

---

## สิ่งที่ต้องระวัง

- **Auto-install Pillow ไม่ถาม student**
- **เก็บ original ไว้ก่อนถ้าจำเป็น** (สำหรับ Mode B student อาจอยากใช้ original ที่อื่น)
- **ห้าม overwrite ไฟล์ student โดยไม่ถาม** ถ้า assets/images/[id].jpg มีอยู่แล้ว ถามก่อน
- **EXIF rotation ต้อง strip + apply** ไม่งั้นรูปแสดงผิดด้าน
- **HEIC convert** ต้องเป็น JPEG หรือ WebP เพราะ HEIC ไม่ universal
- **ห้ามทำลาย parent CSS classes** keep div parent ของ image-slot ไว้
- **Cleanup state.json + image-slot.js** เพื่อ production-ready (Cloudflare Pages ไม่ต้องเสีย bandwidth กับ 31KB JS ที่ไม่ใช้)
- **Replace_all ใน HTML ระวัง** image-slot ของ slot id ต่างกันใช้ Edit แยก
- **ถ้า Mode B ไม่ระบุ target_slot** auto-trigger Mode C scan ก่อน (Step 4.1) ให้นักเรียนเลือกช่องจาก list แล้วกลับมาทำ Mode B พร้อม target_slot อย่า save เป็น `optimized.jpg` ลอย ๆ เพราะนักเรียนไม่รู้จะใส่ตรงไหน

---

## Public API สำหรับ caller (web-import web-finish)

### invoke จาก skill อื่น

```
Skill(web-images)
   พร้อม context "process all images in current project"
   → Mode A automatic ถ้ามี state.json
```

หรือ

```
Skill(web-images)
   พร้อม context "optimize C:/Downloads/photo.jpg for slot hero-portrait"
   → Mode B single file
```

### Return values

หลัง process จบ skill จะ return list ของ
- ไฟล์ที่ save
- size before/after
- slot ที่ replace
- error ถ้ามี

ให้ caller ใช้ต่อ
