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
// ใช้ของเดิมซ้ำได้แค่ช่วงสั้นๆ (~2 นาที) และเวลาตายต้องใกล้กัน — กดรอบหลัง (บอสตายรอบใหม่) ต้องได้ request id + เวลาตายใหม่เสมอ
// ไม่งั้นรอบใหม่จะได้เวลาตายเก่า (เวลาเกิดเลยไปแล้ว) หรือ request id เก่าที่บันทึกไปแล้ว (ฐานข้อมูลคืนรายการเดิม ไม่บันทึกรอบใหม่)
const PENDING_KILL_MS = 120000;
async function record(boss, owner, server, user, killedAt, items, draftKey, displayName) {
  const key = `${PROJECT_ID}:kill:${user}:${owner}:${server}:${boss.id}`;
  if (boss.custom) {
    const now = Date.now();
    let pending;
    try { pending = JSON.parse(sessionStorage.getItem(key)); } catch { /* No valid pending request. */ }
    const fresh = !!pending && pending.draftKey === draftKey && typeof pending.createdAt === 'number'
      && Math.abs(now - pending.createdAt) < PENDING_KILL_MS && !!pending.args
      && Math.abs(Date.parse(pending.args.p_killed_at) - Date.parse(killedAt)) < PENDING_KILL_MS;
    if (!fresh) {
      pending = { draftKey, createdAt: now, args: { p_boss_id: boss.rawId, p_server_id: server, p_killed_at: killedAt, p_items: items, p_request_id: crypto.randomUUID() } };
      try { sessionStorage.setItem(key, JSON.stringify(pending)); } catch { /* ใช้ sessionStorage ไม่ได้ = ส่งครั้งเดียวแบบไม่มีสำรอง */ }
    }
    let id;
    try { id = await rpc('record_custom_kill', pending.args); }
    catch (err) {
      // ฐานข้อมูลตอบกลับเป็น error (RAISE = P0001, 'Request ID already used' ฯลฯ) = ไม่มีอะไรถูกบันทึก ส่ง id เดิมซ้ำก็ไม่ช่วย → ทิ้ง
      // เน็ตหลุด (supabase-js ให้ code '') / gateway ตอบกลับไม่ใช่ JSON (ไม่มี code) = อาจบันทึกไปแล้ว → เก็บไว้ให้กดซ้ำใช้ id เดิม
      if (err && err.code) { try { sessionStorage.removeItem(key); } catch { /* ignore */ } }
      throw err;
    }
    try { sessionStorage.removeItem(key); } catch { /* ignore */ }
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
  if (!['image/png', 'image/jpeg', 'image/webp', 'image/gif'].includes(file.type) || file.size > 1048576) throw new Error('รูปต้องเป็น PNG, JPEG, WebP หรือ GIF ขนาดไม่เกิน 1 MiB');
}
async function upload(owner, bossId, file) {
  validateImage(file);
  const ext = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' }[file.type];
  const path = `${owner}/${bossId}/${crypto.randomUUID()}.${ext}`;
  await result(bucket().upload(path, file, { contentType: file.type, upsert: false }));
  return path;
}
// ลบรูปที่ไม่ใช้แล้วออกจากถัง (เจ้าของลบได้เฉพาะโฟลเดอร์ตัวเอง — policy custom_boss_images_delete_own)
async function removeImages(paths) {
  const list = [...new Set((paths || []).filter(Boolean))];
  if (!list.length) return;
  await result(bucket().remove(list));
}
// ลิงก์รูปอยู่ได้ 1 ชั่วโมง (เท่า cache-control ตอนอัปโหลด) — ลิงก์ในรายการค้นหา/ประวัติใช้ทีหลังได้ ไม่หมดอายุภายใน 1 นาทีแบบเดิม
async function imageUrl(path) {
  if (!path) return null;
  return (await result(bucket().createSignedUrl(path, 3600))).signedUrl;
}
async function pageState(owner) {
  return JSON.stringify(await Promise.all([rpc('boss_page_state', { p_host: owner }), rpc('custom_boss_page_state', { p_host: owner })]));
}

return { client, result, rpc, context, load, definition, update, setTime, marker, add, remove, record, validateImage, upload, removeImages, imageUrl, pageState };
}
