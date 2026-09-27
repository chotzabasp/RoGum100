-- ============================================================
-- ราคาแพ็กเกจใหม่ + โปรลด 50% ทุกแพ็ก + รายปีทุกแพ็ก (2026-09-27)
--   ราคาปกติ รายเดือน / รายปี (รายปี = รายเดือน × 10):
--     1 in 1 (farm)          199 / 1,990
--     2 in 1 (accountItems)  299 / 2,990
--     จับเวลาบอส (timers)     249 / 2,490
--     3 in 1 (bundle)        399 / 3,990
--     4 in 1 (all)           499 / 4,990
--   ช่วงโปร (promo_active() จริง = ถึง 2026-10-12 00:04:59+07) ลด 50% ปัดเศษลง ทุกแพ็ก:
--     1 in 1 99 / 990 · 2 in 1 149 / 1,490 · จับเวลาบอส 124 / 1,240 · 3 in 1 199 / 1,990 · 4 in 1 249 / 2,490
--   1 in 1 / 2 in 1 ซื้อรายปีได้แล้ว (+1 ปี) — เดิมรองรับเฉพาะรายเดือน
-- ต้องตรงกับ PRICING_PLANS ใน assets/app.js
-- เนื้อฟังก์ชันส่วนอื่นคงเดิมทุกตัวอักษรจาก 20260927000100_farm_spelling_db.sql (md5 d211e515a4d31d6d8bc56a5a5fbb4f1a)
-- มีตัวกันในไฟล์: ถ้า buy_plan ในฐานข้อมูลไม่ตรงกับ repo จะหยุดทันที ไม่มีอะไรถูกแก้
-- ============================================================
begin;

do $guard$
declare v_md5 text;
begin
  select md5(replace(p.prosrc, E'\r', '')) into v_md5
    from pg_proc p
   where p.oid = 'public.buy_plan(text, text)'::regprocedure;
  if v_md5 is distinct from 'd211e515a4d31d6d8bc56a5a5fbb4f1a' then
    raise exception 'หยุด: buy_plan ในฐานข้อมูลไม่ตรงกับ repo (md5 %) — ไม่มีอะไรถูกแก้', v_md5;
  end if;
end
$guard$;

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
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  -- ราคาปกติ (รายปี = รายเดือน × 10) · ช่วงโปรลด 50% ปัดเศษลง — ต้องตรงกับ PRICING_PLANS ใน assets/app.js
  v_price := case p_plan_key || ':' || p_cycle
    when 'farm:monthly'         then case when public.promo_active() then   99 else  199 end
    when 'farm:yearly'          then case when public.promo_active() then  990 else 1990 end
    when 'accountItems:monthly' then case when public.promo_active() then  149 else  299 end
    when 'accountItems:yearly'  then case when public.promo_active() then 1490 else 2990 end
    when 'timers:monthly'       then case when public.promo_active() then  124 else  249 end
    when 'timers:yearly'        then case when public.promo_active() then 1240 else 2490 end
    when 'bundle:monthly'       then case when public.promo_active() then  199 else  399 end
    when 'bundle:yearly'        then case when public.promo_active() then 1990 else 3990 end
    when 'all:monthly'          then case when public.promo_active() then  249 else  499 end
    when 'all:yearly'           then case when public.promo_active() then 2490 else 4990 end
  end;
  if v_price is null then raise exception 'แพ็กเกจไม่ถูกต้อง'; end if;
  select points, plan_bundle_expires_at, plan_timers_expires_at into v_points, v_bundle, v_timers
    from public.profiles where id = v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points, 0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
    v_before := greatest(v_before, v_bundle);
    v_new := greatest(coalesce(v_before, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
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

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้:
--   md5 = 2639cbb1c458cd352b726558ed5f0de3 · anon_exec = false · auth_exec = true · promo_active = true (ยังอยู่ในช่วงโปร)
select p.proname as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       public.promo_active() as promo_active
  from pg_proc p
 where p.oid = 'public.buy_plan(text, text)'::regprocedure;
