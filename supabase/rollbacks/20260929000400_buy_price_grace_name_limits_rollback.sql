-- ย้อนกลับ migration 20260929000400_buy_price_grace_name_limits (รันเฉพาะเมื่อจำเป็น)
-- คืน buy_plan / update_my_profile / handle_new_user / set_my_facebook_url เป็นเวอร์ชันก่อนหน้า
-- คืน constraint ชื่อเป็น ≤100 และลบ profiles_facebook_url_len · ชื่อที่ถูกตัดเหลือ 15 ตัวแล้วคืนความยาวเดิมไม่ได้
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)');
  if v_md5 is distinct from '22373548f9efe1120fcacb5c696be310' then
    raise exception 'buy_plan ไม่ใช่เวอร์ชันของ 20260929000400 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.update_my_profile(text, date)');
  if v_md5 is distinct from '50104250e65fb38642efdd413d0f9c47' then
    raise exception 'update_my_profile ไม่ใช่เวอร์ชันของ 20260929000400 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.handle_new_user()');
  if v_md5 is distinct from 'bd1bd2c37a6dd23f62684fba1bc04abd' then
    raise exception 'handle_new_user ไม่ใช่เวอร์ชันของ 20260929000400 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.set_my_facebook_url(text)');
  if v_md5 is distinct from 'd99ffad4906a48368f6955940e8b903a' then
    raise exception 'set_my_facebook_url ไม่ใช่เวอร์ชันของ 20260929000400 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
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
  -- ราคาที่หักจริง (หลังส่วนลด) ต้องตรงกับที่กล่องยืนยันแสดง — เปิดกล่องค้างข้ามเวลาจบโปร / นาฬิกาเครื่องเพี้ยน
  -- = ไม่หักแต้ม ให้ดูราคาใหม่ก่อน · หน้าเว็บที่ไม่ส่งค่านี้ซื้อได้เหมือนเดิม
  if p_expected_price is not null and p_expected_price <> v_price then
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

CREATE OR REPLACE FUNCTION public.update_my_profile(p_display_name text, p_birth_date date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_display_name is null or length(trim(p_display_name)) < 1 or length(trim(p_display_name)) > 40 then
    raise exception 'ชื่อที่ใช้แสดงต้องยาว 1-40 ตัวอักษร';
  end if;
  update public.profiles
     set display_name = trim(p_display_name),
         birth_date = coalesce(birth_date, p_birth_date)
   where id = auth.uid();
end;$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_servers text[];
begin
  select coalesce(array_agg(distinct s.id), '{}') into v_servers
    from jsonb_array_elements_text(coalesce(new.raw_user_meta_data->'servers', '[]'::jsonb)) as x(id)
    join public.servers s on s.id = x.id;
  insert into public.profiles (id, display_name, username, birth_date, servers)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''), new.email),
    nullif(lower(trim(new.raw_user_meta_data->>'username')), ''),
    nullif(new.raw_user_meta_data->>'birth_date', '')::date,
    v_servers
  );
  return new;
end;$function$;

CREATE OR REPLACE FUNCTION public.set_my_facebook_url(p_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare
  v_url text := nullif(trim(p_url), '');
begin
  if v_url is not null and v_url !~* '^(https?://)?(www\.|m\.)?(facebook\.com|fb\.com)/.+' then
    raise exception 'ลิงก์ต้องขึ้นต้นด้วย facebook.com หรือ fb.com เท่านั้น';
  end if;
  update public.profiles set facebook_url = v_url where id = auth.uid();
end;$function$;

alter table public.profiles drop constraint profiles_display_name_safe;
alter table public.profiles add constraint profiles_display_name_safe
  check (display_name !~ '[<>]' and char_length(display_name) <= 100);
alter table public.profiles drop constraint profiles_facebook_url_len;

commit;

notify pgrst, 'reload schema';

select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '6df3f933be2335f3b35dd6dbeb37e47d'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.update_my_profile(text, date)')) = 'da1427bf5802e49e69938736996f522a'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.handle_new_user()')) = 'af0aaa61ff33fdb57a69e558d9e4759b'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.set_my_facebook_url(text)')) = 'e810a384fc035b744914ff117b8d747d'
    and (select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_display_name_safe') = 'CHECK (((display_name !~ ''[<>]''::text) AND (char_length(display_name) <= 100)))'
    and not exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_facebook_url_len') as restored_ok;
