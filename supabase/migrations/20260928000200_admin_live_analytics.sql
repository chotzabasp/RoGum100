-- ============================================================
-- แดชบอร์ดแอดมิน: ออนไลน์ตอนนี้ / วันนี้ / ช่วงเวลาใช้งาน / เวลาใช้งาน / การกลับมาใช้ซ้ำ / ปาร์ตี้ / หน้าแรก / ผู้เข้าชม 7 วัน
-- (ผู้ใช้สั่ง "ทำทั้งหมดที่แนะนำ" 28 ก.ย. 2569 · แท็บที่เปิดทิ้งไว้เบื้องหลังนับเป็นออนไลน์)
--
-- 1) ตาราง user_presence (1 แถว/คน: เห็นล่าสุดเมื่อไหร่ เปิดดูอยู่ไหม หน้าไหน อุปกรณ์)
--    + user_activity_hours (1 แถว/คน/ชั่วโมง: จำนวนนาทีที่มีสัญญาณ / นาทีที่เปิดดูอยู่) — เก็บ 180 วัน
--    ปิดสิทธิ์อ่าน/เขียนตรงทั้งหมด อ่านผ่านฟังก์ชันแอดมิน เขียนผ่าน touch_presence เท่านั้น
-- 2) touch_presence(page, visible, device): หน้าเว็บที่ล็อกอินส่งทุก ~1 นาที (แท็บพื้นหลังด้วย)
-- 3) admin_live(): ตัวเลขสด (ออนไลน์ตอนนี้ แยกหน้า/อุปกรณ์ · ใช้งานวันนี้/เมื่อวาน แยกจ่ายเงิน/ฟรี · ชั่วโมงพีควันนี้ ·
--    เวลาเปิดดูเฉลี่ยวันนี้ · ปาร์ตี้ทั้งหมด/ใช้งานวันนี้/ถูกล็อก) — เบา แดชบอร์ดเรียกทุก 1 นาที
-- 4) admin_usage(p_days): ช่วงเวลาที่คนใช้งาน 24 ชม. (เฉลี่ยต่อวัน) · เวลาเปิดดูเฉลี่ยต่อคนต่อวัน · กลับมาใช้วันถัดไป / ภายใน 7 วัน
-- 5) log_events: + landing_view / landing_cta (หน้าแรกเริ่มนับผู้เข้าชม) · admin_traffic: ตัวเลขเดิม = แอปเท่านั้น (ไม่ปนหน้าแรก)
--    + visitors_7d / members_7d (ผู้เข้าชม 7 วันแบบคงที่) + landing{เข้าชม → กดปุ่ม → เข้าแอป / สมัคร}
-- ไม่นับบัญชีแอดมินทุกตัวเลข · ข้อมูลใหม่เริ่มนับตั้งแต่รันไฟล์นี้ (ย้อนหลังไม่ได้)
-- ทุกอย่างอยู่ใน transaction เดียว — ตัวเช็คด้านบนไม่ผ่าน = ไม่มีอะไรถูกแก้
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260928000200_admin_live_analytics_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)');
  if v_md5 is distinct from 'b41dda6abe71e0730fb0fa24e486d3e4' then
    raise exception 'log_events ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_traffic(integer)');
  if v_md5 is distinct from 'd8558c367358976568852d967094fe78' then
    raise exception 'admin_traffic ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  if to_regclass('public.user_presence') is not null or to_regclass('public.user_activity_hours') is not null
     or to_regprocedure('public.touch_presence(text, boolean, text)') is not null
     or to_regprocedure('public.admin_live()') is not null or to_regprocedure('public.admin_usage(integer)') is not null then
    raise exception 'มีของชุดนี้อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) ตาราง ----------
create table public.user_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  visible_seen_at timestamptz,
  last_ping_at timestamptz,
  page text,
  device text
);
create index user_presence_seen_idx on public.user_presence (last_seen_at);
alter table public.user_presence enable row level security;
revoke all on table public.user_presence from public, anon, authenticated;

create table public.user_activity_hours (
  user_id uuid not null references public.profiles(id) on delete cascade,
  hour timestamptz not null,
  pings integer not null default 0,
  visible_pings integer not null default 0,
  primary key (user_id, hour)
);
create index user_activity_hours_hour_idx on public.user_activity_hours (hour);
alter table public.user_activity_hours enable row level security;
revoke all on table public.user_activity_hours from public, anon, authenticated;

-- ---------- 2) สัญญาณ "ยังอยู่" ----------
create function public.touch_presence(p_page text default null, p_visible boolean default true, p_device text default null)
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
  v_count boolean;
begin
  if v_uid is null then return; end if;
  if v_page is not null and v_page not in ('home', 'farm', 'timers', 'items', 'pricing', 'settings', 'admin') then v_page := null; end if;
  if v_dev is not null and v_dev not in ('mobile', 'tablet', 'desktop') then v_dev := null; end if;
  -- นับเป็น 1 นาทีใช้งานได้ไม่เกินครั้งละ ~1 นาที (เปิดหลายแท็บไม่นับซ้ำ) · อัปเดตเวลาล่าสุดทุกครั้ง
  select last_ping_at into v_last from public.user_presence where user_id = v_uid for update;
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
  end if;
  if random() < 0.001 then
    delete from public.user_activity_hours where hour < now() - interval '180 days';
  end if;
end;
$function$;

revoke all on function public.touch_presence(text, boolean, text) from public, anon;
grant execute on function public.touch_presence(text, boolean, text) to authenticated;

-- ---------- 3) ตัวเลขสดของแดชบอร์ด ----------
create function public.admin_live()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_today_ts timestamptz;
  v_yest_ts timestamptz;
  v_cut timestamptz := now() - interval '5 minutes';
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  v_today_ts := v_today::timestamp at time zone 'Asia/Bangkok';
  v_yest_ts := (v_today - 1)::timestamp at time zone 'Asia/Bangkok';

  with
  -- ไม่นับบัญชีแอดมิน · จ่ายเงิน/ฟรี/สิทธิเดิม ใช้นิยามเดียวกับ admin_dashboard
  u as (
    select p.id, p.display_name, coalesce(p.legacy_unlimited, false) as legacy,
           (not coalesce(p.legacy_unlimited, false) and (
              coalesce(p.plan_bundle_expires_at > now(), false) or coalesce(p.plan_timers_expires_at > now(), false)
              or exists (select 1 from package_feature_entitlements e
                          where e.user_id = p.id and e.feature in ('farm', 'accountItems') and e.expires_at > now()))) as paid
      from profiles p
     where p.role is distinct from 'admin'
  ),
  pres as (
    select up.* from user_presence up join u on u.id = up.user_id where up.last_seen_at >= v_cut
  ),
  -- ใช้งานเมื่อวาน/วันนี้: ชั่วโมงที่มีสัญญาณ "ยังอยู่" + เหตุการณ์ตอนล็อกอิน (เผื่อเครื่องที่ยังเป็นหน้าเว็บเวอร์ชันเก่า)
  act as (
    select h.user_id as uid, h.hour as ts from user_activity_hours h join u on u.id = h.user_id where h.hour >= v_yest_ts
    union all
    select a.user_id, a.created_at from app_events a join u on u.id = a.user_id
     where a.user_id is not null and a.event in ('visit', 'page_view', 'page_time') and a.created_at >= v_yest_ts
  ),
  today as (select distinct uid from act where ts >= v_today_ts),
  yest as (select distinct uid from act where ts >= v_yest_ts and ts < v_today_ts),
  hb_today as (
    select h.user_id, sum(h.visible_pings) as vp from user_activity_hours h join u on u.id = h.user_id
     where h.hour >= v_today_ts group by h.user_id
  ),
  peak as (
    select extract(hour from ts at time zone 'Asia/Bangkok')::int as hr, count(distinct uid) as n
      from act where ts >= v_today_ts group by 1 order by 2 desc, 1 desc limit 1
  ),
  parties as (
    select pm.host_id, count(*) as members, public.has_timers_plan(pm.host_id) as host_ok,
           max(p.plan_timers_expires_at) as host_exp
      from party_members pm join u on u.id = pm.host_id join profiles p on p.id = pm.host_id
     where pm.removed_at is null
     group by pm.host_id
  )
  select jsonb_build_object(
    'generated_at', now(),
    'tracking_since', (select min(hour) from user_activity_hours),
    'online_now', (select count(*) from pres),
    'online_visible', (select count(*) from pres where visible_seen_at >= v_cut),
    'online_pages', (select coalesce(jsonb_agg(jsonb_build_object('page', page, 'count', n) order by n desc), '[]'::jsonb)
                       from (select coalesce(page, '-') as page, count(*) as n from pres group by 1) s),
    'online_devices', (select coalesce(jsonb_agg(jsonb_build_object('device', device, 'count', n) order by n desc), '[]'::jsonb)
                         from (select coalesce(device, 'unknown') as device, count(*) as n from pres group by 1) s),
    'today_users', (select count(*) from today),
    'yesterday_users', (select count(*) from yest),
    'today_paid', (select count(*) from today t join u on u.id = t.uid where u.paid),
    'today_legacy', (select count(*) from today t join u on u.id = t.uid where u.legacy),
    'today_free', (select count(*) from today t join u on u.id = t.uid where not u.paid and not u.legacy),
    'peak_hour', (select hr from peak),
    'peak_users', (select n from peak),
    'avg_minutes_today', (select round(coalesce(sum(vp)::numeric / nullif(count(*), 0), 0), 1) from hb_today),
    'parties', jsonb_build_object(
      'total', (select count(*) from parties),
      'locked', (select count(*) from parties where not host_ok),
      'active_today', (select count(*) from parties pa
                        where exists (select 1 from today t where t.uid = pa.host_id)
                           or exists (select 1 from party_members m join today t on t.uid = m.member_id
                                       where m.host_id = pa.host_id and m.removed_at is null)),
      'locked_hosts', (select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(p.display_name, '-'), 'members', pa.members,
                                                                    'expired_at', pa.host_exp) order by pa.members desc), '[]'::jsonb)
                         from (select * from parties where not host_ok order by members desc limit 10) pa
                         join profiles p on p.id = pa.host_id)
    )
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_live() from public, anon;
grant execute on function public.admin_live() to authenticated;

-- ---------- 4) ช่วงเวลาใช้งาน / เวลาใช้งาน / การกลับมาใช้ซ้ำ ----------
create function public.admin_usage(p_days integer default 30)
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
  v_first date;
  v_eff int;
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  v_start := v_today - (v_days - 1);
  v_start_ts := v_start::timestamp at time zone 'Asia/Bangkok';
  -- เฉลี่ยต่อวันด้วยจำนวนวันที่มีข้อมูลจริงในช่วงที่เลือก (เพิ่งเริ่มเก็บ = ไม่หารด้วยวันที่ยังไม่มีข้อมูล)
  select (least(
            (select min(hour) from user_activity_hours),
            (select min(created_at) from app_events where user_id is not null)
          ) at time zone 'Asia/Bangkok')::date into v_first;
  v_eff := greatest(1, v_today - greatest(v_start, coalesce(v_first, v_today)) + 1);

  with
  u as (select p.id, p.created_at from profiles p where p.role is distinct from 'admin'),
  hb as (
    select h.user_id, h.hour, h.visible_pings from user_activity_hours h join u on u.id = h.user_id where h.hour >= v_start_ts
  ),
  -- กิจกรรมรายชั่วโมง: สัญญาณ "ยังอยู่" + เหตุการณ์ตอนล็อกอิน (ปัดเป็นชั่วโมง) · คนเดียวกันในชั่วโมงเดียวกันนับ 1
  act_h as (
    select distinct uid, hr from (
      select user_id as uid, hour as hr from hb
      union all
      select a.user_id, date_trunc('hour', a.created_at) from app_events a join u on u.id = a.user_id
       where a.user_id is not null and a.event in ('visit', 'page_view', 'page_time') and a.created_at >= v_start_ts
    ) x
  ),
  hours as (select generate_series(0, 23) as h),
  -- การกลับมาใช้ซ้ำ: วันที่ใช้งานของแต่ละคน (ทุกช่วงที่เก็บไว้) เทียบกับวันที่สมัคร
  act_d as (
    select distinct uid, (hr at time zone 'Asia/Bangkok')::date as d from (
      select h.user_id as uid, h.hour as hr from user_activity_hours h join u on u.id = h.user_id
      union all
      select a.user_id, a.created_at from app_events a join u on u.id = a.user_id
       where a.user_id is not null and a.event in ('visit', 'page_view', 'page_time')
    ) x
  ),
  cohort as (
    select u.id, (u.created_at at time zone 'Asia/Bangkok')::date as sd from u
     where u.created_at >= v_start_ts and (u.created_at at time zone 'Asia/Bangkok')::date <= v_today - 1
  )
  select jsonb_build_object(
    'days', v_days,
    'effective_days', v_eff,
    'tracking_since', (select min(hour) from user_activity_hours),
    'hours', (select jsonb_agg(jsonb_build_object(
                'hour', hours.h,
                'avg_users', round((select count(*) from act_h where extract(hour from hr at time zone 'Asia/Bangkok') = hours.h)::numeric / v_eff, 1),
                'total', (select count(*) from act_h where extract(hour from hr at time zone 'Asia/Bangkok') = hours.h)
              ) order by hours.h) from hours),
    'avg_minutes_per_day', (select round(coalesce(sum(vp)::numeric / nullif(count(*), 0), 0), 1)
                              from (select user_id, (hour at time zone 'Asia/Bangkok')::date as d, sum(visible_pings) as vp
                                      from hb group by 1, 2) s),
    'retention', jsonb_build_object(
      'd1_eligible', (select count(*) from cohort),
      'd1_returned', (select count(*) from cohort c where exists (select 1 from act_d a where a.uid = c.id and a.d = c.sd + 1)),
      'd7_eligible', (select count(*) from cohort where sd <= v_today - 7),
      'd7_returned', (select count(*) from cohort c where c.sd <= v_today - 7
                        and exists (select 1 from act_d a where a.uid = c.id and a.d between c.sd + 1 and c.sd + 7))
    )
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_usage(integer) from public, anon;
grant execute on function public.admin_usage(integer) to authenticated;

-- ---------- 5) หน้าแรก + ผู้เข้าชม 7 วัน ----------
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
begin
  if p_visitor is null or p_visitor !~ '^[A-Za-z0-9-]{8,40}$' then return; end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then return; end if;
  if (select count(*) from public.app_events
       where visitor_id = p_visitor and created_at > now() - interval '1 hour') >= 600 then
    return;
  end if;
  select 30 - count(*) into v_err_budget from public.app_events
   where visitor_id = p_visitor and event = 'client_error' and created_at > now() - interval '1 hour';

  for e in select value from jsonb_array_elements(p_events) limit 30 loop
    v_event := e ->> 'e';
    if v_event is null or v_event not in ('visit', 'page_view', 'page_time', 'buy_click', 'buy_click_guest',
                                          'buy_insufficient', 'buy_success', 'signup', 'client_error',
                                          'landing_view', 'landing_cta') then
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
  end if;
end;
$function$;

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

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ true ทุกช่อง ยกเว้น 2 ช่องท้าย (..._false) ต้องได้ false
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)')) = '28853f70f7e778c8aaab5ee5322b5235' as log_events_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_traffic(integer)')) = '1be8f35da1736463face286585bbef0e' as admin_traffic_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.touch_presence(text, boolean, text)')) = '8441f32586b1c59d01a6a893b10cfb2a' as touch_presence_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_live()')) = 'd599b2128d2197545a06e8670ef08014' as admin_live_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_usage(integer)')) = '37679889586c6bc6e1f1d5cecdb17ad4' as admin_usage_ok,
  (select relrowsecurity from pg_class where oid = 'public.user_presence'::regclass)
    and (select relrowsecurity from pg_class where oid = 'public.user_activity_hours'::regclass) as rls_on,
  has_function_privilege('authenticated', 'public.touch_presence(text, boolean, text)', 'execute') as touch_auth_exec_true,
  has_table_privilege('authenticated', 'public.user_presence', 'select') as presence_select_false,
  has_function_privilege('anon', 'public.admin_live()', 'execute') as live_anon_exec_false;
