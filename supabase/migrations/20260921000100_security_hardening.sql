-- ============================================================
--  Gum100 — ชุดแก้ความปลอดภัยและระบบแพ็กเกจ (2026-09-21)
--  รันทั้งไฟล์รวดเดียวใน Supabase Dashboard -> SQL Editor -> New query -> Run
--  (ถ้ามีหน้าต่างเตือน "destructive operation" ให้กดยืนยัน — เป็นการลบ policy/constraint เดิมก่อนสร้างใหม่)
--
--  ไฟล์นี้แบ่งเป็น 5 ช่วง แต่ละช่วงครอบด้วย begin/commit และรันซ้ำได้อย่างปลอดภัย
--   ช่วง 1: บัญชีฟรีไม่หมดอายุ + ปิด buy_package เก่า + กันชื่อที่แสดงมี < >
--   ช่วง 2: ถอนสิทธิ์เขียนตรงของตารางที่หน้าเว็บไม่เคยเขียนตรง + ปิดฟังก์ชันจากคนไม่ล็อกอิน + จำกัด record_kill
--   ช่วง 3: ปิดช่องส่งสลิปแบบเก่า + จำกัดที่เก็บสลิป
--   ช่วง 4: โปรโมชันหมดจริงที่เซิร์ฟเวอร์ (buy_plan ราคาปกติหลัง 31 ต.ค. 2026)
--   ช่วง 5: ลิมิตจับเวลาบอส/Custom Boss (ฟรีรวม 1 ตัว, มีแพ็กจับเวลาบอส Custom ได้ 50 ตัว)
-- ============================================================


-- ============================================================
-- ช่วง 1: บัญชีฟรีไม่หมดอายุ + ปิด buy_package เก่า + กันชื่อที่แสดงมี < >
-- ============================================================
begin;

-- expires_at ห้ามเป็นค่าว่าง จึงใช้ 2099-12-31 แทน "ไม่จำกัด" (หน้าเว็บแสดงเป็น "ไม่จำกัด")
-- บัญชีที่ตั้งวันหมดอายุไว้เองเพื่อระงับการใช้งาน (วันที่ผ่านไปแล้ว) จะไม่ถูกแตะ
alter table public.profiles
  alter column expires_at set default timestamptz '2099-12-31 00:00:00+00';

update public.profiles
   set expires_at = timestamptz '2099-12-31 00:00:00+00'
 where expires_at > now()
   and expires_at <= created_at + interval '31 days';

-- ฟังก์ชันซื้อแบบเก่า (ราคาเก่า ต่อ expires_at อย่างเดียว) เว็บไม่เรียกแล้ว — ปิดกันผู้ใช้เผลอเรียกตรงแล้วเสียแต้มฟรี
revoke execute on function public.buy_package(text, text) from public, anon, authenticated;

-- ชื่อที่แสดง: ห้ามมี < > (กัน XSS อีกชั้นที่ฐานข้อมูล) และยาวไม่เกิน 100
alter table public.profiles drop constraint if exists profiles_display_name_safe;
alter table public.profiles
  add constraint profiles_display_name_safe
  check (display_name !~ '[<>]' and char_length(display_name) <= 100) not valid;
alter table public.profiles validate constraint profiles_display_name_safe;

commit;


-- ============================================================
-- ช่วง 2: ถอนสิทธิ์เขียนตรง + ปิดฟังก์ชันจากคนไม่ล็อกอิน + จำกัด record_kill
-- ============================================================
begin;

-- ตารางเหล่านี้หน้าเว็บไม่เคยเขียนตรงเลย (เขียนผ่านฟังก์ชัน/เซิร์ฟเวอร์เท่านั้น) — ถอนสิทธิ์เขียนไว้เป็นชั้นป้องกันที่สอง
-- (service_role และแดชบอร์ด Supabase ไม่ได้รับผลกระทบ)
revoke insert, update, delete, truncate on
  public.profiles, public.topup_transactions, public.package_purchases,
  public.package_feature_entitlements, public.bosses, public.items, public.servers,
  public.party_members, public.custom_bosses, public.custom_boss_timers, public.topup_requests
  from anon, authenticated;

-- คนไม่ล็อกอิน (anon) ไม่ควรเขียนข้อมูลตารางใดเลย
revoke insert, update, delete, truncate on
  public.kills, public.kill_items, public.user_bosses, public.announcements,
  public.user_app_data, public.farm_entries, public.merchant_entries
  from anon;

-- ปิดฟังก์ชันที่ต้องล็อกอินอยู่แล้วจากคนไม่ล็อกอิน (คง email_for_username กับ username_available ไว้ ไม่งั้นล็อกอิน/สมัครพัง)
do $$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('add_boss_capped', 'buy_plan', 'buy_server_slot',
                         'post_announcement', 'set_kill_server', 'set_my_facebook_url')
  loop
    execute format('revoke execute on function public.%I(%s) from public, anon', r.proname, r.args);
    execute format('grant execute on function public.%I(%s) to authenticated, service_role', r.proname, r.args);
  end loop;
end $$;

-- record_kill: เหมือนเดิมทุกอย่าง เพิ่มแค่ตรวจความยาว/จำนวน (ไอเทมไม่เกิน 50 ชิ้น ชื่อไม่เกิน 120 ตัวอักษร)
create or replace function public.record_kill(p_boss_id text, p_boss_name text, p_killed_at timestamp with time zone, p_items text[])
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  caller_host uuid;
  new_kill uuid;
  it text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if p_boss_id is null or char_length(p_boss_id) not between 1 and 200 then raise exception 'รหัสบอสไม่ถูกต้อง'; end if;
  if p_boss_name is null or char_length(btrim(p_boss_name)) not between 1 and 120 then raise exception 'ชื่อบอสไม่ถูกต้อง'; end if;
  if coalesce(cardinality(p_items), 0) > 50 then raise exception 'บันทึกไอเทมได้ไม่เกิน 50 ชิ้นต่อครั้ง'; end if;
  select host_id into caller_host from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host is null then caller_host := auth.uid(); end if;

  insert into public.kills (host_id, boss_id, boss_name, killed_by, killed_at)
    values (caller_host, p_boss_id, p_boss_name, auth.uid(), p_killed_at)
    returning id into new_kill;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    if it is null or char_length(btrim(it)) not between 1 and 120 then raise exception 'ชื่อไอเทมไม่ถูกต้อง'; end if;
    insert into public.kill_items (kill_id, host_id, name) values (new_kill, caller_host, it);
  end loop;
  return new_kill;
end; $function$;

commit;


-- ============================================================
-- ช่วง 3: ปิดช่องส่งสลิปแบบเก่า (ใช้ QR PromptPay แล้ว) + จำกัดที่เก็บสลิป
-- ============================================================
begin;

drop policy if exists topup_insert_own on public.topup_requests;
drop policy if exists topup_slips_insert_own on storage.objects;

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp']
 where id = 'topup-slips';

commit;


-- ============================================================
-- ช่วง 4: โปรโมชันหมดจริงที่เซิร์ฟเวอร์
--   โปรสิ้นสุดตามหน้าเว็บ 31 ต.ค. 2026 23:59:59 (+07) — ฝั่งเซิร์ฟเวอร์เผื่อเพิ่ม 5 นาที
--   กันนาฬิกาเครื่องผู้ใช้เร็วกว่าเซิร์ฟเวอร์ แล้วถูกหักแพงกว่าราคาที่เห็นในหน้าจอ
--   ราคาที่ไม่มีโปร (ตามที่หน้าเว็บกำหนดอยู่): 3 in 1 / จับเวลาบอส รายปี 990, 1 in 1 = 99, 2 in 1 = 149
--   ถ้าจะเลื่อนวันโปร ต้องแก้ทั้ง promo_active() นี้ และ PROMO_END_AT ใน index.html ให้ตรงกัน
-- ============================================================
begin;

create or replace function public.promo_active()
returns boolean
language sql
stable
set search_path = ''
as $$ select now() <= timestamptz '2026-11-01 00:04:59+07' $$;

revoke all on function public.promo_active() from public, anon, authenticated;

create or replace function public.buy_plan(p_plan_key text, p_cycle text)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  if p_plan_key in ('farm','accountItems') and p_cycle <> 'monthly' then
    raise exception 'แพ็กเกจนี้รองรับเฉพาะรายเดือน';
  end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  v_price := case
    when p_plan_key in ('bundle','timers') and p_cycle = 'yearly' then 990
    when p_plan_key in ('bundle','timers') and public.promo_active() then 99
    when p_plan_key in ('bundle','timers') then 199
    when p_plan_key = 'all' and public.promo_active() then (case p_cycle when 'yearly' then 1750 else 175 end)
    when p_plan_key = 'all' then (case p_cycle when 'yearly' then 3490 else 349 end)
    when p_plan_key = 'accountItems' then 149
    else 99
  end;
  select points, plan_bundle_expires_at, plan_timers_expires_at into v_points, v_bundle, v_timers
    from public.profiles where id = v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points, 0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
    v_before := greatest(v_before, v_bundle);
    v_new := greatest(coalesce(v_before, now()), now()) + interval '30 days';
    insert into public.package_feature_entitlements(user_id, feature, expires_at) values (v_uid, p_plan_key, v_new)
      on conflict (user_id, feature) do update set expires_at = excluded.expires_at;
  elsif p_plan_key = 'bundle' then
    v_before := v_bundle;
    v_new := greatest(coalesce(v_bundle, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_bundle_expires_at = v_new where id = v_uid;
  elsif p_plan_key = 'timers' then
    v_before := v_timers;
    v_new := greatest(coalesce(v_timers, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_timers_expires_at = v_new where id = v_uid;
  else
    v_bundle_new := greatest(coalesce(v_bundle, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    v_timers_new := greatest(coalesce(v_timers, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    v_before := least(coalesce(v_bundle, now()), coalesce(v_timers, now()));
    v_new := least(v_bundle_new, v_timers_new);
    update public.profiles set plan_bundle_expires_at = v_bundle_new, plan_timers_expires_at = v_timers_new where id = v_uid;
  end if;
  update public.profiles set points = points - v_price where id = v_uid;
  v_name := case p_plan_key
    when 'farm' then '1 in 1 — ยอดนักฟาม'
    when 'accountItems' then '2 in 1'
    when 'bundle' then '3 in 1'
    when 'timers' then 'จับเวลาบอส'
    else '4 in 1' end;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id, plan_key, plan_name, cycle, points_spent, days_added, expires_before, expires_after)
    values (v_uid, p_plan_key, v_name, p_cycle, v_price, v_days, v_before, v_new);
  end if;
  return v_new;
end;
$function$;

commit;


-- ============================================================
-- ช่วง 5: ลิมิตจับเวลาบอส/Custom Boss
--   ฟรี: บอสปกติ + Custom รวมกันไม่เกิน 1 ตัว (ทุกเซิร์ฟเวอร์รวมกัน)
--   มีแพ็กเกจ "จับเวลาบอส" (หรือ 4 in 1): บอสปกติไม่จำกัด, Custom Boss สร้างได้ไม่เกิน 50 ตัว
--   ล็อกต่อเจ้าของ กันกดพร้อมกันแล้วทะลุลิมิต
-- ============================================================
begin;

create or replace function public.boss_slot_available(p_owner uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare v_used integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('boss_cap:' || p_owner::text, 0));
  if public.has_timers_plan(p_owner) then return true; end if;
  select (select count(*) from public.user_bosses where user_id = p_owner)
       + (select count(*) from public.custom_boss_timers where owner_id = p_owner)
    into v_used;
  return v_used < 1;
end $function$;

revoke all on function public.boss_slot_available(uuid) from public, anon, authenticated;

create or replace function public.add_boss_capped(p_owner uuid, p_boss_id text, p_server_id text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not (auth.uid() = p_owner or public.is_party_member_of(p_owner)) then
    raise exception 'ไม่มีสิทธิ์เพิ่มบอสให้บัญชีนี้';
  end if;
  if not public.boss_slot_available(p_owner) then
    raise exception 'บัญชีฟรีจับเวลาบอสได้สูงสุด 1 ตัว — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อไม่จำกัด';
  end if;
  insert into public.user_bosses (user_id, boss_id, server_id) values (p_owner, p_boss_id, p_server_id);
end; $function$;

create or replace function public.create_custom_boss(p_name text, p_respawn_minutes integer, p_server_id text, p_map_location text default null::text, p_items text[] default '{}'::text[])
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare h uuid := public.cb_owner(); b uuid;
begin
  if h <> auth.uid() then raise exception 'Only party owner can create a boss'; end if;
  perform public.cb_require_server(h, p_server_id);
  if not public.boss_slot_available(h) then
    raise exception 'บัญชีฟรีจับเวลาบอสได้สูงสุด 1 ตัว — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อไม่จำกัด';
  end if;
  if (select count(*) from public.custom_bosses where owner_id = h and archived_at is null) >= 50 then
    raise exception 'สร้าง Custom Boss ได้สูงสุด 50 ตัว';
  end if;
  insert into public.custom_bosses(owner_id, created_by, name, respawn_minutes, map_location, items)
    values (h, auth.uid(), btrim(p_name), p_respawn_minutes, nullif(btrim(p_map_location), ''), p_items)
    returning id into b;
  insert into public.custom_boss_timers(owner_id, custom_boss_id, server_id) values (h, b, p_server_id);
  return b;
end $function$;

create or replace function public.add_custom_boss_timer(p_boss_id uuid, p_server_id text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare b public.custom_bosses := public.cb_lock_boss(p_boss_id); t uuid;
begin
  perform public.cb_require_server(b.owner_id, p_server_id);
  select id into t from public.custom_boss_timers
    where owner_id = b.owner_id and custom_boss_id = b.id and server_id = p_server_id;
  if t is not null then return t; end if;
  if not public.boss_slot_available(b.owner_id) then
    raise exception 'บัญชีฟรีจับเวลาบอสได้สูงสุด 1 ตัว — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อไม่จำกัด';
  end if;
  insert into public.custom_boss_timers(owner_id, custom_boss_id, server_id)
    values (b.owner_id, b.id, p_server_id) returning id into t;
  return t;
end $function$;

commit;
