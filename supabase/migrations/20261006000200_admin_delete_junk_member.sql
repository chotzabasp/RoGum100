-- ============================================================
-- แอดมินลบบัญชีขยะได้เอง (ผู้ใช้เลือก "เฉพาะบัญชีขยะ" 6 ต.ค. 2569)
-- บัญชีขยะ = สมัครแล้ว "ไม่เคยยืนยันอีเมล" และ "ไม่เคยเข้าสู่ระบบ" (เช่น ใส่อีเมลผิดตอนสมัคร)
--   + ไม่มีแต้ม / แพ็กเกจ / ประวัติเงินหรือโค้ด / ปาร์ตี้ / ข้อมูลใช้งาน — มีอย่างใดอย่างหนึ่ง = ปุ่มปฏิเสธ ต้องลบด้วยขั้นตอนเต็มกับผู้ดูแลระบบ
--   + สมัครมาเกิน 24 ชั่วโมงแล้ว (ผู้ใช้เลือก — คนจริงที่เพิ่งสมัครอาจกำลังยืนยันอีเมล)
-- 1) admin_list_members(): + role, email_confirmed_at, last_sign_in_at (ไว้แสดงป้าย "ยังไม่ยืนยันอีเมล" และปุ่มลบ)
--      คอลัมน์ที่ส่งกลับเปลี่ยน = ต้อง drop แล้วสร้างใหม่ (ส่วนอื่นคงเดิม เนื้อเดิมจาก 20260923000600)
-- 2) admin_user_deletions (ใหม่): ประวัติการลบ (ยูเซอ อีเมล ชื่อ วันสมัคร ใครลบ เมื่อไหร่) — แอดมินอ่านได้อย่างเดียว ไม่มี FK ไปบัญชีที่ลบแล้ว
--      เก็บ 180 วัน (ผู้ใช้เลือก) — แถวเก่ากว่านั้นถูกล้างทุกครั้งที่ลบบัญชี
-- 3) admin_member_delete_blockers() (ภายใน เรียกตรงไม่ได้): เหตุผลที่ลบไม่ได้ ใช้ร่วมกันทั้งตอนตรวจและตอนลบ
--      + ไล่ทุกตารางใน public ที่อ้างถึงบัญชี (รวมตารางที่เพิ่มทีหลัง) มีข้อมูลของบัญชีนี้ = ลบจากปุ่มไม่ได้
-- 4) admin_delete_member_check(id): ตรวจก่อนเปิดกล่องยืนยัน (อ่านอย่างเดียว)
-- 5) admin_delete_member(id, ยูเซอที่พิมพ์ยืนยัน): ล็อกแถว → ตรวจซ้ำ → บันทึกประวัติ → ลบ auth.users (โปรไฟล์และข้อมูลทุกตารางหายตาม)
--      บัญชีที่ไม่เคยล็อกอินอัปโหลดรูปไม่ได้ จึงไม่มีไฟล์ค้างใน Storage
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261006000200_admin_delete_junk_member_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_list_members()');
  if v_md5 is distinct from 'fafb790cbf7be374b5006ff84dac45da' then
    raise exception 'admin_list_members ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  if to_regclass('public.admin_user_deletions') is not null
     or to_regprocedure('public.admin_member_delete_blockers(uuid)') is not null
     or to_regprocedure('public.admin_delete_member_check(uuid)') is not null
     or to_regprocedure('public.admin_delete_member(uuid, text)') is not null then
    raise exception 'มีระบบลบบัญชีอยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) รายชื่อสมาชิก + สถานะยืนยันอีเมล / เข้าสู่ระบบ ----------
drop function public.admin_list_members();

create function public.admin_list_members()
returns table (
  id uuid,
  display_name text,
  username text,
  email text,
  points integer,
  legacy_unlimited boolean,
  plan_bundle_expires_at timestamptz,
  plan_timers_expires_at timestamptz,
  feature_expiries jsonb,
  created_at timestamptz,
  role text,
  email_confirmed_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_role text;
begin
  select pr.role into v_role from public.profiles pr where pr.id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;

  return query
    select p.id, p.display_name::text, p.username::text, u.email::text, p.points, p.legacy_unlimited,
           p.plan_bundle_expires_at, p.plan_timers_expires_at,
           coalesce((
             select jsonb_object_agg(pfe.feature, pfe.expires_at)
             from public.package_feature_entitlements pfe
             where pfe.user_id = p.id and pfe.feature in ('farm','accountItems')
           ), '{}'::jsonb) as feature_expiries,
           p.created_at,
           p.role::text, u.email_confirmed_at, u.last_sign_in_at
    from public.profiles p
    join auth.users u on u.id = p.id
    order by p.created_at desc;
end;
$function$;

revoke all on function public.admin_list_members() from public, anon;
grant execute on function public.admin_list_members() to authenticated;

-- ---------- 2) ประวัติการลบบัญชี ----------
create table public.admin_user_deletions (
  id bigint generated always as identity primary key,
  deleted_user_id uuid not null,
  username text,
  email text,
  display_name text,
  account_created_at timestamptz,
  deleted_by uuid,
  deleted_at timestamptz not null default now()
);
create index admin_user_deletions_deleted_at_idx on public.admin_user_deletions (deleted_at desc);
alter table public.admin_user_deletions enable row level security;
revoke all on table public.admin_user_deletions from public, anon, authenticated;
grant select on table public.admin_user_deletions to authenticated;
create policy admin_user_deletions_admin_select on public.admin_user_deletions
  for select to authenticated using ((select public.is_admin()));

-- ---------- 3) เหตุผลที่ลบไม่ได้ (ภายใน) ----------
create function public.admin_member_delete_blockers(p_user_id uuid)
returns text[]
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_out text[] := '{}';
  v_role text;
  v_points integer;
  v_legacy boolean;
  v_bundle timestamptz;
  v_timers timestamptz;
  v_created timestamptz;
  v_confirmed timestamptz;
  v_last_sign_in timestamptz;
  r record;
  v_has boolean;
begin
  select pr.role, pr.points, pr.legacy_unlimited, pr.plan_bundle_expires_at, pr.plan_timers_expires_at, pr.created_at
    into v_role, v_points, v_legacy, v_bundle, v_timers, v_created
    from public.profiles pr where pr.id = p_user_id;
  select au.email_confirmed_at, au.last_sign_in_at into v_confirmed, v_last_sign_in
    from auth.users au where au.id = p_user_id;

  if p_user_id = auth.uid() then v_out := v_out || 'เป็นบัญชีของคุณเอง'::text; end if;
  if v_role = 'admin' then v_out := v_out || 'เป็นบัญชีแอดมิน'::text; end if;
  -- บัญชีขยะ = สมัครแล้วไม่เคยยืนยันอีเมลและไม่เคยเข้าสู่ระบบ (เช่น ใส่อีเมลผิด ลิงก์ยืนยันไปตกที่อีเมลคนอื่น)
  if v_confirmed is not null then v_out := v_out || 'ยืนยันอีเมลแล้ว'::text; end if;
  if v_last_sign_in is not null then v_out := v_out || 'เคยเข้าสู่ระบบแล้ว'::text; end if;
  -- สมัครไม่ถึง 24 ชม. = อาจเป็นคนจริงที่กำลังยืนยันอีเมล (ผู้ใช้เลือก "รอ 24 ชม." 6 ต.ค. 2569)
  if v_created > now() - interval '24 hours' then
    v_out := v_out || ('เพิ่งสมัครไม่ถึง 24 ชั่วโมง (อาจกำลังยืนยันอีเมล) — ลบได้ตั้งแต่ '
                       || to_char((v_created + interval '24 hours') at time zone 'Asia/Bangkok', 'DD/MM HH24:MI') || ' น.');
  end if;
  -- กันพลาดอีกชั้น: มีเงิน/แพ็กเกจ/ปาร์ตี้/ข้อมูลเกี่ยวข้อง = ต้องลบด้วยขั้นตอนเต็มเท่านั้น
  if coalesce(v_points, 0) <> 0 then v_out := v_out || ('มีแต้มคงเหลือ ' || v_points || ' แต้ม'); end if;
  if coalesce(v_legacy, false) then v_out := v_out || 'เป็นบัญชีเก่าสิทธิไม่จำกัด'::text; end if;
  if v_bundle is not null or v_timers is not null
     or exists (select 1 from public.package_feature_entitlements e where e.user_id = p_user_id) then
    v_out := v_out || 'มีหรือเคยมีแพ็กเกจ'::text;
  end if;
  if exists (select 1 from public.package_purchases x where x.user_id = p_user_id)
     or exists (select 1 from public.points_ledger x where x.user_id = p_user_id)
     or exists (select 1 from public.topup_transactions x where x.user_id = p_user_id)
     or exists (select 1 from public.topup_requests x where x.user_id = p_user_id or x.reviewed_by = p_user_id)
     or exists (select 1 from public.promo_code_redemptions x where x.user_id = p_user_id)
     or exists (select 1 from public.promo_codes x where x.created_by = p_user_id) then
    v_out := v_out || 'มีประวัติแต้ม เติมเงิน ซื้อแพ็กเกจ หรือใช้โค้ด'::text;
  end if;
  -- หัวปาร์ตี้เพิ่มสมาชิกด้วยอีเมลได้แม้อีเมลยังไม่ยืนยัน (อาจจ่าย 50 แต้มเป็นค่าที่นั่งไปแล้ว)
  if exists (select 1 from public.party_members x where (x.member_id = p_user_id or x.host_id = p_user_id) and x.removed_at is null) then
    v_out := v_out || 'อยู่ในปาร์ตี้ (ให้หัวปาร์ตี้เอาออกก่อน)'::text;
  end if;
  if exists (select 1 from public.kill_items x where x.shared_with @> array[p_user_id]) then
    v_out := v_out || 'มีชื่ออยู่ในส่วนแบ่งไอเทมบอสของปาร์ตี้'::text;
  end if;
  -- ข้อมูลที่ต้องล็อกอินถึงสร้างได้ (บอส 1 ตัวที่ระบบแจกตอนสมัครไม่นับ)
  if exists (select 1 from public.merchant_entries x where x.user_id = p_user_id)
     or exists (select 1 from public.farm_entries x where x.user_id = p_user_id)
     or exists (select 1 from public.user_app_data x where x.user_id = p_user_id)
     or exists (select 1 from public.announcements x where x.user_id = p_user_id)
     or exists (select 1 from public.custom_bosses x where x.owner_id = p_user_id)
     or exists (select 1 from public.custom_boss_timers x where x.owner_id = p_user_id)
     or exists (select 1 from public.kills x where x.host_id = p_user_id or x.killed_by = p_user_id)
     or exists (select 1 from public.discord_alert_settings x where x.owner_id = p_user_id) then
    v_out := v_out || 'มีข้อมูลการใช้งานในบัญชี'::text;
  end if;
  -- กันพลาดชั้นสุดท้าย: ตารางอื่นใน public ที่อ้างถึงบัญชี (เช่น ตารางที่เพิ่มทีหลังโดยเครื่องมืออื่น) มีข้อมูลของบัญชีนี้ = ไม่ใช่บัญชีขยะ
  --   ข้ามตารางที่ตรวจด้านบนแล้ว และบอส 1 ตัวที่ระบบแจกตอนสมัคร (user_bosses) · ตรวจทุกครั้งที่กด ไม่ต้องแก้ฟังก์ชันเมื่อมีตารางใหม่
  for r in
    select c.conrelid::regclass::text as tbl, a.attname::text as col
      from pg_catalog.pg_constraint c
      join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and cardinality(c.conkey) = 1
       and c.confrelid in ('public.profiles'::regclass, 'auth.users'::regclass)
       and c.connamespace = 'public'::regnamespace
       and c.conrelid::regclass::text not in ('public.profiles', 'public.user_bosses',
         'public.package_feature_entitlements', 'public.package_purchases', 'public.points_ledger', 'public.topup_transactions',
         'public.topup_requests', 'public.promo_code_redemptions', 'public.promo_codes', 'public.party_members', 'public.kills',
         'public.merchant_entries', 'public.farm_entries', 'public.user_app_data', 'public.announcements',
         'public.custom_bosses', 'public.custom_boss_timers', 'public.discord_alert_settings')
     order by 1, 2
  loop
    execute format('select exists (select 1 from %s where %I = $1)', r.tbl, r.col) into v_has using p_user_id;
    if v_has then v_out := v_out || ('มีข้อมูลในตาราง ' || r.tbl); end if;
  end loop;
  return v_out;
end;
$function$;

revoke all on function public.admin_member_delete_blockers(uuid) from public, anon, authenticated;

-- ---------- 4) ตรวจก่อนลบ ----------
create function public.admin_delete_member_check(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_caller_role text;
  v_out jsonb;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if p_user_id is null then raise exception 'ไม่ได้เลือกสมาชิก'; end if;
  select jsonb_build_object(
           'id', p.id, 'display_name', p.display_name, 'username', p.username, 'email', u.email,
           'created_at', p.created_at, 'email_confirmed_at', u.email_confirmed_at, 'last_sign_in_at', u.last_sign_in_at)
    into v_out
    from public.profiles p join auth.users u on u.id = p.id
   where p.id = p_user_id;
  if v_out is null then raise exception 'ไม่พบสมาชิกคนนี้ (อาจถูกลบไปแล้ว)'; end if;
  return v_out || jsonb_build_object('blockers', to_jsonb(public.admin_member_delete_blockers(p_user_id)));
end;
$function$;

revoke all on function public.admin_delete_member_check(uuid) from public, anon;
grant execute on function public.admin_delete_member_check(uuid) to authenticated;

-- ---------- 5) ลบบัญชีขยะ ----------
create function public.admin_delete_member(p_user_id uuid, p_confirm text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_caller_role text;
  v_email text;
  v_username text;
  v_name text;
  v_created timestamptz;
  v_expect text;
  v_blockers text[];
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if p_user_id is null then raise exception 'ไม่ได้เลือกสมาชิก'; end if;
  -- ล็อกแถวบัญชีก่อนตรวจ: ยืนยันอีเมล / เข้าสู่ระบบ / ถูกเพิ่มเข้าปาร์ตี้ พร้อมกับตอนกดลบ ต้องรอให้จบก่อน
  select au.email into v_email from auth.users au where au.id = p_user_id for update;
  if not found then raise exception 'ไม่พบสมาชิกคนนี้ (อาจถูกลบไปแล้ว)'; end if;
  select pr.username, pr.display_name, pr.created_at into v_username, v_name, v_created
    from public.profiles pr where pr.id = p_user_id for update;
  if not found then raise exception 'บัญชีนี้ไม่มีโปรไฟล์ — ลบด้วยขั้นตอนเต็มกับผู้ดูแลระบบ'; end if;
  -- พิมพ์ยืนยัน = ยูเซอของบัญชีนั้น (บัญชีที่ไม่มียูเซอ = อีเมล) ตรวจที่ฐานข้อมูลด้วย ไม่ใช่แค่หน้าเว็บ
  v_expect := lower(coalesce(nullif(btrim(v_username), ''), v_email, ''));
  if v_expect = '' or lower(btrim(coalesce(p_confirm, ''))) <> v_expect then
    raise exception 'พิมพ์ยืนยันไม่ตรง — ต้องพิมพ์ยูเซอ (หรืออีเมล ถ้าบัญชีไม่มียูเซอ) ของบัญชีที่จะลบ';
  end if;
  v_blockers := public.admin_member_delete_blockers(p_user_id);
  if cardinality(v_blockers) > 0 then
    raise exception 'ลบจากปุ่มนี้ไม่ได้: % — ลบด้วยขั้นตอนเต็มกับผู้ดูแลระบบ', array_to_string(v_blockers, ', ');
  end if;
  insert into public.admin_user_deletions (deleted_user_id, username, email, display_name, account_created_at, deleted_by)
  values (p_user_id, v_username, v_email, v_name, v_created, auth.uid());
  -- ประวัติการลบเก็บ 180 วัน (อีเมลที่พิมพ์ผิดมักเป็นของคนอื่น — ไม่เก็บตลอดไป)
  delete from public.admin_user_deletions where deleted_at < now() - interval '180 days';
  -- ลบบัญชีล็อกอิน → โปรไฟล์และข้อมูลทุกตารางในบัญชีหายตาม (cascade)
  -- มีตารางที่ขวางการลบเหลืออยู่ = ล้มทั้งคำสั่ง ไม่มีอะไรถูกลบ (รวมแถวประวัติด้านบน)
  delete from auth.users where id = p_user_id;
  if exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'ลบไม่สำเร็จ (โปรไฟล์ยังอยู่) — ไม่มีอะไรถูกลบ';
  end if;
  return jsonb_build_object('ok', true, 'username', v_username, 'email', v_email);
end;
$function$;

revoke all on function public.admin_delete_member(uuid, text) from public, anon;
grant execute on function public.admin_delete_member(uuid, text) to authenticated;

-- ---------- ลองใช้จริงก่อน commit (พังตรงไหน = ยกเลิกทั้งหมด ไม่มีอะไรถูกแก้) ----------
do $check$
begin
  -- ตัวตรวจเหตุผลอ่านได้ครบทุกตาราง/คอลัมน์ (รหัสศูนย์ = ไม่มีบัญชีนี้จริง)
  perform public.admin_member_delete_blockers('00000000-0000-0000-0000-000000000000'::uuid);
  -- คอลัมน์ใหม่ของรายชื่อสมาชิกมีจริง
  perform p.role, u.email_confirmed_at, u.last_sign_in_at from public.profiles p join auth.users u on u.id = p.id limit 1;
  -- สิทธิ์ล็อก/ลบแถว auth.users ที่ admin_delete_member ใช้ (รหัสศูนย์ = ไม่ตรงแถวไหน ไม่มีอะไรถูกลบ)
  perform 1 from auth.users where id = '00000000-0000-0000-0000-000000000000'::uuid for update;
  delete from auth.users where id = '00000000-0000-0000-0000-000000000000'::uuid;
end;
$check$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (ฟังก์ชันตรงกับไฟล์นี้ · รายชื่อสมาชิกมีคอลัมน์ใหม่ · ตารางประวัติปิดสิทธิ์ถูกต้อง · ตัวตรวจภายในเรียกตรงไม่ได้)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_list_members()')) = 'c3a6ad6a62bd77ddaec976f6fe62e93b'
    and pg_get_function_result('public.admin_list_members()'::regprocedure) like '%last_sign_in_at timestamp with time zone%'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_member_delete_blockers(uuid)')) = '8d5457338bf7c658c05ebddc25f9d4c0'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_delete_member_check(uuid)')) = '703a317e6c1c0cc14f8a369402b88a6b'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_delete_member(uuid, text)')) = 'fadd320579ed978af6b48598864e81ef'
    and (select relrowsecurity from pg_class where oid = 'public.admin_user_deletions'::regclass)
    and exists (select 1 from pg_policy where polrelid = 'public.admin_user_deletions'::regclass and polname = 'admin_user_deletions_admin_select')
    and not has_table_privilege('anon', 'public.admin_user_deletions', 'select, insert, update, delete')
    and not has_table_privilege('authenticated', 'public.admin_user_deletions', 'insert, update, delete')
    and has_function_privilege('authenticated', 'public.admin_list_members()', 'execute')
    and not has_function_privilege('anon', 'public.admin_list_members()', 'execute')
    and has_function_privilege('authenticated', 'public.admin_delete_member_check(uuid)', 'execute')
    and not has_function_privilege('anon', 'public.admin_delete_member_check(uuid)', 'execute')
    and has_function_privilege('authenticated', 'public.admin_delete_member(uuid, text)', 'execute')
    and not has_function_privilege('anon', 'public.admin_delete_member(uuid, text)', 'execute')
    and not has_function_privilege('anon', 'public.admin_member_delete_blockers(uuid)', 'execute')
    and not has_function_privilege('authenticated', 'public.admin_member_delete_blockers(uuid)', 'execute') as delete_junk_ok;
