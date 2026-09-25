// Compare rendered content and purchase hooks with the pre-polish Git baseline.
// Isolated renderer only: never loads the app, network, auth, or payment handlers.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
// Run: git show ea5e476c0fec88e2c99a413efd4617225afb568d:assets/app.js | node tests/pricing-presentation.cjs
const baseline = fs.readFileSync(0,'utf8');
assert.ok(baseline.includes('var PRICING_PLANS ='), 'Pipe baseline app.js through stdin');
const current = fs.readFileSync('assets/app.js','utf8');
function render(source, cycle, promo, owned, details) {
  const grid = {innerHTML:''};
  const context = {
    document:{getElementById:()=>grid},
    escapeHtml:s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'),
    fmtNum:n=>Number(n).toLocaleString('en-US'), fmtDate:()=> 'DATE',
    planActiveUntil:()=>owned, isPromoActive:()=>promo,
    App:{profile:null}
  };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf('  var PRICING_PLANS ='),source.indexOf('  // วันสิ้นสุดโปร')),context);
  context.pricingCycle=cycle; context.pricingDetailsOpen=details;
  const start=source.indexOf('  function renderPricingPage(){');
  const end=source.indexOf("  document.getElementById('pricingGrid').addEventListener",start);
  vm.runInContext(source.slice(start,end)+'\nrenderPricingPage();',context);
  return grid.innerHTML;
}
const text = html=>html.replace(/<[^>]*>/g,' ').replace(/—/g,'').replace(/\s+/g,' ').trim();
const hooks = html=>html.match(/<button[^>]*>/g);
let cases=0;
for(const cycle of ['monthly','yearly']) for(const promo of [true,false])
for(const owned of [0,Infinity,Date.now()+86400000]) for(const details of [true,false]){
  const before=render(baseline,cycle,promo,owned,details);
  const after=render(current,cycle,promo,owned,details);
  assert.equal(text(after),text(before),'All visible content must be preserved except decorative dashes');
  assert.deepEqual(hooks(after),hooks(before),'Button state and purchase data must be unchanged');
  assert.equal((after.match(/class="pricing-promo-heading"/g)||[]).length,6);
  cases++;
}
console.log(`PASS pricing presentation: ${cases} monthly/yearly, promo, ownership and disclosure cases`);
