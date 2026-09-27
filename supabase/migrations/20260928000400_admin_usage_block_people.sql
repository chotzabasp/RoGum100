-- ============================================================
-- แดชบอร์ดแอดมิน: การ์ด "ช่วงเวลาที่คนใช้งาน" แสดงเป็นจำนวนคนจริง + % การใช้งาน (ผู้ใช้เลือกแบบ ก · 28 ก.ย. 2569)
-- admin_usage(p_days): blocks[] + people (คนไม่ซ้ำที่เข้าใช้ช่วงนั้นตลอดช่วงวันที่เลือก) + user_hours (ชั่วโมงใช้งาน ใช้คิด %)
--   + people_total (คนไม่ซ้ำทั้งหมดในช่วงวันที่เลือก) · ของเดิมคงไว้ทุกตัวอักษร
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260928000400_admin_usage_block_people_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_usage(integer)');
  if v_md5 is distinct from '3e26abe87d33a913dcb718fb34f4c903' then
    raise exception 'admin_usage ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

create or replace function public.admin_usage(p_days integer default 30)
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
    -- ช่วงละ 3 ชั่วโมง (00.00–03.00 … 21.00–24.00): คนเดียวกันในช่วงเดียวกันของวันเดียวกันนับ 1 · เฉลี่ยต่อวันแบบเดียวกับ hours
    'blocks', (select jsonb_agg(jsonb_build_object(
                'block', b.b, 'start_hour', b.b * 3, 'end_hour', b.b * 3 + 3,
                'avg_users', round((select count(*) from (select distinct uid, (hr at time zone 'Asia/Bangkok')::date from act_h
                                    where floor(extract(hour from hr at time zone 'Asia/Bangkok') / 3) = b.b) s)::numeric / v_eff, 1),
                'total', (select count(*) from (select distinct uid, (hr at time zone 'Asia/Bangkok')::date from act_h
                           where floor(extract(hour from hr at time zone 'Asia/Bangkok') / 3) = b.b) s),
                -- คนไม่ซ้ำที่เคยเข้าใช้ช่วงนี้ตลอดช่วงวันที่เลือก (การ์ดแสดงเป็นจำนวนคนจริง) + ชั่วโมงใช้งาน (คนละ 1 ต่อชั่วโมง ไว้คิด % การใช้งาน)
                'people', (select count(distinct uid) from act_h where floor(extract(hour from hr at time zone 'Asia/Bangkok') / 3) = b.b),
                'user_hours', (select count(*) from act_h where floor(extract(hour from hr at time zone 'Asia/Bangkok') / 3) = b.b)
              ) order by b.b) from generate_series(0, 7) as b(b)),
    'people_total', (select count(distinct uid) from act_h),
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

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ true ทั้ง 2 ช่อง
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_usage(integer)')) = 'd77a48858a5e25096d51e17a961f0998' as admin_usage_ok,
  has_function_privilege('authenticated', 'public.admin_usage(integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_usage(integer)', 'execute') as grants_ok;
