-- ============================================================
-- ย้อนกลับ 20261006000100_admin_day_report_sources.sql
--   log_events → ฉบับ 20260929000100 (md5 9542591d…) · ลบ admin_day_report / admin_day_report_data
--   ลบคอลัมน์ app_events.source (แหล่งที่มาที่เก็บไว้จะหายทั้งหมด ตัวเลขการเข้าชมอื่นอยู่ครบ)
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (หน้าเว็บที่ส่ง s มา log_events ฉบับเดิมไม่สนค่านี้)
--   แดชบอร์ดจะซ่อนกล่องรายงานรายวันเองเมื่อไม่มี admin_day_report
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)');
  if v_md5 is distinct from '88e5be2ad2be61c109b4095e81edd4cd' then
    raise exception 'log_events ไม่ใช่ฉบับ 20261006000100 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

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

drop function if exists public.admin_day_report(date);
drop function if exists public.admin_day_report_data(date);
alter table public.app_events drop column if exists source;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.log_events(text, jsonb)')) = '9542591ddf487f2b9692c9192fb5f306'
    and to_regprocedure('public.admin_day_report(date)') is null
    and to_regprocedure('public.admin_day_report_data(date)') is null
    and not exists (select 1 from pg_attribute where attrelid = 'public.app_events'::regclass and attname = 'source' and not attisdropped)
    and has_function_privilege('anon', 'public.log_events(text, jsonb)', 'execute') as day_report_removed_ok;
