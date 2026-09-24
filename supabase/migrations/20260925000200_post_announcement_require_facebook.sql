-- ============================================================
-- ลงประกาศ "รับ M" ต้องมีลิงก์ Facebook ในโปรไฟล์ก่อน (profiles.facebook_url)
-- หน้าเว็บกันไว้แล้วด้วย popup — ฟังก์ชันนี้กันอีกชั้นสำหรับคนที่เรียก RPC ตรงโดยไม่ผ่านหน้าเว็บ
-- เช็คก่อนหักแต้ม → ถ้ายังไม่มีลิงก์ แต้มไม่ถูกหัก และประกาศไม่ถูกสร้าง
-- ส่วนอื่นคงเดิมคำต่อคำจาก pg_get_functiondef ของฐานข้อมูลจริง (25 ก.ย. 2569)
-- การแก้ไขประกาศเดิม (update ตรงที่ตาราง announcements) ไม่ได้ผ่านฟังก์ชันนี้ จึงไม่ถูกบังคับ
-- create or replace คงสิทธิ์ (grant/revoke) เดิมของฟังก์ชันไว้
-- ============================================================
begin;

CREATE OR REPLACE FUNCTION public.post_announcement(p_server_id text, p_buy numeric, p_duration_ms bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_cost int;
begin
  if not public.is_active() then
    raise exception 'บัญชีหมดอายุ ต่ออายุก่อนลงประกาศ';
  end if;
  if coalesce(btrim((select facebook_url from public.profiles where id = auth.uid())), '') = '' then
    raise exception 'กรุณาใส่ลิงก์ Facebook ที่หน้า "ตั้งค่า" ก่อนลงประกาศ';
  end if;
  v_cost := case p_duration_ms
    when 600000 then 1     -- 10 นาที
    when 1800000 then 2    -- 30 นาที
    when 3600000 then 3    -- 1 ชม.
    when 10800000 then 6   -- 3 ชม.
    else null
  end;
  if v_cost is null then
    raise exception 'ระยะเวลาไม่ถูกต้อง';
  end if;
  update public.profiles set points = points - v_cost where id = auth.uid() and points >= v_cost;
  if not found then
    raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_cost;
  end if;
  insert into public.announcements (server_id, buy, expires_at, facebook_url)
  values (p_server_id, p_buy, now() + (p_duration_ms || ' milliseconds')::interval,
          (select facebook_url from public.profiles where id = auth.uid()));
end; $function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ true
select pg_get_functiondef('public.post_announcement'::regproc) like '%ใส่ลิงก์ Facebook%' as has_facebook_check;
