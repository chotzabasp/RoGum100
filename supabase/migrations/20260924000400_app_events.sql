-- ============================================================
-- บันทึกการใช้งานเว็บ (แดชบอร์ดแอดมิน "กลุ่ม 2") — เริ่มนับตั้งแต่รันไฟล์นี้ ไม่มีข้อมูลย้อนหลัง
--   1) คนเข้าเว็บต่อวัน (รวมคนที่ยังไม่ล็อกอิน) + สัดส่วนผู้เข้าชมใหม่ที่สมัครสมาชิก
--   2) หน้าไหนเปิดบ่อย + อยู่นานแค่ไหน (นับเฉพาะตอนแท็บเปิดดูอยู่ ต่อครั้งไม่เกิน 30 นาที)
--   3) เส้นทางการซื้อ: เปิดหน้าเติมแพ็กเกจ → กดซื้อ → แต้มไม่พอ → ซื้อสำเร็จ
--
-- ความเป็นส่วนตัว: ผู้เข้าชมแต่ละเครื่องมีรหัสสุ่ม (visitor_id เก็บใน localStorage ของเครื่องนั้น)
-- ไม่เก็บ IP / อีเมล / ข้อมูลอุปกรณ์ · user_id ใส่ฝั่งเซิร์ฟเวอร์จาก auth.uid() เท่านั้น (ปลอมจากหน้าเว็บไม่ได้)
--
-- ความปลอดภัย: ตาราง app_events เปิด RLS แต่ไม่มี policy = ไม่มีใครอ่าน/เขียนตรงได้
--   เขียนได้ทางเดียวคือ log_events() ซึ่งกรองชื่อเหตุการณ์/หน้าตามรายการที่อนุญาต ตัดค่าที่ยาวเกิน
--   และจำกัดความถี่ (เครื่องเดียวไม่เกิน 600 เหตุการณ์/ชั่วโมง, ครั้งละไม่เกิน 30) กันยิงข้อมูลขยะ
--   อ่านได้ทางเดียวคือ admin_traffic() ซึ่งเช็ค is_admin()
-- เก็บข้อมูล 180 วัน — ของเก่ากว่านั้นถูกลบเองเป็นระยะตอนมีการส่งข้อมูลเข้ามา (ไม่ต้องตั้งงานตามเวลา)
-- ลบผู้ใช้: user_id ตั้งเป็น on delete set null ไม่บล็อกการลบบัญชี (แถวยังอยู่แบบไม่ระบุตัวตน)
-- ============================================================
begin;

create table if not exists public.app_events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  visitor_id text not null,
  user_id uuid references public.profiles(id) on delete set null,
  event text not null,
  page text,
  value integer,
  meta text
);
create index if not exists app_events_created_at_idx on public.app_events (created_at);
create index if not exists app_events_visitor_idx on public.app_events (visitor_id, created_at);

alter table public.app_events enable row level security;
revoke all on table public.app_events from anon, authenticated;

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
begin
  if p_visitor is null or p_visitor !~ '^[A-Za-z0-9-]{8,40}$' then return; end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then return; end if;
  if (select count(*) from public.app_events
       where visitor_id = p_visitor and created_at > now() - interval '1 hour') >= 600 then
    return;
  end if;

  for e in select value from jsonb_array_elements(p_events) limit 30 loop
    v_event := e ->> 'e';
    if v_event is null or v_event not in ('visit', 'page_view', 'page_time', 'buy_click', 'buy_click_guest',
                                          'buy_insufficient', 'buy_success', 'signup') then
      continue;
    end if;
    v_page := nullif(e ->> 'p', '');
    if v_page is not null and v_page not in ('home', 'farm', 'timers', 'items', 'pricing', 'settings', 'admin') then
      v_page := null;
    end if;
    v_value := case when (e ->> 'v') ~ '^\d{1,6}$' then least((e ->> 'v')::int, 86400) else null end;
    v_meta := left(nullif(regexp_replace(coalesce(e ->> 'm', ''), '[^A-Za-z0-9_:-]', '', 'g'), ''), 40);
    insert into public.app_events (visitor_id, user_id, event, page, value, meta)
    values (p_visitor, v_uid, v_event, v_page, v_value, v_meta);
  end loop;

  if random() < 0.005 then
    delete from public.app_events where created_at < now() - interval '180 days';
  end if;
end;
$function$;

revoke all on function public.log_events(text, jsonb) from public;
grant execute on function public.log_events(text, jsonb) to anon, authenticated;

-- สรุปสำหรับแดชบอร์ด — ไม่นับเครื่องที่เคยล็อกอินด้วยบัญชีแอดมิน (รวมตอนก่อนล็อกอินด้วย)
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
                ) s)
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_traffic(integer) from public, anon;
grant execute on function public.admin_traffic(integer) to authenticated;

commit;
