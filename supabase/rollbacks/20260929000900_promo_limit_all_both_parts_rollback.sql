-- ============================================================
-- ย้อนกลับ 20260929000900_promo_limit_all_both_parts.sql — buy_plan กลับเป็นฉบับ 20260929000800
--   (4 in 1 ดูส่วนที่หมดก่อน · md5 7611a9262acdaeea6d35fb94029edb43)
-- รันคู่กับการคืน promoMonthlyLockBase ใน assets/app.js (ตั้ง ?v= ของ app.js เป็นค่าใหม่เสมอ ห้ามใช้ค่าเดิมซ้ำ)
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (ราคาไม่เปลี่ยน)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)');
  if v_md5 is distinct from '5d9788d6326d3e64e2823038d2fe7b6b' then
    raise exception 'buy_plan ไม่ใช่ฉบับ 20260929000900 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

create or replace function public.buy_plan(p_plan_key text, p_cycle text, p_code text default null, p_expected_price integer default null)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text; v_base timestamptz;
  v_promo public.promo_codes%rowtype; v_code text; v_full_price integer; v_discount integer := 0;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  -- ราคาจากตารางราคากลาง plan_price (ช่วงโปรลด 50% เฉพาะรายเดือน อยู่ในนั้นแล้ว)
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
  -- ช่วงโปร รายเดือนซื้อล่วงหน้าได้สูงสุดราว 2 เดือน (ผู้ใช้สั่ง 29 ก.ย. 2569 ตอนยกเลิกโปรรายปี — กันกดรายเดือนราคาโปรซ้อนแทนรายปี)
  -- วันที่จะต่อจาก (คิดแบบเดียวกับด้านล่าง) ต้องเหลือไม่เกิน 30 วัน · รายปี / หลังจบโปร ซื้อซ้อนได้ไม่จำกัด
  -- ต้องตรงกับ promoMonthlyLockedUntil ใน assets/app.js
  if p_cycle = 'monthly' and public.promo_active() then
    if p_plan_key in ('farm','accountItems') then
      select expires_at into v_base from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
      v_base := greatest(v_base, v_bundle);
    elsif p_plan_key = 'bundle' then
      v_base := v_bundle;
    elsif p_plan_key = 'timers' then
      v_base := v_timers;
    else
      v_base := least(coalesce(v_bundle, now()), coalesce(v_timers, now()));
    end if;
    if v_base > now() + interval '30 days' then
      raise exception 'ช่วงโปรโมชันซื้อรายเดือนล่วงหน้าได้สูงสุด 2 เดือน — ซื้อเพิ่มได้เมื่อแพ็กนี้เหลือไม่เกิน 30 วัน หรือหลังโปรจบ';
    end if;
  end if;
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
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '7611a9262acdaeea6d35fb94029edb43'
    and (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buy_plan') = 1
    and has_function_privilege('authenticated', 'public.buy_plan(text, text, text, integer)', 'execute')
    and not has_function_privilege('anon', 'public.buy_plan(text, text, text, integer)', 'execute') as promo_limit_all_restored_ok;
