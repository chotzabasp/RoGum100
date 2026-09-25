-- ============================================================
-- คืนฟังก์ชันซื้อแพ็กเกจ buy_plan เป็นเวอร์ชันล่าสุดของ repo (20260922000100_hardening_round2.sql)
--   พบ 26 ก.ย. 2569 จากการทดสอบบัญชี test: 1 in 1 / 2 in 1 ซื้อไม่ได้ ("แพ็กเกจไม่ถูกต้อง")
--   pg_get_functiondef ของฐานข้อมูลจริงเป็นเวอร์ชันเก่ายุคแรก: รู้จักแค่ bundle/timers, ราคาตายตัว 99/995,
--   ไม่เช็ค promo_active (หลังโปรหมดจะยังหัก 99), ไม่รองรับ farm/accountItems/all (4 in 1 ซื้อไม่ได้ด้วย),
--   ไม่บันทึก package_purchases (ประวัติการซื้อแพ็กเกจไม่ขึ้น)
-- เนื้อฟังก์ชันด้านล่างคัดลอกจาก hardening_round2 ตรงตัวอักษร ไม่ได้แก้ตรรกะ
--   ราคา: 3 in 1 / จับเวลาบอส โปร 99 · 990 ปกติ 199 · 1,990 | 4 in 1 โปร 175 · 1,750 ปกติ 349 · 3,490
--         1 in 1 = 99 · 2 in 1 = 149 (รายเดือนเท่านั้น ไม่มีโปร) — ตรงกับ PRICING_PLANS ใน assets/app.js
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
    when 'farm' then '1 in 1 — ยอดนักฟาม'
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

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ knows_farm = true, knows_all = true, uses_promo = true, logs_purchase = true,
--                                  anon_exec = false, auth_exec = true
select pg_get_functiondef('public.buy_plan(text,text)'::regprocedure) like '%''accountItems''%' as knows_farm,
       pg_get_functiondef('public.buy_plan(text,text)'::regprocedure) like '%p_plan_key = ''all''%' as knows_all,
       pg_get_functiondef('public.buy_plan(text,text)'::regprocedure) like '%promo_active()%' as uses_promo,
       pg_get_functiondef('public.buy_plan(text,text)'::regprocedure) like '%insert into public.package_purchases%' as logs_purchase,
       has_function_privilege('anon', 'public.buy_plan(text,text)', 'execute') as anon_exec,
       has_function_privilege('authenticated', 'public.buy_plan(text,text)', 'execute') as auth_exec;
