-- ============================================================
-- ตรวจรอบสอง (29 ก.ย. 2569) — ผู้ใช้สั่ง "ทำเลย"
-- 1) buy_plan: ตัวเช็คราคาจาก 20260929000100 ปฏิเสธทุกครั้งที่ราคาไม่ตรง แม้ราคาจริงถูกกว่าที่เห็น
--    → ช่วง 00:00–00:05 ของ 12 ต.ค. (promo_active() ผ่อนผัน 5 นาทีหลังหน้าเว็บจบโปร) ซื้อไม่ได้ทุกคน
--    แก้: ปฏิเสธเฉพาะราคาจริงแพงกว่าที่เห็น (ถูกกว่า = ซื้อได้ในราคาที่ถูกกว่า) ส่วนอื่นคงเดิมทุกตัวอักษร
-- 2) ชื่อที่แสดง / ลิงก์ Facebook ให้ฐานข้อมูลกันเท่ากับหน้าเว็บ (ชื่อ ≤15 ตัว ห้าม < > · ลิงก์ ≤200 ตัว)
--    update_my_profile 1–40 → 1–15 + ข้อความไทยเมื่อมี < > · handle_new_user ตัด < > / ยาวเกิน 15 ออก
--    และไม่ใช้อีเมลเป็นชื่ออีก (ไม่ใส่ชื่อ = username → "สมาชิก") · set_my_facebook_url ≤200
--    constraint profiles_display_name_safe ≤100 → ≤15 (ชื่อเดิมที่ยาวเกิน 15 ถูกตัดเหลือ 15 ตัว — ตอนนี้มีแต่บัญชีทดสอบ)
--    constraint ใหม่ profiles_facebook_url_len ≤200 (ถ้ามีลิงก์เดิมยาวเกิน → หยุด ไม่ตัดให้ เพราะตัดแล้วลิงก์เสีย)
-- เนื้อฟังก์ชันเดิม: buy_plan จาก 20260929000100 · อีก 3 ตัวจาก pg_get_functiondef ของฐานข้อมูลจริง (md5 ตรง)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000400_buy_price_grace_name_limits_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
  v_def text;
  v_n int;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)');
  if v_md5 is distinct from '6df3f933be2335f3b35dd6dbeb37e47d' then
    raise exception 'buy_plan ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.update_my_profile(text, date)');
  if v_md5 is distinct from 'da1427bf5802e49e69938736996f522a' then
    raise exception 'update_my_profile ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.handle_new_user()');
  if v_md5 is distinct from 'af0aaa61ff33fdb57a69e558d9e4759b' then
    raise exception 'handle_new_user ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.set_my_facebook_url(text)');
  if v_md5 is distinct from 'e810a384fc035b744914ff117b8d747d' then
    raise exception 'set_my_facebook_url ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select pg_get_constraintdef(oid) into v_def from pg_constraint
   where conrelid = 'public.profiles'::regclass and conname = 'profiles_display_name_safe';
  if v_def is distinct from 'CHECK (((display_name !~ ''[<>]''::text) AND (char_length(display_name) <= 100)))' then
    raise exception 'constraint profiles_display_name_safe ไม่ตรงกับที่คาดไว้ (%) — ไม่มีอะไรถูกแก้', coalesce(v_def, 'ไม่พบ');
  end if;
  if exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_facebook_url_len') then
    raise exception 'มี profiles_facebook_url_len อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
  select count(*) into v_n from public.profiles where char_length(facebook_url) > 200;
  if v_n > 0 then
    raise exception 'มีลิงก์ Facebook ยาวเกิน 200 ตัวอักษรอยู่ % บัญชี — ไม่มีอะไรถูกแก้ (ส่งข้อความนี้ให้ Claude)', v_n;
  end if;
end;
$guard$;

-- ---------- 1) buy_plan: ปฏิเสธเฉพาะราคาจริงแพงกว่าที่เห็น ----------
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

-- ---------- 2) ชื่อที่แสดง ≤15 ตัว / ลิงก์ Facebook ≤200 ตัว ----------
CREATE OR REPLACE FUNCTION public.update_my_profile(p_display_name text, p_birth_date date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  -- ตรงกับหน้าเว็บ (maxlength 15 · ห้าม < >) และ constraint profiles_display_name_safe
  if p_display_name is null or length(trim(p_display_name)) < 1 or length(trim(p_display_name)) > 15 then
    raise exception 'ชื่อที่ใช้แสดงต้องยาว 1-15 ตัวอักษร';
  end if;
  if trim(p_display_name) ~ '[<>]' then
    raise exception 'ชื่อที่ใช้แสดงห้ามมีเครื่องหมาย < หรือ >';
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
AS $function$declare v_servers text[]; v_username text; v_name text;
begin
  select coalesce(array_agg(distinct s.id), '{}') into v_servers
    from jsonb_array_elements_text(coalesce(new.raw_user_meta_data->'servers', '[]'::jsonb)) as x(id)
    join public.servers s on s.id = x.id;
  v_username := nullif(lower(trim(new.raw_user_meta_data->>'username')), '');
  -- ชื่อที่แสดง: ตัด < > ออก ยาวไม่เกิน 15 ตัว (ตรงกับหน้าเว็บ + constraint) · ไม่ใส่ชื่อ = username → "สมาชิก"
  -- (เดิมใช้อีเมลเป็นชื่อ → คนในปาร์ตี้/คนดูประกาศเห็นอีเมล)
  v_name := btrim(left(btrim(translate(coalesce(new.raw_user_meta_data->>'display_name', ''), '<>', '')), 15));
  if v_name = '' then v_name := coalesce(btrim(left(v_username, 15)), 'สมาชิก'); end if;
  insert into public.profiles (id, display_name, username, birth_date, servers)
  values (
    new.id,
    v_name,
    v_username,
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
  -- ตรงกับหน้าเว็บ (maxlength 200) และ constraint profiles_facebook_url_len
  if v_url is not null and char_length(v_url) > 200 then
    raise exception 'ลิงก์ Facebook ยาวเกิน 200 ตัวอักษร';
  end if;
  if v_url is not null and v_url !~* '^(https?://)?(www\.|m\.)?(facebook\.com|fb\.com)/.+' then
    raise exception 'ลิงก์ต้องขึ้นต้นด้วย facebook.com หรือ fb.com เท่านั้น';
  end if;
  update public.profiles set facebook_url = v_url where id = auth.uid();
end;$function$;

-- ชื่อเดิมที่ยาวเกิน 15 ตัว (ถ้ามี) ตัดเหลือ 15 ตัวก่อนเปลี่ยน constraint
update public.profiles set display_name = btrim(left(display_name, 15)) where char_length(display_name) > 15;

alter table public.profiles drop constraint profiles_display_name_safe;
alter table public.profiles add constraint profiles_display_name_safe
  check (display_name !~ '[<>]' and char_length(display_name) <= 15);
alter table public.profiles add constraint profiles_facebook_url_len
  check (facebook_url is null or char_length(facebook_url) <= 200);

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true ทั้ง 6 ช่อง
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '22373548f9efe1120fcacb5c696be310'
    and (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buy_plan') = 1 as buy_plan_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.update_my_profile(text, date)')) = '50104250e65fb38642efdd413d0f9c47' as update_my_profile_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.handle_new_user()')) = 'bd1bd2c37a6dd23f62684fba1bc04abd'
    and exists (select 1 from pg_trigger where tgrelid = 'auth.users'::regclass and tgname = 'on_auth_user_created'
                 and tgfoid = 'public.handle_new_user()'::regprocedure and tgenabled <> 'D') as handle_new_user_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.set_my_facebook_url(text)')) = 'd99ffad4906a48368f6955940e8b903a' as set_my_facebook_url_ok,
  (select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_display_name_safe') = 'CHECK (((display_name !~ ''[<>]''::text) AND (char_length(display_name) <= 15)))'
    and (select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_facebook_url_len') = 'CHECK (((facebook_url IS NULL) OR (char_length(facebook_url) <= 200)))'
    and not exists (select 1 from public.profiles where char_length(display_name) > 15) as constraints_ok,
  has_function_privilege('authenticated', 'public.buy_plan(text, text, text, integer)', 'execute')
    and not has_function_privilege('anon', 'public.buy_plan(text, text, text, integer)', 'execute')
    and has_function_privilege('authenticated', 'public.update_my_profile(text, date)', 'execute')
    and not has_function_privilege('anon', 'public.update_my_profile(text, date)', 'execute')
    and has_function_privilege('authenticated', 'public.set_my_facebook_url(text)', 'execute')
    and not has_function_privilege('anon', 'public.set_my_facebook_url(text)', 'execute')
    and not has_function_privilege('authenticated', 'public.handle_new_user()', 'execute')
    and not has_function_privilege('anon', 'public.handle_new_user()', 'execute') as grants_ok;
