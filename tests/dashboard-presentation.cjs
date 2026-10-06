// Supply the original admin.html on stdin, e.g.:
// git show HEAD:admin.html | node tests/dashboard-presentation.cjs
// Local source/VM checks only: all authentication, RPCs, timers and charts are mocked.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const baseline = fs.readFileSync(0, 'utf8').replace(/\r\n/g, '\n');
const current = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8').replace(/\r\n/g, '\n');
assert.ok(baseline.includes('function renderPlans(r)'), 'Pass baseline admin.html on stdin (UTF-8)');
let checks = 0;

function markup(html) {
  return html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '');
}
function elements(html) {
  return [...markup(html).matchAll(/<([a-z][\w-]*)\b([^>]*?)>/gi)].map(match => {
    const attrs = {};
    for (const attr of match[2].matchAll(/([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) {
      attrs[attr[1]] = attr[2] ?? attr[3] ?? attr[4] ?? '';
    }
    return { tag: match[1].toLowerCase(), attrs };
  });
}
function inlineScript(html) {
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
    .filter(match => !/\bsrc\s*=/.test(match[1]));
  assert.equal(scripts.length, 1, 'Exactly one dashboard inline script');
  return scripts[0][2];
}
const before = elements(baseline);
const after = elements(current);
const originalIds = before.filter(e => e.attrs.id).map(e => e.attrs.id);
const allIds = after.filter(e => e.attrs.id).map(e => e.attrs.id);
assert.equal(new Set(allIds).size, allIds.length, 'No duplicate IDs');
for (const previous of before.filter(e => e.attrs.id)) {
  const id = previous.attrs.id;
  const next = after.find(e => e.attrs.id === id);
  assert.ok(next, `Preserve ID ${id}`);
  assert.equal(next.tag, previous.tag, `${id}: preserve element type`);
  for (const cls of (previous.attrs.class || '').split(/\s+/).filter(Boolean)) {
    assert.ok((next.attrs.class || '').split(/\s+/).includes(cls), `${id}: preserve class ${cls}`);
  }
  for (const attr of ['hidden', 'disabled', 'readonly', 'type', 'href', 'role']) {
    assert.equal(next.attrs[attr], previous.attrs[attr], `${id}: preserve ${attr}`);
  }
  for (const [attr, value] of Object.entries(previous.attrs).filter(([key]) => key.startsWith('data-'))) {
    assert.equal(next.attrs[attr], value, `${id}: preserve ${attr}`);
  }
}
const rangeButtons = html => {
  const group = markup(html).match(/<div\b[^>]*\bid="rangeSeg"[^>]*>([\s\S]*?)<\/div>/);
  assert.ok(group, 'Range group with its buttons remains available');
  return elements(group[1]).filter(e => e.tag === 'button').map(e => ({
    days: e.attrs['data-days'], type: e.attrs.type, active: (e.attrs.class || '').split(/\s+/).includes('active')
  }));
};
assert.deepEqual(rangeButtons(current), rangeButtons(baseline), 'Range values and initial selection unchanged');
checks++;

const tick = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
function harness(html) {
  const nodes = {};
  for (const { attrs } of elements(html).filter(e => e.attrs.id || e.attrs['data-days'])) {
    const node = {
      id: attrs.id, dataset: { days: attrs['data-days'] }, className: attrs.class || '',
      hidden: Object.hasOwn(attrs, 'hidden'), disabled: Object.hasOwn(attrs, 'disabled'),
      textContent: '', innerHTML: '', handlers: {},
      addEventListener(type, handler) { this.handlers[type] = handler; },
      querySelectorAll() { return buttons; }
    };
    node.classList = { toggle(cls, enabled) {
      const classes = new Set(node.className.split(/\s+/).filter(Boolean));
      if (enabled) classes.add(cls); else classes.delete(cls);
      node.className = [...classes].join(' ');
    } };
    nodes[attrs.id || `range-${attrs['data-days']}`] = node;
  }
  const buttons = ['7', '30', '90'].map(days => nodes[`range-${days}`]);
  const rpc = [], intervals = [];
  let resolveAuth;
  const supa = {
    auth: { getSession: () => new Promise(resolve => { resolveAuth = resolve; }) },
    rpc(name, args) {
      return new Promise((resolve, reject) => rpc.push({ name, args: JSON.parse(JSON.stringify(args)), resolve, reject }));
    }
  };
  class FixedDate extends Date {
    constructor(...args) { super(...(args.length ? args : ['2026-09-26T06:00:00Z'])); }
    static now() { return Date.parse('2026-09-26T06:00:00Z'); }
  }
  const charts = [];
  function Chart(node, config) { charts.push({ id: node.id, config }); this.destroy = () => {}; }
  const context = vm.createContext({
    Date: FixedDate, console, Chart,
    window: { Chart, supabase: { createClient: () => supa } },
    document: { hidden: false, documentElement: {}, getElementById: id => nodes[id] || null },
    getComputedStyle: () => ({ getPropertyValue: () => '#6ea8ff' }),
    setInterval: (callback, delay) => intervals.push({ callback, delay })
  });
  const script = inlineScript(html);
  const functionNames = [...script.matchAll(/^  function (\w+)\(/gm)].map(m => m[1]);
  const expose = `\nglobalThis.dashboardTest = { state, loading: () => loading, ${functionNames.join(', ')} };\n`;
  assert.match(script, /\}\)\(\);\s*$/, 'Dashboard closure boundary exists');
  vm.runInContext(script.replace(/\}\)\(\);\s*$/, expose + '})();'), context, { timeout: 1500 });
  return {
    api: context.dashboardTest, context, nodes, buttons, rpc, intervals, charts, script,
    async auth(session) { resolveAuth({ data: { session } }); await tick(); },
    async respond(name, value, reject = false) {
      const call = rpc.find(call => call.name === name && !call.settled);
      assert.ok(call, `Pending mocked RPC ${name}`);
      call.settled = true;
      call[reject ? 'reject' : 'resolve'](value);
      await tick();
    }
  };
}
const reference = harness(baseline);
const modified = harness(current);
const presentationFunctions = ['renderPlans', 'renderDevicesErrors', 'renderTraffic'];
function withoutPresentation(h) {
  let script = h.script;
  for (const name of presentationFunctions) {
    script = script.replace(h.api[name].toString(), `function ${name}(){ /* presentation */ }`);
  }
  // The only permitted chart-option edit is the requested tick typography.
  const chartOptions = h.api.baseOptions.toString();
  script = script.replace(chartOptions, chartOptions.replace(/font:\{ family:'(?:JetBrains Mono|Inter)', size:(?:10|12) \}/g, 'font:{ /* tick typography */ }'));
  return script;
}
// 2026-09-28 live strip ("ตอนนี้", admin_live) + usage cards (admin_usage) are purely additive: their
// self-contained functions/state, the exact hook lines that call them, and new explanatory comment lines are
// removed before comparing. Every other line (including every existing comment) must still match the baseline.
const addedFunctions = ['rpcMissing', 'fmt1', 'hourRange', 'blockRange', 'minutesHtml', 'renderLive', 'loadLive', 'fetchUsage', 'showUsage', 'renderUsage',
  // 2026-10-06 รายงานรายวัน (admin_day_report): การ์ดใหม่แยกจากช่วง 7/30/90 วัน — ฟังก์ชัน/บรรทัดเรียกของมันตัดออกก่อนเทียบเหมือนกัน
  'bkkDateIso', 'shiftIso', 'fmtTimeBkk', 'fmtDayBkk', 'sourceLabel', 'deltaHtml', 'syncDayControls', 'loadDay', 'renderDay', 'initDayControls', 'dayTodayIso', 'dayTick'];
const addedCode = [
  'var live = { busy:false, off:false, shown:false };',
  'var usage = { seq:0, off:false };',
  'var usageJob = fetchUsage();',
  'showUsage(usageJob);',
  "$('refreshBtn').addEventListener('click', loadLive);",
  'setInterval(function(){ if(!document.hidden && state.data) loadLive(); }, 60000);',
  'loadLive();',
  'var day = { pick:null, seq:0, off:false, shown:undefined, offset:0 };',
  'initDayControls();',
  "$('refreshBtn').addEventListener('click', loadDay);",
  'setInterval(function(){ if(!document.hidden && state.data) dayTick(); }, 300000);',
  'loadDay();'
];
// 2026-09-29 audit fixes (intentional; behavior asserted at the end): expiring plans count Bangkok calendar days,
// a lost session (42501) gets its own state, and "not installed" needs PGRST202 and no longer names the old SQL files.
// Only these exact edits are mapped back to the original lines; everything else must still match.
const auditFunctions = ['bkkDay', 'fmtDateBkk'];
const auditAdded = [
  "else if(res.error.code === '42501' || /permission denied|JWT/i.test(msg)) showState('เซสชันหมดอายุ', 'ล็อกอินด้วยบัญชีแอดมินที่หน้าเว็บอีกครั้ง แล้วกลับมารีเฟรชหน้านี้', 'ไปหน้าเว็บเพื่อล็อกอิน');"
];
const auditEdits = [
  ['var days = Math.max(0, Math.ceil((new Date(x.expires_at).getTime() - Date.now()) / 86400000));',
   'var days = Math.max(0, bkkDay(new Date(x.expires_at).getTime()) - bkkDay(Date.now()));'],
  [`'<div class="row-side"><b>' + (days === 0 ? 'วันนี้' : 'อีก ' + days + ' วัน') + '</b>' + fmtDate(x.expires_at) + '</div></div>';`,
   `'<div class="row-side"><b>' + (days === 0 ? 'วันนี้' : 'อีก ' + days + ' วัน') + '</b>' + fmtDateBkk(x.expires_at) + '</div></div>';`],
  ["else if(/admin_dashboard|function|does not exist|schema cache/i.test(msg)) showState('ยังไม่ได้ติดตั้งฟังก์ชันสรุปข้อมูล', 'ต้องรันไฟล์ SQL 20260924000300_admin_dashboard.sql ใน Supabase ก่อน');",
   "else if(res.error.code === 'PGRST202') showState('ยังไม่ได้ติดตั้งฟังก์ชันสรุปข้อมูล', 'ต้องรันไฟล์ migration ล่าสุดของ admin_dashboard ใน Supabase ก่อน');"],
  ['renderTraffic(tr && tr.data, tmsg ? (/admin_traffic|function|does not exist|schema cache/i.test(tmsg)',
   "renderTraffic(tr && tr.data, tmsg ? (tr.error.code === 'PGRST202'"],
  ["? 'ยังไม่ได้ติดตั้งระบบเก็บการเข้าชม — รันไฟล์ SQL 20260924000400_app_events.sql ใน Supabase ก่อน'",
   "? 'ยังไม่ได้ติดตั้งระบบเก็บการเข้าชม — รันไฟล์ migration ล่าสุดของ admin_traffic ใน Supabase ก่อน'"]
];
const referenceComments = new Set(reference.script.split('\n').map(line => line.trim()).filter(line => line.startsWith('//')));
function comparableSource(h) {
  let script = withoutPresentation(h);
  for (const name of [...addedFunctions, ...auditFunctions]) {
    if (typeof h.api[name] === 'function') script = script.replace(h.api[name].toString(), '');
  }
  return script.split('\n').filter(line => {
    const t = line.trim();
    return t && !addedCode.includes(t) && !auditAdded.includes(t) && !(t.startsWith('//') && !referenceComments.has(t));
  }).map(line => {
    const edit = auditEdits.find(([, next]) => line.trim() === next);
    return edit ? line.slice(0, line.length - line.trimStart().length) + edit[0] : line;
  }).join('\n');
}
for (const line of addedCode) {
  assert.equal(modified.script.split('\n').filter(l => l.trim() === line).length, 1, `Added hook appears exactly once: ${line}`);
}
for (const line of [...auditAdded, ...auditEdits.map(([, next]) => next)]) {
  assert.equal(modified.script.split('\n').filter(l => l.trim() === line).length, 1, `Audit edit appears exactly once: ${line}`);
}
assert.equal(comparableSource(modified), comparableSource(reference),
  'Auth/client configuration, fetching, handlers, calculations and other renderers unchanged');
checks++;

const plain = value => JSON.parse(JSON.stringify(value));
// Analytics parts (live strip / usage cards / landing block, added 2026-09-28) are checked by their own assertions
// below; once they are in the baseline, later intentional edits to them must not fail the unchanged-cards comparison.
const ANALYTICS_IDS = ['liveStrip', 'liveTiles', 'liveSince', 'liveStatus', 'usageRow', 'usagePeak', 'usageNote', 'usageStats',
  'chartHours', 'landingBlock', 'landingSince', 'landingStats', 'usageLegend'];
function snapshot(h, ids = originalIds.filter(id => !['plans', 'plansNote'].includes(id) && !ANALYTICS_IDS.includes(id))) {
  return Object.fromEntries(ids.map(id => {
    const n = h.nodes[id];
    return [id, { text: n.textContent, html: n.innerHTML, hidden: n.hidden, disabled: n.disabled, classes: n.className }];
  }));
}
// The two analytics RPCs added 2026-09-28 are asserted separately below; the existing RPC contract must not change.
const NEW_RPCS = ['admin_live', 'admin_usage', 'admin_day_report'];
const existingCalls = h => h.rpc.filter(call => !NEW_RPCS.includes(call.name)).map(({ name, args }) => ({ name, args }));
function compare(a, b, label) {
  assert.deepEqual(snapshot(b), snapshot(a), label);
  assert.deepEqual(existingCalls(b), existingCalls(a), `${label}: RPC contract`);
  assert.equal(b.api.loading(), a.api.loading(), `${label}: loading guard`);
  checks++;
}
function planValues(html) {
  return [...html.matchAll(/<div class="plan(?:\s[^"]*)?"[^>]*>([\s\S]*?)(?=<div class="plan(?:\s[^"]*)?"|$)/g)].map(m => {
    const card = m[1];
    return {
      count: card.match(/class="plan-count"[^>]*>([\s\S]*?)<\/div>/)?.[1].replace(/<[^>]*>/g, '').trim(),
      sales: [...(card.match(/class="plan-meta"[^>]*>([\s\S]*)/)?.[1] || '').matchAll(/<b[^>]*>([^<]*)<\/b>/g)].map(v => v[1]),
      width: card.match(/class="plan-bar"[^>]*><span style="width:([^";]*)/)?.[1],
      status: card.match(/class="pill (pill-ok|pill-mute)"/)?.[1]
    };
  });
}
for (const revenue of [
  {},
  { active_plans: { all: 12, bundle: '4', timers: 0, accountItems: 7, farm: 1 }, plan_sales: [
    { plan_key: 'all', count: '2', points: '400' }, { plan_key: 'all', count: 3, points: 750 },
    { plan_key: 'farm', count: 1, points: 100 }, { plan_key: 'unknown', count: 99, points: 9999 }
  ] },
  { active_plans: { timers: 25000 }, plan_sales: [{ plan_key: 'timers', count: 0, points: 0 }] }
]) {
  reference.api.renderPlans(revenue);
  modified.api.renderPlans(revenue);
  const previous = planValues(reference.nodes.plans.innerHTML);
  assert.equal(previous.length, 5, 'Reference has five plan cards');
  assert.deepEqual(planValues(modified.nodes.plans.innerHTML), previous, 'Active counts, sales sums, proportions and status classes unchanged');
  checks++;
}

const traffic = {
  visitors_today: 8, visitors_yesterday: 6, visitors_period: 22, members_period: 9,
  new_guest_visitors: 13, signups: 3, since: '2026-09-01T00:00:00Z',
  devices: [{ device: 'mobile', visitors: 15, signups: 2 }, { device: 'desktop', visitors: 7, signups: 1 }],
  errors_total: 17, errors: [{ kind: 'load', detail: '<test> & failed', count: 17, visitors: 4, pages: 'home, farm', last_at: '2026-09-26T05:00:00Z' }],
  series: [{ day: '2026-09-25', visitors: 22, members: 9 }],
  pages: [{ page: 'home', views: 30, visitors: 22, avg_seconds: 120, total_minutes: 60 }],
  funnel: { pricing_visitors: 10, clicked: 6, guest_clicked: 1, insufficient: 2, success: 4 },
  plans: [{ plan: 'all', clicks: 6, insufficient: 2, success: 4 }]
};
for (const [data, error] of [[traffic, ''], [{}, ''], [null, 'โหลดข้อมูลการเข้าชมไม่สำเร็จ: fixture error'], [null, '']]) {
  reference.api.renderTraffic(data, error);
  modified.api.renderTraffic(data, error);
  compare(reference, modified, 'Traffic metrics and existing success/empty/error states');
  assert.equal(modified.nodes.errorSummary.hidden, Boolean(error || !data), 'Summary hides when traffic is unavailable');
  if (data && !error) {
    assert.equal(modified.nodes.errorSummaryCount.textContent, modified.nodes.errorsTotal.textContent, 'Summary uses the same error total');
    assert.equal(modified.nodes.errorSummaryCount.className, modified.nodes.errorsTotal.className, 'Summary uses the same warning/zero state');
    assert.ok(modified.nodes.errorSummaryPeriod.textContent.includes(String(modified.api.state.days)), 'Summary identifies selected period');
  }
}
assert.match(modified.nodes.errorsTable.innerHTML, /ไม่มี error/, 'Zero-error table uses original empty state');
assert.ok(after.some(e => e.tag === 'a' && e.attrs.href === '#dashboardErrors'), 'Summary links to the existing error details');
assert.ok(after.some(e => e.attrs.id === 'dashboardErrors'), 'Error details anchor exists');

// 2026-09-28: admin_traffic may also return visitors_7d/members_7d and landing. The loop above proves the original
// tile is kept when they are absent (old SQL); here the extended card and its zero/empty states are checked.
modified.api.renderTraffic({ ...traffic, visitors_7d: 11, members_7d: 4, landing: {
  since: '2026-09-25T01:00:00Z', visitors_today: 2, visitors_period: 20, cta_period: 6, cta_signup: 4, cta_login: 2, to_app: 5, signups: 1 } }, '');
assert.ok(modified.nodes.trafficStats.innerHTML.includes('<b>11</b><span>ผู้เข้าชม 7 วัน</span><small>ล็อกอินแล้ว 4 คน</small>'), 'Fixed 7-day visitors tile');
assert.ok(!modified.nodes.trafficStats.innerHTML.includes('ผู้เข้าชม 30 วัน'), '7-day tile replaces the period tile when available');
assert.equal(modified.nodes.landingBlock.hidden, false, 'Landing block shows with landing data');
for (const text of [
  '<b>20</b><span>ผู้เข้าชมหน้าแรก</span><small>วันนี้ 2 คน</small>',
  '<b>6</b><span>กดปุ่มในหน้าแรก</span><small>สมัคร 4 · เข้าสู่ระบบ 2</small>',
  '<b>5</b><span>ไปต่อที่แอป</span><small>25.0% ของผู้เข้าชมหน้าแรก</small>',
  'class="stat hot"><b>1</b><span>สมัครสมาชิก</span><small>5.0% ของผู้เข้าชมหน้าแรก</small>'
]) assert.ok(modified.nodes.landingStats.innerHTML.includes(text), `Landing shows ${text}`);
assert.ok(modified.nodes.landingSince.textContent.startsWith('ช่วง 30 วัน · เริ่มเก็บ '), 'Landing note names the period and start date');
modified.api.renderTraffic({ ...traffic, visitors_7d: 0, members_7d: 0, landing: {
  since: null, visitors_today: 0, visitors_period: 0, cta_period: 0, cta_signup: 0, cta_login: 0, to_app: 0, signups: 0 } }, '');
assert.equal(modified.nodes.landingSince.textContent, 'ยังไม่มีข้อมูล — เริ่มนับหลังอัปเดตนี้', 'Landing empty note before tracking');
assert.ok(!/NaN|undefined|Infinity/.test(modified.nodes.landingStats.innerHTML + modified.nodes.trafficStats.innerHTML), 'Zero landing data shows 0, never NaN');
modified.api.renderTraffic(traffic, '');
assert.equal(modified.nodes.landingBlock.hidden, true, 'Old SQL without landing hides the landing block');
checks++;

(async () => {
  for (const scenario of ['guest', 'success', 'forbidden', 'missing-function', 'dashboard-reject', 'traffic-reject']) {
    const a = harness(baseline), b = harness(current);
    await a.auth(scenario === 'guest' ? null : { user: { id: 'local-test' } });
    await b.auth(scenario === 'guest' ? null : { user: { id: 'local-test' } });
    compare(a, b, `${scenario}: authentication/loading`);
    if (scenario === 'guest') { assert.equal(b.rpc.length, 0, 'Guest never fetches dashboard data'); continue; }
    assert.deepEqual(existingCalls(b).map(c => c.name), ['admin_traffic', 'admin_dashboard'], 'Existing summary RPCs unchanged');
    assert.deepEqual(b.rpc.filter(c => NEW_RPCS.includes(c.name)).map(({ name, args }) => ({ name, args })),
      [{ name: 'admin_usage', args: { p_days: 30 } }, { name: 'admin_live', args: {} }, { name: 'admin_day_report', args: {} }], 'Only the new analytics RPCs are added');
    a.api.load(); b.api.load();
    assert.equal(existingCalls(b).length, 2, 'Repeated refresh is ignored while loading');
    assert.equal(b.rpc.length, 5, 'Repeated refresh adds no analytics calls while loading');
    const dashboard = scenario === 'forbidden' ? { error: { message: 'สำหรับแอดมินเท่านั้น' } }
      // 2026-09-29 audit: PostgREST's real missing-function error (PGRST202) — "not installed" now requires that code
      : scenario === 'missing-function' ? { error: { code: 'PGRST202', message: 'Could not find the function public.admin_dashboard(p_days) in the schema cache' } }
      : scenario === 'dashboard-reject' ? { message: 'offline fixture' }
      : { data: { generated_at: '2026-09-26T05:00:00Z', kpi: { members: 20, paid_users: 4, active_7d: 7 }, revenue: {} } };
    for (const h of [a, b]) {
      await h.respond('admin_traffic', scenario === 'traffic-reject' ? { message: 'traffic fixture offline' } : { data: traffic }, scenario === 'traffic-reject');
      await h.respond('admin_dashboard', dashboard, scenario === 'dashboard-reject');
    }
    if (scenario === 'missing-function') {
      // 2026-09-29 audit: same state, but the hint no longer names the 2026-09-24 file (re-running it reverts newer versions)
      assert.equal(b.nodes.stateTitle.textContent, a.nodes.stateTitle.textContent, 'Missing function keeps the "not installed" title');
      assert.ok(!/20260924/.test(b.nodes.stateText.textContent) && b.nodes.stateText.textContent.includes('admin_dashboard'), 'Missing-function hint names no old SQL file');
      b.nodes.stateText.textContent = a.nodes.stateText.textContent;
    }
    compare(a, b, `${scenario}: settled state`);
    assert.equal(b.nodes.refreshBtn.disabled, false, 'Refresh re-enabled after settlement');
    if (scenario === 'success') {
      const chartData = h => plain(h.charts.map(({ id, config }) => ({ id, type: config.type, data: config.data })));
      assert.deepEqual(chartData(b), chartData(a), 'Chart series and values unchanged');
      assert.equal(b.intervals[0].delay, 300000, 'Refresh interval stays five minutes');
      // Settle the first live call so a (wrong) live re-fetch on range change would be visible below.
      await b.respond('admin_live', { data: {} });
      // Pre-launch zero/empty data: friendly text, never NaN/undefined.
      assert.equal(b.nodes.liveSince.hidden, false, 'Tracking-start note shows before any heartbeat');
      assert.ok(b.nodes.liveTiles.innerHTML.includes('>0<small>คน</small>') && !/NaN|undefined/.test(b.nodes.liveTiles.innerHTML), 'Empty live data renders zeros');
      await b.respond('admin_usage', { data: { days: 30, effective_days: 1, tracking_since: null, hours: [], avg_minutes_per_day: 0, retention: {} } });
      assert.equal(b.nodes.usagePeak.innerHTML, '<span>ยังไม่มีข้อมูล</span>', 'Empty usage hero');
      assert.ok(b.nodes.usageStats.innerHTML.includes('ยังไม่มีคนสมัครในช่วงนี้') && !/NaN|undefined/.test(b.nodes.usageStats.innerHTML), 'Empty usage stats');
      for (const h of [a, b]) {
        const calls = h.rpc.length;
        h.context.document.hidden = true; h.intervals.forEach(interval => interval.callback());
        assert.equal(existingCalls(h).length, 2, 'Hidden document does not refresh');
        assert.equal(h.rpc.length, calls, 'Hidden document does not refresh (any timer)');
        h.context.document.hidden = false;
        h.nodes.rangeSeg.handlers.click.call(h.nodes.rangeSeg, { target: { closest: () => h.buttons[0] } });
      }
      compare(a, b, 'Changing period preserves handlers and RPC parameters');
      assert.deepEqual(existingCalls(b).slice(2).map(c => c.args), [{ p_days: 7 }, { p_days: 7 }]);
      assert.deepEqual(b.rpc.filter(c => c.name === 'admin_usage').map(c => c.args), [{ p_days: 30 }, { p_days: 7 }], 'Usage follows the selected period');
      assert.equal(b.rpc.filter(c => c.name === 'admin_live').length, 1, 'Changing period does not re-fetch the live strip');
      assert.equal(b.rpc.filter(c => c.name === 'admin_day_report').length, 1, 'Changing period does not re-fetch the daily report');
    }
    if (scenario === 'traffic-reject') {
      assert.equal(b.nodes.dash.hidden, false, 'Traffic failure leaves the main dashboard visible');
      assert.equal(b.nodes.trafficDetail2.hidden, true, 'Traffic failure hides traffic details');
    }
  }

  // 2026-09-28 additions: live strip (admin_live, every minute) and usage cards (admin_usage, per period).
  // They render from their own RPCs, hide when those functions are missing, and never change the existing cards.
  {
    const a = harness(baseline), b = harness(current);
    const session = { user: { id: 'local-test' } };
    await a.auth(session); await b.auth(session);
    assert.equal(b.nodes.liveStrip.hidden, true, 'Live strip stays hidden until data arrives');
    assert.equal(b.nodes.usageRow.hidden, true, 'Usage row stays hidden until data arrives');
    const dashboard = { data: { generated_at: '2026-09-26T05:00:00Z', kpi: { members: 20, paid_users: 4, active_7d: 7 }, revenue: {} } };
    const hours = Array.from({ length: 24 }, (_, hour) => ({
      hour, avg_users: hour === 20 ? 4.5 : hour === 9 ? 1 : 0, total: hour === 20 ? 14 : hour === 9 ? 3 : 0 }));
    const usageData = { days: 30, effective_days: 3, tracking_since: '2026-09-24T00:00:00Z', hours, avg_minutes_per_day: 75.4,
      retention: { d1_eligible: 8, d1_returned: 3, d7_eligible: 0, d7_returned: 0 } };
    const liveData = { generated_at: '2026-09-26T05:59:00Z', tracking_since: '2026-09-24T00:00:00Z', online_now: 5, online_visible: 3,
      online_pages: [{ page: 'timers', count: 4 }, { page: '-', count: 1 }], online_devices: [{ device: 'mobile', count: 5 }],
      today_users: 9, yesterday_users: 7, today_paid: 2, today_legacy: 0, today_free: 7, peak_hour: 23, peak_users: 4, avg_minutes_today: 12.5,
      parties: { total: 3, locked: 1, active_today: 2, locked_hosts: [{ name: '<i>Host</i>', members: 2, expired_at: '2026-09-20T00:00:00Z' }] } };
    for (const h of [a, b]) { await h.respond('admin_traffic', { data: traffic }); await h.respond('admin_dashboard', dashboard); }
    await b.respond('admin_usage', { data: usageData });
    await b.respond('admin_live', { data: liveData });
    compare(a, b, 'New analytics leave existing cards unchanged');

    const tiles = b.nodes.liveTiles.innerHTML;
    assert.equal(b.nodes.liveStrip.hidden, false, 'Live strip shows once admin_live answers');
    assert.equal(b.nodes.liveSince.hidden, true, 'Tracking note hidden once tracking has started');
    for (const text of ['ออนไลน์ตอนนี้', '>5<small>คน</small>', 'เปิดดูอยู่ 3 · เปิดทิ้งไว้ 2', 'จับเวลาบอส 4', 'ไม่ทราบหน้า 1',
      'เมื่อวาน 7', 'จ่ายเงิน 2 · ฟรี 7<', '12.5<small>นาที/คน</small>',
      'ใช้งานวันนี้ 2 · ถูกล็อก <span class="pill pill-danger">1</span>', 'หัวปาร์ตี้ที่ถูกล็อก: ', '&lt;i&gt;Host&lt;/i&gt; (2 คน)']) {
      assert.ok(tiles.includes(text), `Live tiles show ${text}`);
    }
    assert.ok(!tiles.includes('สิทธิเดิม'), 'Legacy count only shown when above zero');
    assert.ok(!tiles.includes('ช่วงพีควันนี้') && (tiles.match(/class="live-tile/g) || []).length === 4, 'Live strip has 4 tiles (no peak tile)');
    assert.ok(!/NaN|undefined|<i>/.test(tiles), 'Live tiles never show NaN/undefined or raw names');

    assert.equal(b.nodes.usageRow.hidden, false, 'Usage row shows once admin_usage answers');
    const hoursChart = b.charts.filter(c => c.id === 'chartHours').pop();
    assert.ok(hoursChart, 'Hourly chart drawn');
    assert.deepEqual(plain(hoursChart.config.data.labels), Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0')), 'Hour labels 00-23');
    const colors = hoursChart.config.data.datasets[0].backgroundColor;
    assert.ok(colors[20] !== colors[9] && colors.filter(c => c === colors[20]).length === 1, 'Only the peak hour is highlighted');
    assert.equal(hoursChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 20 }), ' 20.00–21.00 · เฉลี่ย 4.5 คน/วัน (รวม 14 ครั้ง)');
    assert.ok(b.nodes.usagePeak.innerHTML.includes('<b>20.00–21.00</b>') && b.nodes.usagePeak.innerHTML.includes('เฉลี่ย 4.5 คน/วัน'), 'Peak hero line');
    assert.equal(b.nodes.usageNote.textContent, 'เฉลี่ยต่อวันจาก 3 วันที่มีข้อมูลในช่วง 30 วัน · นับเฉพาะที่ล็อกอิน');
    b.api.renderUsage({ ...usageData, blocks: Array.from({ length: 8 }, (_, block) => ({ block, start_hour: block * 3, end_hour: block * 3 + 3,
      avg_users: block === 6 ? 4.5 : block === 3 ? 1 : 0, total: block === 6 ? 14 : block === 3 ? 3 : 0 })) });
    const blocksChart = b.charts.filter(c => c.id === 'chartHours').pop();
    assert.deepEqual(plain(blocksChart.config.data.labels), Array.from({ length: 8 }, (_, i) =>
      [String(i * 3).padStart(2, '0') + '.00–', String(i * 3 + 3).padStart(2, '0') + '.00']), 'Block labels 00.00–03.00 … 21.00–24.00');
    const blockColors = blocksChart.config.data.datasets[0].backgroundColor;
    assert.ok(blockColors[6] !== blockColors[3] && blockColors.filter(c => c === blockColors[6]).length === 1, 'Only the peak block is highlighted');
    assert.equal(blocksChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 6 }), ' 18.00–21.00 · เฉลี่ย 4.5 คน/วัน');
    assert.ok(b.nodes.usagePeak.innerHTML.includes('<b>18.00–21.00</b>'), 'Peak hero names the 3-hour block');
    assert.equal(blocksChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 7 }), ' 21.00–24.00 · เฉลี่ย 0 คน/วัน');
    // จำนวนคนจริง (SQL 20260928000400): แท่ง = คนไม่ซ้ำต่อช่วง · % = ชั่วโมงใช้งาน · หัวการ์ดบอกช่วงคนใช้มากสุด/เงียบสุด
    b.api.renderUsage({ ...usageData, people_total: 14, blocks: Array.from({ length: 8 }, (_, block) => ({ block, start_hour: block * 3, end_hour: block * 3 + 3,
      avg_users: 0, total: 0, people: [1, 0, 0, 3, 4, 5, 12, 6][block], user_hours: [1, 0, 0, 4, 6, 8, 21, 10][block] })) });
    const peopleChart = b.charts.filter(c => c.id === 'chartHours').pop();
    assert.deepEqual(plain(peopleChart.config.data.datasets[0].data), [1, 0, 0, 3, 4, 5, 12, 6], 'Bars show real people counts');
    const peopleColors = peopleChart.config.data.datasets[0].backgroundColor;
    assert.ok(peopleColors.filter(c => c === peopleColors[6]).length === 1, 'Only the busiest block is highlighted');
    assert.equal(peopleChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 6 }), ' 18.00–21.00 · 12 คน · 42% ของการใช้งาน');
    assert.ok(b.nodes.usagePeak.innerHTML.includes('<span>คนใช้มากสุด</span><b>18.00–21.00</b><span>· 12 คน (42%)</span>'), 'Busiest block with people and share');
    assert.ok(b.nodes.usagePeak.innerHTML.includes('เงียบสุด 03.00–06.00 · 0 คน'), 'Quietest block (first of ties)');
    assert.equal(b.nodes.usageNote.textContent, 'จำนวนคนที่เข้าใช้ในแต่ละช่วง ตลอด 30 วันที่เลือก (ทั้งหมด 14 คน) · นับเฉพาะที่ล็อกอิน');
    assert.equal(b.nodes.usageLegend.textContent, 'จำนวนคน');
    b.api.renderUsage({ ...usageData, people_total: 0, blocks: Array.from({ length: 8 }, (_, block) => ({ block, avg_users: 0, total: 0, people: 0, user_hours: 0 })) });
    assert.equal(b.nodes.usagePeak.innerHTML, '<span>ยังไม่มีข้อมูล</span>', 'No usage yet');
    assert.equal(peopleChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 0 }).includes('NaN'), false);
    for (const text of ['<b>38%</b><span>กลับมาวันถัดไป</span><small>3 จาก 8 คนที่สมัครในช่วงนี้</small>',
      '<b>—</b><span>กลับมาภายใน 7 วัน</span><small>ยังไม่มีคนสมัครครบ 7 วัน</small>', '<b>1<small>ชม.</small> 15<small>นาที/คน/วัน</small></b>']) {
      assert.ok(b.nodes.usageStats.innerHTML.includes(text), `Usage stats show ${text}`);
    }

    // Live polling: every minute while visible, never while hidden, and stops for good once admin_live is missing.
    const livePoll = b.intervals.find(i => i.delay === 60000);
    assert.ok(livePoll, 'Live strip polls every minute');
    const liveCalls = () => b.rpc.filter(c => c.name === 'admin_live').length;
    b.context.document.hidden = true; livePoll.callback();
    assert.equal(liveCalls(), 1, 'Hidden document does not poll live numbers');
    b.context.document.hidden = false; livePoll.callback();
    assert.equal(liveCalls(), 2, 'Visible document polls live numbers');
    await b.respond('admin_live', { error: { code: 'PGRST202', message: 'Could not find the function public.admin_live without parameters in the schema cache' } });
    assert.equal(b.nodes.liveStrip.hidden, true, 'Missing admin_live hides the strip');
    livePoll.callback();
    assert.equal(liveCalls(), 2, 'Missing admin_live stops polling');

    // Missing admin_usage hides only its row and later loads skip it; the rest of the dashboard keeps working.
    a.api.load(); b.api.load();
    for (const h of [a, b]) await h.respond('admin_traffic', { data: traffic });
    await b.respond('admin_usage', { error: { code: 'PGRST202', message: 'Could not find the function public.admin_usage(p_days) in the schema cache' } });
    for (const h of [a, b]) await h.respond('admin_dashboard', dashboard);
    compare(a, b, 'Missing analytics functions leave existing cards unchanged');
    assert.equal(b.nodes.usageRow.hidden, true, 'Missing admin_usage hides the usage row');
    assert.equal(b.nodes.dash.hidden, false, 'Dashboard stays visible without the new functions');
    b.api.load();
    assert.equal(b.rpc.filter(c => c.name === 'admin_usage').length, 2, 'Missing admin_usage is not requested again');
    checks++;
  }

  // 2026-09-29 audit fixes: signed out while the page stays open → anon gets 42501 "permission denied for function …".
  // That is a lost session (not "not installed", no old SQL file names) and must not switch the live strip off for good.
  {
    const b = harness(current);
    await b.auth({ user: { id: 'local-test' } });
    await b.respond('admin_traffic', { data: traffic });
    await b.respond('admin_dashboard', { error: { code: '42501', message: 'permission denied for function admin_dashboard' } });
    assert.equal(b.nodes.stateTitle.textContent, 'เซสชันหมดอายุ', 'Lost session gets its own state');
    assert.equal(b.nodes.stateLink.hidden, false, 'Lost session offers the login link');
    assert.equal(b.nodes.dash.hidden, true, 'Lost session hides the dashboard');
    await b.respond('admin_live', { error: { code: '42501', message: 'permission denied for function admin_live' } });
    b.api.loadLive();
    assert.equal(b.rpc.filter(c => c.name === 'admin_live').length, 2, 'Permission denied does not stop the live strip');
    const dashboard = { data: { generated_at: '2026-09-26T05:00:00Z', kpi: {}, revenue: {} } };
    b.api.load();
    await b.respond('admin_traffic', { error: { code: '42883', message: 'function public.foo() does not exist' } });
    await b.respond('admin_dashboard', dashboard);
    assert.equal(b.nodes.trafficEmpty.textContent, 'โหลดข้อมูลการเข้าชมไม่สำเร็จ: function public.foo() does not exist', 'Only PGRST202 means not installed');
    b.api.load();
    await b.respond('admin_traffic', { error: { code: 'PGRST202', message: 'Could not find the function public.admin_traffic(p_days) in the schema cache' } });
    await b.respond('admin_dashboard', dashboard);
    assert.ok(b.nodes.trafficEmpty.textContent.startsWith('ยังไม่ได้ติดตั้งระบบเก็บการเข้าชม') && !/20260924/.test(b.nodes.trafficEmpty.textContent), 'Traffic hint names no old SQL file');

    // Expiring plans count Bangkok calendar days (fixed now = 26 ก.ย. 13:00 เวลาไทย): 2 h → วันนี้, 25 h → อีก 1 วัน.
    b.api.renderExpiring([
      { name: 'a', username: 'a', plan: 'p', expires_at: '2026-09-26T08:00:00Z' },
      { name: 'b', username: 'b', plan: 'p', expires_at: '2026-09-26T17:30:00Z' },
      { name: 'c', username: 'c', plan: 'p', expires_at: '2026-09-27T07:00:00Z' },
      { name: 'd', username: 'd', plan: 'p', expires_at: '2026-09-29T16:59:00Z' }
    ]);
    const rows = b.nodes.expiring.innerHTML.split('<div class="row" ').slice(1);
    assert.deepEqual(rows.map(r => r.match(/<b>([^<]*)<\/b>/)[1]), ['วันนี้', 'อีก 1 วัน', 'อีก 1 วัน', 'อีก 3 วัน'], 'Days left by Bangkok date');
    assert.ok(rows[1].includes('27 ก.ย.'), 'Date label uses the Bangkok date');
    assert.deepEqual(rows.map(r => r.includes('var(--danger)')), [true, true, true, false], 'Red stripe for today to 2 days');
    checks++;
  }
  // 2026-10-06 รายงานรายวัน (admin_day_report): ตัวเลขวันที่เลือกเทียบวันก่อนหน้า + รายชั่วโมง + แหล่งที่มา · เลือกวัน · ไม่มีฟังก์ชัน = ซ่อน
  {
    const b = harness(current);
    await b.auth({ user: { id: 'local-test' } });
    assert.equal(b.nodes.dayReport.hidden, true, 'Daily report hidden until data arrives');
    await b.respond('admin_traffic', { data: traffic });
    await b.respond('admin_dashboard', { data: { generated_at: '2026-09-26T05:00:00Z', kpi: {}, revenue: {} } });
    assert.deepEqual(b.rpc.filter(c => c.name === 'admin_day_report').map(c => c.args), [{}], 'Today = no p_day');
    assert.equal(b.nodes.dayPicker.value, '2026-09-26', 'Picker shows the Bangkok date');
    assert.equal(b.nodes.dayPicker.max, '2026-09-26', 'Picker cannot pick the future');
    assert.equal(b.nodes.dayPicker.min, '2026-04-01', 'Picker limited to 178 days (the comparison day stays complete)');
    const dayData = {
      generated_at: '2026-09-26T06:00:00Z', day: '2026-09-26', is_today: true, window_end: '2026-09-26T06:00:00Z',
      prev_day: '2026-09-25', prev_end: '2026-09-25T06:00:00Z', tracking_since: '2026-09-24T00:00:00Z', sources_since: '2026-09-26T01:00:00Z',
      cur: { visitors: 12, landing_visitors: 8, app_visitors: 7, new_visitors: 5, signup_clicks: 3, signups: 3, signups_confirmed: 2, signups_new: 2,
             active_members: 4, pricing_visitors: 3, buy_clicks: 2, purchases: 1, purchase_points: 149, revenue: 300, topups: 2 },
      prev: { visitors: 9, landing_visitors: 6, app_visitors: 5, new_visitors: 4, signup_clicks: 1, signups: 1, signups_confirmed: 1, signups_new: 1,
              active_members: 4, pricing_visitors: 1, buy_clicks: 0, purchases: 0, purchase_points: 0, revenue: 0, topups: 0 },
      hours: Array.from({ length: 24 }, (_, hour) => ({ hour, future: hour > 13, visitors: hour === 10 ? 5 : hour === 13 ? 2 : 0,
                                                        prev_visitors: hour === 10 ? 3 : 1, signups: hour === 10 ? 2 : 0 })),
      sources: [{ source: 'tag:fb0610', visitors: 6, signup_clicks: 2, buyers: 1 }, { source: 'direct', visitors: 4, signup_clicks: 1, buyers: 0 },
                { source: '?', visitors: 1, signup_clicks: 0, buyers: 0 }, { source: 'ref:example.com', visitors: 1, signup_clicks: 0, buyers: 0 },
                { source: '*', visitors: 1, signup_clicks: 0, buyers: 0 }, { source: 'email', visitors: 1, signup_clicks: 0, buyers: 0 }]
    };
    await b.respond('admin_day_report', { data: dayData });
    assert.equal(b.nodes.dayReport.hidden, false, 'Daily report shows once admin_day_report answers');
    const stats = b.nodes.dayStats.innerHTML;
    for (const text of [
      '<b>12</b><span>ผู้เข้าชม</span><small><span class="delta up">▲ +3</span>เมื่อวานช่วงเดียวกัน 9<br>หน้าแรก 8 · ในแอป 7</small>',
      'class="stat hot"><b>3</b><span>สมัครสมาชิก</span><small><span class="delta up">▲ +2</span>เมื่อวานช่วงเดียวกัน 1<br>ยืนยันอีเมลแล้ว 2 · ยังไม่ยืนยัน 1</small>',
      '<b>4</b><span>สมาชิกที่ใช้งาน</span><small><span class="delta flat">± 0</span>',
      '<b>300<small>บาท</small></b><span>รายได้</span>', 'เติมเงิน 2 ครั้ง', '<b>1<small>ครั้ง</small></b><span>ซื้อแพ็กเกจ</span>', 'ใช้ 149 แต้ม',
      '<b>40.0%</b><span>สมัครต่อผู้เข้าชมใหม่</span><small>เมื่อวานช่วงเดียวกัน 25.0%</small>'
    ]) assert.ok(stats.includes(text), `Daily tiles show ${text}`);
    assert.equal((stats.match(/class="stat/g) || []).length, 8, 'Eight daily tiles');
    assert.ok(b.nodes.dayCompare.textContent.includes('ถึง 13:00 น.') && b.nodes.dayCompare.textContent.includes('เทียบเมื่อวาน 00:00–13:00 น.'),
      'Today compares with yesterday up to the same time');
    const dayChart = b.charts.filter(c => c.id === 'chartDayHours').pop();
    assert.ok(dayChart, 'Hourly chart drawn');
    assert.equal(dayChart.config.data.labels.length, 24, '24 hourly labels');
    assert.equal(dayChart.config.data.labels[9], '09:00', 'Hour labels 00:00-23:00');
    assert.equal(dayChart.config.data.datasets[0].data[10], 5, 'Visitors bar per hour');
    assert.equal(dayChart.config.data.datasets[0].data[14], null, 'Hours still to come stay empty');
    assert.equal(dayChart.config.data.datasets[1].data[10], 2, 'Sign-ups bar per hour');
    assert.equal(dayChart.config.data.datasets[2].type, 'line', 'Previous day is a line');
    assert.deepEqual(plain(dayChart.config.data.datasets[2].borderDash), [5, 4], 'Previous day line is dashed');
    assert.equal(dayChart.config.data.datasets[2].data[14], 1, 'Previous day line covers the whole day');
    const sources = b.nodes.daySources.innerHTML;
    for (const text of ['<td>ป้ายลิงก์ fb0610</td><td class="num">6<span class="day-share">43%</span></td><td class="num">2</td><td class="num">1</td>',
      '<td>เข้าตรง / ไม่ทราบที่มา</td>', '<td>ไม่ทราบที่มา (เปิดเว็บก่อนเริ่มเก็บ)</td>', '<td>เว็บ example.com</td>',
      '<td>อื่นๆ (รวมแหล่งที่เหลือ)</td>', '<td>ลิงก์ในอีเมล (ยืนยันอีเมล / ตั้งรหัสใหม่)</td>']) {
      assert.ok(sources.includes(text), `Sources show ${text}`);
    }
    assert.ok(b.nodes.daySourceHint.innerHTML.startsWith('เริ่มเก็บแหล่งที่มา ') && b.nodes.daySourceHint.innerHTML.includes('?src=fb0610'), 'Source hint');
    assert.ok(!/NaN|undefined|Infinity/.test(stats + sources + b.nodes.dayCompare.textContent), 'Daily report never shows NaN/undefined');
    b.api.renderDay({ ...dayData, cur: { ...dayData.cur, signups_new: undefined, signups: 9, new_visitors: 3 } });
    assert.ok(b.nodes.dayStats.innerHTML.includes('<b>100.0%</b><span>สมัครต่อผู้เข้าชมใหม่</span>'), 'Sign-up rate never above 100%');
    // ชื่อจากข้อมูลที่ผู้ใช้ส่งมาต้องถูก escape
    b.api.renderDay({ ...dayData, sources: [{ source: 'tag:<b>x', visitors: 1, signup_clicks: 0, buyers: 0 }] });
    assert.ok(b.nodes.daySources.innerHTML.includes('ป้ายลิงก์ &lt;b&gt;x') && !b.nodes.daySources.innerHTML.includes('<b>x'), 'Source names are escaped');
    b.api.renderDay({ ...dayData, cur: {}, prev: {}, hours: [], sources: [], sources_since: null });
    assert.ok(b.nodes.daySources.innerHTML.includes('ยังไม่มีผู้เข้าชมในวันนี้') &&
      b.nodes.daySourceHint.innerHTML.startsWith('แหล่งที่มาจะเริ่มนับหลังอัปเดตนี้'), 'Empty day');
    assert.ok(!/NaN|undefined|Infinity/.test(b.nodes.dayStats.innerHTML), 'Empty day shows zeros');

    // เลือก "เมื่อวาน" → p_day เมื่อวาน · เทียบวันก่อนหน้าทั้งวัน · ปุ่มที่เลือกเปลี่ยนตาม · ปุ่มช่วง 7/30/90 ไม่โดนแตะ
    b.nodes.daySeg.handlers.click.call(b.nodes.daySeg, { target: { closest: () => ({ dataset: { day: 'yesterday' } }) } });
    assert.deepEqual(b.rpc.filter(c => c.name === 'admin_day_report').map(c => c.args).pop(), { p_day: '2026-09-25' }, 'Yesterday sends p_day');
    assert.ok(b.nodes.dayYesterday.className.includes('active') && !b.nodes.dayToday.className.includes('active'), 'Yesterday button active');
    assert.deepEqual(b.buttons.map(x => x.className.includes('active')), [false, true, false], 'Range buttons untouched by the day controls');
    await b.respond('admin_day_report', { data: { ...dayData, day: '2026-09-25', is_today: false, window_end: '2026-09-25T17:00:00Z',
                                                  prev_day: '2026-09-24', prev_end: '2026-09-24T17:00:00Z' } });
    assert.ok(b.nodes.dayCompare.textContent.includes('ทั้งวัน') && b.nodes.dayCompare.textContent.includes('เทียบ '), 'Past day compares whole days');
    assert.ok(b.nodes.dayStats.innerHTML.includes('วันก่อน 9'), 'Past day tiles name the previous day');
    // ดูวันที่ผ่านมาแล้ว: ตัวจับเวลา 5 นาทีไม่ดึงซ้ำ · เลือกวันนี้จากปฏิทิน = กลับไปไม่ส่ง p_day
    const dayCalls = () => b.rpc.filter(c => c.name === 'admin_day_report').length;
    const dayPoll = b.intervals.filter(i => i.delay === 300000).pop();
    let n = dayCalls(); dayPoll.callback();
    assert.equal(dayCalls(), n, 'Past day is not polled');
    b.nodes.dayPicker.value = '2026-09-26';
    b.nodes.dayPicker.handlers.change.call(b.nodes.dayPicker);
    assert.deepEqual(b.rpc.filter(c => c.name === 'admin_day_report').map(c => c.args).pop(), {}, 'Picking today drops p_day');
    await b.respond('admin_day_report', { data: dayData });
    n = dayCalls(); dayPoll.callback();
    assert.equal(dayCalls(), n + 1, 'Today is polled every five minutes');
    b.context.document.hidden = true; dayPoll.callback(); b.context.document.hidden = false;
    assert.equal(dayCalls(), n + 1, 'Hidden document does not poll the daily report');
    await b.respond('admin_day_report', { data: dayData });
    // ผลของรอบเก่าที่มาช้าถูกทิ้ง
    b.nodes.daySeg.handlers.click.call(b.nodes.daySeg, { target: { closest: () => ({ dataset: { day: 'yesterday' } }) } });
    b.nodes.daySeg.handlers.click.call(b.nodes.daySeg, { target: { closest: () => ({ dataset: { day: 'today' } }) } });
    await b.respond('admin_day_report', { data: { ...dayData, cur: { ...dayData.cur, visitors: 77 } } });
    assert.ok(!b.nodes.dayStats.innerHTML.includes('<b>77</b>'), 'Late answer of an older request is ignored');
    await b.respond('admin_day_report', { error: { message: 'เลือกวันในอนาคตไม่ได้' } });
    assert.equal(b.nodes.dayStatus.textContent, ' · โหลดวันที่เลือกไม่สำเร็จ: เลือกวันในอนาคตไม่ได้ (ยังแสดงวันเดิม)', 'Errors are shown on the card');
    // เลือก "เมื่อวาน" แล้วโหลดไม่สำเร็จ → ปุ่ม/ปฏิทินย้อนกลับไปวันที่แสดงอยู่ (วันนี้)
    b.nodes.daySeg.handlers.click.call(b.nodes.daySeg, { target: { closest: () => ({ dataset: { day: 'yesterday' } }) } });
    await b.respond('admin_day_report', { error: { message: 'network down' } });
    assert.ok(b.nodes.dayToday.className.includes('active') && !b.nodes.dayYesterday.className.includes('active') && b.nodes.dayPicker.value === '2026-09-26',
      'Failed pick reverts the controls to the day on screen');
    // พิมพ์วันที่นอกช่วงเอง = ไม่ถาม
    n = dayCalls(); b.nodes.dayPicker.value = '2026-09-30'; b.nodes.dayPicker.handlers.change.call(b.nodes.dayPicker);
    assert.equal(dayCalls(), n, 'Out-of-range typed date is not requested');
    b.nodes.dayPicker.value = '2026-09-26';
    // นาฬิกาเครื่องช้ากว่าเซิร์ฟเวอร์ข้ามเที่ยงคืน: "วันนี้/เมื่อวาน" ใช้วันตามเซิร์ฟเวอร์
    b.api.loadDay();
    await b.respond('admin_day_report', { data: { ...dayData, generated_at: '2026-09-26T17:30:00Z', day: '2026-09-27' } });
    assert.equal(b.nodes.dayPicker.max, '2026-09-27', 'Picker max follows the server date');
    b.nodes.daySeg.handlers.click.call(b.nodes.daySeg, { target: { closest: () => ({ dataset: { day: 'yesterday' } }) } });
    assert.deepEqual(b.rpc.filter(c => c.name === 'admin_day_report').map(c => c.args).pop(), { p_day: '2026-09-26' }, 'Yesterday = server yesterday');
    await b.respond('admin_day_report', { data: { ...dayData, generated_at: '2026-09-26T17:31:00Z', day: '2026-09-26', is_today: false } });
    n = dayCalls(); dayPoll.callback();
    assert.equal(dayCalls(), n, 'Past day: the 5-minute tick only re-syncs the controls');
    assert.ok(b.nodes.dayYesterday.className.includes('active'), 'Tick keeps yesterday highlighted');
    // ยังไม่ได้รัน SQL: ซ่อนการ์ด เลิกดึง
    b.api.loadDay();
    await b.respond('admin_day_report', { error: { code: 'PGRST202', message: 'Could not find the function public.admin_day_report in the schema cache' } });
    assert.equal(b.nodes.dayReport.hidden, true, 'Missing admin_day_report hides the card');
    n = dayCalls(); b.api.loadDay();
    assert.equal(dayCalls(), n, 'Missing admin_day_report stops fetching');
    checks++;
  }
  console.log(`PASS dashboard presentation: ${checks} checks; ${originalIds.length} existing IDs and range hooks preserved; source and mocked data/auth/loading/error behavior match baseline`);
})().catch(error => { console.error(error); process.exitCode = 1; });
