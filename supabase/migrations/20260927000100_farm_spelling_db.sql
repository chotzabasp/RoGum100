-- ============================================================
-- แก้คำสะกดในฐานข้อมูล "ฟาม" → "ฟาร์ม" (หน้าเว็บแก้ไปแล้วใน commit e7c0edc)
--   1) buy_plan: ชื่อแพ็กที่บันทึกลงประวัติการซื้อ '1 in 1 — ยอดนักฟาม' → '1 in 1 — ยอดนักฟาร์ม'
--   2) admin_dashboard: ป้ายรายการแพ็กใกล้หมดอายุ '1 in 1 (ยอดนักฟาม)' → '1 in 1 (ยอดนักฟาร์ม)'
--   3) ประวัติการซื้อเก่าใน package_purchases: เปลี่ยนคำในชื่อแพ็กให้ตรงกัน (แก้แค่ข้อความ ไม่แตะแต้ม/วันหมดอายุ)
-- เนื้อฟังก์ชันคัดลอกจาก 20260926000100_restore_buy_plan.sql และ 20260925001000_admin_dashboard_fixes.sql
-- ตรงตัวอักษร (ตรวจ md5 ตรงกับฐานข้อมูลจริงก่อนรัน) เปลี่ยนแค่คำนี้คำเดียวในแต่ละฟังก์ชัน ไม่ได้แก้ตรรกะ
-- ============================================================
begin;

create or replace function public.buy_plan(p_plan_key text, p_cycle text)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  if p_plan_key in ('farm','accountItems') and p_cycle <> 'monthly' then
    raise exception 'แพ็กเกจนี้รองรับเฉพาะรายเดือน';
  end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  v_price := case
    when p_plan_key in ('bundle','timers') and p_cycle = 'yearly' and public.promo_active() then 990
    when p_plan_key in ('bundle','timers') and p_cycle = 'yearly' then 1990
    when p_plan_key in ('bundle','timers') and public.promo_active() then 99
    when p_plan_key in ('bundle','timers') then 199
    when p_plan_key = 'all' and public.promo_active() then (case p_cycle when 'yearly' then 1750 else 175 end)
    when p_plan_key = 'all' then (case p_cycle when 'yearly' then 3490 else 349 end)
    when p_plan_key = 'accountItems' then 149
    else 99
  end;
  select points, plan_bundle_expires_at, plan_timers_expires_at into v_points, v_bundle, v_timers
    from public.profiles where id = v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points, 0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
    v_before := greatest(v_before, v_bundle);
    v_new := greatest(coalesce(v_before, now()), now()) + interval '30 days';
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
  update public.profiles set points = points - v_price where id = v_uid;
  v_name := case p_plan_key
    when 'farm' then '1 in 1 — ยอดนักฟาร์ม'
    when 'accountItems' then '2 in 1'
    when 'bundle' then '3 in 1'
    when 'timers' then 'จับเวลาบอส'
    else '4 in 1' end;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id, plan_key, plan_name, cycle, points_spent, days_added, expires_before, expires_after)
    values (v_uid, p_plan_key, v_name, p_cycle, v_price, v_days, v_before, v_new);
  end if;
  return v_new;
end;
$function$;

revoke all on function public.buy_plan(text, text) from public, anon;
grant execute on function public.buy_plan(text, text) to authenticated;

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
                                                             'points', points, 'plan_days', plan_days,
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
      'announcements_active', (select count(*) from announcements an join u on u.id = an.user_id where an.expires_at > now())
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

update public.package_purchases
   set plan_name = replace(plan_name, 'ฟาม', 'ฟาร์ม')
 where plan_name like '%ฟาม%';

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว):
--   buy_plan md5 = d211e515a4d31d6d8bc56a5a5fbb4f1a · admin_dashboard md5 = 01bf085e59f5a97d2eaf06303ab7cf85
--   has_old_word = false ทั้ง 2 แถว · anon_exec = false · auth_exec = true
select p.proname as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       position('ฟาม' in p.prosrc) > 0 as has_old_word,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('buy_plan', 'admin_dashboard')
 order by 1;

--   ต้องได้ 0
select count(*) as purchases_with_old_word
  from public.package_purchases
 where plan_name like '%ฟาม%';
