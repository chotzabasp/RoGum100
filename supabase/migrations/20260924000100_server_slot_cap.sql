-- ============================================================
-- เพิ่มเพดานโควต้าช่องเซิร์ฟเวอร์สูงสุด 12 ช่องใน buy_server_slot
-- เดิมไม่มีเพดาน — กดซื้อจากหน้าตั้งค่า (หรือเรียก RPC ตรง) เกิน 12 ช่องได้ เสียแต้มฟรี
-- เพราะหน้าเว็บแสดงการ์ดเรทได้สูงสุด 12 ใบ (MAX_RATE_CHIP_SLOTS ใน index.html)
--
-- ส่วนอื่นเหมือนเดิมทุกอย่าง (30 แต้ม/ช่อง, ต้องไม่หมดอายุ, แต้มต้องพอ)
-- ไม่แตะโควต้าของบัญชีที่มีเกิน 12 อยู่แล้ว (ถ้ามี) — แค่ซื้อเพิ่มไม่ได้อีก
-- ============================================================
create or replace function public.buy_server_slot()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  cost int := 30;
  max_quota int := 12;
  cur_quota int;
  cur_points int;
  new_quota int;
begin
  if not public.is_active() then
    raise exception 'บัญชีหมดอายุ ต่ออายุก่อนจึงจะซื้อโควต้าเพิ่มได้';
  end if;

  select server_quota, points into cur_quota, cur_points
    from public.profiles where id = auth.uid() for update;
  if not found then
    raise exception 'ไม่พบโปรไฟล์';
  end if;

  if coalesce(cur_quota, 1) >= max_quota then
    raise exception 'มีช่องเซิร์ฟเวอร์ครบ % ช่องแล้ว (สูงสุด)', max_quota;
  end if;
  if coalesce(cur_points, 0) < cost then
    raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', cost;
  end if;

  update public.profiles
     set points = points - cost,
         server_quota = server_quota + 1
   where id = auth.uid()
   returning server_quota into new_quota;

  return new_quota;
end; $function$;
