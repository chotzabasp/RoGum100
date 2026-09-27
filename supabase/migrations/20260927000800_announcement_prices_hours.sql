-- ============================================================
-- ปรับราคาลงประกาศ "รับ M" ใหม่ (แต้มต่อระยะเวลา) — ต้องตรงกับ ANNOUNCE_DURATION_OPTIONS ใน assets/app.js
--   1 ชม. = 3 · 3 ชม. = 5 · 6 ชม. = 8 · 12 ชม. = 12
--   (เดิม 20260925000300: 5 นาที = 1 · 15 นาที = 2 · 30 นาที = 3 · 1 ชม. = 5 · 3 ชม. = 10
--    — 5/15/30 นาทีเลิกใช้ ส่งมาจะถูกปฏิเสธ "ระยะเวลาไม่ถูกต้อง")
-- ส่วนอื่นคงเดิมทุกตัวอักษรจาก 20260925000300_announcement_prices.sql (เนื้อฟังก์ชันที่รันอยู่ md5 f021c348…)
-- ประกาศที่ลงไปแล้วไม่กระทบ · แก้ไขประกาศเดิมไม่ผ่านฟังก์ชันนี้ ยังฟรี
-- 12 ชม. ยังอยู่ในเพดาน 24 ชม. ของ trigger announcements_guard (ไม่ต้องแก้)
-- create or replace คงสิทธิ์ (grant/revoke) เดิมของฟังก์ชันไว้
-- ============================================================
begin;

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: เนื้อฟังก์ชันที่รันอยู่ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare v_md5 text;
begin
  select md5(replace(p.prosrc, E'\r', '')) into v_md5
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'post_announcement';
  if v_md5 is distinct from 'f021c348dab79e456ce4f9d9f0ccd729' then
    raise exception 'post_announcement ในฐานข้อมูลไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้ ส่ง pg_get_functiondef มาให้ดูก่อน', v_md5;
  end if;
end $guard$;

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
    when 3600000 then 3    -- 1 ชม.
    when 10800000 then 5   -- 3 ชม.
    when 21600000 then 8   -- 6 ชม.
    when 43200000 then 12  -- 12 ชม.
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

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้: body_ok = true, has_12h = true, no_minutes = true,
-- has_facebook_check = true, anon_exec = false, auth_exec = true
select md5(replace(p.prosrc, E'\r', '')) = 'f7f03aa953088949f9bfb83acca1d6b6' as body_ok,
       p.prosrc like '%when 43200000 then 12%' as has_12h,
       p.prosrc not like '%when 300000 %' and p.prosrc not like '%when 1800000 %' as no_minutes,
       p.prosrc like '%ใส่ลิงก์ Facebook%' as has_facebook_check,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'post_announcement';
