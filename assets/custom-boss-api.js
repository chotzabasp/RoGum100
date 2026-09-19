// Reuse the main application's existing Supabase client and session.
export function createCustomBossAPI(client) {
const PROJECT_ID = new URL(client.supabaseUrl).hostname.split('.')[0];
async function result(request) {
  const { data, error } = await request;
  if (error) throw error;
  return data;
}
const rpc = (name, args) => result(client.rpc(name, args));
async function context(user) {
  const membership = await result(client.from('party_members').select('host_id').eq('member_id', user.id).is('removed_at', null).maybeSingle());
  const owner = membership?.host_id || user.id;
  const profile = await result(client.from('profiles').select('id,display_name,servers').eq('id', owner).single());
  const self = owner === user.id ? profile : await result(client.from('profiles').select('display_name').eq('id', user.id).single());
  return { owner, profile, displayName: self.display_name || '' };
}
async function load(owner, server) {
  const [catalog, definitions, globalTimers, customTimers, history] = await Promise.all([
    result(client.from('bosses').select('*')),
    result(client.from('custom_bosses').select('*').eq('owner_id', owner).is('archived_at', null)),
    result(client.from('user_bosses').select('*').eq('user_id', owner).eq('server_id', server)),
    result(client.from('custom_boss_timers').select('*').eq('owner_id', owner).eq('server_id', server)),
    result(client.from('kills').select('id,boss_id,boss_name,killed_at,killed_by,server_id,kill_items(id,name)').eq('host_id', owner).eq('server_id', server).order('killed_at', { ascending: false }).limit(100))
  ]);
  return { catalog, definitions, globalTimers, customTimers, history };
}
const definition = id => result(client.from('custom_bosses').select('*').eq('id', id).single());
function update(boss, fields) {
  return rpc('update_custom_boss', { p_boss_id: boss.id, p_expected_updated_at: boss.updated_at,
    p_name: fields.name, p_respawn_minutes: fields.respawn_minutes, p_map_location: fields.map_location,
    p_items: fields.items, p_image_path: fields.image_path ?? null, p_map_image_path: fields.map_image_path ?? null });
}
async function setTime(boss, owner, server, target, who) {
  if (boss.custom) return rpc('set_custom_boss_time', { p_boss_id: boss.rawId, p_server_id: server, p_target_time: target });
  return result(client.from('user_bosses').update({ target_time: target, started_by: target ? who : null }).eq('user_id', owner).eq('boss_id', boss.rawId).eq('server_id', server));
}
async function marker(boss, owner, server, x, y) {
  if (boss.custom) return rpc('set_custom_boss_marker', { p_boss_id: boss.rawId, p_server_id: server, p_x: x, p_y: y });
  return result(client.from('user_bosses').update({ marker_x: x, marker_y: y }).eq('user_id', owner).eq('boss_id', boss.rawId).eq('server_id', server));
}
async function add(boss, owner, server) {
  return boss.custom ? rpc('add_custom_boss_timer', { p_boss_id: boss.rawId, p_server_id: server }) :
    rpc('add_boss_capped', { p_owner: owner, p_boss_id: boss.rawId, p_server_id: server });
}
async function remove(boss, owner, server) {
  if (boss.custom) return rpc('remove_custom_boss_timer', { p_boss_id: boss.rawId, p_server_id: server });
  return result(client.from('user_bosses').delete().eq('user_id', owner).eq('boss_id', boss.rawId).eq('server_id', server));
}
// Keep the same request and death timestamp after a network failure, including a page reload.
async function record(boss, owner, server, user, killedAt, items, draftKey, displayName) {
  const key = `${PROJECT_ID}:kill:${user}:${owner}:${server}:${boss.id}`;
  if (boss.custom) {
    let pending;
    try { pending = JSON.parse(sessionStorage.getItem(key)); } catch { /* No valid pending request. */ }
    if (!pending || pending.draftKey !== draftKey) {
      pending = { draftKey, args: { p_boss_id: boss.rawId, p_server_id: server, p_killed_at: killedAt, p_items: items, p_request_id: crypto.randomUUID() } };
      sessionStorage.setItem(key, JSON.stringify(pending));
    }
    const id = await rpc('record_custom_kill', pending.args);
    sessionStorage.removeItem(key);
    return id;
  }
  const id = await rpc('record_kill', { p_boss_id: boss.rawId, p_boss_name: boss.name, p_killed_at: killedAt, p_items: items });
  await rpc('set_kill_server', { p_kill_id: id, p_server_id: server });
  await setTime(boss, owner, server, new Date(Date.parse(killedAt) + boss.minutes * 60000).toISOString(), displayName);
  return id;
}
const bucket = () => client.storage.from('custom-boss-images');
function validateImage(file) {
  if (!file) return;
  if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type) || file.size > 1048576) throw new Error('รูปต้องเป็น PNG, JPEG หรือ WebP ขนาดไม่เกิน 1 MiB');
}
async function upload(owner, bossId, file) {
  validateImage(file);
  const ext = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' }[file.type];
  const path = `${owner}/${bossId}/${crypto.randomUUID()}.${ext}`;
  await result(bucket().upload(path, file, { contentType: file.type, upsert: false }));
  return path;
}
async function imageUrl(path) {
  if (!path) return null;
  return (await result(bucket().createSignedUrl(path, 60))).signedUrl;
}
async function pageState(owner) {
  return JSON.stringify(await Promise.all([rpc('boss_page_state', { p_host: owner }), rpc('custom_boss_page_state', { p_host: owner })]));
}

return { client, result, rpc, context, load, definition, update, setTime, marker, add, remove, record, validateImage, upload, imageUrl, pageState };
}
