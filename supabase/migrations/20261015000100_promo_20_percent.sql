-- ============================================================
-- โปรโมชันลด 20% ทุกแพ็กเกจ ทั้งรายเดือนและรายปี (ผู้ใช้สั่ง 15 ต.ค. 2569 — 3 วัน จบสิ้นวันอาทิตย์ 18 ต.ค.)
-- เริ่มทันทีที่รันไฟล์นี้ · หน้าเว็บจบโปร 18 ต.ค. 23:59:59 (PROMO_END_AT ใน assets/app.js)
--   ฐานข้อมูลจบช้ากว่าหน้าเว็บ 5 นาที (19 ต.ค. 00:04:59 เวลาไทย) กันนาฬิกาเครื่องผู้ใช้เร็วแล้วโดนหักแพงกว่าที่เห็น (หลักเดิม)
-- 1) promo_active(): วันจบโปรใหม่ (เดิมจบ 12 ต.ค. 00:04:59)
-- 2) plan_price(): ราคาโปร = ราคาปกติลด 20% ปัดเศษลง ทั้งรายเดือนและรายปี (ราคาปกติไม่เปลี่ยน)
--      รายเดือน ปกติ → โปร : 1 in 1 99 → 79 · 2 in 1 99 → 79 · จับเวลาบอส 199 → 159 · 3 in 1 179 → 143 · 4 in 1 299 → 239
--      รายปี   ปกติ → โปร : 990 → 792 · 990 → 792 · 1,990 → 1,592 · 1,790 → 1,432 · 2,990 → 2,392
-- buy_plan / check_discount_code ไม่แก้ — อ่านราคาจาก plan_price อยู่แล้ว · ตัวจำกัดซื้อรายเดือนล่วงหน้าช่วงโปร (≤ 30 วัน)
--   ใน buy_plan ใช้ promo_active() → ทำงานตลอดช่วงโปรนี้เหมือนโปรที่แล้ว · โค้ดส่วนลดลดต่อจากราคาโปรได้เหมือนเดิม
-- ต้องตรงกับ PRICING_PLANS (promoMonthly / promoYearly) + PROMO_END_AT ใน assets/app.js
-- ลำดับ: ราคาลง → รันไฟล์นี้ก่อน แล้วค่อยเอาหน้าเว็บใหม่ขึ้น (ระหว่างนั้นหน้าเว็บเก่าโชว์ราคาปกติ ฐานข้อมูลหักราคาโปรที่ถูกกว่า — ซื้อได้)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261015000100_promo_20_percent_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '6aa574dc5821699d6363ef1e10aaf382' then
    raise exception 'plan_price ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  if pg_get_functiondef('public.promo_active()'::regprocedure) not like '%2026-10-12 00:04:59+07%' then
    raise exception 'promo_active ไม่ใช่ฉบับวันจบ 12 ต.ค. 00:04:59 — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) วันจบโปรใหม่ ----------
create or replace function public.promo_active()
returns boolean
language sql
stable
set search_path = ''
as $$ select now() <= timestamptz '2026-10-19 00:04:59+07' $$;

-- ---------- 2) ตารางราคากลาง — ต้องตรงกับ PRICING_PLANS ใน assets/app.js ----------
create or replace function public.plan_price(p_plan_key text, p_cycle text)
returns integer
language sql
stable
set search_path to 'public'
as $function$
  select case p_plan_key || ':' || p_cycle
    when 'farm:monthly'         then case when public.promo_active() then   79 else   99 end
    when 'farm:yearly'          then case when public.promo_active() then  792 else  990 end
    when 'accountItems:monthly' then case when public.promo_active() then   79 else   99 end
    when 'accountItems:yearly'  then case when public.promo_active() then  792 else  990 end
    when 'timers:monthly'       then case when public.promo_active() then  159 else  199 end
    when 'timers:yearly'        then case when public.promo_active() then 1592 else 1990 end
    when 'bundle:monthly'       then case when public.promo_active() then  143 else  179 end
    when 'bundle:yearly'        then case when public.promo_active() then 1432 else 1790 end
    when 'all:monthly'          then case when public.promo_active() then  239 else  299 end
    when 'all:yearly'           then case when public.promo_active() then 2392 else 2990 end
  end
$function$;

revoke all on function public.plan_price(text, text) from public, anon, authenticated;
revoke all on function public.promo_active() from public, anon, authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true ทุกช่อง
-- (ตอนนี้อยู่ในช่วงโปร · ราคาโปรครบ 10 แบบ · ฟังก์ชันตรงกับไฟล์นี้ · buy_plan ยังเป็นฉบับเดิม)
select
  public.promo_active() as promo_active_now,
  public.plan_price('farm', 'monthly') = 79 and public.plan_price('farm', 'yearly') = 792
    and public.plan_price('accountItems', 'monthly') = 79 and public.plan_price('accountItems', 'yearly') = 792
    and public.plan_price('timers', 'monthly') = 159 and public.plan_price('timers', 'yearly') = 1592
    and public.plan_price('bundle', 'monthly') = 143 and public.plan_price('bundle', 'yearly') = 1432
    and public.plan_price('all', 'monthly') = 239 and public.plan_price('all', 'yearly') = 2392 as promo_prices_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '19c0b6c7d51a708cf757a88d6e7e037a'
    and pg_get_functiondef('public.promo_active()'::regprocedure) like '%2026-10-19 00:04:59+07%'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.buy_plan(text, text, text, integer)')) = '5d9788d6326d3e64e2823038d2fe7b6b'
    and not has_function_privilege('authenticated', 'public.plan_price(text,text)', 'execute') as functions_ok;
