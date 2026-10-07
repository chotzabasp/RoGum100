-- ============================================================
-- แดชบอร์ดแอดมิน กล่อง "ยอดรวมการใช้งานทั้งหมด": เพิ่มตัวเลข "มาจากกี่คน" ใต้แต่ละช่อง (ผู้ใช้สั่ง 7 ต.ค. 2569)
-- admin_dashboard(): ส่วน features เพิ่ม 7 ค่า — นับคนไม่ซ้ำ ไม่นับบัญชีแอดมิน (เหมือนตัวเลขหลัก)
--   merchant_users / farm_users = คนที่มีรายการซื้อ–ขาย / รายการยอดฟาร์ม
--   kills_users          = คนที่กด "ตายแล้ว" (รวมบอส Custom · คนในปาร์ตี้กดรอบเดียวกันภายใน 60 วิ นับคนที่กดคนแรก)
--   bosses_users         = เจ้าของรายการจับเวลาที่มีบอสปกติ (รายการของปาร์ตี้นับเป็นของหัวปาร์ตี้)
--   party_members        = สมาชิกปาร์ตี้ที่ยังอยู่ในปาร์ตี้ (ไม่นับหัวปาร์ตี้)
--   custom_bosses_users  = คนที่สร้างบอส Custom (ที่ยังไม่ลบ)
--   announcements_users  = คนที่มีประกาศรับ M ที่ยังไม่หมดอายุ
-- ตัวเลขเดิมทุกตัวและส่วนอื่นของฟังก์ชันคงเดิมทุกตัวอักษร (เนื้อเดิมจาก 20260927000300 md5 cdc91f8f…)
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (หน้าเว็บที่ยังไม่มีค่าใหม่ = ไม่แสดงบรรทัด "จาก N คน" เฉยๆ)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261007000100_admin_features_people_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_dashboard(integer)');
  if v_md5 is distinct from 'cdc91f8fc7c591b72ea9675c6f417fbe' then
    raise exception 'admin_dashboard ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

create or replace function public.admin_dashboard(p_days integer default 30)
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
  v_start_ms bigint;
  v_from timestamptz;
  v_month_ts timestamptz := date_trunc('month', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
  v_prev_month_ts timestamptz := (date_trunc('month', now() at time zone 'Asia/Bangkok') - interval '1 month') at time zone 'Asia/Bangkok';
  v_prev_same_end timestamptz;
  v_real text[] := array['topup', 'admin_confirm_topup', 'slip_topup', 'admin_reverse'];
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;

  v_start := v_today - (v_days - 1);
  v_start_ts := v_start::timestamp at time zone 'Asia/Bangkok';
  v_start_ms := (extract(epoch from v_start_ts) * 1000)::bigint;
  v_from := least(v_start_ts, now() - interval '14 days');
  v_prev_same_end := least(v_prev_month_ts + (now() - v_month_ts), v_month_ts);

  with
  u as (
    select p.id, p.display_name, p.username, p.created_at, p.servers,
           coalesce(p.legacy_unlimited, false) as legacy,
           p.plan_bundle_expires_at as b, p.plan_timers_expires_at as t,
           (select max(e.expires_at) from package_feature_entitlements e where e.user_id = p.id and e.feature = 'farm') as f,
           (select max(e.expires_at) from package_feature_entitlements e where e.user_id = p.id and e.feature = 'accountItems') as a
      from profiles p
     where p.role is distinct from 'admin'
  ),
  us as (
    -- coalesce ทุกตัว: วันหมดอายุที่ว่าง (null) ต้องนับเป็น "ไม่มีสิทธิ์" ไม่ใช่ null ที่ทำให้แถวหลุดจากการนับ
    select u.*,
           (legacy or coalesce(b > now(), false) or coalesce(a > now(), false)) as trade_ok,
           (legacy or coalesce(b > now(), false) or coalesce(f > now(), false)) as farm_ok,
           (not legacy and (coalesce(b > now(), false) or coalesce(t > now(), false)
                            or coalesce(f > now(), false) or coalesce(a > now(), false))) as paid
      from u
  ),
  ev as (
    select x.uid, x.at from (
      select user_id as uid, updated_at as at from merchant_entries where updated_at >= v_from
      union all select user_id, updated_at from farm_entries where updated_at >= v_from
      union all select user_id, updated_at from user_app_data where updated_at >= v_from
      union all select killed_by, created_at from kills where created_at >= v_from and killed_by is not null
      union all select user_id, updated_at from user_bosses where updated_at >= v_from
      union all select owner_id, updated_at from custom_boss_timers where updated_at >= v_from
      union all select user_id, created_at from points_ledger where created_at >= v_from
      union all select id, last_sign_in_at from auth.users where last_sign_in_at >= v_from
      -- เปิดเว็บขณะล็อกอินอยู่ (ดูอย่างเดียวก็นับ เช่น สมาชิกปาร์ตี้ที่เปิดดูตัวจับเวลาบอส) — มีข้อมูลตั้งแต่ 24 ก.ย. 2569
      union all select user_id, created_at from app_events
       where user_id is not null and event in ('visit', 'page_view', 'page_time') and created_at >= v_from
    ) x
    join u on u.id = x.uid
  ),
  led as (
    select l.* from points_ledger l join u on u.id = l.user_id
  ),
  days as (
    select generate_series(v_start, v_today, interval '1 day')::date as d
  ),
  m_day as (
    select m.user_id, (to_timestamp(m.ts / 1000.0) at time zone 'Asia/Bangkok')::date as d, count(*) as n
      from merchant_entries m join u on u.id = m.user_id
     where m.ts >= v_start_ms
     group by 1, 2
  ),
  f_day as (
    select fe.user_id, (to_timestamp(fe.ts / 1000.0) at time zone 'Asia/Bangkok')::date as d, count(*) as n
      from farm_entries fe join u on u.id = fe.user_id
     where fe.ts >= v_start_ms
     group by 1, 2
  ),
  k_day as (
    select (coalesce(k.killed_at, k.created_at) at time zone 'Asia/Bangkok')::date as d, count(*) as n
      from kills k join u on u.id = k.host_id
     where coalesce(k.killed_at, k.created_at) >= v_start_ts
     group by 1
  )
  select jsonb_build_object(
    'generated_at', now(),
    'days', v_days,

    -- A. ตัวเลขหลัก
    'kpi', jsonb_build_object(
      'members', (select count(*) from us),
      'new_today', (select count(*) from us where (created_at at time zone 'Asia/Bangkok')::date = v_today),
      'new_yesterday', (select count(*) from us where (created_at at time zone 'Asia/Bangkok')::date = v_today - 1),
      'new_period', (select count(*) from us where created_at >= v_start_ts),
      'active_7d', (select count(distinct uid) from ev where at >= now() - interval '7 days'),
      'active_prev_7d', (select count(distinct uid) from ev where at >= now() - interval '14 days' and at < now() - interval '7 days'),
      'revenue_month', (select coalesce(sum(delta), 0) from led where reason = any(v_real) and created_at >= v_month_ts),
      'revenue_prev_month', (select coalesce(sum(delta), 0) from led where reason = any(v_real) and created_at >= v_prev_month_ts and created_at < v_month_ts),
      'revenue_prev_month_same', (select coalesce(sum(delta), 0) from led where reason = any(v_real) and created_at >= v_prev_month_ts and created_at < v_prev_same_end),
      'prev_month_same_end', v_prev_same_end,
      'admin_grant_month', (select coalesce(sum(delta), 0) from led where reason = 'admin_grant' and created_at >= v_month_ts),
      'paid_users', (select count(*) from us where paid),
      'legacy_users', (select count(*) from us where legacy),
      'free_users', (select count(*) from us where not paid and not legacy)
    ),

    -- B. รายได้และแพ็กเกจ
    'revenue', jsonb_build_object(
      'period_revenue', (select coalesce(sum(delta), 0) from led where reason = any(v_real) and created_at >= v_start_ts),
      'period_admin_grant', (select coalesce(sum(delta), 0) from led where reason = 'admin_grant' and created_at >= v_start_ts),
      'points_outstanding', (select coalesce(sum(p.points), 0) from profiles p join u on u.id = p.id),
      'points_in', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason, 'points', pts) order by pts desc), '[]'::jsonb)
                      from (select reason, sum(delta) as pts from led where delta > 0 and created_at >= v_start_ts group by reason) s),
      'points_out', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason, 'points', pts) order by pts desc), '[]'::jsonb)
                       from (select reason, -sum(delta) as pts from led where delta < 0 and created_at >= v_start_ts group by reason) s),
      'plan_sales', (select coalesce(jsonb_agg(jsonb_build_object('plan_key', plan_key, 'plan_name', plan_name, 'cycle', cycle,
                                                                  'count', cnt, 'points', pts) order by pts desc), '[]'::jsonb)
                       from (select pp.plan_key, max(pp.plan_name) as plan_name, pp.cycle, count(*) as cnt, sum(pp.points_spent) as pts
                               from package_purchases pp join u on u.id = pp.user_id
                              where pp.created_at >= v_start_ts
                              group by pp.plan_key, pp.cycle) s),
      'active_plans', jsonb_build_object(
        'all', (select count(*) from us where not legacy and b > now() and t > now()),
        'bundle', (select count(*) from us where not legacy and b > now() and not coalesce(t > now(), false)),
        'timers', (select count(*) from us where not legacy and t > now() and not coalesce(b > now(), false)),
        'accountItems', (select count(*) from us where not legacy and a > now() and not coalesce(b > now(), false)),
        'farm', (select count(*) from us where not legacy and f > now() and not coalesce(b > now(), false))
      ),
      'expiring', (select coalesce(jsonb_agg(jsonb_build_object('name', display_name, 'username', username,
                                                                'plan', plan, 'expires_at', exp) order by exp), '[]'::jsonb)
                     from (
                       select display_name, username, '4 in 1 (แพ็กรวม + จับเวลาบอส)' as plan, least(b, t) as exp from us
                        where not legacy and b > now() and b <= now() + interval '7 days' and t > now() and t <= now() + interval '7 days'
                          and (b at time zone 'Asia/Bangkok')::date = (t at time zone 'Asia/Bangkok')::date
                       union all select display_name, username, 'แพ็กรวม (3 in 1 / 4 in 1)', b from us
                        where not legacy and b > now() and b <= now() + interval '7 days'
                          and not (t is not null and t > now() and t <= now() + interval '7 days'
                                   and (b at time zone 'Asia/Bangkok')::date = (t at time zone 'Asia/Bangkok')::date)
                       union all select display_name, username, 'จับเวลาบอส', t from us
                        where not legacy and t > now() and t <= now() + interval '7 days'
                          and not (b is not null and b > now() and b <= now() + interval '7 days'
                                   and (b at time zone 'Asia/Bangkok')::date = (t at time zone 'Asia/Bangkok')::date)
                       union all select display_name, username, '1 in 1 (ยอดนักฟาร์ม)', f from us where not legacy and f > now() and f <= now() + interval '7 days'
                       union all select display_name, username, '2 in 1 (นักลงทุน/คลัง)', a from us where not legacy and a > now() and a <= now() + interval '7 days'
                     ) s),
      'promo', (select coalesce(jsonb_agg(jsonb_build_object('code', code, 'used', used_count, 'max', max_uses,
                                                             'expires_at', expires_at, 'reward_type', reward_type,
                                                             'points', points, 'plan_days', plan_days, 'plan_key', plan_key, 'discount_percent', discount_percent,
                                                             'used_period', (select count(*) from promo_code_redemptions r
                                                                              where r.code = pc.code and r.redeemed_at >= v_start_ts))
                                                   order by created_at desc), '[]'::jsonb)
                  from (select * from promo_codes order by created_at desc limit 10) pc)
    ),

    -- C. สัญญาณอยากอัปเกรด
    'upgrade', jsonb_build_object(
      'trade_limit_users', (select count(distinct m.user_id) from m_day m join us on us.id = m.user_id where not us.trade_ok and m.n >= 5),
      'trade_limit_days', (select count(*) from m_day m join us on us.id = m.user_id where not us.trade_ok and m.n >= 5),
      'farm_limit_users', (select count(distinct fd.user_id) from f_day fd join us on us.id = fd.user_id where not us.farm_ok and fd.n >= 3),
      'farm_limit_days', (select count(*) from f_day fd join us on us.id = fd.user_id where not us.farm_ok and fd.n >= 3),
      'candidates', (select coalesce(jsonb_agg(c order by (c->>'score')::int desc, (c->>'active_days')::int desc), '[]'::jsonb)
                       from (
                         select jsonb_build_object(
                                  'name', us.display_name, 'username', us.username,
                                  'trade_days', coalesce(td.n, 0), 'farm_days', coalesce(fd.n, 0),
                                  'active_days', coalesce(ad.n, 0),
                                  'score', coalesce(td.n, 0) * 2 + coalesce(fd.n, 0) * 2 + coalesce(ad.n, 0)) as c
                           from us
                           left join (select user_id, count(*) as n from m_day where n >= 5 group by user_id) td on td.user_id = us.id
                           left join (select user_id, count(*) as n from f_day where n >= 3 group by user_id) fd on fd.user_id = us.id
                           left join (select uid, count(distinct (at at time zone 'Asia/Bangkok')::date) as n
                                        from ev where at >= v_start_ts group by uid) ad on ad.uid = us.id
                          where not us.paid and not us.legacy
                            and (coalesce(td.n, 0) > 0 or coalesce(fd.n, 0) > 0 or coalesce(ad.n, 0) >= 3)
                          order by coalesce(td.n, 0) * 2 + coalesce(fd.n, 0) * 2 + coalesce(ad.n, 0) desc
                          limit 10
                       ) s)
    ),

    -- D. การใช้งานรายวัน (กราฟ)
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
                  'day', days.d,
                  'signups', (select count(*) from us where (us.created_at at time zone 'Asia/Bangkok')::date = days.d),
                  'active', (select count(distinct ev.uid) from ev where (ev.at at time zone 'Asia/Bangkok')::date = days.d),
                  'merchant', (select coalesce(sum(n), 0) from m_day where m_day.d = days.d),
                  'farm', (select coalesce(sum(n), 0) from f_day where f_day.d = days.d),
                  'kills', (select coalesce(sum(n), 0) from k_day where k_day.d = days.d),
                  'revenue', (select coalesce(sum(delta), 0) from led
                               where reason = any(v_real) and (led.created_at at time zone 'Asia/Bangkok')::date = days.d)
                ) order by days.d), '[]'::jsonb) from days),

    'features', jsonb_build_object(
      'merchant_total', (select count(*) from merchant_entries m join u on u.id = m.user_id),
      'farm_total', (select count(*) from farm_entries fe join u on u.id = fe.user_id),
      'kills_total', (select count(*) from kills k join u on u.id = k.host_id),
      'bosses_tracked', (select count(*) from user_bosses ub join u on u.id = ub.user_id),
      'parties_active', (select count(distinct pm.host_id) from party_members pm join u on u.id = pm.host_id where pm.removed_at is null),
      'custom_bosses', (select count(*) from custom_bosses cb join u on u.id = cb.owner_id where cb.archived_at is null),
      'announcements_active', (select count(*) from announcements an join u on u.id = an.user_id where an.expires_at > now()),
      -- มาจากกี่คน (20261007000100) — นับคนไม่ซ้ำ ไม่นับบัญชีแอดมินเหมือนตัวเลขหลัก
      --   ฆ่าบอส = คนที่กด "ตายแล้ว" · บอสในรายการ = เจ้าของรายการ (รายการของปาร์ตี้ = หัวปาร์ตี้) · ปาร์ตี้ = สมาชิกที่ยังอยู่ (ไม่นับหัวปาร์ตี้)
      'merchant_users', (select count(distinct m.user_id) from merchant_entries m join u on u.id = m.user_id),
      'farm_users', (select count(distinct fe.user_id) from farm_entries fe join u on u.id = fe.user_id),
      'kills_users', (select count(distinct k.killed_by) from kills k join u on u.id = k.host_id join u kb on kb.id = k.killed_by),
      'bosses_users', (select count(distinct ub.user_id) from user_bosses ub join u on u.id = ub.user_id),
      'party_members', (select count(distinct pm.member_id) from party_members pm join u on u.id = pm.host_id join u um on um.id = pm.member_id
                         where pm.removed_at is null),
      'custom_bosses_users', (select count(distinct cb.owner_id) from custom_bosses cb join u on u.id = cb.owner_id where cb.archived_at is null),
      'announcements_users', (select count(distinct an.user_id) from announcements an join u on u.id = an.user_id where an.expires_at > now())
    ),

    -- E. เซิร์ฟเวอร์ยอดนิยม
    'servers', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'active', s.active, 'users', s.users)
                                          order by s.users desc, s.sort_order), '[]'::jsonb)
                  from (select sv.id, sv.name, sv.active, sv.sort_order,
                               (select count(*) from us where sv.id = any(us.servers)) as users
                          from servers sv) s),

    -- F. ความเคลื่อนไหวล่าสุด + คิวงานแอดมิน
    'feed', (select coalesce(jsonb_agg(jsonb_build_object('at', at, 'type', type, 'name', name, 'detail', detail) order by at desc), '[]'::jsonb)
               from (
                 select * from (
                   select us.created_at as at, 'signup' as type, us.display_name as name, coalesce('@' || us.username, '') as detail from us
                   union all
                   select pp.created_at, 'purchase', u.display_name, pp.plan_name || ' · ' || case pp.cycle when 'yearly' then 'รายปี' else 'รายเดือน' end || ' · ' || pp.points_spent || ' แต้ม'
                     from package_purchases pp join u on u.id = pp.user_id
                   union all
                   select led.created_at, case when led.reason = 'admin_reverse' then 'reverse' else 'topup' end, u.display_name,
                          case led.reason when 'topup' then 'QR' when 'admin_confirm_topup' then 'แอดมินยืนยัน QR'
                                          when 'slip_topup' then 'สลิป' when 'admin_grant' then 'แอดมินเติมให้'
                                          else 'แอดมินยกเลิก' end || ' · ' || led.delta || ' แต้ม'
                     from led join u on u.id = led.user_id
                    where led.reason in ('topup', 'admin_confirm_topup', 'slip_topup', 'admin_grant', 'admin_reverse')
                   union all
                   select r.redeemed_at, 'promo', u.display_name, 'โค้ด ' || r.code
                     from promo_code_redemptions r join u on u.id = r.user_id
                 ) all_ev
                 order by at desc
                 limit 25
               ) f),
    'queue', jsonb_build_object(
      'qr_attention', (select count(*) from topup_transactions where status in ('paid', 'manual_review') and provider <> 'manual'),
      'qr_pending', (select count(*) from topup_transactions where status = 'pending' and provider <> 'manual' and created_at >= now() - interval '1 day'),
      'slip_pending', (select count(*) from topup_requests where status = 'pending')
    )
  ) into v_out;

  return v_out;
end;
$function$;

revoke all on function public.admin_dashboard(integer) from public, anon;
grant execute on function public.admin_dashboard(integer) to authenticated;

-- ---------- ลองเรียกจริงก่อน commit (อ่านอย่างเดียว · พังตรงไหน = ยกเลิกทั้งหมด ไม่มีอะไรถูกแก้) ----------
-- ฟังก์ชันเช็คแอดมินข้างใน → เรียกแทนบัญชีแอดมินบัญชีแรกเฉพาะในทรานแซกชันนี้ แล้วคืนค่าเดิมทันที
-- นับซ้ำอีกทางในคำสั่งเดียวกัน (เห็นข้อมูลชุดเดียวกัน) — ค่าใหม่ต้องตรงทุกตัว
do $check$
declare
  v_admin uuid;
  v_claims text := current_setting('request.jwt.claims', true);
  v_out jsonb;
  f jsonb;
  v_expect jsonb;
  k text;
  r record;
begin
  select id into v_admin from public.profiles where role = 'admin' order by created_at limit 1;
  if v_admin is null then
    raise exception 'ไม่พบบัญชีแอดมินสำหรับทดสอบ — ไม่มีอะไรถูกแก้';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  select public.admin_dashboard(30),
         jsonb_build_object(
           'merchant_users', (select count(distinct m.user_id) from public.merchant_entries m
                               where exists (select 1 from public.profiles p where p.id = m.user_id and p.role is distinct from 'admin')),
           'farm_users', (select count(distinct fe.user_id) from public.farm_entries fe
                           where exists (select 1 from public.profiles p where p.id = fe.user_id and p.role is distinct from 'admin')),
           'kills_users', (select count(distinct k2.killed_by) from public.kills k2
                            where exists (select 1 from public.profiles p where p.id = k2.host_id and p.role is distinct from 'admin')
                              and exists (select 1 from public.profiles p where p.id = k2.killed_by and p.role is distinct from 'admin')),
           'bosses_users', (select count(distinct ub.user_id) from public.user_bosses ub
                             where exists (select 1 from public.profiles p where p.id = ub.user_id and p.role is distinct from 'admin')),
           'party_members', (select count(distinct pm.member_id) from public.party_members pm
                              where pm.removed_at is null
                                and exists (select 1 from public.profiles p where p.id = pm.host_id and p.role is distinct from 'admin')
                                and exists (select 1 from public.profiles p where p.id = pm.member_id and p.role is distinct from 'admin')),
           'custom_bosses_users', (select count(distinct cb.owner_id) from public.custom_bosses cb
                                    where cb.archived_at is null
                                      and exists (select 1 from public.profiles p where p.id = cb.owner_id and p.role is distinct from 'admin')),
           'announcements_users', (select count(distinct an.user_id) from public.announcements an
                                    where an.expires_at > now()
                                      and exists (select 1 from public.profiles p where p.id = an.user_id and p.role is distinct from 'admin')))
    into v_out, v_expect;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);

  -- หัวข้ออื่นของผลลัพธ์ยังครบเหมือนเดิม (10 หัวข้อ ชื่อเดิมทุกตัว)
  if (select count(*) from jsonb_object_keys(v_out)) <> 10
     or (select count(*) from jsonb_object_keys(v_out) x
          where x = any (array['days', 'feed', 'features', 'generated_at', 'kpi', 'queue', 'revenue', 'series', 'servers', 'upgrade'])) <> 10 then
    raise exception 'self-test: หัวข้อในผลลัพธ์ของ admin_dashboard ไม่ครบ/เกิน';
  end if;
  f := v_out -> 'features';
  if (select count(*) from jsonb_object_keys(f)) <> 14 then
    raise exception 'self-test: features ต้องมี 14 ค่า (เดิม 7 + ใหม่ 7)';
  end if;
  foreach k in array array['merchant_total', 'farm_total', 'kills_total', 'bosses_tracked', 'parties_active', 'custom_bosses', 'announcements_active',
                           'merchant_users', 'farm_users', 'kills_users', 'bosses_users', 'party_members', 'custom_bosses_users', 'announcements_users'] loop
    if jsonb_typeof(f -> k) is distinct from 'number' then
      raise exception 'self-test: features.% หายไปหรือไม่ใช่ตัวเลข', k;
    end if;
  end loop;
  -- ค่าใหม่ = นับซ้ำอีกทาง
  foreach k in array array['merchant_users', 'farm_users', 'kills_users', 'bosses_users', 'party_members', 'custom_bosses_users', 'announcements_users'] loop
    if (f ->> k)::bigint is distinct from (v_expect ->> k)::bigint then
      raise exception 'self-test: features.% = % แต่นับซ้ำได้ %', k, f ->> k, v_expect ->> k;
    end if;
  end loop;
  -- จำนวนคนต้องไม่เกินจำนวนรายการ · มีรายการ = มีคนอย่างน้อย 1 คน (ฆ่าบอส: คนกดอาจเป็นบัญชีที่ลบแล้ว/แอดมิน → เช็คแค่ไม่เกิน)
  for r in select * from (values
      ('merchant_total', 'merchant_users', true), ('farm_total', 'farm_users', true), ('bosses_tracked', 'bosses_users', true),
      ('custom_bosses', 'custom_bosses_users', true), ('announcements_active', 'announcements_users', true),
      ('kills_total', 'kills_users', false)) v(total_key, users_key, zero_together) loop
    if (f ->> r.users_key)::bigint > (f ->> r.total_key)::bigint
       or (r.zero_together and ((f ->> r.total_key)::bigint > 0) <> ((f ->> r.users_key)::bigint > 0)) then
      raise exception 'self-test: % (%) ไม่สอดคล้องกับ % (%)', r.users_key, f ->> r.users_key, r.total_key, f ->> r.total_key;
    end if;
  end loop;
  if (f ->> 'party_members')::bigint > 0 and (f ->> 'parties_active')::bigint = 0 then
    raise exception 'self-test: มีสมาชิกปาร์ตี้ % คน แต่ปาร์ตี้ที่มีสมาชิก = 0', f ->> 'party_members';
  end if;
end;
$check$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (ฟังก์ชันตรงกับไฟล์นี้ · สิทธิ์เดิม: ผู้ล็อกอินเรียกได้ (เช็คแอดมินข้างใน) · ผู้ไม่ล็อกอินเรียกไม่ได้)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_dashboard(integer)')) = '1c3c7e5a1a5cd70ec174067bc31d3601'
    and has_function_privilege('authenticated', 'public.admin_dashboard(integer)', 'execute')
    and not has_function_privilege('anon', 'public.admin_dashboard(integer)', 'execute') as features_people_ok;
