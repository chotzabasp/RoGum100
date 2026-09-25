-- ============================================================
-- ประกาศรับ M: ห้ามแก้ลิงก์ Facebook ของประกาศหลังลงแล้ว
--   ตอนลงประกาศ post_announcement คัดลอกลิงก์ที่ตรวจแล้ว (facebook.com / fb.com เท่านั้น) จากโปรไฟล์มาใส่
--   แต่ผู้ใช้ยังมีสิทธิ์ UPDATE ตาราง announcements (แก้เซิร์ฟเวอร์/ราคาของประกาศตัวเอง) → แก้ facebook_url
--   ตรงๆ จาก console เป็นเว็บใดก็ได้ (เช่นเว็บหลอกเอารหัส) แล้วทุกคนที่กดชื่อบนแถบประกาศจะถูกพาไปเว็บนั้น
--   หน้าเว็บแก้แค่ server_id กับ buy อยู่แล้ว → ล็อกลิงก์ไม่กระทบการใช้งานปกติ
-- เขียนจาก pg_get_functiondef ของฐานข้อมูลจริง (25 ก.ย. 2569) — เพิ่มบรรทัดเดียว new.facebook_url := old.facebook_url
-- สิทธิ์เรียกใช้คงเดิม (CREATE OR REPLACE ไม่ล้าง revoke ที่ตั้งไว้ใน 20260925000600) · trigger เดิมใช้ฟังก์ชันนี้ต่อเอง
-- ============================================================
begin;

CREATE OR REPLACE FUNCTION public.announcements_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  min_exp timestamptz := now() + interval '1 minute';
  max_exp timestamptz := now() + interval '24 hours';
begin
  if tg_op = 'INSERT' then
    new.user_id    := auth.uid();
    select coalesce(p.display_name, 'สมาชิก') into new.user_name
      from public.profiles p where p.id = auth.uid();
    if new.user_name is null then new.user_name := 'สมาชิก'; end if;
    new.created_at := now();
    if new.expires_at is null or new.expires_at < min_exp then new.expires_at := min_exp; end if;
    if new.expires_at > max_exp then new.expires_at := max_exp; end if;
  else
    -- แก้ไขประกาศ = เปลี่ยนได้แค่เซิร์ฟเวอร์กับราคา นาฬิกานับถอยหลังห้ามรีเซ็ต ลิงก์ Facebook ห้ามเปลี่ยน
    new.id           := old.id;
    new.user_id      := old.user_id;
    new.user_name    := old.user_name;
    new.created_at   := old.created_at;
    new.expires_at   := old.expires_at;
    new.facebook_url := old.facebook_url;
  end if;
  return new;
end; $function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ locks_facebook = true, trigger_on = true, anon_exec = false, auth_exec = false
select pg_get_functiondef('public.announcements_guard()'::regprocedure) like '%new.facebook_url := old.facebook_url%' as locks_facebook,
       exists(select 1 from pg_trigger where tgname = 'announcements_guard_trg' and not tgisinternal) as trigger_on,
       has_function_privilege('anon', 'public.announcements_guard()', 'execute') as anon_exec,
       has_function_privilege('authenticated', 'public.announcements_guard()', 'execute') as auth_exec;
