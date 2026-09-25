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
assert.equal(withoutPresentation(modified), withoutPresentation(reference),
  'Auth/client configuration, fetching, handlers, calculations and other renderers unchanged');
checks++;

const plain = value => JSON.parse(JSON.stringify(value));
function snapshot(h, ids = originalIds.filter(id => !['plans', 'plansNote'].includes(id))) {
  return Object.fromEntries(ids.map(id => {
    const n = h.nodes[id];
    return [id, { text: n.textContent, html: n.innerHTML, hidden: n.hidden, disabled: n.disabled, classes: n.className }];
  }));
}
function compare(a, b, label) {
  assert.deepEqual(snapshot(b), snapshot(a), label);
  assert.deepEqual(b.rpc.map(({ name, args }) => ({ name, args })), a.rpc.map(({ name, args }) => ({ name, args })), `${label}: RPC contract`);
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

(async () => {
  for (const scenario of ['guest', 'success', 'forbidden', 'missing-function', 'dashboard-reject', 'traffic-reject']) {
    const a = harness(baseline), b = harness(current);
    await a.auth(scenario === 'guest' ? null : { user: { id: 'local-test' } });
    await b.auth(scenario === 'guest' ? null : { user: { id: 'local-test' } });
    compare(a, b, `${scenario}: authentication/loading`);
    if (scenario === 'guest') { assert.equal(b.rpc.length, 0, 'Guest never fetches dashboard data'); continue; }
    assert.deepEqual(b.rpc.map(c => c.name), ['admin_traffic', 'admin_dashboard'], 'Only existing summary RPCs are called');
    a.api.load(); b.api.load();
    assert.equal(b.rpc.length, 2, 'Repeated refresh is ignored while loading');
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
      for (const h of [a, b]) {
        h.context.document.hidden = true; h.intervals[0].callback();
        assert.equal(h.rpc.length, 2, 'Hidden document does not refresh');
        h.context.document.hidden = false;
        h.nodes.rangeSeg.handlers.click.call(h.nodes.rangeSeg, { target: { closest: () => h.buttons[0] } });
      }
      compare(a, b, 'Changing period preserves handlers and RPC parameters');
      assert.deepEqual(b.rpc.slice(2).map(c => c.args), [{ p_days: 7 }, { p_days: 7 }]);
    }
    if (scenario === 'traffic-reject') {
      assert.equal(b.nodes.dash.hidden, false, 'Traffic failure leaves the main dashboard visible');
      assert.equal(b.nodes.trafficDetail2.hidden, true, 'Traffic failure hides traffic details');
    }
  }
  console.log(`PASS dashboard presentation: ${checks} checks; ${originalIds.length} existing IDs and range hooks preserved; source and mocked data/auth/loading/error behavior match baseline`);
})().catch(error => { console.error(error); process.exitCode = 1; });
