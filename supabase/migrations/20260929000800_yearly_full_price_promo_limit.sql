-- ============================================================
-- ยกเลิกโปรลด 50% เฉพาะรายปี + จำกัดซื้อรายเดือนล่วงหน้าช่วงโปร (ผู้ใช้สั่ง 29 ก.ย. 2569)
-- 1) plan_price(): รายปีราคาเต็มตลอด (ช่วงโปรก็ไม่ลด) · รายเดือนช่วงโปรยังลด 50% เหมือนเดิม
--      รายปี  1 in 1 990 · 2 in 1 990 · จับเวลาบอส 1,990 · 3 in 1 1,790 · 4 in 1 2,990   (เดิมช่วงโปร 495 / 495 / 995 / 895 / 1,495)
--      รายเดือน ไม่เปลี่ยน: ช่วงโปร 49 / 49 / 99 / 89 / 149 · ปกติ 99 / 99 / 199 / 179 / 299
-- 2) buy_plan(): ช่วงโปร ซื้อรายเดือนได้เมื่อแพ็กนั้นเหลือไม่เกิน 30 วัน (ถือล่วงหน้าได้สูงสุดราว 2 เดือน)
--      กันกดรายเดือนราคาโปรซ้อน 12 ครั้งแทนรายปี · รายปี / หลังจบโปร ซื้อซ้อนได้ไม่จำกัดเหมือนเดิม
--      เพิ่มเฉพาะตัวจำกัด + ตัวแปร v_base + แก้คอมเมนต์ราคา 1 บรรทัด ส่วนอื่นคงเดิมทุกตัวอักษร (เนื้อเดิมจาก 20260929000400)
-- ลำดับ: ราคารายปีขึ้น → เอาหน้าเว็บใหม่ขึ้นก่อน (ผู้ใช้พิมพ์ "เชฟ") แล้วค่อยรันไฟล์นี้
--   (ถ้ารันก่อน หน้าเว็บเดิมโชว์รายปีราคาโปร → buy_plan ปฏิเสธ "ราคาเปลี่ยน" และหน้าเว็บเข้าใจผิดว่าโปรจบแล้ว)
-- ต้องตรงกับ PRICING_PLANS / promoMonthlyLockedUntil ใน assets/app.js
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000800_yearly_full_price_promo_limit_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '29d63bb4ab49e039d78717fc812bde79' then
    raise exception 'plan_price ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)');
  if v_md5 is distinct from '22373548f9efe1120fcacb5c696be310' then
    raise exception 'buy_plan ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
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
    when 'farm:yearly'          then  990
    when 'accountItems:monthly' then case when public.promo_active() then   49 else   99 end
    when 'accountItems:yearly'  then  990
    when 'timers:monthly'       then case when public.promo_active() then   99 else  199 end
    when 'timers:yearly'        then 1990
    when 'bundle:monthly'       then case when public.promo_active() then   89 else  179 end
    when 'bundle:yearly'        then 1790
    when 'all:monthly'          then case when public.promo_active() then  149 else  299 end
    when 'all:yearly'           then 2990
  end
$function$;

revoke all on function public.plan_price(text, text) from public, anon, authenticated;

-- ---------- 2) buy_plan: จำกัดซื้อรายเดือนล่วงหน้าช่วงโปร ----------
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
-- (ฟังก์ชันทั้งสองตรงกับไฟล์นี้ · buy_plan มีตัวเดียว · ราคาครบ 10 ช่องตามสถานะโปรตอนนี้ · สิทธิ์เรียกฟังก์ชันเหมือนเดิม)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '6aa574dc5821699d6363ef1e10aaf382'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '7611a9262acdaeea6d35fb94029edb43'
    and (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buy_plan') = 1
    and public.plan_price('farm', 'monthly')         = case when public.promo_active() then   49 else   99 end
    and public.plan_price('farm', 'yearly')          =  990
    and public.plan_price('accountItems', 'monthly') = case when public.promo_active() then   49 else   99 end
    and public.plan_price('accountItems', 'yearly')  =  990
    and public.plan_price('timers', 'monthly')       = case when public.promo_active() then   99 else  199 end
    and public.plan_price('timers', 'yearly')        = 1990
    and public.plan_price('bundle', 'monthly')       = case when public.promo_active() then   89 else  179 end
    and public.plan_price('bundle', 'yearly')        = 1790
    and public.plan_price('all', 'monthly')          = case when public.promo_active() then  149 else  299 end
    and public.plan_price('all', 'yearly')           = 2990
    and not has_function_privilege('anon', 'public.plan_price(text,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.plan_price(text,text)', 'execute')
    and has_function_privilege('authenticated', 'public.buy_plan(text, text, text, integer)', 'execute')
    and not has_function_privilege('anon', 'public.buy_plan(text, text, text, integer)', 'execute') as yearly_full_price_ok;
