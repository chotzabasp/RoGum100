-- ============================================================
-- รายงานรายวันในแดชบอร์ดแอดมิน + เก็บแหล่งที่มาของการเข้าเว็บ (ผู้ใช้เลือก "กล่องรายงานรายวัน" 6 ต.ค. 2569)
-- 1) app_events.source (ใหม่): แหล่งที่มาของการเข้าเว็บแต่ละรอบ ติดมากับ visit (แอป) / landing_view (หน้าแรก)
--      direct = เข้าตรง/ไม่ทราบ · facebook / line / google ฯลฯ = ดูจากเว็บต้นทาง/แอป · tag:<ป้าย> = ?src= หรือ utm_ ในลิงก์ · ref:<เว็บ> = เว็บอื่น
--      email = เปิดจากลิงก์ยืนยัน/รีเซ็ตในอีเมล
--      ไม่เก็บข้อมูลส่วนตัว (ไม่มี IP / URL เต็ม) · แถวเก่าก่อน SQL นี้ = ว่าง
-- 2) log_events(): รับค่า s (แหล่งที่มา) เฉพาะ visit / landing_view · กรองเหลือ a-z 0-9 . _ : / - ยาวไม่เกิน 90
--      ส่วนอื่นคงเดิมทุกตัวอักษร (เนื้อเดิมจาก 20260929000100)
-- 3) admin_day_report(p_day) (ใหม่, แอดมินเท่านั้น): ตัวเลขของวันที่เลือกเทียบวันก่อนหน้า + รายชั่วโมง + แหล่งที่มา
--      ตัวคำนวณจริงอยู่ใน admin_day_report_data (เรียกตรงไม่ได้ทั้ง anon / authenticated) · ย้อนหลังได้ 178 วัน
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (หน้าเว็บเก่าไม่ส่ง s · log_events เก่าไม่สนค่า s) — แนะนำรันก่อน
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261006000100_admin_day_report_sources_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)');
  if v_md5 is distinct from '9542591ddf487f2b9692c9192fb5f306' then
    raise exception 'log_events ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'public.app_events'::regclass and attname = 'source' and not attisdropped) then
    raise exception 'app_events มีคอลัมน์ source อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
  if to_regprocedure('public.admin_day_report(date)') is not null or to_regprocedure('public.admin_day_report_data(date)') is not null then
    raise exception 'มี admin_day_report อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) คอลัมน์แหล่งที่มา ----------
alter table public.app_events add column source text;

-- ---------- 2) log_events: รับแหล่งที่มา ----------
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
  v_source text;
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
    -- แหล่งที่มาของการเข้าเว็บรอบนี้ (ติดมากับ visit / landing_view เท่านั้น — ดู 20261006000100)
    v_source := null;
    if v_event in ('visit', 'landing_view') then
      v_source := left(nullif(regexp_replace(lower(coalesce(e ->> 's', '')), '[^a-z0-9._:/-]', '', 'g'), ''), 90);
    end if;

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

    insert into public.app_events (visitor_id, user_id, event, page, value, meta, detail, source)
    values (p_visitor, v_uid, v_event, v_page, v_value, v_meta, v_detail, v_source);
  end loop;

  if random() < 0.005 then
    delete from public.app_events where created_at < now() - interval '180 days';
    delete from public.app_event_budget where window_start < now() - interval '1 day';
  end if;
end;
$function$;

-- ---------- 3) รายงานรายวัน ----------
create function public.admin_day_report_data(p_day date)
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_day date := coalesce(p_day, (now() at time zone 'Asia/Bangkok')::date);
  v_start timestamptz;
  v_end timestamptz;
  v_pstart timestamptz;
  v_pend timestamptz;
  v_real text[] := array['topup', 'admin_confirm_topup', 'slip_topup', 'admin_reverse'];
  v_out jsonb;
begin
  if v_day > v_today then raise exception 'เลือกวันในอนาคตไม่ได้'; end if;
  -- ข้อมูลการเข้าชมเก็บ 180 วัน: วันที่เลือกเก่าสุด 178 วันก่อน เพื่อให้วันก่อนหน้าที่ใช้เทียบยังครบทั้งวัน
  if v_day < v_today - 178 then raise exception 'ดูย้อนหลังได้ไม่เกิน 178 วัน — ข้อมูลเก่ากว่านั้นถูกล้างไปบางส่วนแล้ว'; end if;
  -- วันที่เลือก (เวลาไทย) ถึงตอนนี้ · เทียบกับวันก่อนหน้า "ยาวเท่ากัน" — ดูวันนี้ = เมื่อวานถึงเวลาเดียวกัน, ดูวันที่ผ่านมาแล้ว = วันก่อนหน้าทั้งวัน
  v_start := v_day::timestamp at time zone 'Asia/Bangkok';
  v_end := least(v_start + interval '1 day', now());
  v_pstart := v_start - interval '1 day';
  v_pend := v_pstart + (v_end - v_start);

  with
  -- ไม่นับเครื่องที่เคยล็อกอินเป็นแอดมิน และบัญชีแอดมิน (นิยามเดียวกับ admin_traffic / admin_dashboard)
  admin_vis as (
    select distinct a.visitor_id from app_events a join profiles p on p.id = a.user_id where p.role = 'admin'
  ),
  u as (
    select p.id, p.created_at from profiles p where p.role is distinct from 'admin'
  ),
  -- เหตุการณ์ทั้งหมดตั้งแต่ต้นวันก่อนหน้าถึงตอนนี้ (รวมหน้าแรก landing_* และในแอป)
  ev as (
    select a.visitor_id, a.user_id, a.event, a.page, a.source, a.created_at
      from app_events a
     where a.created_at >= v_pstart and a.created_at < v_end
       and not exists (select 1 from admin_vis x where x.visitor_id = a.visitor_id)
  ),
  -- เห็นเครื่องนี้ครั้งแรกเมื่อไหร่ (ทั้งหน้าแรกและในแอป) — ผู้เข้าชมใหม่ของวันนั้น
  first_seen as (
    select a.visitor_id, min(a.created_at) as first_at
      from app_events a
     where a.visitor_id in (select visitor_id from ev)
     group by a.visitor_id
  ),
  -- สมาชิกที่ใช้งาน: ชั่วโมงที่มีสัญญาณ "ยังอยู่" + เหตุการณ์ตอนล็อกอิน (นิยามเดียวกับ admin_live)
  --   ชั่วโมงที่มีสัญญาณนับจากต้นชั่วโมง → ทั้งสองช่วงนับเฉพาะชั่วโมงที่จบแล้ว (ts_end) + เหตุการณ์ที่มีเวลาแน่นอน — เทียบแบบเดียวกันทั้งสองฝั่ง
  act as (
    select h.user_id as uid, h.hour as ts, h.hour + interval '1 hour' as ts_end from user_activity_hours h join u on u.id = h.user_id
     where h.hour >= v_pstart and h.hour < v_end
    union all
    select a.user_id, a.created_at, a.created_at from app_events a join u on u.id = a.user_id
     where a.event in ('visit', 'page_view', 'page_time') and a.created_at >= v_pstart and a.created_at < v_end
  ),
  led as (
    select l.reason, l.delta, l.created_at from points_ledger l join u on u.id = l.user_id
     where l.created_at >= v_pstart and l.created_at < v_end
  ),
  pur as (
    select pp.points_spent, pp.created_at from package_purchases pp join u on u.id = pp.user_id
     where pp.created_at >= v_pstart and pp.created_at < v_end
  ),
  -- สมัครสมาชิก = บัญชีที่สร้างในช่วงนั้น · แยกว่ายืนยันอีเมลแล้วหรือยัง (บัญชีที่ใส่อีเมลผิดจะไม่ยืนยันตลอด)
  sig as (
    select u.created_at, (au.email_confirmed_at is not null) as confirmed
      from u join auth.users au on au.id = u.id
     where u.created_at >= v_pstart and u.created_at < v_end
  ),
  per as (
    select 'cur'::text as k, v_start as s, v_end as e
    union all
    select 'prev'::text, v_pstart, v_pend
  ),
  met as (
    select per.k, jsonb_build_object(
      'visitors', (select count(distinct visitor_id) from ev where created_at >= per.s and created_at < per.e),
      'landing_visitors', (select count(distinct visitor_id) from ev where event = 'landing_view' and created_at >= per.s and created_at < per.e),
      'app_visitors', (select count(distinct visitor_id) from ev
                        where event not in ('landing_view', 'landing_cta') and created_at >= per.s and created_at < per.e),
      'new_visitors', (select count(*) from first_seen where first_at >= per.s and first_at < per.e),
      'signup_clicks', (select count(distinct visitor_id) from ev where event = 'signup' and created_at >= per.s and created_at < per.e),
      'signups', (select count(*) from sig where created_at >= per.s and created_at < per.e),
      'signups_confirmed', (select count(*) from sig where confirmed and created_at >= per.s and created_at < per.e),
      -- ผู้เข้าชมใหม่ของช่วงนี้ที่สมัคร (ตัวตั้งของ % สมัคร — ไม่เกิน new_visitors เสมอ แบบเดียวกับ signups_new ของ admin_traffic)
      'signups_new', (select count(distinct e.visitor_id) from ev e join first_seen f on f.visitor_id = e.visitor_id
                       where e.event = 'signup' and e.created_at >= per.s and e.created_at < per.e
                         and f.first_at >= per.s and f.first_at < per.e),
      'active_members', (select count(distinct uid) from act where ts >= per.s and ts_end <= per.e),
      'pricing_visitors', (select count(distinct visitor_id) from ev
                            where event = 'page_view' and page = 'pricing' and created_at >= per.s and created_at < per.e),
      'buy_clicks', (select count(distinct visitor_id) from ev
                      where event in ('buy_click', 'buy_click_guest') and created_at >= per.s and created_at < per.e),
      'purchases', (select count(*) from pur where created_at >= per.s and created_at < per.e),
      'purchase_points', (select coalesce(sum(points_spent), 0) from pur where created_at >= per.s and created_at < per.e),
      'revenue', (select coalesce(sum(delta), 0) from led where reason = any(v_real) and created_at >= per.s and created_at < per.e),
      'topups', (select count(*) from led
                  where reason in ('topup', 'admin_confirm_topup', 'slip_topup') and delta > 0 and created_at >= per.s and created_at < per.e)
    ) as j
    from per
  ),
  hrs as (select generate_series(0, 23) as h),
  -- แหล่งที่มาแรกของวันนั้นของแต่ละเครื่อง (ติดมากับ visit / landing_view ตั้งแต่ SQL นี้)
  cur_first_src as (
    select distinct on (visitor_id) visitor_id, source from ev
     where created_at >= v_start and event in ('visit', 'landing_view') and source is not null
     order by visitor_id, created_at
  ),
  -- แท็บที่เปิดค้าง/โหลดซ้ำข้ามวัน (เช่น จับเวลาบอส) ไม่ส่ง visit ใหม่ → ใช้แหล่งที่มาล่าสุดก่อนวันนั้นของเครื่องเดียวกัน
  --   ไม่เคยมีเลย = '?' (เปิดเว็บก่อนเริ่มเก็บ)
  prior_src as (
    select distinct on (a.visitor_id) a.visitor_id, a.source from app_events a
     where a.visitor_id in (select visitor_id from ev where created_at >= v_start)
       and a.created_at < v_start and a.source is not null
     order by a.visitor_id, a.created_at desc
  ),
  src_rows as (
    select coalesce(fs.source, ps.source, '?') as src,
           count(distinct c.visitor_id) as vis,
           count(distinct c.visitor_id) filter (where c.event = 'signup') as sc,
           count(distinct c.visitor_id) filter (where c.event = 'buy_success') as b
      from ev c
      left join cur_first_src fs on fs.visitor_id = c.visitor_id
      left join prior_src ps on ps.visitor_id = c.visitor_id
     where c.created_at >= v_start
     group by 1
  ),
  -- เกิน 30 แหล่ง (เช่น ป้ายมั่ว/เว็บสแปม) รวมที่เหลือเป็นแถวเดียว '*'
  src_ranked as (
    select src_rows.*, row_number() over (order by vis desc, src) as rn from src_rows
  )
  select jsonb_build_object(
    'generated_at', now(),
    'day', v_day,
    'is_today', v_day = v_today,
    'window_end', v_end,
    'prev_day', v_day - 1,
    'prev_end', v_pend,
    'tracking_since', (select min(created_at) from app_events),
    'sources_since', (select min(created_at) from app_events where source is not null),
    'cur', (select j from met where k = 'cur'),
    'prev', (select j from met where k = 'prev'),
    'hours', (select jsonb_agg(jsonb_build_object(
                'hour', hrs.h,
                'future', v_start + make_interval(hours => hrs.h) >= now(),
                'visitors', (select count(distinct visitor_id) from ev
                              where created_at >= v_start + make_interval(hours => hrs.h)
                                and created_at < v_start + make_interval(hours => hrs.h + 1)),
                'prev_visitors', (select count(distinct visitor_id) from ev
                                   where created_at >= v_pstart + make_interval(hours => hrs.h)
                                     and created_at < v_pstart + make_interval(hours => hrs.h + 1)),
                'signups', (select count(*) from sig
                             where created_at >= v_start + make_interval(hours => hrs.h)
                               and created_at < v_start + make_interval(hours => hrs.h + 1))
              ) order by hrs.h) from hrs),
    'sources', (select coalesce(jsonb_agg(jsonb_build_object('source', src, 'visitors', vis, 'signup_clicks', sc, 'buyers', b)
                                          order by sort_key, vis desc, src), '[]'::jsonb)
                  from (
                    select src, vis, sc, b, 0 as sort_key from src_ranked where rn <= 30
                    union all
                    select '*', sum(vis), sum(sc), sum(b), 1 from src_ranked where rn > 30 having count(*) > 0
                  ) s)
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_day_report_data(date) from public, anon, authenticated;

create function public.admin_day_report(p_day date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;
  return public.admin_day_report_data(p_day);
end;
$function$;

revoke all on function public.admin_day_report(date) from public, anon;
grant execute on function public.admin_day_report(date) to authenticated;

-- ---------- ลองใช้จริงก่อน commit (พังตรงไหน = ยกเลิกทั้งหมด ไม่มีอะไรถูกแก้) ----------
do $check$
begin
  -- รายงานวันนี้คำนวณได้ครบทุกตาราง/คอลัมน์
  perform public.admin_day_report_data((now() at time zone 'Asia/Bangkok')::date);
  -- log_events บันทึกแหล่งที่มาได้ และกรองตัวอักษรถูก — ลองแล้วย้อนแถวทดสอบทิ้งทันที (ไม่มีข้อมูลค้าง)
  begin
    -- ใช้โควตาแยกของตัวทดสอบเอง (ไม่ใช่ ip:unknown ที่ใช้ร่วมกัน) — ค่านี้ย้อนกลับพร้อมแถวทดสอบ
    perform set_config('request.headers', '{"x-real-ip":"migcheck-20261006"}', true);
    perform public.log_events('migcheck-20261006', '[{"e":"visit","m":"desktop","s":"Tag:FB0610!"}]'::jsonb);
    if not exists (select 1 from public.app_events
                    where visitor_id = 'migcheck-20261006' and event = 'visit' and source = 'tag:fb0610') then
      raise exception 'log_events บันทึกแหล่งที่มาไม่ได้ (ถ้าตอนนั้นมีคนเข้าเว็บเยอะมากอาจติดลิมิตชั่วคราว — รันใหม่ในอีก 1 นาที)';
    end if;
    raise exception 'migcheck_ok';
  exception when others then
    if sqlerrm <> 'migcheck_ok' then raise; end if;
  end;
end;
$check$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (คอลัมน์ใหม่มีแล้ว · ฟังก์ชันตรงกับไฟล์นี้ · ไม่มีแถวทดสอบค้าง · สิทธิ์ถูกต้อง: รายงานเฉพาะผู้ล็อกอิน (เช็คแอดมินข้างใน) ตัวคำนวณเรียกตรงไม่ได้)
select
  exists (select 1 from pg_attribute where attrelid = 'public.app_events'::regclass and attname = 'source' and not attisdropped)
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)')) = '88e5be2ad2be61c109b4095e81edd4cd'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_day_report_data(date)')) = 'd4ba2aac0868d0c971032c27fed63340'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_day_report(date)')) = 'bfd94073dec308b0bfcf19bde50d81e9'
    and not exists (select 1 from public.app_events where visitor_id = 'migcheck-20261006')
    and has_function_privilege('anon', 'public.log_events(text, jsonb)', 'execute')
    and has_function_privilege('authenticated', 'public.admin_day_report(date)', 'execute')
    and not has_function_privilege('anon', 'public.admin_day_report(date)', 'execute')
    and not has_function_privilege('anon', 'public.admin_day_report_data(date)', 'execute')
    and not has_function_privilege('authenticated', 'public.admin_day_report_data(date)', 'execute') as day_report_ok;
