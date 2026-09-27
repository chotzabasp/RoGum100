-- ============================================================
-- ปาร์ตี้ต้องมีหัวปาร์ตี้ที่มีแพ็กเกจ "จับเวลาบอส" (ตามที่ผู้ใช้เลือก ก1 ข2 + 1ก 2ก 3ข 4ก + ปิดปาร์ตี้ซ้อน · 28 ก.ย. 2569)
--   ก1 = เพิ่มเพื่อนเข้าปาร์ตี้ได้เมื่อหัวปาร์ตี้มีแพ็กเกจ "จับเวลาบอส" (หรือ 4 in 1) · สมาชิกที่กดเพิ่มต้องมีแพ็กเกจด้วย
--   ข2 = แพ็กเกจของหัวปาร์ตี้หมดอายุ → ล็อกทั้งปาร์ตี้ (สมาชิกดู/แก้ข้อมูลของหัวปาร์ตี้ไม่ได้) จนกว่าหัวปาร์ตี้จะต่ออายุ
--        หัวปาร์ตี้ยังใช้บัญชีตัวเองได้ (แบบฟรี) และเอาสมาชิกออกได้ · สมาชิกกดออกจากปาร์ตี้ได้เสมอ
--   1ก = ไอเทมที่ถูกติ๊กหารให้สมาชิก (shared_with) ยังเห็นได้ระหว่างล็อก (policy กิ่งนั้นไม่ได้แตะ)
--   2ก = ระหว่างล็อกซื้อที่นั่ง 50 แต้มไม่ได้
--   ปิดปาร์ตี้ซ้อน = เพิ่มคนที่เป็นหัวปาร์ตี้และยังมีสมาชิกอยู่ เข้าปาร์ตี้อื่นไม่ได้
--
-- 1) is_party_member_of(host): + has_timers_plan(host) — policy/ฟังก์ชันที่ใช้ตัวนี้ล็อกตามไปเอง
--    (user_bosses, kills, kill_items, บอส Custom, รูปบอส Custom, party_roster, add_boss_capped, set_kill_server,
--     แจ้งเตือน Discord ของปาร์ตี้, ประวัติ boss_history_* ฯลฯ)
-- 2) ตัวที่อ่าน party_members เองโดยไม่ผ่านข้อ 1 → เติมเช็คแพ็กหัวปาร์ตี้ตรงๆ:
--    record_kill, บอส Custom 5 ตัว (add/remove timer, set time, set marker, record_custom_kill), buy_party_seat
-- 3) add_party_member / party_add_quote: ก1 + ห้ามปาร์ตี้ซ้อน (เช็คก่อนหาเพื่อน/หักแต้ม)
-- 4) ฟังก์ชันใหม่ my_party_status(): หน้าเว็บรู้ว่าปาร์ตี้ของฉันถูกล็อกไหม + ชื่อหัวปาร์ตี้ + วันหมดแพ็กของหัวปาร์ตี้
--    (ไว้เตือนสมาชิกล่วงหน้า 3 วัน) · หัวปาร์ตี้ได้จำนวนสมาชิก (ไว้เตือนว่าปาร์ตี้จะถูกล็อก)
-- ข้อความ error "ปาร์ตี้ถูกล็อก — ..." ใช้ข้อความเดียวทุกที่ หน้าเว็บจับคำว่า "ปาร์ตี้ถูกล็อก" เพื่อเปิดหน้าล็อก
-- ทุกอย่างอยู่ใน transaction เดียว — ตัวเช็คด้านบนไม่ผ่าน = ไม่มีอะไรถูกแก้
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260928000100_party_host_plan_lock_rollback.sql (ไม่ต้องรัน ถ้าไม่มีปัญหา)
-- ============================================================
begin;

set local lock_timeout = '5s';

-- ---------- กันเขียนทับของที่ถูกแก้จากที่อื่น ----------
do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.is_party_member_of(uuid)');
  if v_md5 is distinct from '35d5cf80b0ad6a5f2cb34e715d9f3bde' then
    raise exception 'is_party_member_of ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.add_party_member(text, integer)');
  if v_md5 is distinct from 'a9a158bf94be92763cb7240e2c98f13e' then
    raise exception 'add_party_member ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.party_add_quote(text)');
  if v_md5 is distinct from 'e4fc9b1ee9ee5a6153a3c180bfd9a853' then
    raise exception 'party_add_quote ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_party_seat()');
  if v_md5 is distinct from '89431b10e9951527d555f7e7c9c5f9a5' then
    raise exception 'buy_party_seat ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.record_kill(text, text, timestamp with time zone, text[])');
  if v_md5 is distinct from 'd21bbaadadb4f82f2a05f8f0a703cf55' then
    raise exception 'record_kill ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.record_custom_kill(uuid, text, timestamp with time zone, text[], uuid)');
  if v_md5 is distinct from 'c18a8fbf9d989824df8d970467b711f8' then
    raise exception 'record_custom_kill ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.add_custom_boss_timer(uuid, text)');
  if v_md5 is distinct from 'bb2f0bfcd2bc9b5cf8a369ca2ff545fd' then
    raise exception 'add_custom_boss_timer ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.remove_custom_boss_timer(uuid, text)');
  if v_md5 is distinct from 'e72d569fc7f53af915995098211bc446' then
    raise exception 'remove_custom_boss_timer ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.set_custom_boss_time(uuid, text, timestamp with time zone)');
  if v_md5 is distinct from 'c5a884dab7c016749c192819fc703619' then
    raise exception 'set_custom_boss_time ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.set_custom_boss_marker(uuid, text, numeric, numeric)');
  if v_md5 is distinct from 'e55be35db49e2f0daa91a8501c74398e' then
    raise exception 'set_custom_boss_marker ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  if to_regprocedure('public.my_party_status()') is not null then
    raise exception 'มี my_party_status อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) is_party_member_of: สมาชิกใช้ข้อมูลปาร์ตี้ได้เฉพาะตอนหัวปาร์ตี้มีแพ็กเกจ ----------
CREATE OR REPLACE FUNCTION public.is_party_member_of(host uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1 from public.party_members
    where host_id = host and member_id = auth.uid() and removed_at is null
      and (seat = 'paid' or public.has_timers_plan(auth.uid()))
      and public.has_timers_plan(host)
  );
$function$;


-- ---------- 2) เพิ่มเพื่อน: ก1 + ห้ามปาร์ตี้ซ้อน ----------
create or replace function public.party_add_quote(member_email text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$declare
  target_id uuid;
  caller_host_id uuid;
  ident text := lower(trim(member_email));
  v_name text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if ident is null or ident = '' then raise exception 'กรุณากรอกอีเมลหรือ Username ของเพื่อน'; end if;

  select host_id into caller_host_id from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host_id is null then
    caller_host_id := auth.uid();
  end if;

  -- ปาร์ตี้เพิ่มคนได้เมื่อหัวปาร์ตี้มีแพ็กเกจ "จับเวลาบอส" · สมาชิกที่กดเพิ่มต้องมีแพ็กเกจด้วย (ไม่มี = ดูอย่างเดียว)
  if not public.has_timers_plan(caller_host_id) then
    if caller_host_id = auth.uid() then
      raise exception 'ต้องมีแพ็กเกจ "จับเวลาบอส" ก่อน ถึงจะเพิ่มเพื่อนเข้าปาร์ตี้ได้';
    end if;
    raise exception 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  end if;
  if caller_host_id <> auth.uid() and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;

  select p.id into target_id from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = ident or p.username = ident
   limit 1;
  if target_id is null then raise exception 'ไม่พบบัญชีที่ใช้อีเมลหรือ Username นี้'; end if;
  if target_id = caller_host_id then raise exception 'เพิ่มคนนี้ไม่ได้ (เป็นหัวปาร์ตี้อยู่แล้ว)'; end if;

  if exists(select 1 from public.party_members where host_id=caller_host_id and member_id=target_id and removed_at is null) then
    raise exception 'เพื่อนคนนี้อยู่ในปาร์ตี้อยู่แล้ว';
  end if;
  if exists(select 1 from public.party_members where member_id=target_id and removed_at is null) then
    raise exception 'คนนี้เข้าร่วมปาร์ตี้อื่นอยู่แล้ว ต้องออกจากปาร์ตี้เดิมก่อนถึงจะเพิ่มเข้าปาร์ตี้นี้ได้';
  end if;
  -- ห้ามปาร์ตี้ซ้อนปาร์ตี้: หัวปาร์ตี้ที่ยังมีสมาชิกอยู่ เข้าเป็นสมาชิกปาร์ตี้อื่นไม่ได้
  if exists(select 1 from public.party_members where host_id=target_id and removed_at is null) then
    raise exception 'คนนี้เป็นหัวปาร์ตี้ที่มีสมาชิกอยู่ — ต้องเอาสมาชิกออกให้หมดก่อน ถึงจะเข้าปาร์ตี้อื่นได้';
  end if;

  select display_name into v_name from public.profiles where id = target_id;
  return jsonb_build_object('display_name', v_name,
                            'cost', case when public.has_timers_plan(target_id) then 0 else 50 end);
end;$function$;

create or replace function public.add_party_member(member_email text, p_expected_cost integer default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$declare
  target_id uuid;
  caller_host_id uuid;
  ident text := lower(trim(member_email));
  v_cost integer;
  v_seat text;
  v_name text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if ident is null or ident = '' then raise exception 'กรุณากรอกอีเมลหรือ Username ของเพื่อน'; end if;

  select host_id into caller_host_id from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host_id is null then
    caller_host_id := auth.uid();
  end if;

  -- ปาร์ตี้เพิ่มคนได้เมื่อหัวปาร์ตี้มีแพ็กเกจ "จับเวลาบอส" · สมาชิกที่กดเพิ่มต้องมีแพ็กเกจด้วย (ไม่มี = ดูอย่างเดียว)
  if not public.has_timers_plan(caller_host_id) then
    if caller_host_id = auth.uid() then
      raise exception 'ต้องมีแพ็กเกจ "จับเวลาบอส" ก่อน ถึงจะเพิ่มเพื่อนเข้าปาร์ตี้ได้';
    end if;
    raise exception 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  end if;
  if caller_host_id <> auth.uid() and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;

  select p.id into target_id from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = ident or p.username = ident
   limit 1;
  if target_id is null then raise exception 'ไม่พบบัญชีที่ใช้อีเมลหรือ Username นี้'; end if;
  if target_id = caller_host_id then raise exception 'เพิ่มคนนี้ไม่ได้ (เป็นหัวปาร์ตี้อยู่แล้ว)'; end if;

  if exists(select 1 from public.party_members where host_id=caller_host_id and member_id=target_id and removed_at is null) then
    raise exception 'เพื่อนคนนี้อยู่ในปาร์ตี้อยู่แล้ว';
  end if;
  if exists(select 1 from public.party_members where member_id=target_id and removed_at is null) then
    raise exception 'คนนี้เข้าร่วมปาร์ตี้อื่นอยู่แล้ว ต้องออกจากปาร์ตี้เดิมก่อนถึงจะเพิ่มเข้าปาร์ตี้นี้ได้';
  end if;
  -- ห้ามปาร์ตี้ซ้อนปาร์ตี้: หัวปาร์ตี้ที่ยังมีสมาชิกอยู่ เข้าเป็นสมาชิกปาร์ตี้อื่นไม่ได้
  if exists(select 1 from public.party_members where host_id=target_id and removed_at is null) then
    raise exception 'คนนี้เป็นหัวปาร์ตี้ที่มีสมาชิกอยู่ — ต้องเอาสมาชิกออกให้หมดก่อน ถึงจะเข้าปาร์ตี้อื่นได้';
  end if;

  -- เพื่อนมีแพ็กเกจ "จับเวลาบอส" = เข้าฟรี (seat 'plan' ใช้ได้ตราบที่แพ็กยังไม่หมด) · ไม่มี = คนกดเพิ่มจ่าย 50 แต้ม (seat 'paid' ถาวร)
  if public.has_timers_plan(target_id) then
    v_cost := 0; v_seat := 'plan';
  else
    v_cost := 50; v_seat := 'paid';
  end if;
  -- หน้าเว็บส่งราคาที่ผู้ใช้เห็นมาด้วย — แพ็กเกจเพื่อนเปลี่ยนระหว่างนั้น = ไม่เพิ่ม กันเสียแต้มโดยไม่รู้ตัว
  if p_expected_cost is not null and p_expected_cost <> v_cost then
    raise exception 'ค่าเข้าปาร์ตี้ของเพื่อนคนนี้เปลี่ยนไปแล้ว — กดตรวจสอบใหม่อีกครั้ง';
  end if;
  if v_cost > 0 then
    update public.profiles set points = points - v_cost where id = auth.uid() and points >= v_cost;
    if not found then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_cost; end if;
  end if;

  insert into public.party_members (host_id, member_id, seat) values (caller_host_id, target_id, v_seat);
  select display_name into v_name from public.profiles where id = target_id;
  return jsonb_build_object('display_name', v_name, 'cost', v_cost, 'seat', v_seat);
end;$function$;


-- ---------- 3) ที่นั่ง 50 แต้ม: ปาร์ตี้ถูกล็อกซื้อไม่ได้ ----------
create or replace function public.buy_party_seat()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.party_members%rowtype;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  select * into v_row from public.party_members
   where member_id = auth.uid() and removed_at is null
   limit 1
   for update;
  if not found then raise exception 'คุณไม่ได้อยู่ในปาร์ตี้ของใคร'; end if;
  if v_row.seat = 'paid' then raise exception 'คุณเป็นสมาชิกถาวรของปาร์ตี้นี้อยู่แล้ว'; end if;
  -- ปาร์ตี้ถูกล็อก (แพ็กหัวปาร์ตี้หมดอายุ) = จ่ายไปก็ยังใช้ไม่ได้ → ไม่ให้ซื้อ กันเสียแต้มฟรี
  if not public.has_timers_plan(v_row.host_id) then
    raise exception 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  end if;
  perform set_config('app.points_ledger_detail', 'จ่าย 50 แต้ม อยู่ปาร์ตี้ถาวร (แบบแพ็กฟรี)', true);
  update public.profiles set points = points - 50 where id = auth.uid() and points >= 50;
  if not found then raise exception 'แต้มไม่พอ (ต้องการ 50 แต้ม)'; end if;
  update public.party_members set seat = 'paid'
   where host_id = v_row.host_id and member_id = auth.uid() and removed_at is null;
end;
$function$;


-- ---------- 4) บันทึกการฆ่า: สมาชิกของปาร์ตี้ที่ถูกล็อกบันทึกไม่ได้ ----------
CREATE OR REPLACE FUNCTION public.record_kill(p_boss_id text, p_boss_name text, p_killed_at timestamp with time zone, p_items text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  caller_host uuid;
  new_kill uuid;
  dup_kill uuid;
  dup_at timestamptz;
  dup_by uuid;
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

  if caller_host <> auth.uid() and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกบันทึกลงประวัติของหัวปาร์ตี้ไม่ได้จนกว่าจะต่ออายุ
  if caller_host <> auth.uid() and not public.has_timers_plan(caller_host) then
    raise exception 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  end if;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    if it is null or char_length(btrim(it)) not between 1 and 120 then raise exception 'ชื่อไอเทมไม่ถูกต้อง'; end if;
  end loop;

  -- ต่อคิวการบันทึกของบอสตัวนี้ในปาร์ตี้นี้ทีละคำสั่ง แล้วเช็คว่ามีรอบเดียวกันอยู่แล้วหรือยัง
  perform pg_advisory_xact_lock(hashtext('record_kill:' || caller_host::text || ':' || p_boss_id));
  select k.id, k.killed_at, k.killed_by into dup_kill, dup_at, dup_by
    from public.kills k
   where k.host_id = caller_host and k.boss_id = p_boss_id and k.custom_boss_id is null
     and p_killed_at is not null
     and k.killed_at between p_killed_at - interval '60 seconds' and p_killed_at + interval '60 seconds'
   order by abs(extract(epoch from (k.killed_at - p_killed_at)))
   limit 1;
  if dup_kill is not null then
    -- สมาชิกปาร์ตี้รวมได้เฉพาะรอบที่ตัวเองเห็น (อยู่ในปาร์ตี้ตอนนั้น) — รอบก่อนเข้าปาร์ตี้: ไม่เพิ่มไอเทม และไม่สร้างรอบซ้ำ
    if caller_host <> auth.uid() and not public.party_kill_visible(caller_host, dup_at, dup_by) then
      raise exception 'รอบนี้ถูกบันทึกไว้ก่อนคุณเข้าปาร์ตี้แล้ว';
    end if;
    insert into public.kill_items (kill_id, host_id, name)
      select dup_kill, caller_host, d.v
        from (select distinct v from unnest(coalesce(p_items, '{}'::text[])) as u(v)) d
       where not exists (select 1 from public.kill_items i where i.kill_id = dup_kill and i.name = d.v);
    return dup_kill;
  end if;

  insert into public.kills (host_id, boss_id, boss_name, killed_by, killed_at)
    values (caller_host, p_boss_id, p_boss_name, auth.uid(), p_killed_at)
    returning id into new_kill;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    insert into public.kill_items (kill_id, host_id, name) values (new_kill, caller_host, it);
  end loop;
  return new_kill;
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_custom_kill(p_boss_id uuid, p_server_id text, p_killed_at timestamp with time zone, p_items text[], p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
  k public.kills; who text; target timestamptz;
BEGIN
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (เหมือน record_kill ของบอสปกติ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกแก้ไม่ได้จนกว่าหัวปาร์ตี้จะต่ออายุ
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(b.owner_id) THEN
    RAISE EXCEPTION 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  END IF;
  IF p_request_id IS NULL OR p_killed_at IS NULL OR NOT isfinite(p_killed_at) THEN
    RAISE EXCEPTION 'Invalid request/time';
  END IF;
  IF p_killed_at > clock_timestamp() + interval '5 minutes' THEN
    RAISE EXCEPTION 'เวลาตายต้องไม่เกินเวลาปัจจุบัน';
  END IF;
  IF NOT public.cb_validate_items(p_items) OR NOT (p_items <@ b.items) THEN
    RAISE EXCEPTION 'Drops must be selected from this boss';
  END IF;
  SELECT * INTO k FROM public.kills WHERE id=p_request_id;
  IF FOUND THEN
    IF k.custom_boss_id IS DISTINCT FROM b.id OR k.host_id<>b.owner_id
      OR k.server_id IS DISTINCT FROM p_server_id OR k.killed_by IS DISTINCT FROM auth.uid()
      OR k.killed_at IS DISTINCT FROM p_killed_at
      OR (SELECT coalesce(array_agg(name ORDER BY name),'{}'::text[]) FROM public.kill_items WHERE kill_id=k.id)
        IS DISTINCT FROM (SELECT coalesce(array_agg(v ORDER BY v),'{}'::text[]) FROM unnest(p_items) AS u(v)) THEN
      RAISE EXCEPTION 'Request ID already used';
    END IF;
    RETURN k.id;
  END IF;
  PERFORM 1 FROM public.custom_boss_timers WHERE owner_id=b.owner_id
    AND custom_boss_id=b.id AND server_id=p_server_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
  -- รอบเดียวกัน (ห่างไม่เกิน 60 วิ) มีคนบันทึกไปแล้ว → คืนรายการเดิม + เพิ่มไอเทมที่ยังไม่มี
  SELECT * INTO k FROM public.kills
   WHERE host_id=b.owner_id AND custom_boss_id=b.id
     AND killed_at BETWEEN p_killed_at - interval '60 seconds' AND p_killed_at + interval '60 seconds'
   ORDER BY abs(extract(epoch from (killed_at - p_killed_at)))
   LIMIT 1;
  IF FOUND THEN
    -- สมาชิกปาร์ตี้รวมได้เฉพาะรอบที่ตัวเองเห็น (อยู่ในปาร์ตี้ตอนนั้น) — รอบก่อนเข้าปาร์ตี้: ไม่เพิ่มไอเทม ไม่สร้างรอบซ้ำ ไม่แตะเวลาเกิด
    IF auth.uid()<>b.owner_id AND NOT public.party_kill_visible(k.host_id, k.killed_at, k.killed_by) THEN
      RAISE EXCEPTION 'รอบนี้ถูกบันทึกไว้ก่อนคุณเข้าปาร์ตี้แล้ว';
    END IF;
    INSERT INTO public.kill_items(kill_id,host_id,name)
      SELECT k.id,b.owner_id,d.v FROM (SELECT DISTINCT v FROM unnest(p_items) AS u(v)) d
       WHERE NOT EXISTS (SELECT 1 FROM public.kill_items i WHERE i.kill_id=k.id AND i.name=d.v);
    -- คนที่กดคนแรก (เจ้าของรายการ) กดซ้ำ → เวลาเกิดนับใหม่ตามที่กด · คนอื่นกด → คงเวลาของคนแรก
    IF k.killed_by = auth.uid() THEN
      target=p_killed_at + b.respawn_minutes * interval '1 minute';
      SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
      UPDATE public.custom_boss_timers SET target_time=target,started_by=who
        WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
    END IF;
    RETURN k.id;
  END IF;
  target=p_killed_at + b.respawn_minutes * interval '1 minute';
  SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
  INSERT INTO public.kills(id,host_id,boss_id,boss_name,killed_by,killed_at,server_id,custom_boss_id)
    VALUES(p_request_id,b.owner_id,'custom:'||b.id::text,b.name,auth.uid(),p_killed_at,p_server_id,b.id);
  INSERT INTO public.kill_items(kill_id,host_id,name)
    SELECT p_request_id,b.owner_id,v FROM unnest(p_items) AS u(v);
  UPDATE public.custom_boss_timers SET target_time=target,started_by=who
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  RETURN p_request_id;
END $function$;


-- ---------- 5) บอส Custom: สมาชิกของปาร์ตี้ที่ถูกล็อกแก้ไม่ได้ ----------
create or replace function public.add_custom_boss_timer(p_boss_id uuid, p_server_id text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare b public.custom_bosses := public.cb_lock_boss(p_boss_id); t uuid;
begin
  perform public.cb_require_server(b.owner_id, p_server_id);
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  if auth.uid() <> b.owner_id and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกแก้ไม่ได้จนกว่าหัวปาร์ตี้จะต่ออายุ
  if auth.uid() <> b.owner_id and not public.has_timers_plan(b.owner_id) then
    raise exception 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  end if;
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

CREATE OR REPLACE FUNCTION public.remove_custom_boss_timer(p_boss_id uuid, p_server_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกแก้ไม่ได้จนกว่าหัวปาร์ตี้จะต่ออายุ
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(b.owner_id) THEN
    RAISE EXCEPTION 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  END IF;
  DELETE FROM public.custom_boss_timers WHERE owner_id=b.owner_id
    AND custom_boss_id=b.id AND server_id=p_server_id;
END $function$;

CREATE OR REPLACE FUNCTION public.set_custom_boss_time(p_boss_id uuid, p_server_id text, p_target_time timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id); who text;
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกแก้ไม่ได้จนกว่าหัวปาร์ตี้จะต่ออายุ
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(b.owner_id) THEN
    RAISE EXCEPTION 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  END IF;
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  IF p_target_time IS NOT NULL AND NOT isfinite(p_target_time) THEN RAISE EXCEPTION 'Invalid target time'; END IF;
  SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
  UPDATE public.custom_boss_timers SET target_time=p_target_time,
    started_by=CASE WHEN p_target_time IS NULL THEN NULL ELSE who END
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
END $function$;

CREATE OR REPLACE FUNCTION public.set_custom_boss_marker(p_boss_id uuid, p_server_id text, p_x numeric, p_y numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  -- ปาร์ตี้ถูกล็อก (แพ็กเกจของหัวปาร์ตี้หมดอายุ) = สมาชิกแก้ไม่ได้จนกว่าหัวปาร์ตี้จะต่ออายุ
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(b.owner_id) THEN
    RAISE EXCEPTION 'ปาร์ตี้ถูกล็อก — แพ็กเกจ "จับเวลาบอส" ของหัวปาร์ตี้หมดอายุ';
  END IF;
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  UPDATE public.custom_boss_timers SET marker_x=p_x,marker_y=p_y
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
END $function$;

-- ---------- 6) สถานะปาร์ตี้ของฉัน (อ่านจากแถวสมาชิกของตัวเอง ไม่ผ่าน is_party_member_of — ปาร์ตี้ถูกล็อกก็ยังรู้ว่าล็อก) ----------
create function public.my_party_status()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_host uuid; v_seat text; v_name text; v_legacy boolean; v_role text; v_exp timestamptz; v_n int;
begin
  if auth.uid() is null then return jsonb_build_object('role', 'none'); end if;
  select m.host_id, m.seat into v_host, v_seat from public.party_members m
   where m.member_id = auth.uid() and m.removed_at is null
   limit 1;
  if v_host is not null then
    select p.display_name, p.legacy_unlimited, p.role, p.plan_timers_expires_at
      into v_name, v_legacy, v_role, v_exp
      from public.profiles p where p.id = v_host;
    return jsonb_build_object(
      'role', 'member', 'host_id', v_host, 'host_name', v_name, 'seat', v_seat,
      'host_has_timers', public.has_timers_plan(v_host),
      'host_unlimited', coalesce(v_legacy, false) or coalesce(v_role, '') = 'admin',
      'host_timers_expires_at', v_exp);
  end if;
  select count(*) into v_n from public.party_members where host_id = auth.uid() and removed_at is null;
  return jsonb_build_object('role', case when v_n > 0 then 'host' else 'none' end, 'member_count', v_n);
end;
$function$;

revoke all on function public.my_party_status() from public, anon;
grant execute on function public.my_party_status() to authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ true ทุกช่อง ยกเว้นช่องสุดท้าย (status_anon_exec_false) ต้องได้ false
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.is_party_member_of(uuid)')) = '6790ea6d80e22566faa004f526a49cbb' as is_party_member_of_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.add_party_member(text, integer)')) = '30234f39227c07954c69b4a51ac0de37' as add_party_member_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.party_add_quote(text)')) = 'ffb0e903cc5fb35be676ef7e3659e62c' as party_add_quote_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_party_seat()')) = '19e817b5c3308bf891e9e4ba7ea356cd' as buy_party_seat_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.record_kill(text, text, timestamp with time zone, text[])')) = '87bbeae7464bea90e67a56cd73dd56d4' as record_kill_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.record_custom_kill(uuid, text, timestamp with time zone, text[], uuid)')) = '1e14f0237e7c555758a7bcb452ae73e3' as record_custom_kill_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.add_custom_boss_timer(uuid, text)')) = 'b92e1fa68e3770463f2abc9b10eea5f6' as add_custom_boss_timer_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.remove_custom_boss_timer(uuid, text)')) = 'fdfc3f3722b3e178425749c638badfc0' as remove_custom_boss_timer_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.set_custom_boss_time(uuid, text, timestamp with time zone)')) = '357c08def3ddbf047c67fb9744b9c1c0' as set_custom_boss_time_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.set_custom_boss_marker(uuid, text, numeric, numeric)')) = '447b487116b8a22de01bea8e76408ddf' as set_custom_boss_marker_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.my_party_status()')) = '00ce2c8b11dae4ba3588442cb9010500' as my_party_status_ok,
  (select prosecdef from pg_proc where oid = to_regprocedure('public.my_party_status()')) as status_definer,
  has_function_privilege('authenticated', 'public.my_party_status()', 'execute') as status_auth_exec_true,
  has_function_privilege('anon', 'public.my_party_status()', 'execute') as status_anon_exec_false;
