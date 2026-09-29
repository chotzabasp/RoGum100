-- ============================================================
-- ย้อนกลับ 20260929000700_new_prices_lower.sql — คืนราคาชุด 27 ก.ย. 2569 (plan_price เดิมทุกตัวอักษร md5 40b30fcb…)
--   1 in 1 199 / 1,990 (โปร 99 / 990) · 2 in 1 299 / 2,990 (โปร 149 / 1,490) · จับเวลาบอส 249 / 2,490 (โปร 124 / 1,240)
--   3 in 1 399 / 3,990 (โปร 199 / 1,990) · 4 in 1 499 / 4,990 (โปร 249 / 2,490)
-- รันคู่กับการคืน PRICING_PLANS ใน assets/app.js เป็นราคาชุดเดิม (git revert คอมมิตราคาใหม่)
-- ลำดับ (กลับด้านกับตอนลดราคา): เอาหน้าเว็บราคาเดิมขึ้นก่อน แล้วค่อยรันไฟล์นี้
--   (ถ้ารันไฟล์นี้ก่อน หน้าเว็บราคาใหม่ส่งราคาต่ำกว่าที่ฐานข้อมูลหัก → buy_plan ปฏิเสธ "ราคาเปลี่ยน" และหน้าเว็บเข้าใจผิดว่าโปรจบแล้ว)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '29d63bb4ab49e039d78717fc812bde79' then
    raise exception 'plan_price ไม่ใช่ฉบับราคาใหม่ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
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

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '40b30fcb43e692467c356508465ed36d'
    and not has_function_privilege('anon', 'public.plan_price(text,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.plan_price(text,text)', 'execute') as old_prices_restored_ok;
