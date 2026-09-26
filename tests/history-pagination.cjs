const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('assets/app.js','utf8');
const ctx={App:{keys:{merchantLog:'account-a'}},historyState:{serverId:'s',category:'all',range:'today',search:''},historyItemRowHtml:g=>`[row:${g.key}]`};
vm.createContext(ctx);
vm.runInContext(source.slice(source.indexOf('  function historyCategoryIcon('),source.indexOf('  function renderHistoryItemView(')),ctx);
const rows=Array.from({length:24},(_,n)=>({key:String(n+1),category:'item'}));
ctx.resetHistoryPagingForFilters();
let html=ctx.historyCategoryRowsHtml(rows,false);
assert.equal((html.match(/\[row:/g)||[]).length,10);
assert.ok(html.includes('1–10 จาก 24'));
ctx.historyPaging.pages['active-item']=3;
html=ctx.historyCategoryRowsHtml(rows,false);
assert.equal((html.match(/\[row:/g)||[]).length,4);
assert.ok(html.includes('[row:24]')&&!html.includes('[row:1]'));
assert.ok(ctx.historyCategoryRowsHtml(rows,false,'sold').includes('1–10 จาก 24'));
ctx.historyPaging.sizes['active-item']=20;ctx.historyPaging.pages['active-item']=1;
assert.equal(ctx.historyPageWindow(rows,'active-item').rows.length,20);
ctx.historyPaging.sizes['active-item']=50;
assert.equal(ctx.historyPageWindow(rows,'active-item').rows.length,24);
ctx.historyPaging.sizes['active-item']=20;
ctx.historyPaging.pages['active-item']=9;
assert.equal(ctx.historyPageWindow(rows.slice(0,3),'active-item').page,1,'Clamp after deletion');
for(const field of ['search','range','category','serverId']){
  ctx.historyPaging.pages['active-item']=2;ctx.historyState[field]+='changed';ctx.resetHistoryPagingForFilters();
  assert.equal(ctx.historyPaging.pages['active-item'],undefined,field+' resets pages');
}
ctx.historyPaging.pages['active-item']=2;ctx.App.keys.merchantLog='account-b';ctx.resetHistoryPagingForFilters();
assert.equal(ctx.historyPaging.pages['active-item'],undefined);
assert.equal(ctx.historyCategoryRowsHtml([],false),'');
const zeny=rows.map(g=>({...g,category:'zeny'}));
assert.equal((ctx.historyCategoryRowsHtml(zeny,true).match(/\[row:/g)||[]).length,24,'Zeny stays unpaginated across servers');
// Render receives a full filtered group list, preserving aggregate archive profit.
ctx.computeHistoryItemGroups=()=>rows.map(g=>({...g,sellQty:1,remaining:0,profit:5}));
ctx.historyEmptyHtml=()=>'<empty>';ctx.recentNewGroupIds={};ctx.soldNewSeen={};ctx.hydrateItemThumbs=()=>{};ctx.fmtNum=String;
vm.runInContext(source.slice(source.indexOf('  function renderHistoryItemView('),source.indexOf('  function renderMerchantHistory(')),ctx);
const list={};ctx.renderHistoryItemView(list);
assert.ok(list.innerHTML.includes('กำไรรวม +120 บ'),'Archive aggregate includes all 24 rows');
// The real row renderer preserves warning and New in the compact summary.
Object.assign(ctx,{historyState:{expanded:{}},fmtNum:String,historyGroupImagePath:()=>'',itemImageNameHtml:(_p,n)=>n,itemNameWithSlots:n=>n,historyCategoryTag:()=>'',historyServerTag:()=>'',historyTxGroupedByDayHtml:()=>'<day>',recentNewGroupIds:{warn:true}});
vm.runInContext(source.slice(source.indexOf('  function historyItemRowHtml('),source.indexOf('  // Presentation only: keep cards')),ctx);
const warningRow=ctx.historyItemRowHtml({key:'warn',category:'item',name:'sample',remaining:-2,buyQty:1,buyBaht:10,sellQty:3,sellBaht:20,profit:-10,leftCost:0},false,0);
assert.ok(warningRow.includes('mr-compact-warning">ขายเกินที่ซื้อ 2 ชิ้น'));
assert.ok(warningRow.includes('mr-ic-new-badge">ล่าสุด'));
assert.ok(warningRow.includes('profit-neg">-10 บ'));
console.log('PASS: 10/20 paging, last page, independent sold pages, deletion clamp, filters/account reset, Zeny and full archive totals');
