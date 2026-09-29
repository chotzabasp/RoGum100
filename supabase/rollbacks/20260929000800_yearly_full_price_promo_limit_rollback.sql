-- ============================================================
-- ย้อนกลับ 20260929000800_yearly_full_price_promo_limit.sql
--   plan_price → ฉบับ 20260929000700 (รายปีช่วงโปรลด 50%: 495 / 495 / 995 / 895 / 1,495) md5 29d63bb4…
--   buy_plan   → ฉบับ 20260929000400 (ไม่มีตัวจำกัดซื้อรายเดือนล่วงหน้า) md5 22373548…
-- รันคู่กับการคืน PRICING_PLANS / ตัวจำกัดใน assets/app.js (git revert คอมมิตนี้)
-- ลำดับ: ย้อนกลับ = รายปีกลับไปถูกลง → รันไฟล์นี้ก่อน แล้วค่อยเอาหน้าเว็บฉบับเดิมขึ้น
--   (หน้าเว็บใหม่ที่ยังค้างอยู่โชว์รายปีราคาเต็ม ฐานข้อมูลหักถูกกว่า = ซื้อได้ ไม่มีใครโดนหักเกิน)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '6aa574dc5821699d6363ef1e10aaf382' then
    raise exception 'plan_price ไม่ใช่ฉบับรายปีราคาเต็ม (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)');
  if v_md5 is distinct from '7611a9262acdaeea6d35fb94029edb43' then
    raise exception 'buy_plan ไม่ใช่ฉบับที่มีตัวจำกัดซื้อล่วงหน้า (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

-- ---------- 1) ตารางราคากลาง — ต้องตรงกับ PRICING_PLANS ใน assets/app.js ----------
create or replace function public.plan_price(p_plan_key text, p_cycle text)
returns integer
language sql
stable
set search_path to 'public'
as $function$
  select case p_plan_key || ':' || p_cycle
    when 'farm:monthly'         then case when public.promo_active() then   49 else   99 end
    when 'farm:yearly'          then case when public.promo_active() then  495 else  990 end
    when 'accountItems:monthly' then case when public.promo_active() then   49 else   99 end
    when 'accountItems:yearly'  then case when public.promo_active() then  495 else  990 end
    when 'timers:monthly'       then case when public.promo_active() then   99 else  199 end
    when 'timers:yearly'        then case when public.promo_active() then  995 else 1990 end
    when 'bundle:monthly'       then case when public.promo_active() then   89 else  179 end
    when 'bundle:yearly'        then case when public.promo_active() then  895 else 1790 end
    when 'all:monthly'          then case when public.promo_active() then  149 else  299 end
    when 'all:yearly'           then case when public.promo_active() then 1495 else 2990 end
  end
$function$;

revoke all on function public.plan_price(text, text) from public, anon, authenticated;

-- ---------- 2) buy_plan: ฉบับก่อนมีตัวจำกัดซื้อรายเดือนล่วงหน้า ----------
create or replace function public.buy_plan(p_plan_key text, p_cycle text, p_code text default null, p_expected_price integer default null)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text;
  v_promo public.promo_codes%rowtype; v_code text; v_full_price integer; v_discount integer := 0;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  -- ราคาจากตารางราคากลาง plan_price (ช่วงโปรลด 50% อยู่ในนั้นแล้ว)
  v_price := public.plan_price(p_plan_key, p_cycle);
  if v_price is null then raise exception 'แพ็กเกจไม่ถูกต้อง'; end if;
  -- โค้ดส่วนลด (%): ลดจากราคาที่ต้องจ่ายตอนนั้น (ซ้อนกับโปรได้) ราคาหลังลดปัดเศษลง
  -- ตรวจและล็อกแถวโค้ดก่อนหักแต้ม — นับว่าใช้โค้ดแล้วเฉพาะตอนซื้อสำเร็จ (อยู่ในธุรกรรมเดียวกัน)
  if nullif(btrim(coalesce(p_code, '')), '') is not null then
    v_promo := public.discount_code_check(p_code, p_plan_key, v_uid, true);
    v_code := v_promo.code;
    v_full_price := v_price;
    v_price := floor(v_full_price * (100 - v_promo.discount_percent) / 100.0)::integer;
    v_discount := v_full_price - v_price;
  end if;
  -- ราคาที่หักจริง (หลังส่วนลด) ต้องไม่แพงกว่าที่กล่องยืนยันแสดง — เปิดกล่องค้างข้ามเวลาจบโปร / นาฬิกาเครื่องเพี้ยน
  -- = ไม่หักแต้ม ให้ดูราคาใหม่ก่อน · ถูกกว่าที่เห็น = ซื้อได้ (ช่วงผ่อนผันโปร 5 นาทีหลังเที่ยงคืนของ promo_active())
  -- หน้าเว็บที่ไม่ส่งค่านี้ซื้อได้เหมือนเดิม
  if p_expected_price is not null and v_price > p_expected_price then
    raise exception 'ราคาเปลี่ยนแล้ว (ตอนนี้ % แต้ม) กรุณาตรวจสอบอีกครั้ง', v_price;
  end if;
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
  v_name := case p_plan_key
    when 'farm' then '1 in 1 — ยอดนักฟาร์ม'
    when 'accountItems' then '2 in 1'
    when 'bundle' then '3 in 1'
    when 'timers' then 'จับเวลาบอส'
    else '4 in 1' end;
  if v_code is not null then
    -- บันทึกการใช้โค้ด + ข้อความในประวัติแต้ม (trigger log_points_change อ่านค่านี้ตอนหักแต้มบรรทัดถัดไป)
    insert into public.promo_code_redemptions (code, user_id) values (v_code, v_uid);
    update public.promo_codes set used_count = used_count + 1 where code = v_code;
    perform set_config('app.points_ledger_detail',
      'ซื้อแพ็กเกจ ' || v_name || ' · ใช้โค้ดส่วนลด ' || v_code || ' ลด ' || v_promo.discount_percent || '%', true);
  end if;
  update public.profiles set points = points - v_price where id = v_uid;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id, plan_key, plan_name, cycle, points_spent, days_added, expires_before, expires_after, promo_code, discount_points)
    values (v_uid, p_plan_key, v_name, p_cycle, v_price, v_days, v_before, v_new, v_code, nullif(v_discount, 0));
  end if;
  return v_new;
end;
$function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '29d63bb4ab49e039d78717fc812bde79'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '22373548f9efe1120fcacb5c696be310'
    and (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buy_plan') = 1
    and not has_function_privilege('anon', 'public.plan_price(text,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.plan_price(text,text)', 'execute')
    and has_function_privilege('authenticated', 'public.buy_plan(text, text, text, integer)', 'execute')
    and not has_function_privilege('anon', 'public.buy_plan(text, text, text, integer)', 'execute') as yearly_promo_restored_ok;
