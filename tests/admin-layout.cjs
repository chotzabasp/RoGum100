const fs=require('node:fs');
const assert=require('node:assert/strict');
const baseline=fs.readFileSync(0,'utf8');
const current=fs.readFileSync('index.html','utf8');
function section(html){return html.split('<section id="view-admin"')[1].split('</section>')[0];}
function hooks(html){return [...section(html).matchAll(/(?:id|data-admin-tab)="([^"]+)"/g)].map(m=>m[0]).filter(v=>v!=='id="adminStatusLabel"').sort();}
assert.deepEqual(hooks(current),hooks(baseline));
assert.match(current,/for="adminQrSearch"/);
assert.match(current,/for="adminQrRange"/);
console.log('PASS admin layout: existing IDs and tab hooks preserved, visible filter labels present');
