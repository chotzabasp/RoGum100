-- ============================================================
-- ปิดสิทธิ์เรียกฟังก์ชันที่ไม่ควรถูกเรียกตรง (จาก Supabase Security Advisor 25 ก.ย. 2569)
--
-- 1) has_bundle_plan / has_timers_plan — คนที่ไม่ได้ล็อกอิน (anon) เรียกได้ → ถามได้ว่าบัญชีไหนซื้อแพ็กแล้ว
--    ปิดจาก anon · ยังเปิดให้ผู้ใช้ที่ล็อกอิน (authenticated) เพราะ RLS policy ของ kills / kill_items
--    เรียกใช้ด้วยสิทธิ์ผู้ใช้ (ปิดแล้วการบันทึกการฆ่า/ไอเทมจะพัง) · service_role คงไว้เผื่อเบื้องหลัง
--    (ต้อง grant กลับชัดๆ เพราะเดิมได้สิทธิ์ผ่าน PUBLIC ที่เรา revoke ออก)
-- 2) ฟังก์ชัน trigger 4 ตัว (ทำงานอัตโนมัติตอนมีการเขียนตาราง) — ไม่มีใครต้องเรียกตรง ปิดทั้งหมด
--    Postgres เช็คสิทธิ์ EXECUTE ของฟังก์ชัน trigger เฉพาะตอนสร้าง trigger ไม่ใช่ตอนทำงาน
--    → trigger ยังทำงานเหมือนเดิมทุกอย่าง (สมัครสมาชิก / ลงประกาศ / เพิ่มบอส / ชื่อไอเทม)
--
-- ฟังก์ชันอื่นที่ Advisor เตือนว่า "ผู้ใช้ที่ล็อกอินเรียกได้" เป็นแบบนั้นโดยตั้งใจ (ปุ่มต่างๆ ในเว็บ)
-- และตรวจแล้วว่าเช็คสิทธิ์ข้างในครบ (แอดมิน = เช็ค role, แต้ม/บอส = เช็ค auth.uid() หรือผ่าน cb_lock_boss)
-- email_for_login / username_available / log_events เปิดให้ anon โดยตั้งใจ (ล็อกอิน / สมัคร / สถิติ)
-- รันซ้ำได้
-- ============================================================
begin;

revoke all on function public.has_bundle_plan(uuid) from public, anon;
revoke all on function public.has_timers_plan(uuid) from public, anon;
grant execute on function public.has_bundle_plan(uuid) to authenticated, service_role;
grant execute on function public.has_timers_plan(uuid) to authenticated, service_role;

revoke all on function public.announcements_guard() from public, anon, authenticated;
revoke all on function public.seed_default_boss() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.sync_item_names() from public, anon, authenticated;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): has_* → anon=false, auth=true · trigger 4 ตัว → false ทั้งคู่
select p.proname,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('has_bundle_plan', 'has_timers_plan', 'announcements_guard', 'seed_default_boss', 'handle_new_user', 'sync_item_names')
 order by p.proname;
