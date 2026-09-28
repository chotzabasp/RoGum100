-- ============================================================
-- ข้อมูลบอส: Osiris เกิดที่ moc_pryd04 (ผู้ใช้ยืนยัน 29 ก.ย. 2569)
-- การ์ดเคยบอกแผนที่ moc_pryd06 แต่รูปแผนที่เป็น moc_pryd04.gif อยู่แล้ว → แก้เฉพาะ bosses.map_location ของ id 'osiris' 1 แถว
-- ไม่แตะรูป / เวลาเกิด / ไอเทม / บอสตัวอื่น
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000200_osiris_map_location_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_loc text;
  v_img text;
begin
  select map_location, map_image_url into v_loc, v_img from public.bosses where id = 'osiris';
  if not found then
    raise exception 'ไม่พบบอส osiris — ไม่มีอะไรถูกแก้';
  end if;
  if v_loc is distinct from 'moc_pryd06' or coalesce(v_img, '') not like '%/moc_pryd04.gif' then
    raise exception 'ข้อมูล Osiris ไม่ตรงกับที่คาดไว้ (แผนที่ %, รูป %) — ไม่มีอะไรถูกแก้', coalesce(v_loc, 'ว่าง'), coalesce(v_img, 'ว่าง');
  end if;
end;
$guard$;

update public.bosses set map_location = 'moc_pryd04' where id = 'osiris' and map_location = 'moc_pryd06';

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select map_location = 'moc_pryd04' and map_image_url like '%/moc_pryd04.gif' as osiris_ok
from public.bosses where id = 'osiris';
