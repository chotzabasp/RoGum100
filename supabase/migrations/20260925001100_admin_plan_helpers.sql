-- ============================================================
-- แอดมิน = ไม่จำกัดทุกระบบ ให้ตรงกับหน้าเว็บ (hasBundlePlan/hasTimersPlan ใน app.js ถือว่า role admin ใช้ได้เต็ม)
--   เดิม has_timers_plan / has_bundle_plan เช็คแค่ legacy_unlimited หรือวันหมดอายุแพ็ก → บัญชีแอดมินที่สมัคร
--   หลังเปลี่ยนระบบแพ็กเกจ (ไม่ใช่บัญชีเก่า) ถูกฐานข้อมูลจำกัดจับเวลาบอส 1 ตัว / ถูกนับเป็นสมาชิกฟรีในปาร์ตี้
--   ทั้งที่หน้าเว็บให้กดได้ (เจอจากบัญชีทดสอบ ClaudeTest 25 ก.ย. 2569)
-- เขียนจาก pg_get_functiondef ของฐานข้อมูลจริง (25 ก.ย. 2569) — เพิ่มแค่ "หรือ role = admin" ที่เหลือเหมือนเดิมทุกอย่าง
-- has_farm_plan / has_trade_plan เรียก has_bundle_plan ต่ออยู่แล้ว จึงได้ผลตามไปเอง (ไม่ต้องแก้)
-- สิทธิ์เรียกใช้ (grant) คงเดิม: CREATE OR REPLACE ไม่ล้างสิทธิ์ที่ตั้งไว้ใน 20260925000600
-- ตัวเลขแดชบอร์ดไม่เปลี่ยน (admin_dashboard อ่านคอลัมน์วันหมดอายุตรง และไม่นับบัญชีแอดมินอยู่แล้ว)
-- ============================================================
begin;

CREATE OR REPLACE FUNCTION public.has_timers_plan(uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select legacy_unlimited or coalesce(role, '') = 'admin' or (plan_timers_expires_at > now())
                   from public.profiles where id = uid), false);
$function$;

CREATE OR REPLACE FUNCTION public.has_bundle_plan(uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select legacy_unlimited or coalesce(role, '') = 'admin' or (plan_bundle_expires_at > now())
                   from public.profiles where id = uid), false);
$function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ClaudeTest (แอดมิน) ต้องได้ true ทั้งสองช่อง · สิทธิ์: anon=false, authenticated=true
select public.has_timers_plan('90374010-de50-4138-8ce8-ac1d89a0e4b8') as timers_ok,
       public.has_bundle_plan('90374010-de50-4138-8ce8-ac1d89a0e4b8') as bundle_ok,
       has_function_privilege('anon', 'public.has_timers_plan(uuid)', 'execute') as anon_exec,
       has_function_privilege('authenticated', 'public.has_timers_plan(uuid)', 'execute') as auth_exec;
