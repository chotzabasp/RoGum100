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
const addedFunctions = ['rpcMissing', 'fmt1', 'hourRange', 'minutesHtml', 'renderLive', 'loadLive', 'fetchUsage', 'showUsage', 'renderUsage'];
const addedCode = [
  'var live = { busy:false, off:false, shown:false };',
  'var usage = { seq:0, off:false };',
  'var usageJob = fetchUsage();',
  'showUsage(usageJob);',
  "$('refreshBtn').addEventListener('click', loadLive);",
  'setInterval(function(){ if(!document.hidden && state.data) loadLive(); }, 60000);',
  'loadLive();'
];
const referenceComments = new Set(reference.script.split('\n').map(line => line.trim()).filter(line => line.startsWith('//')));
function comparableSource(h) {
  let script = withoutPresentation(h);
  for (const name of addedFunctions) {
    if (typeof h.api[name] === 'function') script = script.replace(h.api[name].toString(), '');
  }
  return script.split('\n').filter(line => {
    const t = line.trim();
    return t && !addedCode.includes(t) && !(t.startsWith('//') && !referenceComments.has(t));
  }).join('\n');
}
for (const line of addedCode) {
  assert.equal(modified.script.split('\n').filter(l => l.trim() === line).length, 1, `Added hook appears exactly once: ${line}`);
}
assert.equal(comparableSource(modified), comparableSource(reference),
  'Auth/client configuration, fetching, handlers, calculations and other renderers unchanged');
checks++;

const plain = value => JSON.parse(JSON.stringify(value));
function snapshot(h, ids = originalIds.filter(id => !['plans', 'plansNote'].includes(id))) {
  return Object.fromEntries(ids.map(id => {
    const n = h.nodes[id];
    return [id, { text: n.textContent, html: n.innerHTML, hidden: n.hidden, disabled: n.disabled, classes: n.className }];
  }));
}
// The two analytics RPCs added 2026-09-28 are asserted separately below; the existing RPC contract must not change.
const NEW_RPCS = ['admin_live', 'admin_usage'];
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
      [{ name: 'admin_usage', args: { p_days: 30 } }, { name: 'admin_live', args: {} }], 'Only the two new analytics RPCs are added');
    a.api.load(); b.api.load();
    assert.equal(existingCalls(b).length, 2, 'Repeated refresh is ignored while loading');
    assert.equal(b.rpc.length, 4, 'Repeated refresh adds no analytics calls while loading');
    const dashboard = scenario === 'forbidden' ? { error: { message: 'สำหรับแอดมินเท่านั้น' } }
      : scenario === 'missing-function' ? { error: { message: 'admin_dashboard does not exist' } }
      : scenario === 'dashboard-reject' ? { message: 'offline fixture' }
      : { data: { generated_at: '2026-09-26T05:00:00Z', kpi: { members: 20, paid_users: 4, active_7d: 7 }, revenue: {} } };
    for (const h of [a, b]) {
      await h.respond('admin_traffic', scenario === 'traffic-reject' ? { message: 'traffic fixture offline' } : { data: traffic }, scenario === 'traffic-reject');
      await h.respond('admin_dashboard', dashboard, scenario === 'dashboard-reject');
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
      assert.ok(b.nodes.liveTiles.innerHTML.includes('ยังไม่มีข้อมูล') && !/NaN|undefined/.test(b.nodes.liveTiles.innerHTML), 'Empty live data renders zeros');
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
      'เมื่อวาน 7', 'จ่ายเงิน 2 · ฟรี 7<', '23:00–00:00', 'ใช้งาน 4 คน', '12.5<small>นาที/คน</small>',
      'ใช้งานวันนี้ 2 · ถูกล็อก <span class="pill pill-danger">1</span>', 'หัวปาร์ตี้ที่ถูกล็อก: ', '&lt;i&gt;Host&lt;/i&gt; (2 คน)']) {
      assert.ok(tiles.includes(text), `Live tiles show ${text}`);
    }
    assert.ok(!tiles.includes('สิทธิเดิม'), 'Legacy count only shown when above zero');
    assert.ok(!/NaN|undefined|<i>/.test(tiles), 'Live tiles never show NaN/undefined or raw names');

    assert.equal(b.nodes.usageRow.hidden, false, 'Usage row shows once admin_usage answers');
    const hoursChart = b.charts.filter(c => c.id === 'chartHours').pop();
    assert.ok(hoursChart, 'Hourly chart drawn');
    assert.deepEqual(plain(hoursChart.config.data.labels), Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0')), 'Hour labels 00-23');
    const colors = hoursChart.config.data.datasets[0].backgroundColor;
    assert.ok(colors[20] !== colors[9] && colors.filter(c => c === colors[20]).length === 1, 'Only the peak hour is highlighted');
    assert.equal(hoursChart.config.options.plugins.tooltip.callbacks.label({ dataIndex: 20 }), ' 20:00–21:00 · เฉลี่ย 4.5 คน/วัน (รวม 14 ครั้ง)');
    assert.ok(b.nodes.usagePeak.innerHTML.includes('<b>20:00–21:00</b>') && b.nodes.usagePeak.innerHTML.includes('เฉลี่ย 4.5 คน/วัน'), 'Peak hero line');
    assert.equal(b.nodes.usageNote.textContent, 'เฉลี่ยต่อวันจาก 3 วันที่มีข้อมูลในช่วง 30 วัน · นับเฉพาะที่ล็อกอิน');
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
  console.log(`PASS dashboard presentation: ${checks} checks; ${originalIds.length} existing IDs and range hooks preserved; source and mocked data/auth/loading/error behavior match baseline`);
})().catch(error => { console.error(error); process.exitCode = 1; });
