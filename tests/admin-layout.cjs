const fs=require('node:fs');
const assert=require('node:assert/strict');
const baseline=fs.readFileSync(0,'utf8');
const current=fs.readFileSync('app.html','utf8');
function section(html){return html.split('<section id="view-admin"')[1].split('</section>')[0];}
function hooks(html){return [...section(html).matchAll(/(?:id|data-admin-tab)="([^"]+)"/g)].map(m=>m[0]).filter(v=>v!=='id="adminStatusLabel"').sort();}
// 2026-10-06: ประวัติการลบบัญชีขยะในแท็บสมาชิก (SQL 20261006000200) — ID ใหม่ที่ตั้งใจเพิ่ม · ID เดิมทุกตัวต้องอยู่ครบ
const ADDED=['id="adminDeletions"','id="adminDeletionsList"'];
assert.deepEqual(hooks(current).filter(h=>!ADDED.includes(h)),hooks(baseline).filter(h=>!ADDED.includes(h)));
assert.match(current,/for="adminQrSearch"/);
assert.match(current,/for="adminQrRange"/);
console.log('PASS admin layout: existing IDs and tab hooks preserved, visible filter labels present');
