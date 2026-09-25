const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const source = fs.readFileSync('assets/app.js', 'utf8');
const ctx = {
  App: { keys: { merchantLog: 'readability-fixture' } },
  historyState: { serverId: 'all', category: 'all', range: 'all', search: '', expanded: {}, soldOutOpen: null },
  recentNewGroupIds: { oversold: true },
  soldNewSeen: {},
  fmtNum: String,
  historyGroupImagePath: group => group.imagePath || '',
  itemNameWithSlots: name => name,
  ITEM_IMAGE_ICON: '<span class="item-img-ico"></span>',
  itemImageNameHtml: (path, name) => (path ? '<span class="item-img-ico"></span>' : '') + name,
  escapeHtml: value => String(value).replaceAll('&', '&amp;').replaceAll('"', '&quot;'),
  historyCategoryTag: category => '<span class="mr-cat-tag" data-test-category="' + category + '">' + category + '</span>',
  historyServerTag: server => '<span class="mr-cat-tag" data-test-server="' + server + '">' + server + '</span>',
  historyTxGroupedByDayHtml: group => '<div data-test-day="' + group.key + '"></div>',
  historyEmptyHtml: () => '<empty>',
  hydrateItemThumbs: () => {}
};
vm.createContext(ctx);
const rowStart = source.indexOf('  function historyItemRowHtml(');
const rowEnd = source.indexOf('  // Presentation only: keep cards', rowStart);
const categoriesStart = source.indexOf('  function historyCategoryIcon(');
const categoriesEnd = source.indexOf('  function renderMerchantHistory(', categoriesStart);
assert.ok(rowStart >= 0 && rowEnd > rowStart && categoriesStart >= 0 && categoriesEnd > categoriesStart, 'Production renderer boundaries exist');
vm.runInContext(source.slice(rowStart, rowEnd) + source.slice(categoriesStart, categoriesEnd), ctx);

const item = {
  key: 'item|server-a', category: 'item', name: 'Fixture item', serverId: 'server-a',
  buyQty: 5, buyBaht: 125, sellQty: 2, sellBaht: 80, remaining: 3, leftCost: 75, profit: 30
};
function row(overrides = {}, showServer = true) {
  return ctx.historyItemRowHtml({ ...item, ...overrides }, showServer, 0);
}
function compact(html) {
  const match = html.match(/<span class="mr-compact-metrics">([\s\S]*?)<\/button>/);
  assert.ok(match, 'Item/other compact summary exists');
  return match[1];
}
function has(html, fragment, message) {
  assert.ok(html.includes(fragment), message || fragment);
}

const positive = row();
has(compact(positive), '<span class="mr-compact-remaining"><span>คงเหลือ</span> <b>3 ชิ้น</b></span>');
has(compact(positive), '<span class="mr-compact-profit"><span>กำไร</span> <b class="profit-pos">+30 บ</b></span>');
for (const fragment of [
  '<i>ซื้อมา</i><b>5 ชิ้น</b><small>-125 บ</small>',
  '<i>ขายไป</i><b>2 ชิ้น</b><small>80 บ</small>',
  '<i>เหลือ</i><b>3 ชิ้น</b><small>ทุนค้าง ~75 บ</small>',
  'เฉลี่ย 25บ/ชิ้น', 'เฉลี่ย 40บ/ชิ้น',
  '<b class="profit-pos">+30 บ</b>',
  'data-key="item%7Cserver-a"', 'class="mr-ic-head" aria-expanded="false"',
  '<div class="mr-ic-body" hidden>', 'data-test-day="item|server-a"',
  'class="mr-history-server"', 'data-test-server="server-a"'
]) has(positive, fragment);
assert.ok(!positive.includes('data-test-category="item"'), 'Redundant Item type badge is removed');
assert.ok(!row({}, false).includes('mr-history-server'), 'Single-server view still omits the server subtitle');

const negative = row({ key: 'loss', category: 'other', profit: -20 });
has(compact(negative), '<b class="profit-neg">-20 บ</b>');
has(negative, 'data-test-category="other"', 'Other category badge remains');
const breakEven = row({ key: 'zero-profit', remaining: 0, leftCost: 0, buyQty: 2, buyBaht: 40, sellQty: 2, sellBaht: 40, profit: 0 });
has(compact(breakEven), '<span>คงเหลือ</span> <b>0 ชิ้น</b>');
has(compact(breakEven), '<b class="profit-pos">+0 บ</b>');
has(breakEven, 'class="mr-it-cell left zero"');
has(breakEven, '<small>ขายหมดแล้ว</small>');
const unsold = row({ key: 'unsold', sellQty: 0, sellBaht: 0, profit: 0 });
has(compact(unsold), '<span class="mr-compact-profit"><span>กำไร</span> <b class="">—</b></span>');
has(unsold, '<span class="mr-it-cell profit none"><i>กำไร</i><b>—</b><small>ยังไม่ได้ขาย</small>');
const oversold = row({ key: 'oversold', remaining: -2, profit: -10 });
has(compact(oversold), '<span>คงเหลือ</span> <b>0 ชิ้น</b>', 'Negative inventory display stays clamped to zero');
has(compact(oversold), 'mr-compact-warning">ขายเกินที่ซื้อ 2 ชิ้น');
has(oversold, 'mr-ic-new-badge">New');

ctx.historyState.expanded[item.key] = true;
const expanded = row();
has(expanded, 'history-alt-odd open"');
has(expanded, 'aria-expanded="true"');
has(expanded, '<div class="mr-ic-body"><div data-test-day="item|server-a">');
assert.ok(!expanded.includes('<div class="mr-ic-body" hidden>'));
has(expanded, '<i>ซื้อมา</i><b>5 ชิ้น</b><small>-125 บ</small>');
delete ctx.historyState.expanded[item.key];

const image = row({ imagePath: 'fixture/item.png' });
has(image, 'class="item-img-ico"');
has(image, 'class="mr-history-thumb" data-thumb-path="fixture/item.png" alt="" loading="lazy"');
const zeny = row({ key: 'money', category: 'zeny', name: 'Zeny' });
has(zeny, '<span class="chip">M</span>');
has(zeny, '<i>ซื้อมา</i><b>5 M</b><small>-125 บ</small>');
assert.ok(!zeny.includes('mr-compact-metrics'), 'Zeny keeps its full summary');

const active = Array.from({ length: 12 }, (_, index) => ({ ...item, key: 'active-' + index }));
const sold = Array.from({ length: 12 }, (_, index) => ({ ...item, key: 'sold-' + index, remaining: 0, leftCost: 0, profit: 5 }));
ctx.computeHistoryItemGroups = () => [...active, ...sold];
ctx.resetHistoryPagingForFilters();
const list = {};
ctx.renderHistoryItemView(list);
has(list.innerHTML, 'data-history-section="active-item"');
has(list.innerHTML, 'data-history-section="sold-item"');
assert.equal((list.innerHTML.match(/class="mr-history-count">12 รายการ/g) || []).length, 2, 'Each category count covers all entries');
assert.equal((list.innerHTML.match(/data-key="/g) || []).length, 20, 'Ten active and ten sold cards render');
has(list.innerHTML, 'ขายหมดแล้ว 12 รายการ');
has(list.innerHTML, 'กำไรรวม +60 บ', 'Archive total includes all pages');
has(list.innerHTML, 'id="mrItSoldList" hidden', 'Archive stays collapsed while active inventory exists');
has(list.innerHTML, 'data-history-size="active-item"');
has(list.innerHTML, 'data-history-page="sold-item"');
ctx.historyPaging.pages['active-item'] = 2;
ctx.renderHistoryItemView(list);
has(list.innerHTML, '11–12 จาก 12 รายการ');
has(list.innerHTML, '1–10 จาก 12 รายการ', 'Sold pagination is independent');
assert.equal((list.innerHTML.match(/data-key="/g) || []).length, 12);
has(ctx.historyCategoryRowsHtml([item], true), '<span>1 / 1</span>', 'Existing single-page controls remain');
ctx.computeHistoryItemGroups = () => sold;
ctx.renderHistoryItemView(list);
has(list.innerHTML, 'id="mrItSoldList"><', 'Archive auto-opens when no active inventory remains');

console.log('PASS: readability markup preserves values, profit states, warning/New/server/image/disclosure hooks, category counts and pagination');
