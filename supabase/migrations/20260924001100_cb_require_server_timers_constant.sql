-- ============================================================
-- แก้ "Server must be active and assigned to the owner" ตอนสร้าง/จับเวลา Custom Boss
--
-- สาเหตุ: ตั้งแต่ 22 ก.ย. 2569 หน้าจับเวลาบอสเลิกแยกตามเซิร์ฟเวอร์ ฝั่งเว็บส่ง server_id เป็นค่าคงที่ '-'
-- เสมอ (TIMERS_SERVER ใน assets/app.js) และถอด foreign key ของ server_id ไปแล้ว
-- (20260922000800_drop_boss_timer_server_fk.sql) แต่ลืมฟังก์ชัน cb_require_server ที่ Custom Boss
-- ทุกตัวเรียกใช้ — มันยังเช็คว่า server_id ต้องเป็นเซิร์ฟเวอร์จริงที่เจ้าของเลือกไว้ จึงปฏิเสธ '-'
-- ผลคือ สร้างบอสใหม่ / เพิ่มเข้าตาราง / ลบออก / ตั้งเวลา / ปักหมุด / บันทึกการฆ่า ของ Custom Boss
-- ใช้ไม่ได้ทั้งหมด (แก้ไขบอสที่มีอยู่ยังได้ เพราะ update_custom_boss ไม่ได้ส่ง server)
--
-- แก้: ให้ '-' ผ่าน (เป็นค่ามาตรฐานของหน้าจับเวลาบอสตอนนี้) ค่าอื่นยังเช็คแบบเดิมทุกอย่าง
-- ฟังก์ชันเดิม (ดึงจากฐานข้อมูลจริง): returns void, plpgsql, security definer, search_path ''
-- ============================================================
begin;

create or replace function public.cb_require_server(h uuid, s text)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if s = '-' then
    return;
  end if;
  if s is null or not exists (select 1 from public.servers where id = s and active)
    or not exists (select 1 from public.profiles where id = h and s = any(servers)) then
    raise exception 'Server must be active and assigned to the owner';
  end if;
end $function$;

commit;
