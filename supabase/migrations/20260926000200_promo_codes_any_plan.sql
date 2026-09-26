-- ============================================================
-- โค้ดโปรโมชันแจกแพ็กเกจได้ทุกแพ็ก (ยกเว้นฟรี): 4 in 1 / 3 in 1 / จับเวลาบอส / 2 in 1 / 1 in 1
--   เดิมโค้ดแบบ plan_days แจกได้แค่ 4 in 1 — เพิ่มคอลัมน์ plan_key บอกว่าแจกแพ็กไหน
--   โค้ด plan_days ที่มีอยู่ถูกตั้งเป็น 'all' (4 in 1) ทำงานเหมือนเดิม · plan_key ว่าง = 4 in 1 (กันหน้าแอดมินรุ่นเก่าใน cache)
-- ต่ออายุแบบเดียวกับการซื้อด้วยแต้ม: ต่อจากวันหมดอายุเดิมถ้ายังไม่หมด ไม่ทับ
--   all    = 3 in 1 + จับเวลาบอส ตั้งให้เท่ากัน (ตรรกะเดิมทุกตัวอักษร)
--   bundle = plan_bundle_expires_at · timers = plan_timers_expires_at
--   farm / accountItems = package_feature_entitlements นับต่อจาก 3 in 1 ถ้ายังเหลือ
-- เขียนจาก redeem_promo_code / list_my_promo_redemptions ของฐานข้อมูลจริง (ลายนิ้วมือตรงกับ
--   20260923000200_promo_code_ledger_detail.sql / 20260923000300_list_my_promo_redemptions.sql ตรวจ 26 ก.ย. 2569)
-- ============================================================
begin;

alter table public.promo_codes add column if not exists plan_key text;
update public.promo_codes set plan_key = 'all' where reward_type = 'plan_days' and plan_key is null;
alter table public.promo_codes drop constraint if exists promo_codes_plan_key_check;
alter table public.promo_codes add constraint promo_codes_plan_key_check check (
  (reward_type = 'points' and plan_key is null) or
  (reward_type = 'plan_days' and (plan_key is null or plan_key in ('all', 'bundle', 'timers', 'farm', 'accountItems')))
);

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

-- ประวัติการใช้โค้ดของสมาชิก: เพิ่ม plan_key (เปลี่ยนคอลัมน์ผลลัพธ์ต้อง drop แล้วสร้างใหม่ — ตั้งสิทธิ์เดิมกลับ)
drop function if exists public.list_my_promo_redemptions();
create function public.list_my_promo_redemptions()
returns table (
  code text,
  reward_type text,
  points integer,
  plan_days integer,
  redeemed_at timestamptz,
  plan_key text
)
language sql
security definer
set search_path to 'public'
stable
as $function$
  select pc.code, pc.reward_type, pc.points, pc.plan_days, r.redeemed_at,
         case when pc.reward_type = 'plan_days' then coalesce(pc.plan_key, 'all') end
  from public.promo_code_redemptions r
  join public.promo_codes pc on pc.code = r.code
  where r.user_id = auth.uid()
  order by r.redeemed_at desc;
$function$;

revoke all on function public.list_my_promo_redemptions() from public, anon;
grant execute on function public.list_my_promo_redemptions() to authenticated;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ has_plan_key = true, old_codes_all = true, redeem_any_plan = true,
--   list_has_plan_key = true, redeem_anon = false, redeem_auth = true, list_anon = false, list_auth = true
select exists(select 1 from information_schema.columns where table_schema = 'public' and table_name = 'promo_codes' and column_name = 'plan_key') as has_plan_key,
       not exists(select 1 from public.promo_codes where reward_type = 'plan_days' and plan_key is null) as old_codes_all,
       pg_get_functiondef('public.redeem_promo_code(text)'::regprocedure) like '%package_feature_entitlements%' as redeem_any_plan,
       pg_get_function_result('public.list_my_promo_redemptions()'::regprocedure) like '%plan_key%' as list_has_plan_key,
       has_function_privilege('anon', 'public.redeem_promo_code(text)', 'execute') as redeem_anon,
       has_function_privilege('authenticated', 'public.redeem_promo_code(text)', 'execute') as redeem_auth,
       has_function_privilege('anon', 'public.list_my_promo_redemptions()', 'execute') as list_anon,
       has_function_privilege('authenticated', 'public.list_my_promo_redemptions()', 'execute') as list_auth;
