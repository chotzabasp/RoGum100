-- ============================================================
-- สร้างถัง Storage ส่วนตัว 2 ถังคืน (ถูกลบทั้งถังโดยไม่ตั้งใจ ตอนล้างไฟล์ทดสอบ 24 ก.ย. 2569)
--   custom-boss-images : รูปบอส/แผนที่ ของบอสที่ผู้ใช้สร้างเอง (assets/custom-boss-api.js)
--                        ค่าตามที่หน้าเว็บตรวจ: PNG/JPEG/WebP/GIF ไม่เกิน 1 MiB
--   topup-slips        : สลิประบบเติมเงินแบบเก่า (ปิดการส่งแล้ว แต่หน้าแอดมินยังเปิดดูสลิปเก่าได้)
--                        ค่าตาม 20260921000100_security_hardening.sql: PNG/JPEG/WebP ไม่เกิน 5 MiB
-- ทั้งสองถังเป็นแบบส่วนตัว (public = false) — สิทธิ์เข้าถึงไฟล์มาจาก policy บน storage.objects
-- ที่ยังอยู่ครบ (policy ไม่ได้ผูกกับแถวของถัง ลบถังแล้ว policy ไม่หาย)
-- รันซ้ำได้ ไม่พัง (on conflict do nothing)
-- ============================================================
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('custom-boss-images', 'custom-boss-images', false, 1048576,
   array['image/png', 'image/jpeg', 'image/webp', 'image/gif']),
  ('topup-slips', 'topup-slips', false, 5242880,
   array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ถัง + policy ของ 2 ถังนี้
select 'bucket' as kind, id as name, public::text as detail
  from storage.buckets
 where id in ('custom-boss-images', 'topup-slips')
union all
select 'policy', policyname, cmd
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and (coalesce(qual, '') || coalesce(with_check, '')) ~ '(custom-boss-images|topup-slips)'
 order by 1, 2;
