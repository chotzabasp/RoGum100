-- ย้อนกลับ migration 20260928000300_admin_usage_blocks (รันเฉพาะเมื่อจำเป็น): คืน admin_usage เป็นเวอร์ชัน 20260928000200 (ไม่มี blocks)
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_usage(integer)');
  if v_md5 is distinct from '3e26abe87d33a913dcb718fb34f4c903' then
    raise exception 'admin_usage ไม่ใช่เวอร์ชันของ 20260928000300 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
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

select (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_usage(integer)')) = '37679889586c6bc6e1f1d5cecdb17ad4' as admin_usage_restored;
