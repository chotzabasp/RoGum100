-- ============================================================
-- แดชบอร์ดแอดมิน: การใช้งานรายคน (ผู้ใช้ขอ 10 ต.ค. 2569 — "วันๆ นึง user ไหนใช้อันไหนบ้าง กี่รายการ ฟาร์มกี่กั้ม"
--   เพื่อคาดการณ์การใช้งานต่อเนื่องของแต่ละคน และแพ็กเกจที่น่าจะซื้อต่อ · ผู้ใช้เลือกแบบครบ: รายคน + รายวัน + กดชื่อดูรายวัน)
--
-- 1) admin_usage_daily(from, to, user) (ภายใน เรียกตรงไม่ได้): 1 แถว/คน/วัน (เวลาไทย) ไม่นับบัญชีแอดมิน
--      pings = นาทีที่ออนไลน์ (สัญญาณทุก ~1 นาที รวมแท็บพื้นหลัง) · minutes = นาทีที่เปิดดูอยู่
--      merchant = รายการซื้อขาย · farm = รายการฟาร์ม · gums = จำนวนกั้มรวม ("จำนวนกั้ม" ในรายการ ไม่มี/ผิดรูปแบบ = 1)
--      kills = กด "ตายแล้ว" (รอบที่คนในปาร์ตี้กดซ้ำภายใน 60 วิ นับให้คนกดคนแรก) · announcements = โพสต์ประกาศรับ M
--      home_s / farm_s / timers_s / items_s / other_s = วินาทีที่อยู่หน้านั้น (นับเฉพาะตอนแท็บเปิดดูอยู่)
--      รายการซื้อขาย/ฟาร์ม นับตามวันของรายการ (ts) แบบเดียวกับลิมิตบัญชีฟรี · ที่ลบไปแล้วไม่นับ · แก้ไขไม่นับเพิ่ม
--      กดตาย/ประกาศ นับตามเวลาที่กด/โพสต์ · นาทีออนไลน์/เวลาแต่ละหน้า เก็บ 180 วัน (เริ่มเก็บปลาย ก.ย. 2569)
--      มีแถว = วันนั้นใช้งาน (เปิดเว็บตอนล็อกอิน หรือบันทึกอะไรก็ได้)
-- 2) admin_usage_plan(user) (ภายใน): วันหมดอายุแพ็กปัจจุบัน { legacy, bundle, timers, farm, accountItems }
-- 3) admin_user_usage(p_days 7–90): รายคนในช่วง — วันที่ใช้ · ใช้ล่าสุด · แถบ 14 วันล่าสุด (0 ไม่เข้า / 1 เปิดเว็บ / 2 บันทึกอะไรสักอย่าง)
--      · ยอดแต่ละฟีเจอร์ + จำนวนวันที่ใช้ (จับเวลาบอส = กดตาย หรือเปิดหน้า ≥ 1 นาที · คลังไอเทม = เปิดหน้า ≥ 1 นาที)
--      · วันที่ถึงลิมิตบัญชีฟรี (ซื้อขาย ≥ 5 / ฟาร์ม ≥ 3 ต่อวัน) · แพ็กปัจจุบัน · การซื้อล่าสุด · ปาร์ตี้
--      สูงสุด 300 คน (ใช้หลายวันก่อน) + total = จำนวนจริงทั้งหมด
-- 4) admin_user_usage_day(p_day): ทุกคนที่ใช้งานวันนั้น + ยอดรวมของวัน (ย้อนได้ 180 วัน) — สูงสุด 500 คน (บันทึกมากก่อน)
-- 5) admin_user_usage_detail(p_user, p_days 7–90): รายวันของคนเดียว (เฉพาะวันที่ใช้) + ประวัติซื้อแพ็ก 10 ครั้งล่าสุด
-- แอดมินเท่านั้น · อ่านอย่างเดียว · ไม่แก้ตาราง/ฟังก์ชันเดิม
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261010000200_admin_user_usage_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
begin
  if to_regclass('public.user_activity_hours') is null or to_regclass('public.app_events') is null
     or to_regclass('public.merchant_entries') is null or to_regclass('public.farm_entries') is null
     or to_regclass('public.kills') is null or to_regclass('public.announcements') is null
     or to_regclass('public.package_purchases') is null or to_regclass('public.package_feature_entitlements') is null
     or to_regclass('public.party_members') is null or to_regclass('public.user_presence') is null
     or to_regprocedure('public.is_admin()') is null then
    raise exception 'ไม่พบตาราง/ฟังก์ชันที่ต้องใช้ (รัน migration ก่อนหน้าครบแล้วหรือยัง?) — ไม่มีอะไรถูกแก้';
  end if;
  if to_regprocedure('public.admin_usage_daily(date, date, uuid)') is not null
     or to_regprocedure('public.admin_usage_plan(uuid)') is not null
     or to_regprocedure('public.admin_user_usage(integer)') is not null
     or to_regprocedure('public.admin_user_usage_day(date)') is not null
     or to_regprocedure('public.admin_user_usage_detail(uuid, integer)') is not null then
    raise exception 'มีฟังก์ชันการใช้งานรายคนอยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) ยอดต่อคนต่อวัน (ภายใน) ----------
create function public.admin_usage_daily(p_from date, p_to date, p_user uuid default null)
returns table (
  user_id uuid, d date, pings integer, minutes integer, merchant integer, farm integer, gums numeric,
  kills integer, announcements integer, home_s integer, farm_s integer, timers_s integer, items_s integer, other_s integer
)
language sql
stable
set search_path to ''
as $function$
  with
  b as (
    select (p_from::timestamp at time zone 'Asia/Bangkok') as t0,
           ((p_to + 1)::timestamp at time zone 'Asia/Bangkok') as t1
  ),
  bm as (
    select b.t0, b.t1, (extract(epoch from b.t0) * 1000)::bigint as m0, (extract(epoch from b.t1) * 1000)::bigint as m1 from b
  ),
  u as (
    select p.id from public.profiles p
     where p.role is distinct from 'admin' and (p_user is null or p.id = p_user)
  ),
  src as (
    -- สัญญาณ "ยังอยู่" (ชั่วโมงเวลา UTC — ไทย +7 ชม.เต็ม ชั่วโมงหนึ่งจึงอยู่ในวันไทยวันเดียว)
    select h.user_id, (h.hour at time zone 'Asia/Bangkok')::date as d,
           h.pings as pings, h.visible_pings as minutes, 0 as merchant, 0 as farm, 0::numeric as gums,
           0 as kills, 0 as announcements, 0 as home_s, 0 as farm_s, 0 as timers_s, 0 as items_s, 0 as other_s
      from public.user_activity_hours h, bm
     where h.hour >= bm.t0 and h.hour < bm.t1 and h.user_id in (select u.id from u)
    union all
    -- เปิดเว็บ / เปิดหน้า / เวลาที่อยู่แต่ละหน้า (page_time.value = วินาที)
    select a.user_id, (a.created_at at time zone 'Asia/Bangkok')::date, 0, 0, 0, 0, 0, 0, 0,
           case when a.event = 'page_time' and a.page = 'home' then greatest(coalesce(a.value, 0), 0) else 0 end,
           case when a.event = 'page_time' and a.page = 'farm' then greatest(coalesce(a.value, 0), 0) else 0 end,
           case when a.event = 'page_time' and a.page = 'timers' then greatest(coalesce(a.value, 0), 0) else 0 end,
           case when a.event = 'page_time' and a.page = 'items' then greatest(coalesce(a.value, 0), 0) else 0 end,
           case when a.event = 'page_time' and coalesce(a.page, '') not in ('home', 'farm', 'timers', 'items')
                then greatest(coalesce(a.value, 0), 0) else 0 end
      from public.app_events a, bm
     where a.created_at >= bm.t0 and a.created_at < bm.t1 and a.user_id in (select u.id from u)
       and a.event in ('visit', 'page_view', 'page_time')
    union all
    select m.user_id, (to_timestamp(m.ts / 1000.0) at time zone 'Asia/Bangkok')::date, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
      from public.merchant_entries m, bm
     where m.ts >= bm.m0 and m.ts < bm.m1 and m.user_id in (select u.id from u)
    union all
    select f.user_id, (to_timestamp(f.ts / 1000.0) at time zone 'Asia/Bangkok')::date, 0, 0, 0, 1,
           case when jsonb_typeof(f.data -> 'count') = 'number' then greatest((f.data ->> 'count')::numeric, 1)
                when (f.data ->> 'count') ~ '^[0-9]{1,9}$' then greatest((f.data ->> 'count')::numeric, 1)
                else 1 end,
           0, 0, 0, 0, 0, 0, 0
      from public.farm_entries f, bm
     where f.ts >= bm.m0 and f.ts < bm.m1 and f.user_id in (select u.id from u)
    union all
    select k.killed_by, (k.created_at at time zone 'Asia/Bangkok')::date, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0
      from public.kills k, bm
     where k.created_at >= bm.t0 and k.created_at < bm.t1 and k.killed_by in (select u.id from u)
    union all
    select an.user_id, (an.created_at at time zone 'Asia/Bangkok')::date, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0
      from public.announcements an, bm
     where an.created_at >= bm.t0 and an.created_at < bm.t1 and an.user_id in (select u.id from u)
  )
  select s.user_id, s.d,
         sum(s.pings)::integer, sum(s.minutes)::integer, sum(s.merchant)::integer, sum(s.farm)::integer, sum(s.gums),
         sum(s.kills)::integer, sum(s.announcements)::integer,
         sum(s.home_s)::integer, sum(s.farm_s)::integer, sum(s.timers_s)::integer, sum(s.items_s)::integer, sum(s.other_s)::integer
    from src s
   where s.d between p_from and p_to
   group by s.user_id, s.d
$function$;

revoke all on function public.admin_usage_daily(date, date, uuid) from public, anon, authenticated;

-- ---------- 2) แพ็กปัจจุบัน (ภายใน) — วันหมดอายุดิบ ให้หน้าเว็บตัดสินว่ายังใช้ได้/หมดแล้ว ----------
create function public.admin_usage_plan(p_user uuid)
returns jsonb
language sql
stable
set search_path to ''
as $function$
  select jsonb_build_object(
    'legacy', coalesce(p.legacy_unlimited, false),
    'bundle', p.plan_bundle_expires_at,
    'timers', p.plan_timers_expires_at,
    'farm', (select max(e.expires_at) from public.package_feature_entitlements e where e.user_id = p.id and e.feature = 'farm'),
    'accountItems', (select max(e.expires_at) from public.package_feature_entitlements e where e.user_id = p.id and e.feature = 'accountItems'))
    from public.profiles p
   where p.id = p_user
$function$;

revoke all on function public.admin_usage_plan(uuid) from public, anon, authenticated;

-- ---------- 3) รายคนในช่วง 7–90 วัน ----------
create function public.admin_user_usage(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_from date;
  v_strip date;
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  v_from := v_today - (v_days - 1);
  v_strip := v_today - 13;

  with
  daily as (
    select * from public.admin_usage_daily(least(v_from, v_strip), v_today, null)
  ),
  per as (
    select dd.user_id,
           count(*) filter (where dd.d >= v_from) as active_days,
           max(dd.d) as last_day,
           coalesce(sum(dd.minutes) filter (where dd.d >= v_from), 0) as minutes,
           coalesce(sum(dd.pings) filter (where dd.d >= v_from), 0) as pings,
           coalesce(sum(dd.merchant) filter (where dd.d >= v_from), 0) as merchant,
           coalesce(sum(dd.farm) filter (where dd.d >= v_from), 0) as farm,
           coalesce(sum(dd.gums) filter (where dd.d >= v_from), 0) as gums,
           coalesce(sum(dd.kills) filter (where dd.d >= v_from), 0) as kills,
           coalesce(sum(dd.announcements) filter (where dd.d >= v_from), 0) as announcements,
           coalesce(sum(dd.home_s) filter (where dd.d >= v_from), 0) as home_s,
           coalesce(sum(dd.farm_s) filter (where dd.d >= v_from), 0) as farm_s,
           coalesce(sum(dd.timers_s) filter (where dd.d >= v_from), 0) as timers_s,
           coalesce(sum(dd.items_s) filter (where dd.d >= v_from), 0) as items_s,
           count(*) filter (where dd.d >= v_from and dd.merchant > 0) as merchant_days,
           count(*) filter (where dd.d >= v_from and dd.farm > 0) as farm_days,
           count(*) filter (where dd.d >= v_from and (dd.kills > 0 or dd.timers_s >= 60)) as timers_days,
           count(*) filter (where dd.d >= v_from and dd.items_s >= 60) as items_days,
           count(*) filter (where dd.d >= v_from and dd.announcements > 0) as announce_days,
           count(*) filter (where dd.d >= v_from and dd.merchant >= 5) as trade_limit_days,
           count(*) filter (where dd.d >= v_from and dd.farm >= 3) as farm_limit_days
      from daily dd
     group by dd.user_id
    having count(*) filter (where dd.d >= v_from) > 0
  ),
  shown as (
    select * from per order by active_days desc, last_day desc, minutes desc limit 300
  ),
  strip as (
    select sh.user_id,
           jsonb_agg(case when dd.user_id is null then 0
                          when dd.merchant + dd.farm + dd.kills + dd.announcements > 0 then 2
                          else 1 end order by g.d) as cells
      from shown sh
      cross join generate_series(v_strip::timestamp, v_today::timestamp, interval '1 day') as g(d)
      left join daily dd on dd.user_id = sh.user_id and dd.d = g.d::date
     group by sh.user_id
  )
  select jsonb_build_object(
    'generated_at', now(),
    'days', v_days,
    'from', v_from,
    'to', v_today,
    'strip_from', v_strip,
    'total', (select count(*) from per),
    'users', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.display_name, 'username', p.username, 'created_at', p.created_at,
               'plan', public.admin_usage_plan(p.id),
               'purchases', (select count(*) from public.package_purchases pp where pp.user_id = p.id),
               'last_purchase', (select jsonb_build_object('plan_key', pp.plan_key, 'plan_name', pp.plan_name, 'cycle', pp.cycle, 'at', pp.created_at)
                                   from public.package_purchases pp where pp.user_id = p.id order by pp.created_at desc limit 1),
               'party_host', (select coalesce(hp.display_name, hp.username) from public.party_members pm
                                join public.profiles hp on hp.id = pm.host_id
                               where pm.member_id = p.id and pm.removed_at is null order by pm.created_at desc limit 1),
               'party_members', (select count(*) from public.party_members pm where pm.host_id = p.id and pm.removed_at is null),
               'last_seen_at', (select up.last_seen_at from public.user_presence up where up.user_id = p.id),
               'active_days', sh.active_days,
               'last_day', sh.last_day,
               'strip', coalesce(st.cells, '[]'::jsonb),
               'totals', jsonb_build_object('minutes', sh.minutes, 'pings', sh.pings, 'merchant', sh.merchant, 'farm', sh.farm,
                                            'gums', sh.gums, 'kills', sh.kills, 'announcements', sh.announcements,
                                            'home_s', sh.home_s, 'farm_s', sh.farm_s, 'timers_s', sh.timers_s, 'items_s', sh.items_s),
               'days_used', jsonb_build_object('merchant', sh.merchant_days, 'farm', sh.farm_days, 'timers', sh.timers_days,
                                               'items', sh.items_days, 'announce', sh.announce_days),
               'limit_days', jsonb_build_object('trade', sh.trade_limit_days, 'farm', sh.farm_limit_days))
             order by sh.active_days desc, sh.last_day desc, sh.minutes desc)
        from shown sh
        join public.profiles p on p.id = sh.user_id
        left join strip st on st.user_id = sh.user_id), '[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_user_usage(integer) from public, anon;
grant execute on function public.admin_user_usage(integer) to authenticated;

-- ---------- 4) ทุกคนที่ใช้งานในวันที่เลือก ----------
create function public.admin_user_usage_day(p_day date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_day date;
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  v_day := coalesce(p_day, v_today);
  -- นาทีออนไลน์/เวลาแต่ละหน้าเก็บ 180 วัน → เลือกได้ย้อนหลังไม่เกินนั้น
  if v_day > v_today or v_day < v_today - 179 then
    raise exception 'เลือกวันได้ตั้งแต่ % ถึงวันนี้', to_char(v_today - 179, 'DD/MM/YYYY');
  end if;

  with
  daily as (
    select * from public.admin_usage_daily(v_day, v_day, null)
  ),
  shown as (
    select * from daily order by (merchant + farm + kills + announcements) desc, minutes desc, pings desc limit 500
  )
  select jsonb_build_object(
    'generated_at', now(),
    'day', v_day,
    'today', v_today,
    'min_day', v_today - 179,
    'total', (select count(*) from daily),
    'totals', (select jsonb_build_object(
                 'minutes', coalesce(sum(dd.minutes), 0), 'merchant', coalesce(sum(dd.merchant), 0), 'farm', coalesce(sum(dd.farm), 0),
                 'gums', coalesce(sum(dd.gums), 0), 'kills', coalesce(sum(dd.kills), 0), 'announcements', coalesce(sum(dd.announcements), 0),
                 'merchant_users', count(*) filter (where dd.merchant > 0), 'farm_users', count(*) filter (where dd.farm > 0),
                 'timers_users', count(*) filter (where dd.kills > 0 or dd.timers_s >= 60),
                 'items_users', count(*) filter (where dd.items_s >= 60),
                 'announce_users', count(*) filter (where dd.announcements > 0))
                 from daily dd),
    'users', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.display_name, 'username', p.username,
               'plan', public.admin_usage_plan(p.id),
               'pings', sh.pings, 'minutes', sh.minutes, 'merchant', sh.merchant, 'farm', sh.farm, 'gums', sh.gums,
               'kills', sh.kills, 'announcements', sh.announcements,
               'home_s', sh.home_s, 'farm_s', sh.farm_s, 'timers_s', sh.timers_s, 'items_s', sh.items_s, 'other_s', sh.other_s)
             order by (sh.merchant + sh.farm + sh.kills + sh.announcements) desc, sh.minutes desc, sh.pings desc)
        from shown sh
        join public.profiles p on p.id = sh.user_id), '[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_user_usage_day(date) from public, anon;
grant execute on function public.admin_user_usage_day(date) to authenticated;

-- ---------- 5) รายวันของคนเดียว ----------
create function public.admin_user_usage_detail(p_user uuid, p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_from date;
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  if p_user is null then raise exception 'ไม่ได้เลือกผู้ใช้'; end if;
  v_from := v_today - (v_days - 1);

  select jsonb_build_object(
    'generated_at', now(),
    'days', v_days,
    'from', v_from,
    'to', v_today,
    'user', jsonb_build_object(
      'id', p.id, 'name', p.display_name, 'username', p.username, 'created_at', p.created_at,
      'plan', public.admin_usage_plan(p.id),
      'last_seen_at', (select up.last_seen_at from public.user_presence up where up.user_id = p.id),
      'party_host', (select coalesce(hp.display_name, hp.username) from public.party_members pm
                       join public.profiles hp on hp.id = pm.host_id
                      where pm.member_id = p.id and pm.removed_at is null order by pm.created_at desc limit 1),
      'party_members', (select count(*) from public.party_members pm where pm.host_id = p.id and pm.removed_at is null)),
    'purchases_total', (select count(*) from public.package_purchases pp where pp.user_id = p.id),
    'purchases', coalesce((
      select jsonb_agg(jsonb_build_object('plan_key', x.plan_key, 'plan_name', x.plan_name, 'cycle', x.cycle,
                                          'points', x.points_spent, 'at', x.created_at) order by x.created_at desc)
        from (select pp.* from public.package_purchases pp where pp.user_id = p.id order by pp.created_at desc limit 10) x), '[]'::jsonb),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
               'd', dd.d, 'pings', dd.pings, 'minutes', dd.minutes, 'merchant', dd.merchant, 'farm', dd.farm, 'gums', dd.gums,
               'kills', dd.kills, 'announcements', dd.announcements,
               'home_s', dd.home_s, 'farm_s', dd.farm_s, 'timers_s', dd.timers_s, 'items_s', dd.items_s, 'other_s', dd.other_s)
             order by dd.d desc)
        from public.admin_usage_daily(v_from, v_today, p.id) dd), '[]'::jsonb)
  ) into v_out
    from public.profiles p
   where p.id = p_user;
  if v_out is null then raise exception 'ไม่พบผู้ใช้นี้ (อาจถูกลบไปแล้ว)'; end if;
  return v_out;
end;
$function$;

revoke all on function public.admin_user_usage_detail(uuid, integer) from public, anon;
grant execute on function public.admin_user_usage_detail(uuid, integer) to authenticated;

-- ---------- ลองเรียกจริงก่อน commit (อ่านอย่างเดียว · พังตรงไหน = ยกเลิกทั้งหมด ไม่มีอะไรถูกแก้) ----------
-- ฟังก์ชันเช็คแอดมินข้างใน → เรียกแทนบัญชีแอดมินบัญชีแรกเฉพาะในทรานแซกชันนี้ แล้วคืนค่าเดิมทันที
-- ผลลัพธ์กับยอดที่นับตรงจากตาราง ดึงในคำสั่งเดียวกัน = เห็นข้อมูลชุดเดียวกัน (มีคนใช้เว็บอยู่ระหว่างรันก็ไม่ทำให้ยอดเพี้ยน)
do $check$
declare
  v_admin uuid;
  v_claims text := current_setting('request.jwt.claims', true);
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_t0 timestamptz := (((now() at time zone 'Asia/Bangkok')::date - 29)::timestamp at time zone 'Asia/Bangkok');
  v_t1 timestamptz := (((now() at time zone 'Asia/Bangkok')::date + 1)::timestamp at time zone 'Asia/Bangkok');
  v_usage jsonb;
  v_day jsonb;
  v_detail jsonb;
  v_daily jsonb;
  v_exp jsonb;
  v_sum jsonb;
  v_user jsonb;
  v_n int;
  v_rejected boolean := false;
begin
  select id into v_admin from public.profiles where role = 'admin' order by created_at limit 1;
  if v_admin is null then
    raise exception 'ไม่พบบัญชีแอดมินสำหรับทดสอบ — ไม่มีอะไรถูกแก้';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  begin
    select x.u, x.dy,
           case when (x.u -> 'users' -> 0) is not null
                then public.admin_user_usage_detail((x.u -> 'users' -> 0 ->> 'id')::uuid, 30) end,
           (select jsonb_build_object('merchant', coalesce(sum(dd.merchant), 0), 'farm', coalesce(sum(dd.farm), 0),
                                      'gums', coalesce(sum(dd.gums), 0), 'kills', coalesce(sum(dd.kills), 0),
                                      'announcements', coalesce(sum(dd.announcements), 0))
              from public.admin_usage_daily(v_today - 29, v_today, null) dd),
           jsonb_build_object(
             'merchant', (select count(*) from public.merchant_entries m join public.profiles p on p.id = m.user_id
                           where p.role is distinct from 'admin'
                             and m.ts >= (extract(epoch from v_t0) * 1000)::bigint and m.ts < (extract(epoch from v_t1) * 1000)::bigint),
             'farm', (select count(*) from public.farm_entries f join public.profiles p on p.id = f.user_id
                       where p.role is distinct from 'admin'
                         and f.ts >= (extract(epoch from v_t0) * 1000)::bigint and f.ts < (extract(epoch from v_t1) * 1000)::bigint),
             'gums', (select coalesce(sum(case when jsonb_typeof(f.data -> 'count') = 'number' then greatest((f.data ->> 'count')::numeric, 1)
                                               when (f.data ->> 'count') ~ '^[0-9]{1,9}$' then greatest((f.data ->> 'count')::numeric, 1)
                                               else 1 end), 0)
                        from public.farm_entries f join public.profiles p on p.id = f.user_id
                       where p.role is distinct from 'admin'
                         and f.ts >= (extract(epoch from v_t0) * 1000)::bigint and f.ts < (extract(epoch from v_t1) * 1000)::bigint),
             'kills', (select count(*) from public.kills k join public.profiles p on p.id = k.killed_by
                        where p.role is distinct from 'admin' and k.created_at >= v_t0 and k.created_at < v_t1),
             'announcements', (select count(*) from public.announcements an join public.profiles p on p.id = an.user_id
                                where p.role is distinct from 'admin' and an.created_at >= v_t0 and an.created_at < v_t1))
      into v_usage, v_day, v_detail, v_daily, v_exp
      from (select public.admin_user_usage(30) as u, public.admin_user_usage_day(null) as dy) x;
    perform public.admin_user_usage(7);
    perform public.admin_user_usage(90);
    perform public.admin_user_usage_day(v_today - 179);
    -- วันเกิน 180 วัน ต้องถูกปฏิเสธ
    begin
      perform public.admin_user_usage_day(v_today - 180);
    exception when others then
      if sqlerrm not like 'เลือกวันได้ตั้งแต่%' then raise; end if;
      v_rejected := true;
    end;
  exception when others then
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    raise;
  end;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);

  if not v_rejected then raise exception 'self-test: วันเกิน 180 วันต้องถูกปฏิเสธ'; end if;
  if jsonb_typeof(v_usage -> 'users') is distinct from 'array' or jsonb_typeof(v_day -> 'users') is distinct from 'array'
     or jsonb_typeof(v_day -> 'totals') is distinct from 'object' then
    raise exception 'self-test: รูปแบบผลลัพธ์ไม่ถูกต้อง';
  end if;
  -- ฟังก์ชันภายใน 30 วัน = นับตรงจากตาราง (ไม่นับแอดมิน)
  if v_daily is distinct from v_exp then
    raise exception 'self-test: ยอด 30 วันไม่ตรง (ได้ % · นับตรงได้ %)', v_daily, v_exp;
  end if;
  -- ผลรวมของทุกคนในรายการรายคน = ยอดจากตาราง (ทุกคนอยู่ในรายการเมื่อไม่เกิน 300 คน)
  if (v_usage ->> 'total')::int <= 300 then
    select jsonb_build_object('merchant', coalesce(sum((x -> 'totals' ->> 'merchant')::numeric), 0),
                              'farm', coalesce(sum((x -> 'totals' ->> 'farm')::numeric), 0),
                              'gums', coalesce(sum((x -> 'totals' ->> 'gums')::numeric), 0),
                              'kills', coalesce(sum((x -> 'totals' ->> 'kills')::numeric), 0),
                              'announcements', coalesce(sum((x -> 'totals' ->> 'announcements')::numeric), 0))
      into v_sum from jsonb_array_elements(v_usage -> 'users') x;
    if v_sum is distinct from v_exp then
      raise exception 'self-test: ผลรวมรายคนไม่ตรงกับตาราง (ได้ % · นับตรงได้ %)', v_sum, v_exp;
    end if;
  end if;
  select count(*) into v_n from jsonb_array_elements(v_usage -> 'users') x
   where jsonb_array_length(x -> 'strip') <> 14 or (x ->> 'active_days')::int not between 1 and 30;
  if v_n > 0 then raise exception 'self-test: แถบ 14 วัน/จำนวนวันที่ใช้ผิด % คน', v_n; end if;
  -- รายวันของคนแรกในรายการ รวมกัน = ยอดของคนนั้นในรายการรายคน
  v_user := v_usage -> 'users' -> 0;
  if v_user is not null then
    if v_detail is null
       or jsonb_array_length(v_detail -> 'rows') <> (v_user ->> 'active_days')::int
       or (select coalesce(sum((r ->> 'merchant')::numeric), 0) from jsonb_array_elements(v_detail -> 'rows') r) <> (v_user -> 'totals' ->> 'merchant')::numeric
       or (select coalesce(sum((r ->> 'farm')::numeric), 0) from jsonb_array_elements(v_detail -> 'rows') r) <> (v_user -> 'totals' ->> 'farm')::numeric
       or (select coalesce(sum((r ->> 'gums')::numeric), 0) from jsonb_array_elements(v_detail -> 'rows') r) <> (v_user -> 'totals' ->> 'gums')::numeric
       or (select coalesce(sum((r ->> 'kills')::numeric), 0) from jsonb_array_elements(v_detail -> 'rows') r) <> (v_user -> 'totals' ->> 'kills')::numeric then
      raise exception 'self-test: รายวันของ @% ไม่ตรงกับยอดในรายการรายคน', v_user ->> 'username';
    end if;
  end if;
  -- รายวัน: จำนวนคน/ยอดรวม สอดคล้องกับรายชื่อ (ทุกคนอยู่ในรายการเมื่อไม่เกิน 500 คน)
  if (v_day ->> 'total')::int <= 500 then
    if jsonb_array_length(v_day -> 'users') <> (v_day ->> 'total')::int
       or (select coalesce(sum((x ->> 'merchant')::numeric), 0) from jsonb_array_elements(v_day -> 'users') x) <> (v_day -> 'totals' ->> 'merchant')::numeric
       or (select coalesce(sum((x ->> 'gums')::numeric), 0) from jsonb_array_elements(v_day -> 'users') x) <> (v_day -> 'totals' ->> 'gums')::numeric then
      raise exception 'self-test: รายวัน — จำนวนคน/ยอดรวมไม่ตรงกับรายชื่อ';
    end if;
  end if;
end;
$check$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (ฟังก์ชันตรงกับไฟล์นี้ · แอดมินที่ล็อกอินเรียกได้ · คนที่ไม่ได้ล็อกอินเรียกไม่ได้ · ฟังก์ชันภายในเรียกตรงไม่ได้)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_usage_daily(date, date, uuid)')) = '88f117ca5458658f53f39fd12db431c8'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_usage_plan(uuid)')) = 'c8be7459960c27c752dd29085aba290b'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_user_usage(integer)')) = '33b97516e52da3c890bc1239964ecd28'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_user_usage_day(date)')) = 'c75c46dcadce2f83f51b4bfe99a21123'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_user_usage_detail(uuid, integer)')) = 'e458195b5b818cccab7920c859c0a100'
    and has_function_privilege('authenticated', 'public.admin_user_usage(integer)', 'execute')
    and has_function_privilege('authenticated', 'public.admin_user_usage_day(date)', 'execute')
    and has_function_privilege('authenticated', 'public.admin_user_usage_detail(uuid, integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_user_usage(integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_user_usage_day(date)', 'execute')
    and not has_function_privilege('anon', 'public.admin_user_usage_detail(uuid, integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_usage_daily(date, date, uuid)', 'execute')
    and not has_function_privilege('authenticated', 'public.admin_usage_daily(date, date, uuid)', 'execute')
    and not has_function_privilege('anon', 'public.admin_usage_plan(uuid)', 'execute')
    and not has_function_privilege('authenticated', 'public.admin_usage_plan(uuid)', 'execute') as user_usage_ok;
