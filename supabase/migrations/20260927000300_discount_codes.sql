-- ============================================================
-- โค้ดส่วนลด (%) ใช้ตอนซื้อแพ็กเกจ (2026-09-27)
--   แอดมินสร้างโค้ด reward_type = 'discount' (ลด 1–100%) ใช้ได้ทุกแพ็กเกจ (plan_key ว่าง) หรือระบุแพ็กเดียว
--   จำนวนคนใช้ / วันหมดอายุ / คนละบัญชีใช้ได้ครั้งเดียว ใช้กติกาเดิมของตาราง promo_codes
--   ลดจากราคาที่ต้องจ่ายตอนนั้น (ซ้อนกับโปรเปิดตัวได้) ราคาหลังลดปัดเศษลง เช่น 249 ลด 10% = 224
--   1) plan_price(): ตารางราคากลางที่เดียว (ย้ายออกมาจาก buy_plan ตัวเลขเดิมทุกตัว) — buy_plan / check_discount_code ใช้ร่วมกัน
--   2) discount_code_check(): ตรวจโค้ด (ใช้ภายในเท่านั้น สมาชิกเรียกตรงไม่ได้)
--   3) check_discount_code(): ให้กล่องยืนยันการซื้อตรวจโค้ดและแสดงราคาหลังลด (ยังไม่ใช้สิทธิ์ ยังไม่หักแต้ม)
--   4) buy_plan(p_plan_key, p_cycle, p_code default null): รับโค้ดได้ — ตรวจ/ล็อกโค้ด หักแต้มราคาหลังลด
--      บันทึกการใช้โค้ดเฉพาะตอนซื้อสำเร็จ · เว็บรุ่นเก่าที่ส่งแค่ 2 ค่ายังซื้อได้ตามปกติ
--   5) redeem_promo_code(): โค้ดส่วนลดกรอกในหน้าตั้งค่าไม่ได้ (แจ้งให้ใช้ตอนซื้อ) — กันระบบแจกแต้มจากโค้ดส่วนลด
--   6) list_my_promo_redemptions() + admin_dashboard(): ส่งเปอร์เซ็นต์ส่วนลด/แพ็กที่ใช้ได้ ให้หน้าประวัติ/แดชบอร์ดแสดง
--   7) package_purchases: + promo_code, discount_points (ประวัติการซื้อโชว์โค้ดและส่วนลดที่ใช้)
-- เนื้อฟังก์ชันเดิมคัดลอกตรงตัวจาก repo (ตรวจ md5 ตรงกับฐานข้อมูลจริง) แก้เฉพาะจุดที่ระบุ
-- มีตัวกันในไฟล์: ถ้าฟังก์ชันในฐานข้อมูลไม่ตรงกับ repo จะหยุดทันที ไม่มีอะไรถูกแก้
-- ============================================================
begin;

do $guard$
declare v text; bad text := '';
begin
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.buy_plan(text, text)'::regprocedure;
  if v is distinct from '2639cbb1c458cd352b726558ed5f0de3' then bad := bad || ' buy_plan=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.redeem_promo_code(text)'::regprocedure;
  if v is distinct from 'b88589af889cc6e0264e7ae66d5cd8ee' then bad := bad || ' redeem_promo_code=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.list_my_promo_redemptions()'::regprocedure;
  if v is distinct from '14b749e6cb2ea63f1016d970985179d1' then bad := bad || ' list_my_promo_redemptions=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.admin_dashboard(integer)'::regprocedure;
  if v is distinct from '01bf085e59f5a97d2eaf06303ab7cf85' then bad := bad || ' admin_dashboard=' || coalesce(v, '-'); end if;
  if bad <> '' then raise exception 'หยุด: ฟังก์ชันในฐานข้อมูลไม่ตรงกับ repo —% · ไม่มีอะไรถูกแก้', bad; end if;
end
$guard$;

-- ---------- ตาราง: โค้ดประเภทส่วนลด ----------
alter table public.promo_codes add column if not exists discount_percent integer;
alter table public.promo_codes drop constraint if exists promo_codes_discount_percent_check;
alter table public.promo_codes add constraint promo_codes_discount_percent_check check (discount_percent is null or discount_percent between 1 and 100);
alter table public.promo_codes drop constraint if exists promo_codes_reward_type_check;
alter table public.promo_codes add constraint promo_codes_reward_type_check check (reward_type in ('points', 'plan_days', 'discount'));
alter table public.promo_codes drop constraint if exists promo_codes_reward_shape_check;
alter table public.promo_codes add constraint promo_codes_reward_shape_check check (
  (reward_type = 'points' and points is not null and plan_days is null and discount_percent is null) or
  (reward_type = 'plan_days' and plan_days is not null and points is null and discount_percent is null) or
  (reward_type = 'discount' and discount_percent is not null and points is null and plan_days is null)
);
alter table public.promo_codes drop constraint if exists promo_codes_plan_key_check;
alter table public.promo_codes add constraint promo_codes_plan_key_check check (
  (reward_type = 'points' and plan_key is null) or
  (reward_type in ('plan_days', 'discount') and (plan_key is null or plan_key in ('all', 'bundle', 'timers', 'farm', 'accountItems')))
);

-- ประวัติการซื้อ: โค้ดส่วนลดที่ใช้ + จำนวนแต้มที่ลดไป (ซื้อแบบไม่ใช้โค้ด = ว่าง)
alter table public.package_purchases add column if not exists promo_code text;
alter table public.package_purchases add column if not exists discount_points integer;

-- ---------- 1) ตารางราคากลาง — ต้องตรงกับ PRICING_PLANS ใน assets/app.js ----------
create or replace function public.plan_price(p_plan_key text, p_cycle text)
returns integer
language sql
stable
set search_path to 'public'
as $function$
  select case p_plan_key || ':' || p_cycle
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
  end
$function$;

revoke all on function public.plan_price(text, text) from public, anon, authenticated;

-- ---------- 2) ตรวจโค้ดส่วนลด (ภายใน) — p_lock = true ล็อกแถวโค้ดจนจบธุรกรรม กันแย่งใช้สิทธิ์สุดท้ายพร้อมกัน ----------
create or replace function public.discount_code_check(p_code text, p_plan_key text, p_uid uuid, p_lock boolean)
returns public.promo_codes
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
begin
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;
  if p_lock then
    select * into v_row from public.promo_codes where code = v_code for update;
  else
    select * into v_row from public.promo_codes where code = v_code;
  end if;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.reward_type <> 'discount' then
    raise exception 'โค้ดนี้ไม่ใช่โค้ดส่วนลด — ใช้ที่ช่อง "โค้ดโปรโมชัน" หน้าตั้งค่า';
  end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = p_uid) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;
  if v_row.plan_key is not null and v_row.plan_key <> p_plan_key then
    raise exception 'โค้ดนี้ใช้ได้กับแพ็กเกจ % เท่านั้น', case v_row.plan_key
      when 'all' then '4 in 1' when 'bundle' then '3 in 1' when 'timers' then 'จับเวลาบอส'
      when 'accountItems' then '2 in 1' else '1 in 1' end;
  end if;
  return v_row;
end;
$function$;

revoke all on function public.discount_code_check(text, text, uuid, boolean) from public, anon, authenticated;

-- ---------- 3) ตรวจโค้ดก่อนกดยืนยัน (ยังไม่ใช้สิทธิ์ ยังไม่หักแต้ม) ----------
create or replace function public.check_discount_code(p_code text, p_plan_key text, p_cycle text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.promo_codes%rowtype;
  v_price integer;
  v_after integer;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  v_price := public.plan_price(p_plan_key, p_cycle);
  if v_price is null then raise exception 'แพ็กเกจไม่ถูกต้อง'; end if;
  v_row := public.discount_code_check(p_code, p_plan_key, auth.uid(), false);
  v_after := floor(v_price * (100 - v_row.discount_percent) / 100.0)::integer;
  return jsonb_build_object('code', v_row.code, 'percent', v_row.discount_percent,
                            'price_before', v_price, 'discount', v_price - v_after, 'price_after', v_after);
end;
$function$;

revoke all on function public.check_discount_code(text, text, text) from public, anon;
grant execute on function public.check_discount_code(text, text, text) to authenticated;

-- ---------- 4) buy_plan รับโค้ดส่วนลดได้ (ลบตัวเดิม 2 ค่าออก กันเรียกแล้วชนกัน 2 ตัว) ----------
drop function public.buy_plan(text, text);

create function public.buy_plan(p_plan_key text, p_cycle text, p_code text default null)
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

revoke all on function public.buy_plan(text, text, text) from public, anon;
grant execute on function public.buy_plan(text, text, text) to authenticated;

-- ---------- 5) redeem_promo_code: ไม่รับโค้ดส่วนลด ----------
create or replace function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
  v_plan text;
  v_name text;
  v_bundle timestamptz;
  v_timers timestamptz;
  v_before timestamptz;
  v_base timestamptz;
  v_new timestamptz;
  v_points_after int;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;

  select * into v_row from public.promo_codes where code = v_code for update;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.reward_type = 'discount' then raise exception 'โค้ดนี้เป็นโค้ดส่วนลด ใช้ตอนกดซื้อแพ็กเกจ (กรอกในกล่องยืนยันการซื้อ)'; end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = auth.uid()) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;

  insert into public.promo_code_redemptions (code, user_id) values (v_code, auth.uid());
  update public.promo_codes set used_count = used_count + 1 where code = v_code;

  if v_row.reward_type = 'plan_days' then
    v_plan := coalesce(v_row.plan_key, 'all');
    v_name := case v_plan
      when 'bundle' then '3 in 1'
      when 'timers' then 'จับเวลาบอส'
      when 'farm' then '1 in 1'
      when 'accountItems' then '2 in 1'
      else '4 in 1' end;
    select plan_bundle_expires_at, plan_timers_expires_at into v_bundle, v_timers
      from public.profiles where id = auth.uid() for update;

    if v_plan = 'bundle' then
      v_new := greatest(coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_bundle_expires_at = v_new where id = auth.uid();
    elsif v_plan = 'timers' then
      v_new := greatest(coalesce(v_timers, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_timers_expires_at = v_new where id = auth.uid();
    elsif v_plan in ('farm', 'accountItems') then
      select expires_at into v_before from public.package_feature_entitlements
        where user_id = auth.uid() and feature = v_plan;
      v_new := greatest(coalesce(v_before, now()), coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      insert into public.package_feature_entitlements (user_id, feature, expires_at) values (auth.uid(), v_plan, v_new)
        on conflict (user_id, feature) do update set expires_at = excluded.expires_at;
    else
      v_base := greatest(coalesce(v_bundle, now()), coalesce(v_timers, now()), now());
      v_new := v_base + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_bundle_expires_at = v_new, plan_timers_expires_at = v_new where id = auth.uid();
    end if;

    select points into v_points_after from public.profiles where id = auth.uid();
    insert into public.points_ledger (user_id, delta, balance_after, reason, actor, detail)
    values (auth.uid(), 0, v_points_after, 'promo_code', auth.uid(),
      'กรอกรหัสโปรโมชั่น '||v_code||' — แพ็กเกจ '||v_name||' จำนวน '||v_row.plan_days||' วัน');

    return jsonb_build_object('reward_type', 'plan_days', 'plan_key', v_plan, 'plan_days', v_row.plan_days, 'expires_at', v_new);
  else
    perform set_config('app.points_ledger_detail', 'กรอกรหัสโปรโมชั่น '||v_code, true);
    update public.profiles set points = points + v_row.points where id = auth.uid();
    return jsonb_build_object('reward_type', 'points', 'points', v_row.points);
  end if;
end;
$function$;

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;

-- ---------- 6) ประวัติการใช้โค้ดของสมาชิก + แดชบอร์ดแอดมิน ----------
drop function public.list_my_promo_redemptions();
create function public.list_my_promo_redemptions()
returns table (
  code text,
  reward_type text,
  points integer,
  plan_days integer,
  redeemed_at timestamptz,
  plan_key text,
  discount_percent integer
)
language sql
security definer
set search_path to 'public'
stable
as $function$
  select pc.code, pc.reward_type, pc.points, pc.plan_days, r.redeemed_at,
         case when pc.reward_type = 'plan_days' then coalesce(pc.plan_key, 'all')
              when pc.reward_type = 'discount' then pc.plan_key end,
         pc.discount_percent
  from public.promo_code_redemptions r
  join public.promo_codes pc on pc.code = r.code
  where r.user_id = auth.uid()
  order by r.redeemed_at desc;
$function$;

revoke all on function public.list_my_promo_redemptions() from public, anon;
grant execute on function public.list_my_promo_redemptions() to authenticated;

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

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 7 แถว:
--   buy_plan(text,text,text) 66fc0af55492cd8dec0a444db436bf65 anon=false auth=true (ต้องไม่มี buy_plan(text,text) เหลือ)
--   plan_price 40b30fcb43e692467c356508465ed36d anon=false auth=false
--   discount_code_check a8008419a2c6c598d37d9a43888b7b4a anon=false auth=false
--   check_discount_code 7501a8ed1d6fe2467a4a0963a6f3c2e4 anon=false auth=true
--   redeem_promo_code 336945b83ac777012af5a071f079327f anon=false auth=true
--   list_my_promo_redemptions a967fa0d738dc525b9fb95e53daa158a anon=false auth=true
--   admin_dashboard cdc91f8fc7c591b72ea9675c6f417fbe anon=false auth=true
select p.oid::regprocedure as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('buy_plan', 'plan_price', 'discount_code_check', 'check_discount_code',
                     'redeem_promo_code', 'list_my_promo_redemptions', 'admin_dashboard')
 order by 1;

-- ต้องได้ price_4in1_month = 249, price_1in1_year = 990 (ช่วงโปร) และ new_columns = 3
select public.plan_price('all', 'monthly') as price_4in1_month,
       public.plan_price('farm', 'yearly') as price_1in1_year,
       (select count(*) from information_schema.columns
         where table_schema = 'public'
           and ((table_name = 'promo_codes' and column_name = 'discount_percent')
             or (table_name = 'package_purchases' and column_name in ('promo_code', 'discount_points')))) as new_columns;
