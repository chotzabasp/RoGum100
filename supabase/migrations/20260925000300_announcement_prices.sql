-- ============================================================
-- ปรับราคาลงประกาศ "รับ M" (แต้มต่อระยะเวลา) — ต้องตรงกับ ANNOUNCE_DURATION_OPTIONS ใน assets/app.js
--   5 นาที = 1 · 15 นาที = 2 · 30 นาที = 3 · 1 ชม. = 5 · 3 ชม. = 10
--   (เดิม: 10 นาที = 1 · 30 นาที = 2 · 1 ชม. = 3 · 3 ชม. = 6 — 10 นาทีเลิกใช้ ส่งมาจะถูกปฏิเสธ)
-- ส่วนอื่นคงเดิมทุกตัวอักษรจาก 20260925000200_post_announcement_require_facebook.sql (รันแล้ว)
-- ประกาศที่ลงไปแล้วไม่กระทบ · การแก้ไขประกาศเดิมไม่ผ่านฟังก์ชันนี้ ยังฟรีเหมือนเดิม
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
    when 300000 then 1     -- 5 นาที
    when 900000 then 2     -- 15 นาที
    when 1800000 then 3    -- 30 นาที
    when 3600000 then 5    -- 1 ชม.
    when 10800000 then 10  -- 3 ชม.
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

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ true ทั้งสองช่อง
select pg_get_functiondef('public.post_announcement'::regproc) like '%when 300000 then 1 %' as new_prices,
       pg_get_functiondef('public.post_announcement'::regproc) like '%ใส่ลิงก์ Facebook%' as has_facebook_check;
