-- ============================================================
-- ระบบเก็บการใช้งาน (ต่อจาก 20260924000400_app_events.sql) — เพิ่ม 2 เรื่องที่เหลือของ "กลุ่ม 2"
--   1) ประเภทอุปกรณ์: แนบไปกับเหตุการณ์ 'visit' ในช่อง meta = 'mobile' | 'tablet' | 'desktop'
--      (หน้าเว็บเดาจากขนาดจอ + การใช้นิ้วแตะ ไม่เก็บชื่อรุ่น/ยี่ห้อ/เบราว์เซอร์)
--   2) error ที่ผู้ใช้เจอ: เหตุการณ์ใหม่ 'client_error'
--      meta = ประเภท ('js' โค้ดหน้าเว็บพัง, 'promise' งานเบื้องหลังล้มเหลว, 'sync' ซิงก์ขึ้นคลาวด์ไม่ได้,
--             'load' โหลดข้อมูลจากคลาวด์ไม่ได้) · detail = ข้อความ error (ตัดเหลือ 200 ตัวอักษร)
--      กันถล่ม 2 ชั้น: หน้าเว็บส่ง error เดิมครั้งเดียวต่อการเปิดเว็บ ไม่เกิน 10 เรื่อง
--                     + ฐานข้อมูลรับ client_error ไม่เกิน 30 ครั้ง/ชั่วโมง/เครื่อง
-- ข้อมูลที่เก็บไว้แล้วไม่หาย · ชื่อเหตุการณ์ใหม่ต้องตรงกับ Track ใน index.html
-- ============================================================
begin;

alter table public.app_events add column if not exists detail text;

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
                                          'buy_insufficient', 'buy_success', 'signup', 'client_error') then
      continue;
    end if;
    v_page := nullif(e ->> 'p', '');
    if v_page is not null and v_page not in ('home', 'farm', 'timers', 'items', 'pricing', 'settings', 'admin') then
      v_page := null;
    end if;
    v_value := case when (e ->> 'v') ~ '^\d{1,6}$' then least((e ->> 'v')::int, 86400) else null end;
    v_meta := left(nullif(regexp_replace(coalesce(e ->> 'm', ''), '[^A-Za-z0-9_:-]', '', 'g'), ''), 40);
    v_detail := null;

    if v_event = 'visit' and v_meta is not null and v_meta not in ('mobile', 'tablet', 'desktop') then
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

revoke all on function public.log_events(text, jsonb) from public;
grant execute on function public.log_events(text, jsonb) to anon, authenticated;

-- สรุปสำหรับแดชบอร์ด (เหมือนเดิมทุกส่วน + devices + errors)
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
  allev as (
    select a.* from app_events a where not exists (select 1 from admin_vis x where x.visitor_id = a.visitor_id)
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

revoke all on function public.admin_traffic(integer) from public, anon;
grant execute on function public.admin_traffic(integer) to authenticated;

commit;
