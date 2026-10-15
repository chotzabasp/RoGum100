-- ============================================================
-- ย้อนกลับ 20261015000100_promo_20_percent.sql — ปิดโปรทันที
--   promo_active() → ฉบับวันจบ 12 ต.ค. 00:04:59 (= หมดแล้ว) · plan_price() → ฉบับ 20260929000800 (md5 6aa574dc…)
--   หลังรัน: ราคาปกติทุกแพ็ก (ตารางโปรใน plan_price กลับเป็นชุดเก่า แต่ promo_active() = false จึงไม่ถูกใช้)
-- ลำดับ: ราคาขึ้น → เอาหน้าเว็บที่ไม่มีโปรขึ้นก่อน แล้วค่อยรันไฟล์นี้
--   (รันก่อน = หน้าเว็บยังโชว์ราคาโปร → buy_plan ปฏิเสธ "ราคาเปลี่ยน" แล้วหน้าเว็บถือว่าโปรจบเอง ซื้อซ้ำได้ราคาปกติ)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.plan_price(text,text)');
  if v_md5 is distinct from '19c0b6c7d51a708cf757a88d6e7e037a' then
    raise exception 'plan_price ไม่ใช่ฉบับ 20261015000100 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

create or replace function public.promo_active()
returns boolean
language sql
stable
set search_path = ''
as $$ select now() <= timestamptz '2026-10-12 00:04:59+07' $$;

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
revoke all on function public.promo_active() from public, anon, authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว: promo_active_now = false และ ok = true
select public.promo_active() as promo_active_now,
       (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.plan_price(text,text)')) = '6aa574dc5821699d6363ef1e10aaf382'
         and public.plan_price('all', 'monthly') = 299 and public.plan_price('all', 'yearly') = 2990 as ok;
