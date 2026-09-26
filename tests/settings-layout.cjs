// Compare settings markup with the baseline HTML supplied on stdin.
// With --check-js, instead pass baseline app.js on stdin to compare settings code.
// This is a local source check; it does not execute account or payment handlers.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const baseline = fs.readFileSync(0, 'utf8');
const current = fs.readFileSync(path.join(root, 'app.html'), 'utf8');

if (process.argv.includes('--check-js')) {
  const currentJs = fs.readFileSync(path.join(root, 'assets/app.js'), 'utf8');
  const start = '  var fmtFullDate = function(v)';
  const end = '  function isNoExpiry(ts)';
  const settingsCode = source => {
    const normalized = source.replace(/\r\n/g, '\n');
    const first = normalized.indexOf(start);
    const last = normalized.indexOf(end, first);
    assert.ok(first >= 0 && last > first, 'Settings business code boundaries must exist');
    return normalized.slice(first, last);
  };
  assert.equal(settingsCode(currentJs), settingsCode(baseline), 'Settings business code must match baseline');
  console.log('PASS settings source layout: settings business code unchanged against supplied baseline');
  process.exit(0);
}

function settingsSection(html) {
  const match = html.match(/<section\b[^>]*\bid="view-settings"[^>]*>[\s\S]*?<\/section>/);
  assert.ok(match, 'Settings section must exist in current and baseline HTML');
  return match[0].replace(/<!--[\s\S]*?-->/g, '');
}

function elements(html) {
  return [...settingsSection(html).matchAll(/<([a-z][\w-]*)\b([^>]*?)>/gi)].map(match => {
    const attrs = {};
    for (const attr of match[2].matchAll(/([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) {
      attrs[attr[1]] = attr[2] ?? attr[3] ?? attr[4] ?? '';
    }
    return { tag: match[1].toLowerCase(), attrs };
  });
}

const before = elements(baseline);
const after = elements(current);
const ids = rows => rows.filter(row => row.attrs.id).map(row => row.attrs.id).sort();
assert.deepEqual(ids(after), ids(before), 'All settings IDs, including duplicates, must be preserved');

for (const previous of before.filter(row => row.attrs.id)) {
  const id = previous.attrs.id;
  const next = after.find(row => row.attrs.id === id);
  assert.equal(next.tag, previous.tag, `${id}: element type must be preserved`);
  for (const [attr, value] of Object.entries(previous.attrs)) {
    if (attr === 'class') {
      const classes = new Set((next.attrs.class || '').split(/\s+/));
      for (const token of value.split(/\s+/).filter(Boolean)) {
        assert.ok(classes.has(token), `${id}: preserve existing class ${token}`);
      }
    } else if (/^(?:data-|type$|maxlength$|min$|max$|autocomplete$|hidden$|disabled$|readonly$)/.test(attr)) {
      assert.equal(next.attrs[attr], value, `${id}: preserve ${attr}`);
    }
  }
  for (const state of ['hidden', 'disabled', 'readonly']) {
    assert.equal(Object.hasOwn(next.attrs, state), Object.hasOwn(previous.attrs, state), `${id}: preserve initial ${state} state`);
  }
}

const tabs = rows => rows.filter(row => Object.hasOwn(row.attrs, 'data-sthtab'))
  .map(row => [row.attrs.id, row.attrs['data-sthtab']]).sort();
assert.deepEqual(tabs(after), tabs(before), 'History tab IDs and data-sthtab mapping must be preserved');
for (const label of before.filter(row => row.tag === 'label' && row.attrs.for)) {
  assert.ok(after.some(row => row.tag === 'label' && row.attrs.for === label.attrs.for), `Preserve label for ${label.attrs.for}`);
}

// The expiry value sits in a hidden row without its own ID.
assert.match(settingsSection(current), /<div\b[^>]*\bhidden\b[^>]*>\s*<span\b[^>]*>[\s\S]*?<\/span>\s*<b\b[^>]*\bid="stExpires"/, 'Legacy expiry row stays hidden');

console.log(`PASS settings source layout: ${ids(after).length} IDs, ${tabs(after).length} history tabs, existing classes/control attributes/hidden states and labels preserved`);
