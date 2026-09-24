-- ============================================================
-- ปุ่ม "รีเซ็ตรหัสผ่าน" ในหน้าแอดมิน (แท็บเติมแต้มให้สมาชิก → ค้นหาสมาชิก)
-- เว็บไม่ส่งอีเมลรีเซ็ตรหัสแล้ว (ไม่ได้ตั้ง SMTP) — สมาชิกที่ลืมรหัสติดต่อแอดมินที่เพจ FB
-- แอดมินยืนยันตัวตนก่อน (username + วันเกิดที่กรอกตอนสมัคร — อีเมลยืนยันไม่ได้ เพราะระบบไม่เคยตรวจอีเมล)
-- แล้วกดปุ่ม → หน้าเว็บสุ่มรหัสชั่วคราว → ฟังก์ชันนี้ตั้งรหัสใหม่ + เตะทุกเครื่องที่ค้างล็อกอินบัญชีนั้นออก
--
-- 1) admin_find_member: เพิ่ม birth_date ในผลค้นหา (ไว้เทียบตอนยืนยันตัวตน) + role — ที่เหลือเหมือนเดิมทุกอย่าง
-- 2) admin_reset_password(p_user_id, p_new_password): เฉพาะแอดมิน, รหัส 8–72 ตัว (bcrypt อ่านได้แค่ 72 ไบต์แรก),
--    ห้ามใช้กับบัญชีแอดมิน (แอดมินเปลี่ยนรหัสตัวเองที่หน้าตั้งค่า) · เก็บรหัสแบบ bcrypt แบบเดียวกับที่ Supabase Auth ใช้
--    หา schema ของ pgcrypto ตอนเรียกใช้จริง (ไม่เดาว่าอยู่ใน extensions หรือ public)
-- ============================================================
begin;

create or replace function public.admin_find_member(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_role text;
  v_key text := lower(btrim(coalesce(p_identifier, '')));
  r record;
  v_scoped jsonb;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if char_length(v_key) < 3 then raise exception 'กรอก username หรืออีเมลอย่างน้อย 3 ตัวอักษร'; end if;

  if position('@' in v_key) > 0 then
    select p.id, p.display_name, p.username, p.points, u.email, p.birth_date, p.role,
           p.legacy_unlimited, p.plan_bundle_expires_at, p.plan_timers_expires_at into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(u.email) = v_key;
  else
    select p.id, p.display_name, p.username, p.points, u.email, p.birth_date, p.role,
           p.legacy_unlimited, p.plan_bundle_expires_at, p.plan_timers_expires_at into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(p.username) = v_key;
  end if;
  if not found then raise exception 'ไม่พบสมาชิกจาก username/อีเมลนี้'; end if;

  select coalesce(jsonb_object_agg(feature, expires_at), '{}'::jsonb) into v_scoped
    from public.package_feature_entitlements
   where user_id = r.id and feature in ('farm','accountItems');

  return jsonb_build_object('id', r.id, 'display_name', r.display_name, 'username', r.username,
                            'email', r.email, 'points', r.points,
                            'birth_date', r.birth_date, 'role', r.role,
                            'legacy_unlimited', r.legacy_unlimited,
                            'plan_bundle_expires_at', r.plan_bundle_expires_at,
                            'plan_timers_expires_at', r.plan_timers_expires_at,
                            'feature_expiries', v_scoped);
end;
$function$;

create or replace function public.admin_reset_password(p_user_id uuid, p_new_password text)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_caller_role text;
  v_target_role text;
  v_schema text;
  v_hash text;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if p_user_id is null then raise exception 'ไม่ได้เลือกสมาชิก'; end if;
  if p_new_password is null or char_length(p_new_password) < 8 or octet_length(p_new_password) > 72 then
    raise exception 'รหัสผ่านใหม่ต้องยาว 8–72 ตัวอักษร';
  end if;

  select role into v_target_role from public.profiles where id = p_user_id;
  if not found or not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'ไม่พบสมาชิกคนนี้';
  end if;
  if v_target_role = 'admin' then
    raise exception 'รีเซ็ตรหัสบัญชีแอดมินจากปุ่มนี้ไม่ได้ — เปลี่ยนรหัสตัวเองที่หน้าตั้งค่า';
  end if;

  select n.nspname into v_schema
    from pg_catalog.pg_extension e join pg_catalog.pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pgcrypto';
  if v_schema is null then raise exception 'ระบบยังไม่มี pgcrypto — แจ้งผู้ดูแลระบบ'; end if;
  execute format('select %I.crypt($1, %I.gen_salt(''bf''))', v_schema, v_schema) into v_hash using p_new_password;

  update auth.users set encrypted_password = v_hash, updated_at = now() where id = p_user_id;
  delete from auth.sessions where user_id = p_user_id; -- เตะทุกเครื่องที่ค้างล็อกอินบัญชีนี้อยู่ออก
end;
$function$;

revoke all on function public.admin_reset_password(uuid, text) from public, anon;
grant execute on function public.admin_reset_password(uuid, text) to authenticated;

commit;

-- ตรวจว่าเรียก pgcrypto ได้ (อ่านอย่างเดียว) — ควรได้ ok = true และชื่อ schema ของ pgcrypto
select n.nspname as pgcrypto_schema, true as ok
  from pg_catalog.pg_extension e join pg_catalog.pg_namespace n on n.oid = e.extnamespace
 where e.extname = 'pgcrypto';
