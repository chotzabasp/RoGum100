const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('assets/app.js', 'utf8');
const saves = {};
let click;
const soldList = {hidden:true};
const ctx = {
  App:{keys:{recentNewGroup:'groups',recentNewTx:'tx',soldNewSeen:'sold'}},
  recentNewGroupIds:{sold:true,active:true}, recentNewTxIds:{tx1:true}, soldNewSeen:{},
  historyState:{expanded:{},expandedDays:{}}, historyDayTxIds:{day:['tx1']},
  persist:(key,value)=>{saves[key]=JSON.parse(JSON.stringify(value));},
  renderMerchantHistory:()=>{},
  computeHistoryItemGroups:()=>[{key:'sold',sellQty:1,remaining:0},{key:'active',sellQty:0,remaining:1}],
  document:{getElementById:id=>id==='mrItSoldList'?soldList:{addEventListener:(event,fn)=>{if(event==='click')click=fn;}}},
};
vm.createContext(ctx);
for(const name of ['saveRecentNewGroupIds','saveRecentNewTxIds','saveSoldNewSeen']){
  vm.runInContext(source.match(new RegExp('function '+name+'\\(\\)\\{[^\\n]+'))[0],ctx);
}
vm.runInContext(source.slice(source.indexOf('  function clearNewGroupIdsFor('),source.indexOf('  function onHistoryServerFilterChange(')),ctx);
const event = matches => ({target:{closest:selector=>matches[selector]||null}});
click(event({'#mrItSoldToggle':{}}));
assert.equal(ctx.soldNewSeen.sold,true);
assert.equal(ctx.soldNewSeen.active,undefined);
assert.equal(ctx.recentNewGroupIds.sold,true,'Opening archive must preserve child New');
assert.equal(ctx.recentNewTxIds.tx1,true,'Opening archive must preserve date New');
assert.equal(saves.sold.sold,true,'Acknowledgement must persist per account');
const cardBody = {hidden:true};
const card = {dataset:{key:'sold'},classList:{toggle(){}},querySelector:s=>s==='.mr-ic-body'?cardBody:{setAttribute(){}}};
click(event({'.mr-it-row.mr-ic':card}));
assert.equal(ctx.recentNewGroupIds.sold,undefined);
assert.equal(ctx.recentNewTxIds.tx1,true);
assert.equal(cardBody.hidden,false);
const dayRows = {hidden:true};
const day = {dataset:{dayKey:'day'},classList:{contains:()=>false,toggle(){}},querySelector:()=>dayRows};
click(event({'.mr-ic-day-head':{closest:()=>day,setAttribute(){}}}));
assert.equal(ctx.recentNewTxIds.tx1,undefined);
assert.equal(dayRows.hidden,false);
// Execute the production new-entry marking block to verify a new record resets acknowledgement.
ctx.lines=[{name:'item'}];ctx.newEntry={serverId:'server',category:'item',id:'next'};
const key='server|item|item|[]';ctx.soldNewSeen[key]=true;
const normalized=source.replace(/\r\n/g,'\n');
const markingStart=normalized.indexOf('    lines.forEach(function(l){\n      var histKey');
assert.ok(markingStart>=0);
vm.runInContext(normalized.slice(markingStart,normalized.indexOf('    renderMerchantHistory();',markingStart)),ctx);
assert.equal(ctx.soldNewSeen[key],undefined);
assert.equal(ctx.recentNewGroupIds[key],true);
assert.equal(ctx.recentNewTxIds.next,true);
console.log('PASS: archive/card/day acknowledgement, account persistence and new-record reset');
