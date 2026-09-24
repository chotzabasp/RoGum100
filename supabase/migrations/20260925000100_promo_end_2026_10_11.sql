-- ============================================================
-- เลื่อนวันสิ้นสุดโปรโมชัน: จาก 31 ต.ค. 2569 เป็น 11 ต.ค. 2569 (วันที่ 11 ยังได้ราคาโปรทั้งวัน)
--   หน้าเว็บ: PROMO_END_AT = '2026-10-11T23:59:59+07:00' (assets/app.js)
--   ฐานข้อมูล: promo_active() หมดช้ากว่าหน้าเว็บ 5 นาที (12 ต.ค. 00:04:59 เวลาไทย)
--   กันนาฬิกาเครื่องผู้ใช้เร็วกว่าเซิร์ฟเวอร์ แล้วถูกหักแพงกว่าราคาที่เห็นบนหน้าจอ (หลักเดิมจาก
--   20260921000100_security_hardening.sql) · buy_plan ใช้ promo_active() ตัดสินราคาจริงอยู่แล้ว ไม่ต้องแก้
-- ถ้าจะเลื่อนวันโปรอีก ต้องแก้ทั้ง promo_active() นี้ และ PROMO_END_AT ใน assets/app.js ให้ตรงกัน
-- create or replace คงสิทธิ์ (grant/revoke) เดิมของฟังก์ชันไว้
-- ============================================================
begin;

create or replace function public.promo_active()
returns boolean
language sql
stable
set search_path = ''
as $$ select now() <= timestamptz '2026-10-12 00:04:59+07' $$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ตอนนี้ยังอยู่ในช่วงโปร ต้องได้ promo_active = true
select public.promo_active() as promo_active,
       pg_get_functiondef('public.promo_active()'::regprocedure) like '%2026-10-12 00:04:59+07%' as new_end_date;
