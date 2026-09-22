-- ============================================================
-- เพิ่มโค้ดโปรโมชันประเภทที่ 2: แจกแพ็กเกจ "4 in 1" เป็นจำนวนวัน (เช่น ทดลอง 3 วัน) แทนการแจกแต้มตรงๆ
-- ตรวจ source จริงของ has_bundle_plan/has_farm_plan/has_trade_plan/has_timers_plan/buy_plan แล้วก่อนแก้
-- (has_farm_plan และ has_trade_plan เป็นจริงอัตโนมัติเมื่อ has_bundle_plan เป็นจริง) — "4 in 1" ในระบบนี้คือ
-- การตั้ง plan_bundle_expires_at กับ plan_timers_expires_at ให้เท่ากัน จึงตั้งแค่ 2 คอลัมน์นี้ก็ครบทั้ง
-- 4 ระบบจริง ไม่ต้องแตะ package_feature_entitlements หรือ buy_plan เลย ใช้ตรรกะ "ต่อจากวันเดิมถ้ายังไม่
-- หมดอายุ ไม่ทับ" แบบเดียวกับที่ buy_plan ใช้อยู่แล้ว
--
-- โค้ดแบบเดิม (แจกแต้ม) ยังทำงานเหมือนเดิมทุกอย่าง เพิ่มคอลัมน์ reward_type เพื่อแยก 2 แบบเท่านั้น
-- ============================================================
begin;

alter table public.promo_codes add column if not exists reward_type text not null default 'points';
alter table public.promo_codes drop constraint if exists promo_codes_reward_type_check;
alter table public.promo_codes add constraint promo_codes_reward_type_check check (reward_type in ('points','plan_days'));

alter table public.promo_codes alter column points drop not null;
alter table public.promo_codes drop constraint if exists promo_codes_points_check;
alter table public.promo_codes add constraint promo_codes_points_check check (points is null or points > 0);

alter table public.promo_codes add column if not exists plan_days integer;
alter table public.promo_codes drop constraint if exists promo_codes_plan_days_check;
alter table public.promo_codes add constraint promo_codes_plan_days_check check (plan_days is null or plan_days > 0);

alter table public.promo_codes drop constraint if exists promo_codes_reward_shape_check;
alter table public.promo_codes add constraint promo_codes_reward_shape_check check (
  (reward_type = 'points' and points is not null and plan_days is null) or
  (reward_type = 'plan_days' and plan_days is not null and points is null)
);

drop function if exists public.redeem_promo_code(text);

create function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
  v_base timestamptz;
  v_new timestamptz;
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
    select greatest(coalesce(plan_bundle_expires_at, now()), coalesce(plan_timers_expires_at, now()), now())
      into v_base from public.profiles where id = auth.uid();
    v_new := v_base + (v_row.plan_days || ' days')::interval;
    update public.profiles set plan_bundle_expires_at = v_new, plan_timers_expires_at = v_new where id = auth.uid();
    return jsonb_build_object('reward_type', 'plan_days', 'plan_days', v_row.plan_days, 'expires_at', v_new);
  else
    update public.profiles set points = points + v_row.points where id = auth.uid();
    return jsonb_build_object('reward_type', 'points', 'points', v_row.points);
  end if;
end;
$function$;

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;

commit;
