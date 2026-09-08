# /connect-repo

เชื่อมต่อโฟลเดอร์กับ GitHub อัตโนมัติ นักเรียนไม่ต้องพิมพ์คำสั่งใดเลย

## Usage

```
/connect-repo <github-repo-url>
```

## กฎหลัก
- สื่อสารภาษาไทยเสมอ ห้ามให้นักเรียนเห็น error — แก้เองก่อนเสมอ
- **ตรวจผลลัพธ์จริงทุกคำสั่ง** ก่อนไปต่อ ห้ามรายงานสำเร็จโดยไม่ตรวจ
- **Windows** → ใช้ `PowerShell` tool, ห้ามใช้ `&&`, รันแยกทีละคำสั่ง, ใช้ `Set-Location` แทน `cd`
- **macOS** → ใช้ `Bash` tool, ใช้ `&&` และ `cd` ได้ปกติ

---

## ขั้นตอนที่ 1 — ตรวจ OS

| OS | คำสั่ง | ผลที่ต้องได้ |
|----|--------|-------------|
| Windows (PowerShell) | `$env:OS` | `Windows_NT` |
| macOS (Bash) | `uname -s` | `Darwin` |
| macOS CPU | `uname -m` | `arm64` = Apple Silicon / `x86_64` = Intel |

ใช้ tool และคำสั่งตาม OS นั้นตลอด

---

## ขั้นตอนที่ 2 — Git

รัน `git --version` → ถ้าได้ version ข้ามได้เลย

### ถ้ายังไม่มี Git

**Windows — ตรวจ winget ก่อน:** รัน `winget --version`
| ผลลัพธ์ winget | การติดตั้ง Git |
|--------------|----------------|
| มี version (เช่น `v1.x`) | `winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements` → reload PATH* → `git --version` ยืนยัน |
| ไม่พบ / error | เปิด Microsoft Store ติดตั้ง "App Installer" หรือใช้ fallback ด้านล่าง |
| ติดตั้งผ่าน winget แล้ว `git` ยังไม่เจอ | Fallback: `Start-Process "https://git-scm.com/download/win"` → แจ้งนักเรียน "กรุณาติดตั้ง Git จากหน้าเว็บที่เปิดขึ้น แล้ว **ปิด-เปิด** หน้าต่างนี้ใหม่นะคะ/ครับ" → หยุดรอ |

*reload PATH (Windows): `$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")`

**macOS:**
1. ตรวจ Homebrew: `brew --version`
2. ถ้าไม่มี: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
   - Apple Silicon: รัน `eval "$(/opt/homebrew/bin/brew shellenv)"` หลังติดตั้ง
3. `brew install git`
4. Fallback ถ้า brew ล้มเหลว: `xcode-select --install`

ยืนยันด้วย `git --version` ก่อนไปต่อ — **ห้ามข้าม**

---

## ขั้นตอนที่ 3 — GitHub CLI

รัน `gh --version` → ถ้าได้ version ข้ามได้เลย

| OS | ติดตั้ง | Fallback |
|----|---------|---------|
| Windows | `winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements` แล้ว reload PATH* | `winget upgrade winget` แล้วลองใหม่ / ถ้ายังไม่ผ่าน เปิด `Start-Process "https://cli.github.com/"` |
| macOS | Apple Silicon: `eval "$(/opt/homebrew/bin/brew shellenv)"` ก่อน แล้ว `brew install gh` | `brew update && brew install gh` |

ยืนยันด้วย `gh --version` ก่อนไปต่อ

---

## ขั้นตอนที่ 4 — GitHub Login

รัน `gh auth status` → ถ้าเห็น `Logged in to github.com` ข้ามได้เลย

ถ้ายังไม่ login: รัน `gh auth login --web` → แจ้งนักเรียน "จะมีหน้าเว็บเปิดขึ้นมา ให้กด Authorize นะคะ/ครับ"
- รอจนเสร็จ แล้วรัน `gh auth status` ยืนยันอีกครั้ง
- ถ้ายังไม่ผ่าน: `gh auth login --git-protocol https --web`

---

## ขั้นตอนที่ 5 — Git Config

รัน `git config --global user.name` และ `git config --global user.email`
- ถ้าว่าง: ถามนักเรียน แล้วรัน `git config --global user.name "ชื่อ"` / `git config --global user.email "อีเมล"`
- รัน `git config --global user.name` และ `git config --global user.email` อีกครั้งเพื่อยืนยัน

---

## ขั้นตอนที่ 6 — เชื่อมต่อ (รันทีละคำสั่ง ตรวจผลทุกครั้ง)

**6.1 `git init`**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `Initialized` หรือ `Reinitialized` | ✅ ผ่าน |
| `already a git repository` | ✅ ข้ามได้ |
| `permission denied` (Win) | `attrib -r "." /s /d` แล้วลองใหม่ |
| `permission denied` (mac) | `chmod 755 .` แล้วลองใหม่ |

**6.2 `git branch -M main`**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| ไม่มี output | ✅ ผ่าน |
| `not a valid object` | ยังไม่มี commit → ไปทำ 6.4 ก่อน แล้วกลับมาทำ 6.2 |

**6.3 `git remote add origin <url>`**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| ไม่มี output | ✅ ผ่าน — ยืนยันด้วย `git remote -v` |
| `already exists` | `git remote set-url origin <url>` |
| URL ผิด / ไม่ขึ้นต้น `https://github.com/` | `git remote remove origin` แล้ว `git remote add origin <url ที่แก้แล้ว>` |

**6.4 `git add .` แล้ว `git commit -m "first commit"`**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `[main (root-commit) ...]` | ✅ ผ่าน |
| `nothing to commit` | ✅ ผ่าน |
| `unsafe directory` | `git config --global --add safe.directory "<path>"` แล้วลองใหม่ |
| `Author identity unknown` | set `user.name` และ `user.email` แล้วลองใหม่ |
| CRLF warning | ✅ warning ปกติ ผ่านได้ |

**6.5 `git ls-remote origin HEAD` — ตรวจก่อน push**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| มี hash เช่น `a1b2c3... HEAD` | pull ก่อน: `git pull origin main --allow-unrelated-histories` |
| ↳ pull แล้ว merge conflict | `git checkout --theirs .` → `git add .` → `git commit -m "merge remote"` |
| ↳ `couldn't find remote ref main` | `git pull origin master --allow-unrelated-histories` → `git branch -M main` |
| ไม่มี output | ✅ repo ว่าง ข้ามการ pull |
| `authentication` error | `gh auth login --web` แล้วลองใหม่ |

**6.6 `git push -u origin main`**
| ผลลัพธ์ | การแก้ไข |
|---------|---------|
| `set up to track remote branch 'main'` | ✅ ผ่าน |
| `rejected / non-fast-forward` | `git pull origin main --allow-unrelated-histories` แล้ว push ใหม่ |
| `authentication failed` | `gh auth login --web` → `git remote set-url origin https://github.com/<user>/<repo>.git` → push ใหม่ |
| `src refspec main does not match` | ยังไม่มี commit → กลับไปทำ 6.4 |
| `timeout` / `Could not resolve host` | ตรวจเน็ต: Win `Test-NetConnection github.com -Port 443` / mac `curl -I https://github.com` → รอ 30 วิ แล้ว push ใหม่ |

---

## ขั้นตอนที่ 7 — Verification (ห้ามข้าม)

รันทั้ง 4 คำสั่ง ถ้าข้อใดไม่ผ่านให้แก้แล้วตรวจซ้ำทั้งหมด

| คำสั่ง | ต้องเห็น | ถ้าไม่ผ่าน |
|--------|---------|-----------|
| `git remote -v` | `origin` ชี้ URL ของนักเรียน | `git remote add origin <url>` หรือ `set-url` |
| `git log --oneline -1` | commit อย่างน้อย 1 อัน | กลับไปทำ 6.4 |
| `git ls-remote origin HEAD` | hash กลับมา เช่น `a1b2c3... HEAD` | `git push -u origin main` แล้วตรวจซ้ำ |
| `git status` | `up to date with 'origin/main'` | `git push` ถ้า ahead / `git checkout -b main && git push -u origin main` ถ้า detached HEAD |

ผ่านทั้ง 4 → ไปขั้นตอนที่ 8

---

## ขั้นตอนที่ 8 — แจ้งสำเร็จ

"เสร็จแล้วค่ะ/ครับ! 🎉 โฟลเดอร์ของคุณเชื่อมต่อกับ GitHub เรียบร้อยแล้ว ไฟล์ทุกอย่างถูกบันทึกออนไลน์ที่ [repo URL] แล้วนะคะ/ครับ ต่อไปนี้งานของคุณจะปลอดภัยบนอินเทอร์เน็ตแล้ว ไม่ต้องกลัวไฟล์หายอีกต่อไปนะคะ/ครับ! 😊"
