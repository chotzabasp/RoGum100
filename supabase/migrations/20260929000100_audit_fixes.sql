-- ============================================================
-- แก้บั๊กจากการตรวจโค้ดรอบสุดท้าย (29 ก.ย. 2569) — รวมทุกข้อที่ต้องแก้ที่ฐานข้อมูลไว้ในไฟล์เดียว
-- เนื้อฟังก์ชันคัดลอกตรงตัวจากไฟล์ล่าสุดใน repo (md5 ตรงกับฐานข้อมูลจริงตาม baseline) แก้เฉพาะจุดที่ระบุ
-- create or replace คงสิทธิ์เรียกใช้เดิม · buy_plan ต้องลบแล้วสร้างใหม่ (เพิ่มพารามิเตอร์) จึงตั้งสิทธิ์ให้ใหม่แบบเดิม
--
-- 1) touch_presence — "เวลาเปิดดูเฉลี่ย" นับขาด เหลือ 0 ได้ทั้งที่ดูอยู่: เปิดแอปไว้ 2 แท็บ แท็บพื้นหลังส่งสัญญาณก่อน
--    แท็บที่เปิดดูไม่ถึง 50 วิ → นาทีนั้นถูกนับจากแท็บพื้นหลังทุกครั้ง แท็บที่เปิดดูไม่เคยถูกนับ
--    แก้: แท็บที่เปิดดูส่งมาในนาทีที่ถูกนับไปแล้วแบบ "พื้นหลัง" → เปลี่ยนนาทีนั้นเป็น "เปิดดู" 1 ครั้ง
--    (visible_seen_at ก่อนหน้า < เวลาที่นับนาทีนั้น = นาทีนั้นยังไม่มีแท็บที่เปิดดู · ไม่ให้เกินจำนวนนาทีที่นับ) ไม่ต้องเพิ่มคอลัมน์
-- 2) RLS profiles_select — ชื่อคนที่ออกจากปาร์ตี้ไปแล้วหาย: ประวัติขึ้นคนกดว่าง / "ไม่ทราบชื่อ" / ชิป "✓ ไม่ทราบชื่อ" ในแท็บไอเทม
--    (กิ่งเดิมเห็นชื่อได้เฉพาะเมื่อเรากับคนนั้นอยู่ใน shared_with ของไอเทมชิ้นเดียวกันทั้งคู่)
--    แก้: เปลี่ยนเฉพาะกิ่งสุดท้ายเป็น ก) คนกด MVP ของรอบที่เรามองเห็น ข) คนที่อยู่ในการหารของไอเทมที่เรามองเห็น
--    subquery อ่าน kills / kill_items ด้วยสิทธิ์ของผู้เรียก (RLS เดิมของ 2 ตารางนั้นคุม) → เห็นชื่อเฉพาะคนในรอบ/ไอเทม
--    ที่เห็นอยู่แล้ว ไม่มีฟังก์ชันใหม่ให้เรียกดูชื่อใครก็ได้ · policy ของ kills / kill_items ไม่อ่าน profiles → ไม่วนซ้ำ
--    กิ่งอื่นคงเดิมทุกตัวอักษร · กิ่ง ข) ครอบคลุมกิ่งเดิมทั้งหมด (kill_items_select มี shared_with @> [ผู้เรียก] อยู่แล้ว)
-- 3) boss_history_by_boss — "กดโดย" ของแต่ละบอสจัดกลุ่มตามชื่อ → คนละคนที่ชื่อเหมือนกัน (เช่น "ไม่ทราบชื่อ" 2 คน) รวมเป็นบรรทัดเดียว
--    แก้: จัดกลุ่มตามรหัสคนกด (killer_key แบบเดียวกับรายชื่อ killers) ใช้ชื่อของคนนั้น
-- 4) announcements_guard + คอลัมน์ announcements.ref_buy — ราคารับ M ไม่มีตัวตรวจฝั่งฐานข้อมูล: แก้ buy ผ่าน API เป็น
--    999999999 / -1 ได้ (ชิปราคาของทุกคนเพี้ยน + คนอื่นลงราคาจริงไม่ผ่านตัวกัน 30% ของหน้าเว็บ) และแก้ประกาศตัวเองซ้ำๆ (ฟรี)
--    ดันราคาขึ้นทีละ 29% ได้เรื่อยๆ เพราะหน้าเว็บเทียบกับราคาที่ประกาศของตัวเองตั้งไว้
--    แก้: ราคาต้อง > 0 และ < 1,000,000 · ต่างจากราคาอ้างอิงไม่เกิน ±30% (ต้องตรงกับ RATE_MAX_DEVIATION ใน assets/app.js)
--    ราคาอ้างอิง = ประกาศล่าสุดที่ยังไม่หมดอายุของเซิร์ฟนั้น "ของคนอื่น" · ไม่มี = ราคาตั้งต้นที่แอดมินตั้ง (servers.buy)
--    คิดตอนลงประกาศแล้วเก็บไว้ใน ref_buy (ผู้ใช้แก้เองไม่ได้) · แก้ไขประกาศเทียบกับ ref_buy เดิมเสมอ · ย้ายเซิร์ฟ = คิดใหม่
--    ลงประกาศไม่ผ่าน = post_announcement ยกเลิกทั้งธุรกรรม แต้มไม่ถูกหัก (post_announcement ไม่ต้องแก้)
-- 5) redeem_promo_code — โค้ด 4 in 1 แบบแพ็กเกจรายวัน ตั้งทั้ง 3 in 1 และจับเวลาบอสเป็นวันหมดอายุที่ไกลกว่า + N วัน
--    (มีจับเวลาบอสรายปี แล้วกรอกโค้ด 7 วัน = ได้ 3 in 1 เกือบ 1 ปี)
--    แก้: ต่อแต่ละตัวจากวันหมดอายุของตัวเอง (แบบเดียวกับ buy_plan) · expires_at ที่ส่งกลับ = ตัวที่หมดก่อน
-- 6) buy_plan + p_expected_price — กล่องยืนยันเปิดค้างข้ามเวลาจบโปร / นาฬิกาเครื่องช้า → หักราคาใหม่ (~2 เท่า) โดยไม่เตือน
--    แก้: รับราคาที่หน้าเว็บแสดง (ไม่ส่ง = ทำงานเหมือนเดิม) ไม่ตรงกับราคาจริงหลังหักส่วนลด = ปฏิเสธ
--    "ราคาเปลี่ยนแล้ว (ตอนนี้ N แต้ม) ..." ไม่หักแต้ม · ลบตัวเดิม 3 ค่าออก (กัน PostgREST เจอ 2 ตัวแล้วเลือกไม่ได้)
--    หน้าเว็บที่ส่ง 2 หรือ 3 ค่ายังซื้อได้ตามปกติ
-- 7) enforce_free_entry_limit_update + trigger BEFORE UPDATE — บัญชีฟรีเลี่ยงลิมิตรายวัน (ซื้อ–ขาย 5 / ฟาร์ม 3) ได้
--    ด้วยการ upsert / แก้ ts ของรายการเก่าให้เป็นวันนี้ (trigger เดิมดักเฉพาะ insert และถือว่า id เดิม = แก้ไข ไม่นับ)
--    แก้: ย้ายรายการไปวันอื่น (ตามเวลาไทย) ต้องมีโควต้าว่างของวันนั้น · แก้ไขที่ ts เดิม/วันเดิมไม่นับ · ts ล่วงหน้าเกิน 1 วันไม่ได้
--    ข้อความ/ตัวเลข/เงื่อนไขแพ็กเกจเดียวกับ enforce_free_entry_limit (ตัวเดิมไม่แก้)
-- 8) log_events + ตาราง app_event_budget — ลิมิตเดิมผูกกับรหัสเครื่องที่ผู้เรียกสุ่มเองได้ → สคริปต์ยิงไม่จำกัด
--    (ฐานข้อมูล Free 500 MB เต็ม = ทั้งเว็บเขียนไม่ได้ · ตัวเลขผู้เข้าชม/สมัคร/ซื้อในแดชบอร์ดปลอมได้)
--    แก้: จำกัดตามผู้เรียกจริง 1,200 เหตุการณ์/ชม. (ไม่ล็อกอิน = ต่อ IP · ล็อกอิน = ต่อบัญชี · คนใช้จริงไม่ถึง 200)
--    + ผู้ไม่ล็อกอินทั้งระบบเกิน 600 เหตุการณ์/นาที = หยุดรับชั่วคราว (ยอมเสียสถิติช่วงนั้น ดีกว่าฐานข้อมูลเต็ม)
--    + buy_click / buy_insufficient / buy_success ต้องล็อกอิน (หน้าเว็บส่งตอนล็อกอินเท่านั้น) · signup / buy_click_guest รับเหมือนเดิม
-- 9) admin_traffic + signups_new — "% สมัครสมาชิก" เอาคนสมัครทั้งหมดหารด้วยผู้เข้าชมใหม่ → เกิน 100% หรือ 0% ทั้งที่มีคนสมัคร
--    แก้: เพิ่ม signups_new = ผู้เข้าชมใหม่ในช่วงนี้ที่สมัคร (ไม่เกิน new_guest_visitors เสมอ) · ค่าเดิมทุกตัวคงไว้
--
-- หน้าเว็บ: ใช้ค่าใหม่เมื่อมี ไม่มี (ยังไม่รันไฟล์นี้) ก็ทำงานแบบเดิม
-- ทุกอย่างอยู่ใน transaction เดียว — ตัวเช็คด้านล่างไม่ผ่าน / คำสั่งไหนพัง = ไม่มีอะไรถูกแก้
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000100_audit_fixes_rollback.sql
-- ============================================================
begin;

-- ALTER TABLE / ALTER POLICY / CREATE TRIGGER ต้องล็อกตาราง — รอเกิน 5 วิ ยกเลิกทั้งไฟล์ (ไม่มีอะไรถูกแก้) แทนการรอจนเว็บค้าง
set local lock_timeout = '5s';

-- ---------- กันเขียนทับของที่ถูกแก้จากที่อื่น ----------
do $guard$
declare
  v_md5 text;
  v_expr text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.touch_presence(text, boolean, text)');
  if v_md5 is distinct from '8441f32586b1c59d01a6a893b10cfb2a' then
    raise exception 'touch_presence ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)');
  if v_md5 is distinct from '28853f70f7e778c8aaab5ee5322b5235' then
    raise exception 'log_events ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_traffic(integer)');
  if v_md5 is distinct from '1be8f35da1736463face286585bbef0e' then
    raise exception 'admin_traffic ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc
   where oid = to_regprocedure('public.boss_history_by_boss(uuid, boolean, timestamp with time zone, timestamp with time zone, text)');
  if v_md5 is distinct from 'f718a12da7387115535ad8641db4c1ce' then
    raise exception 'boss_history_by_boss ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.announcements_guard()');
  if v_md5 is distinct from 'b4019cab722bbf8c004a61828d381ad7' then
    raise exception 'announcements_guard ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.redeem_promo_code(text)');
  if v_md5 is distinct from '315a380671dae7a1a942bf7258af3975' then
    raise exception 'redeem_promo_code ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text)');
  if v_md5 is distinct from '66fc0af55492cd8dec0a444db436bf65' then
    raise exception 'buy_plan ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;

  -- trigger ที่ใช้ announcements_guard ต้องมีอยู่ (ตัวตรวจราคาทำงานผ่าน trigger นี้)
  if not exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                  and tgname = 'announcements_guard_trg' and not tgisinternal) then
    raise exception 'ไม่พบ trigger announcements_guard_trg — ไม่มีอะไรถูกแก้';
  end if;

  -- ของใหม่ต้องยังไม่มี (กันรันซ้ำ)
  if to_regprocedure('public.buy_plan(text, text, text, integer)') is not null
     or to_regprocedure('public.enforce_free_entry_limit_update()') is not null
     or to_regclass('public.app_event_budget') is not null
     or exists (select 1 from pg_attribute where attrelid = 'public.announcements'::regclass
                 and attname = 'ref_buy' and not attisdropped)
     or exists (select 1 from pg_trigger where tgname in ('merchant_entries_free_limit_update', 'farm_entries_free_limit_update')) then
    raise exception 'มีของชุดนี้อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;

  -- policy profiles_select ต้องตรงกับที่ repo รู้จัก (เทียบแบบรวมช่องว่าง — ข้อความจาก baseline ฐานข้อมูลจริง)
  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.profiles'::regclass and polname = 'profiles_select';
  if v_expr is distinct from '((( SELECT auth.uid() AS uid) = id) OR ( SELECT is_admin() AS is_admin) OR is_party_member_of(id) OR is_my_party_member(id) OR shares_party_with(id) OR (EXISTS ( SELECT 1 FROM kill_items ki WHERE (ki.shared_with @> ARRAY[( SELECT auth.uid() AS uid), profiles.id]))))' then
    raise exception 'policy profiles_select ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', coalesce(v_expr, 'ไม่พบ policy');
  end if;
end;
$guard$;

-- ---------- 1) touch_presence: นาทีที่แท็บพื้นหลังนับไปแล้ว + มีแท็บที่เปิดดูในนาทีเดียวกัน = นาที "เปิดดู" ----------
create or replace function public.touch_presence(p_page text default null, p_visible boolean default true, p_device text default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_page text := nullif(p_page, '');
  v_dev text := nullif(p_device, '');
  v_vis boolean := coalesce(p_visible, false);
  v_last timestamptz;
  v_vis_prev timestamptz;
  v_count boolean;
begin
  if v_uid is null then return; end if;
  if v_page is not null and v_page not in ('home', 'farm', 'timers', 'items', 'pricing', 'settings', 'admin') then v_page := null; end if;
  if v_dev is not null and v_dev not in ('mobile', 'tablet', 'desktop') then v_dev := null; end if;
  -- นับเป็น 1 นาทีใช้งานได้ไม่เกินครั้งละ ~1 นาที (เปิดหลายแท็บไม่นับซ้ำ) · อัปเดตเวลาล่าสุดทุกครั้ง
  select last_ping_at, visible_seen_at into v_last, v_vis_prev from public.user_presence where user_id = v_uid for update;
  v_count := v_last is null or v_last <= now() - interval '50 seconds';
  insert into public.user_presence as up (user_id, last_seen_at, visible_seen_at, last_ping_at, page, device)
  values (v_uid, now(), case when v_vis then now() end, now(), v_page, v_dev)
  on conflict (user_id) do update set
    last_seen_at = now(),
    visible_seen_at = case when v_vis then now() else up.visible_seen_at end,
    last_ping_at = case when v_count then now() else up.last_ping_at end,
    -- หน้าที่กำลังดู: ยึดแท็บที่เปิดดูอยู่ก่อนแท็บพื้นหลัง
    page = case when v_vis or up.visible_seen_at is null or up.visible_seen_at < now() - interval '5 minutes'
                then coalesce(v_page, up.page) else up.page end,
    device = coalesce(v_dev, up.device);
  if v_count then
    insert into public.user_activity_hours as h (user_id, hour, pings, visible_pings)
    values (v_uid, date_trunc('hour', now()), 1, case when v_vis then 1 else 0 end)
    on conflict (user_id, hour) do update set
      pings = h.pings + 1,
      visible_pings = h.visible_pings + excluded.visible_pings;
  -- นาทีนี้ถูกนับไปแล้วจากแท็บพื้นหลัง แต่มีแท็บที่เปิดดูอยู่ส่งมาในนาทีเดียวกัน → นับนาทีนั้นเป็น "เปิดดู" (ครั้งเดียว)
  -- visible_seen_at ก่อนหน้า < เวลาที่นับนาทีนั้น = นาทีนั้นยังไม่มีแท็บที่เปิดดู (นาทีที่นับจากแท็บเปิดดูเอง 2 ค่านี้เท่ากันพอดี)
  -- ไม่ให้นาทีเปิดดูเกินจำนวนนาทีที่นับ
  elsif v_vis and v_last is not null and (v_vis_prev is null or v_vis_prev < v_last) then
    update public.user_activity_hours set visible_pings = visible_pings + 1
     where user_id = v_uid and hour = date_trunc('hour', v_last) and visible_pings < pings;
  end if;
  if random() < 0.001 then
    delete from public.user_activity_hours where hour < now() - interval '180 days';
  end if;
end;
$function$;

-- ---------- 2) RLS profiles_select: เห็นชื่อคนกด MVP / คนในการหาร ของรอบและไอเทมที่เรามองเห็น ----------
alter policy profiles_select on public.profiles
  using (((select auth.uid()) = id) or (select is_admin()) or is_party_member_of(id) or is_my_party_member(id)
         or shares_party_with(id)
         or (exists (select 1 from public.kills k where k.killed_by = profiles.id))
         or (exists (select 1 from public.kill_items ki where ki.shared_with @> array[profiles.id])));

-- ---------- 3) boss_history_by_boss: "กดโดย" แยกตามรหัสคนกด ----------
create or replace function public.boss_history_by_boss(
  p_host uuid, p_include_self boolean,
  p_since timestamptz default null, p_today_start timestamptz default null,
  p_killer text default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with base as (
    select s.id, s.boss_id, s.boss_name, s.server_id, s.killed_at, s.killed_by,
           coalesce(s.killed_by::text, 'none') as killer_key,
           case when s.killed_by is null then 'ไม่ระบุ'
                else coalesce((select p.display_name from public.profiles p where p.id = s.killed_by), 'ไม่ทราบชื่อ') end as killer_name
      from public.boss_history_scope(p_host, p_include_self) s
     where p_since is null or s.killed_at >= p_since
  ), scoped as (
    select * from base
     where p_killer is null or p_killer = 'all' or killer_key = p_killer
  ), killers as (
    select killer_key, min(killer_name) as name, count(*) as cnt, max(killed_at) as last_at
      from base group by killer_key
  ), grp as (
    select boss_id, coalesce(server_id, '') as sv,
           (array_agg(boss_name order by killed_at desc, id desc))[1] as boss_name,
           count(*) as kills,
           count(*) filter (where p_today_start is not null and killed_at >= p_today_start) as today,
           max(killed_at) as last_at
      from scoped group by boss_id, coalesce(server_id, '')
  ), by_killer as (
    select boss_id, coalesce(server_id, '') as sv, min(killer_name) as killer_name, count(*) as cnt, max(killed_at) as last_at
      from scoped group by boss_id, coalesce(server_id, ''), killer_key
  ), item_counts as (
    select sc.boss_id, coalesce(sc.server_id, '') as sv, it.name, count(*) as cnt, max(sc.killed_at) as last_at
      from scoped sc join public.kill_items it on it.kill_id = sc.id
     group by sc.boss_id, coalesce(sc.server_id, ''), it.name
  )
  select jsonb_build_object(
    'killers', coalesce((select jsonb_agg(jsonb_build_object('id', killer_key, 'name', name, 'count', cnt)
                                          order by last_at desc) from killers), '[]'::jsonb),
    'groups', coalesce((select jsonb_agg(jsonb_build_object(
        'boss_id', g.boss_id, 'server_id', nullif(g.sv, ''), 'boss_name', g.boss_name,
        'kills', g.kills, 'today', g.today, 'last_at', g.last_at,
        'by', coalesce((select jsonb_agg(jsonb_build_object('name', b.killer_name, 'count', b.cnt) order by b.last_at desc)
                          from by_killer b where b.boss_id = g.boss_id and b.sv = g.sv), '[]'::jsonb),
        'items', coalesce((select jsonb_agg(jsonb_build_object('name', ic.name, 'count', ic.cnt) order by ic.last_at desc, ic.name)
                             from item_counts ic where ic.boss_id = g.boss_id and ic.sv = g.sv), '[]'::jsonb)
      ) order by g.last_at desc) from grp g), '[]'::jsonb)
  );
$$;

-- ---------- 4) ราคารับ M: ตรวจที่ฐานข้อมูล + ราคาอ้างอิงล็อกไว้ตอนลงประกาศ ----------
-- ประกาศที่ลงไว้ก่อนรันไฟล์นี้ ref_buy ว่าง → แก้ไขครั้งแรกคิดราคาอ้างอิงให้ตอนนั้น (ไม่นับประกาศของตัวเอง)
alter table public.announcements add column ref_buy numeric;

CREATE OR REPLACE FUNCTION public.announcements_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  min_exp timestamptz := now() + interval '1 minute';
  max_exp timestamptz := now() + interval '24 hours';
  v_ref numeric;
begin
  if tg_op = 'INSERT' then
    new.user_id    := auth.uid();
    select coalesce(p.display_name, 'สมาชิก') into new.user_name
      from public.profiles p where p.id = auth.uid();
    if new.user_name is null then new.user_name := 'สมาชิก'; end if;
    new.created_at := now();
    if new.expires_at is null or new.expires_at < min_exp then new.expires_at := min_exp; end if;
    if new.expires_at > max_exp then new.expires_at := max_exp; end if;
    new.ref_buy    := null;
  else
    -- แก้ไขประกาศ = เปลี่ยนได้แค่เซิร์ฟเวอร์กับราคา นาฬิกานับถอยหลังห้ามรีเซ็ต ลิงก์ Facebook ห้ามเปลี่ยน
    new.id           := old.id;
    new.user_id      := old.user_id;
    new.user_name    := old.user_name;
    new.created_at   := old.created_at;
    new.expires_at   := old.expires_at;
    new.facebook_url := old.facebook_url;
    -- ราคาอ้างอิงผู้ใช้แก้เองไม่ได้ · ไม่ได้แก้ราคา/เซิร์ฟเวอร์ = ไม่ต้องตรวจราคา
    if new.buy is not distinct from old.buy and new.server_id is not distinct from old.server_id then
      new.ref_buy := old.ref_buy;
      return new;
    end if;
    -- แก้ไขประกาศเทียบกับราคาอ้างอิงตอนลงประกาศ (แก้ซ้ำๆ ดันราคาขึ้นเองไม่ได้) · ย้ายเซิร์ฟ = คิดราคาอ้างอิงของเซิร์ฟใหม่
    new.ref_buy := case when new.server_id is distinct from old.server_id then null else old.ref_buy end;
  end if;
  -- ราคารับ M: ราคาอ้างอิง = ประกาศล่าสุดที่ยังไม่หมดอายุของเซิร์ฟนี้ "ของคนอื่น" · ไม่มี = ราคาตั้งต้นของแอดมิน (servers.buy)
  -- ไม่นับประกาศของตัวเอง (กันลงประกาศ/แก้ราคาต่อยอดจากราคาของตัวเอง) · ±30% ต้องตรงกับ RATE_MAX_DEVIATION ใน assets/app.js
  if new.ref_buy is null then
    select a.buy into v_ref from public.announcements a
     where a.server_id = new.server_id and a.expires_at > now() and a.buy > 0 and a.buy < 1000000
       and a.user_id is distinct from auth.uid()
     order by a.created_at desc limit 1;
    if v_ref is null then
      select s.buy into v_ref from public.servers s where s.id = new.server_id;
    end if;
    new.ref_buy := v_ref;
  end if;
  -- NaN ของ numeric มากกว่าทุกตัวเลข (ผ่าน > 0) → ตรวจตรงๆ · เพดาน 1,000,000 กัน Infinity / เลขเกินจริง
  if new.buy is null or new.buy = 'NaN'::numeric or new.buy <= 0 or new.buy >= 1000000 then
    raise exception 'ราคารับ M ไม่ถูกต้อง';
  end if;
  if new.ref_buy > 0 and abs(new.buy - new.ref_buy) > new.ref_buy * 0.30 then
    raise exception 'ราคาต่างจากราคาปัจจุบัน (%บ) เกิน 30%% กรุณาตรวจสอบราคาอีกครั้ง', new.ref_buy;
  end if;
  return new;
end; $function$;

-- ---------- 5) redeem_promo_code: โค้ด 4 in 1 ต่อแต่ละแพ็กจากวันหมดอายุของตัวเอง ----------
create or replace function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
  v_plan text;
  v_name text;
  v_bundle timestamptz;
  v_timers timestamptz;
  v_before timestamptz;
  v_bundle_new timestamptz;
  v_timers_new timestamptz;
  v_new timestamptz;
  v_points_after int;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;

  select * into v_row from public.promo_codes where code = v_code for update;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.reward_type = 'discount' then raise exception 'โค้ดนี้เป็นโค้ดส่วนลด ใช้ตอนกดซื้อแพ็กเกจ (กรอกในกล่องยืนยันการซื้อ)'; end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = auth.uid()) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;
  perform public.promo_group_check(v_row.group_key, auth.uid());

  insert into public.promo_code_redemptions (code, user_id) values (v_code, auth.uid());
  update public.promo_codes set used_count = used_count + 1 where code = v_code;

  if v_row.reward_type = 'plan_days' then
    v_plan := coalesce(v_row.plan_key, 'all');
    v_name := case v_plan
      when 'bundle' then '3 in 1'
      when 'timers' then 'จับเวลาบอส'
      when 'farm' then '1 in 1'
      when 'accountItems' then '2 in 1'
      else '4 in 1' end;
    select plan_bundle_expires_at, plan_timers_expires_at into v_bundle, v_timers
      from public.profiles where id = auth.uid() for update;

    if v_plan = 'bundle' then
      v_new := greatest(coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_bundle_expires_at = v_new where id = auth.uid();
    elsif v_plan = 'timers' then
      v_new := greatest(coalesce(v_timers, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_timers_expires_at = v_new where id = auth.uid();
    elsif v_plan in ('farm', 'accountItems') then
      select expires_at into v_before from public.package_feature_entitlements
        where user_id = auth.uid() and feature = v_plan;
      v_new := greatest(coalesce(v_before, now()), coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      insert into public.package_feature_entitlements (user_id, feature, expires_at) values (auth.uid(), v_plan, v_new)
        on conflict (user_id, feature) do update set expires_at = excluded.expires_at;
    else
      -- 4 in 1 = ต่อ 3 in 1 และจับเวลาบอสแยกจากวันหมดอายุของแต่ละตัว (แบบเดียวกับ buy_plan)
      -- ไม่ดึงตัวที่สั้นกว่าไปเท่าตัวที่ยาวกว่า · expires_at ที่ส่งกลับ = ตัวที่หมดก่อน
      v_bundle_new := greatest(coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      v_timers_new := greatest(coalesce(v_timers, now()), now()) + (v_row.plan_days || ' days')::interval;
      v_new := least(v_bundle_new, v_timers_new);
      update public.profiles set plan_bundle_expires_at = v_bundle_new, plan_timers_expires_at = v_timers_new where id = auth.uid();
    end if;

    select points into v_points_after from public.profiles where id = auth.uid();
    insert into public.points_ledger (user_id, delta, balance_after, reason, actor, detail)
    values (auth.uid(), 0, v_points_after, 'promo_code', auth.uid(),
      'กรอกรหัสโปรโมชั่น '||v_code||' — แพ็กเกจ '||v_name||' จำนวน '||v_row.plan_days||' วัน');

    return jsonb_build_object('reward_type', 'plan_days', 'plan_key', v_plan, 'plan_days', v_row.plan_days, 'expires_at', v_new);
  else
    perform set_config('app.points_ledger_detail', 'กรอกรหัสโปรโมชั่น '||v_code, true);
    update public.profiles set points = points + v_row.points where id = auth.uid();
    return jsonb_build_object('reward_type', 'points', 'points', v_row.points);
  end if;
end;
$function$;

-- ---------- 6) buy_plan: + p_expected_price (ลบตัวเดิม 3 ค่าออก กันเรียกแล้วชนกัน 2 ตัว) ----------
drop function public.buy_plan(text, text, text);

create function public.buy_plan(p_plan_key text, p_cycle text, p_code text default null, p_expected_price integer default null)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text;
  v_promo public.promo_codes%rowtype; v_code text; v_full_price integer; v_discount integer := 0;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  -- ราคาจากตารางราคากลาง plan_price (ช่วงโปรลด 50% อยู่ในนั้นแล้ว)
  v_price := public.plan_price(p_plan_key, p_cycle);
  if v_price is null then raise exception 'แพ็กเกจไม่ถูกต้อง'; end if;
  -- โค้ดส่วนลด (%): ลดจากราคาที่ต้องจ่ายตอนนั้น (ซ้อนกับโปรได้) ราคาหลังลดปัดเศษลง
  -- ตรวจและล็อกแถวโค้ดก่อนหักแต้ม — นับว่าใช้โค้ดแล้วเฉพาะตอนซื้อสำเร็จ (อยู่ในธุรกรรมเดียวกัน)
  if nullif(btrim(coalesce(p_code, '')), '') is not null then
    v_promo := public.discount_code_check(p_code, p_plan_key, v_uid, true);
    v_code := v_promo.code;
    v_full_price := v_price;
    v_price := floor(v_full_price * (100 - v_promo.discount_percent) / 100.0)::integer;
    v_discount := v_full_price - v_price;
  end if;
  -- ราคาที่หักจริง (หลังส่วนลด) ต้องตรงกับที่กล่องยืนยันแสดง — เปิดกล่องค้างข้ามเวลาจบโปร / นาฬิกาเครื่องเพี้ยน
  -- = ไม่หักแต้ม ให้ดูราคาใหม่ก่อน · หน้าเว็บที่ไม่ส่งค่านี้ซื้อได้เหมือนเดิม
  if p_expected_price is not null and p_expected_price <> v_price then
    raise exception 'ราคาเปลี่ยนแล้ว (ตอนนี้ % แต้ม) กรุณาตรวจสอบอีกครั้ง', v_price;
  end if;
  select points, plan_bundle_expires_at, plan_timers_expires_at into v_points, v_bundle, v_timers
    from public.profiles where id = v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points, 0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
    v_before := greatest(v_before, v_bundle);
    v_new := greatest(coalesce(v_before, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
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
  v_name := case p_plan_key
    when 'farm' then '1 in 1 — ยอดนักฟาร์ม'
    when 'accountItems' then '2 in 1'
    when 'bundle' then '3 in 1'
    when 'timers' then 'จับเวลาบอส'
    else '4 in 1' end;
  if v_code is not null then
    -- บันทึกการใช้โค้ด + ข้อความในประวัติแต้ม (trigger log_points_change อ่านค่านี้ตอนหักแต้มบรรทัดถัดไป)
    insert into public.promo_code_redemptions (code, user_id) values (v_code, v_uid);
    update public.promo_codes set used_count = used_count + 1 where code = v_code;
    perform set_config('app.points_ledger_detail',
      'ซื้อแพ็กเกจ ' || v_name || ' · ใช้โค้ดส่วนลด ' || v_code || ' ลด ' || v_promo.discount_percent || '%', true);
  end if;
  update public.profiles set points = points - v_price where id = v_uid;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id, plan_key, plan_name, cycle, points_spent, days_added, expires_before, expires_after, promo_code, discount_points)
    values (v_uid, p_plan_key, v_name, p_cycle, v_price, v_days, v_before, v_new, v_code, nullif(v_discount, 0));
  end if;
  return v_new;
end;
$function$;

revoke all on function public.buy_plan(text, text, text, integer) from public, anon;
grant execute on function public.buy_plan(text, text, text, integer) to authenticated;

-- ---------- 7) ลิมิตบัญชีฟรี: ย้ายรายการไปวันอื่นด้วยการแก้ / upsert ต้องมีโควต้าของวันนั้น ----------
-- upsert ของ id ที่มีอยู่แล้วผ่านทาง UPDATE → โดนตัวนี้ด้วย · แก้ไขปกติ (ts เดิม หรือวันเดิม) ผ่านเหมือนเดิม
create function public.enforce_free_entry_limit_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit int;
  v_label text;
  v_plan_name text;
  v_unit text;
  v_day date;
  v_start bigint;
  v_end bigint;
  v_count int;
begin
  if v_uid is null or new.user_id is distinct from v_uid then return new; end if;
  -- เวลาเดิม = แก้ไขเนื้อรายการเฉยๆ ไม่นับโควต้า
  if new.ts is not distinct from old.ts then return new; end if;
  if public.is_admin() then return new; end if;

  if TG_TABLE_NAME = 'merchant_entries' then
    if public.has_trade_plan(v_uid) then return new; end if;
    v_limit := 5; v_label := 'บันทึกซื้อ–ขาย'; v_unit := 'รายการ'; v_plan_name := '2 in 1, 3 in 1 หรือ 4 in 1';
  elsif TG_TABLE_NAME = 'farm_entries' then
    if public.has_farm_plan(v_uid) then return new; end if;
    v_limit := 3; v_label := 'บันทึกต้นทุนต่อกั้ม'; v_unit := 'ครั้ง'; v_plan_name := '1 in 1, 3 in 1 หรือ 4 in 1';
  else
    return new;
  end if;

  if new.ts > (extract(epoch from now()) * 1000)::bigint + 86400000 then
    raise exception 'เวลาของรายการไม่ถูกต้อง';
  end if;

  -- ย้ายเวลาภายในวันเดียวกัน (ตามเวลาไทย) ไม่นับเพิ่ม — ย้ายไปวันอื่น = ใช้โควต้าของวันนั้น
  v_day := (to_timestamp(new.ts / 1000.0) at time zone 'Asia/Bangkok')::date;
  if v_day = (to_timestamp(old.ts / 1000.0) at time zone 'Asia/Bangkok')::date then return new; end if;

  -- คิวเดียวกับ trigger ตอน insert (กันสองแท็บบันทึก/ย้ายพร้อมกันแล้วนับพลาด)
  perform pg_advisory_xact_lock(hashtext(TG_TABLE_NAME || ':' || v_uid::text));

  v_start := (extract(epoch from (v_day::timestamp at time zone 'Asia/Bangkok')) * 1000)::bigint;
  v_end := v_start + 86400000;

  if TG_TABLE_NAME = 'merchant_entries' then
    select count(*) into v_count from public.merchant_entries
     where user_id = v_uid and ts >= v_start and ts < v_end and id is distinct from old.id;
  else
    select count(*) into v_count from public.farm_entries
     where user_id = v_uid and ts >= v_start and ts < v_end and id is distinct from old.id;
  end if;

  if v_count >= v_limit then
    raise exception 'บัญชีฟรี%ได้ % % ต่อวัน — วันนี้ครบแล้ว (สมัครแพ็กเกจ % เพื่อบันทึกไม่จำกัด)',
      v_label, v_limit, v_unit, v_plan_name;
  end if;

  return new;
end;
$function$;

revoke all on function public.enforce_free_entry_limit_update() from public, anon, authenticated;

create trigger merchant_entries_free_limit_update
  before update on public.merchant_entries
  for each row when (old.ts is distinct from new.ts)
  execute function public.enforce_free_entry_limit_update();

create trigger farm_entries_free_limit_update
  before update on public.farm_entries
  for each row when (old.ts is distinct from new.ts)
  execute function public.enforce_free_entry_limit_update();

-- ---------- 8) log_events: จำกัดตามผู้เรียกจริง (IP / บัญชี) + เพดานรวมของผู้ไม่ล็อกอิน ----------
-- ตัวนับต่อผู้เรียก: 1 แถวต่อ 'ip:<ip>' (ไม่ล็อกอิน) หรือ 'u:<รหัสบัญชี>' (ล็อกอิน) · หน้าต่าง 1 ชม. เริ่มใหม่เมื่อครบ
-- ปิดสิทธิ์อ่าน/เขียนตรง (RLS เปิด ไม่มี policy) ใช้ผ่าน log_events เท่านั้น · แถวเก่ากว่า 1 วันถูกล้างเป็นระยะ
create table public.app_event_budget (
  key text primary key,
  window_start timestamptz not null default now(),
  n integer not null default 0
);
alter table public.app_event_budget enable row level security;
revoke all on table public.app_event_budget from public, anon, authenticated;

create or replace function public.log_events(p_visitor text, p_events jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  e jsonb;
  v_event text;
  v_page text;
  v_value int;
  v_meta text;
  v_detail text;
  v_err_budget int;
  v_hdr text;
  v_key text;
  v_n int;
begin
  if p_visitor is null or p_visitor !~ '^[A-Za-z0-9-]{8,40}$' then return; end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then return; end if;
  if (select count(*) from public.app_events
       where visitor_id = p_visitor and created_at > now() - interval '1 hour') >= 600 then
    return;
  end if;
  -- รหัสเครื่อง (p_visitor) ผู้เรียกสุ่มใหม่ได้ทุกครั้ง → จำกัดเพิ่มตามผู้เรียกจริง: ไม่ล็อกอิน = ต่อ IP · ล็อกอิน = ต่อบัญชี
  if v_uid is null then
    -- เพดานรวมของผู้ไม่ล็อกอินทั้งระบบ (กันยิงจากหลาย IP): เกิน 600 เหตุการณ์ใน 1 นาที = ไม่บันทึกชั่วคราว
    if (select count(*) from public.app_events
         where user_id is null and created_at > now() - interval '1 minute') >= 600 then
      return;
    end if;
    -- IP ของผู้เรียก: cf-connecting-ip → x-forwarded-for ตัวแรก → x-real-ip · หาไม่ได้ใช้ 'unknown'
    v_hdr := nullif(current_setting('request.headers', true), '');
    if v_hdr is not null then
      v_key := nullif(btrim(split_part(coalesce(v_hdr::json ->> 'cf-connecting-ip', v_hdr::json ->> 'x-forwarded-for',
                                                v_hdr::json ->> 'x-real-ip', ''), ',', 1)), '');
    end if;
    v_key := 'ip:' || left(coalesce(v_key, 'unknown'), 64);
  else
    v_key := 'u:' || v_uid::text;
  end if;
  -- ไม่เกิน 1,200 เหตุการณ์ต่อชั่วโมงต่อผู้เรียก (คนใช้จริงไม่ถึง 200) · นับทุกชุดที่ส่งมา · ครบ 1 ชม. เริ่มนับใหม่
  insert into public.app_event_budget as b (key, window_start, n)
  values (v_key, now(), least(jsonb_array_length(p_events), 30))
  on conflict (key) do update set
    n = case when b.window_start < now() - interval '1 hour' then excluded.n else b.n + excluded.n end,
    window_start = case when b.window_start < now() - interval '1 hour' then now() else b.window_start end
  returning n into v_n;
  if v_n > 1200 then return; end if;
  select 30 - count(*) into v_err_budget from public.app_events
   where visitor_id = p_visitor and event = 'client_error' and created_at > now() - interval '1 hour';

  for e in select value from jsonb_array_elements(p_events) limit 30 loop
    v_event := e ->> 'e';
    if v_event is null or v_event not in ('visit', 'page_view', 'page_time', 'buy_click', 'buy_click_guest',
                                          'buy_insufficient', 'buy_success', 'signup', 'client_error',
                                          'landing_view', 'landing_cta') then
      continue;
    end if;
    -- ขั้นตอนซื้อแพ็กเกจส่งตอนล็อกอินเท่านั้น (ผู้เยี่ยมชมใช้ buy_click_guest) — ไม่มีบัญชี = ไม่นับ
    if v_uid is null and v_event in ('buy_click', 'buy_insufficient', 'buy_success') then
      continue;
    end if;
    v_page := nullif(e ->> 'p', '');
    if v_page is not null and v_page not in ('home', 'farm', 'timers', 'items', 'pricing', 'settings', 'admin', 'landing') then
      v_page := null;
    end if;
    v_value := case when (e ->> 'v') ~ '^\d{1,6}$' then least((e ->> 'v')::int, 86400) else null end;
    v_meta := left(nullif(regexp_replace(coalesce(e ->> 'm', ''), '[^A-Za-z0-9_:-]', '', 'g'), ''), 40);
    v_detail := null;

    if v_event in ('visit', 'landing_view') and v_meta is not null and v_meta not in ('mobile', 'tablet', 'desktop') then
      v_meta := null;
    end if;
    -- ปุ่มที่กดบนหน้าแรก: สมัคร / เข้าสู่ระบบ / ดูแพ็กเกจ / เข้าแอป
    if v_event = 'landing_cta' and (v_meta is null or v_meta not in ('signup', 'login', 'pricing', 'app')) then
      v_meta := null;
    end if;
    if v_event = 'client_error' then
      if v_err_budget <= 0 then continue; end if;
      v_err_budget := v_err_budget - 1;
      if v_meta is null or v_meta not in ('js', 'promise', 'sync', 'load') then v_meta := 'js'; end if;
      v_detail := left(btrim(regexp_replace(coalesce(e ->> 'd', ''), '[[:cntrl:]]+', ' ', 'g')), 200);
      if v_detail = '' then continue; end if;
    end if;

    insert into public.app_events (visitor_id, user_id, event, page, value, meta, detail)
    values (p_visitor, v_uid, v_event, v_page, v_value, v_meta, v_detail);
  end loop;

  if random() < 0.005 then
    delete from public.app_events where created_at < now() - interval '180 days';
    delete from public.app_event_budget where window_start < now() - interval '1 day';
  end if;
end;
$function$;

-- ---------- 9) admin_traffic: + signups_new (ตัวตั้งของ % สมัครสมาชิก) ----------
create or replace function public.admin_traffic(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_start date;
  v_start_ts timestamptz;
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  v_start := v_today - (v_days - 1);
  v_start_ts := v_start::timestamp at time zone 'Asia/Bangkok';

  with
  admin_vis as (
    select distinct a.visitor_id from app_events a join profiles p on p.id = a.user_id where p.role = 'admin'
  ),
  -- ตัวเลขเดิมทั้งหมด = ผู้เข้าชมแอป (app.html) · เหตุการณ์หน้าแรก (landing_*) แยกไปนับใน landall ไม่ปนกัน
  allev as (
    select a.* from app_events a where a.event not in ('landing_view', 'landing_cta')
       and not exists (select 1 from admin_vis x where x.visitor_id = a.visitor_id)
  ),
  landall as (
    select a.*, (a.created_at at time zone 'Asia/Bangkok')::date as d from app_events a
     where a.event in ('landing_view', 'landing_cta')
       and not exists (select 1 from admin_vis x where x.visitor_id = a.visitor_id)
  ),
  lev as (
    select * from landall where created_at >= v_start_ts
  ),
  ev as (
    select a.*, (a.created_at at time zone 'Asia/Bangkok')::date as d from allev a where a.created_at >= v_start_ts
  ),
  first_seen as (
    select visitor_id, min(created_at) as first_at,
           (array_agg(user_id order by created_at))[1] as first_user
      from allev group by visitor_id
  ),
  -- อุปกรณ์ล่าสุดของแต่ละเครื่อง (จากเหตุการณ์ visit ที่มีข้อมูลอุปกรณ์)
  vis_device as (
    select distinct on (visitor_id) visitor_id, meta as device
      from allev where event = 'visit' and meta in ('mobile', 'tablet', 'desktop')
     order by visitor_id, created_at desc
  ),
  days as (
    select generate_series(v_start, v_today, interval '1 day')::date as d
  )
  select jsonb_build_object(
    'since', (select min(created_at) from app_events),
    'days', v_days,
    'visitors_today', (select count(distinct visitor_id) from ev where d = v_today),
    'visitors_yesterday', (select count(distinct visitor_id) from ev where d = v_today - 1),
    'visitors_period', (select count(distinct visitor_id) from ev),
    -- ผู้เข้าชม 7 วันล่าสุด (รวมวันนี้) แบบคงที่ ไม่ตามช่วงที่เลือก (ช่วงสั้นสุด 7 วัน ev จึงครอบคลุมเสมอ)
    'visitors_7d', (select count(distinct visitor_id) from ev where d >= v_today - 6),
    'members_7d', (select count(distinct visitor_id) from ev where d >= v_today - 6 and user_id is not null),
    'members_period', (select count(distinct visitor_id) from ev where user_id is not null),
    'new_guest_visitors', (select count(*) from first_seen where first_at >= v_start_ts and first_user is null),
    'signups', (select count(distinct visitor_id) from ev where event = 'signup'),
    -- สมัครเฉพาะ "ผู้เข้าชมใหม่" ของช่วงนี้ (ตัวตั้งของ % สมัครสมาชิก — ไม่เกิน new_guest_visitors เสมอ)
    'signups_new', (select count(distinct e.visitor_id) from ev e join first_seen f on f.visitor_id = e.visitor_id
                     where e.event = 'signup' and f.first_at >= v_start_ts and f.first_user is null),
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
                  'day', days.d,
                  'visitors', (select count(distinct visitor_id) from ev where ev.d = days.d),
                  'members', (select count(distinct visitor_id) from ev where ev.d = days.d and ev.user_id is not null)
                ) order by days.d), '[]'::jsonb) from days),
    'pages', (select coalesce(jsonb_agg(jsonb_build_object('page', page, 'views', views, 'visitors', visitors,
                                                           'avg_seconds', avg_s, 'total_minutes', total_m) order by views desc), '[]'::jsonb)
                from (
                  select page,
                         count(*) filter (where event = 'page_view') as views,
                         count(distinct visitor_id) filter (where event = 'page_view') as visitors,
                         round(coalesce(avg(value) filter (where event = 'page_time'), 0)) as avg_s,
                         round(coalesce(sum(value) filter (where event = 'page_time'), 0) / 60.0) as total_m
                    from ev where page is not null and event in ('page_view', 'page_time')
                   group by page
                ) s),
    'funnel', jsonb_build_object(
      'pricing_visitors', (select count(distinct visitor_id) from ev where event = 'page_view' and page = 'pricing'),
      'clicked', (select count(distinct visitor_id) from ev where event in ('buy_click', 'buy_click_guest')),
      'guest_clicked', (select count(distinct visitor_id) from ev where event = 'buy_click_guest'),
      'insufficient', (select count(distinct visitor_id) from ev where event = 'buy_insufficient'),
      'success', (select count(distinct visitor_id) from ev where event = 'buy_success')
    ),
    'plans', (select coalesce(jsonb_agg(jsonb_build_object('plan', plan, 'clicks', clicks, 'insufficient', insufficient,
                                                           'success', success) order by clicks desc), '[]'::jsonb)
                from (
                  select split_part(meta, ':', 1) as plan,
                         count(*) filter (where event in ('buy_click', 'buy_click_guest')) as clicks,
                         count(*) filter (where event = 'buy_insufficient') as insufficient,
                         count(*) filter (where event = 'buy_success') as success
                    from ev where meta is not null and event in ('buy_click', 'buy_click_guest', 'buy_insufficient', 'buy_success')
                   group by 1
                ) s),
    -- ผู้เข้าชมในช่วงนี้แยกตามอุปกรณ์ + สมัครสมาชิกกี่คนจากอุปกรณ์นั้น (เครื่องเก่าที่ยังไม่มีข้อมูลอุปกรณ์ = unknown)
    'devices', (select coalesce(jsonb_agg(jsonb_build_object('device', device, 'visitors', visitors, 'signups', signups)
                                          order by visitors desc), '[]'::jsonb)
                  from (
                    select coalesce(vd.device, 'unknown') as device,
                           count(distinct ev.visitor_id) as visitors,
                           count(distinct ev.visitor_id) filter (where ev.event = 'signup') as signups
                      from ev left join vis_device vd on vd.visitor_id = ev.visitor_id
                     group by 1
                  ) s),
    -- หน้าแรก (landing): เข้าชม → กดปุ่ม → เข้าแอป / สมัคร (เครื่องเดียวกันใช้รหัสสุ่มเดียวกันทั้งหน้าแรกและแอป)
    'landing', jsonb_build_object(
      'since', (select min(created_at) from landall),
      'visitors_today', (select count(distinct visitor_id) from lev where event = 'landing_view' and d = v_today),
      'visitors_period', (select count(distinct visitor_id) from lev where event = 'landing_view'),
      'cta_period', (select count(distinct visitor_id) from lev where event = 'landing_cta'),
      'cta_signup', (select count(distinct visitor_id) from lev where event = 'landing_cta' and meta = 'signup'),
      'cta_login', (select count(distinct visitor_id) from lev where event = 'landing_cta' and meta = 'login'),
      'to_app', (select count(distinct l.visitor_id) from lev l where l.event = 'landing_view'
                    and exists (select 1 from ev e where e.visitor_id = l.visitor_id and e.created_at >= l.created_at)),
      'signups', (select count(distinct l.visitor_id) from lev l where l.event = 'landing_view'
                    and exists (select 1 from ev e where e.visitor_id = l.visitor_id and e.event = 'signup' and e.created_at >= l.created_at))
    ),
    'errors_total', (select count(*) from ev where event = 'client_error'),
    'errors', (select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'detail', detail, 'count', cnt, 'visitors', vis,
                                                            'pages', pages, 'last_at', last_at) order by cnt desc, last_at desc), '[]'::jsonb)
                 from (
                   select meta as kind, detail, count(*) as cnt, count(distinct visitor_id) as vis,
                          array_to_string(array_agg(distinct coalesce(page, '-')), ', ') as pages,
                          max(created_at) as last_at
                     from ev where event = 'client_error'
                    group by meta, detail
                    order by count(*) desc, max(created_at) desc
                    limit 20
                 ) s)
  ) into v_out;
  return v_out;
end;
$function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ true ทุกช่อง
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.touch_presence(text, boolean, text)')) = '081f1e053d59a7760a6baaabbc7d471a' as touch_presence_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc
    where oid = to_regprocedure('public.boss_history_by_boss(uuid, boolean, timestamp with time zone, timestamp with time zone, text)')) = '849df81a7a8e8c33e61b5e7524cac54d' as boss_history_by_boss_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.announcements_guard()')) = 'fbc2e992f28e7705929ad04dbbb7c053'
    and exists (select 1 from pg_attribute where attrelid = 'public.announcements'::regclass and attname = 'ref_buy' and not attisdropped)
    and exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass and tgname = 'announcements_guard_trg'
                 and not tgisinternal and tgenabled <> 'D' and (tgtype & 4) <> 0 and (tgtype & 16) <> 0) as announcements_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.redeem_promo_code(text)')) = '178ac59f3eaca220eb52880b2b160488' as redeem_promo_code_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '6df3f933be2335f3b35dd6dbeb37e47d'
    and to_regprocedure('public.buy_plan(text, text, text)') is null
    and (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buy_plan') = 1 as buy_plan_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.enforce_free_entry_limit_update()')) = '317ed8e4d35b05eb33dc7a1de0ce8727'
    and (select count(*) from pg_trigger where tgname in ('merchant_entries_free_limit_update', 'farm_entries_free_limit_update')
          and not tgisinternal and tgenabled <> 'D') = 2 as free_limit_update_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)')) = '9542591ddf487f2b9692c9192fb5f306'
    and (select relrowsecurity from pg_class where oid = 'public.app_event_budget'::regclass)
    and not has_table_privilege('anon', 'public.app_event_budget', 'select, insert, update, delete')
    and not has_table_privilege('authenticated', 'public.app_event_budget', 'select, insert, update, delete') as log_events_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_traffic(integer)')) = 'dd29974b750db62452e1f48505d736e6' as admin_traffic_ok,
  (select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') like '%kills k%k.killed_by = profiles.id%'
      and regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') like '%ki.shared_with @> ARRAY[profiles.id]%'
      and regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') not like '%ARRAY[( SELECT auth.uid() AS uid), profiles.id]%'
     from pg_policy where polrelid = 'public.profiles'::regclass and polname = 'profiles_select') as profiles_policy_ok,
  has_function_privilege('authenticated', 'public.buy_plan(text, text, text, integer)', 'execute')
    and not has_function_privilege('anon', 'public.buy_plan(text, text, text, integer)', 'execute')
    and has_function_privilege('authenticated', 'public.touch_presence(text, boolean, text)', 'execute')
    and not has_function_privilege('anon', 'public.touch_presence(text, boolean, text)', 'execute')
    and has_function_privilege('authenticated', 'public.redeem_promo_code(text)', 'execute')
    and not has_function_privilege('anon', 'public.redeem_promo_code(text)', 'execute')
    and has_function_privilege('authenticated', 'public.boss_history_by_boss(uuid, boolean, timestamp with time zone, timestamp with time zone, text)', 'execute')
    and not has_function_privilege('anon', 'public.boss_history_by_boss(uuid, boolean, timestamp with time zone, timestamp with time zone, text)', 'execute')
    and has_function_privilege('authenticated', 'public.admin_traffic(integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_traffic(integer)', 'execute')
    and has_function_privilege('anon', 'public.log_events(text, jsonb)', 'execute')
    and not has_function_privilege('authenticated', 'public.announcements_guard()', 'execute')
    and not has_function_privilege('authenticated', 'public.enforce_free_entry_limit_update()', 'execute')
    and not has_function_privilege('anon', 'public.enforce_free_entry_limit_update()', 'execute') as grants_ok;
