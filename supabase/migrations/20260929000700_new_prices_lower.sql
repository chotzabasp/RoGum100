-- ============================================================
-- ราคาแพ็กเกจใหม่ (ผู้ใช้สั่ง 29 ก.ย. 2569) — ราคาปกติรายเดือน / รายปี (= รายเดือน × 10) · ช่วงโปรลด 50% ปัดเศษลง ทุกแพ็ก
--   1 in 1 ยอดนักฟาร์ม        99 /   990  → โปร  49 /   495   (เดิม 199 / 1,990 → โปร  99 /   990)
--   2 in 1 นักลงทุน/คลัง       99 /   990  → โปร  49 /   495   (เดิม 299 / 2,990 → โปร 149 / 1,490)
--   จับเวลาบอส               199 / 1,990  → โปร  99 /   995   (เดิม 249 / 2,490 → โปร 124 / 1,240)
--   3 in 1                   179 / 1,790  → โปร  89 /   895   (เดิม 399 / 3,990 → โปร 199 / 1,990)
--   4 in 1                   299 / 2,990  → โปร 149 / 1,495   (เดิม 499 / 4,990 → โปร 249 / 2,490)
-- plan_price(): เปลี่ยนเฉพาะตัวเลขในตาราง · promo_active() (วันจบโปร) / buy_plan / check_discount_code ไม่แตะ (อ่านราคาจากฟังก์ชันนี้อยู่แล้ว)
-- ต้องตรงกับ PRICING_PLANS ใน assets/app.js — รันไฟล์นี้ก่อนเอาหน้าเว็บราคาใหม่ขึ้น
--   (ถ้าหน้าเว็บใหม่ขึ้นก่อน ฐานข้อมูลยังหักราคาเดิมที่แพงกว่า → buy_plan ปฏิเสธ "ราคาเปลี่ยน" ทุกครั้ง)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000700_new_prices_lower_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '40b30fcb43e692467c356508465ed36d' then
    raise exception 'plan_price ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

-- ---------- ตารางราคากลาง — ต้องตรงกับ PRICING_PLANS ใน assets/app.js ----------
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

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (ฟังก์ชันตรงกับไฟล์นี้ · ราคาครบ 10 ช่องตามสถานะโปรตอนนี้ · สมาชิก/คนทั่วไปยังเรียกฟังก์ชันนี้ตรงๆ ไม่ได้)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '29d63bb4ab49e039d78717fc812bde79'
    and public.plan_price('farm', 'monthly')         = case when public.promo_active() then   49 else   99 end
    and public.plan_price('farm', 'yearly')          = case when public.promo_active() then  495 else  990 end
    and public.plan_price('accountItems', 'monthly') = case when public.promo_active() then   49 else   99 end
    and public.plan_price('accountItems', 'yearly')  = case when public.promo_active() then  495 else  990 end
    and public.plan_price('timers', 'monthly')       = case when public.promo_active() then   99 else  199 end
    and public.plan_price('timers', 'yearly')        = case when public.promo_active() then  995 else 1990 end
    and public.plan_price('bundle', 'monthly')       = case when public.promo_active() then   89 else  179 end
    and public.plan_price('bundle', 'yearly')        = case when public.promo_active() then  895 else 1790 end
    and public.plan_price('all', 'monthly')          = case when public.promo_active() then  149 else  299 end
    and public.plan_price('all', 'yearly')           = case when public.promo_active() then 1495 else 2990 end
    and not has_function_privilege('anon', 'public.plan_price(text,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.plan_price(text,text)', 'execute') as new_prices_ok;
