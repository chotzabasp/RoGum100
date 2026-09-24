-- ============================================================
-- คืนสิทธิ์ (policy) ของถัง custom-boss-images + topup-slips
-- ตอนลบถังทั้งถังจากหน้า Dashboard (24 ก.ย. 2569) policy ของถังหายไปด้วย
-- สร้างถังคืนแล้วใน 20260924000900_recreate_private_buckets.sql — ไฟล์นี้คืน policy ให้ตรงกับของเดิม
-- (คัดจากรายการ policy จริงที่ดึงจากฐานข้อมูลก่อนหน้านี้ คำต่อคำ)
--
--   custom_boss_images_read          SELECT  authenticated  เจ้าของบอส หรือสมาชิกปาร์ตี้ของเจ้าของ
--   custom_boss_images_upload        INSERT  authenticated  เจ้าของบอส บัญชียังไม่หมดอายุ บอสไม่ถูกเก็บ ไม่ได้อยู่ในปาร์ตี้คนอื่น
--   topup_slips_select_own_or_admin  SELECT  public         เจ้าของสลิป หรือแอดมิน
--
-- ไม่คืน topup_slips_insert_own โดยตั้งใจ — ถูกปิดไปแล้วใน 20260921000100_security_hardening.sql
-- (เลิกระบบส่งสลิป ใช้ QR PromptPay แทน)
-- ใช้ฟังก์ชันเดิมที่ยังอยู่: public.cb_image_access(text, boolean), public.is_admin()
-- รันซ้ำได้ (drop if exists ก่อน create)
-- ============================================================
begin;

drop policy if exists custom_boss_images_read on storage.objects;
create policy custom_boss_images_read on storage.objects
  for select to authenticated
  using ((bucket_id = 'custom-boss-images'::text) and public.cb_image_access(name, false));

drop policy if exists custom_boss_images_upload on storage.objects;
create policy custom_boss_images_upload on storage.objects
  for insert to authenticated
  with check ((bucket_id = 'custom-boss-images'::text) and public.cb_image_access(name, true));

drop policy if exists topup_slips_select_own_or_admin on storage.objects;
create policy topup_slips_select_own_or_admin on storage.objects
  for select to public
  using ((bucket_id = 'topup-slips'::text)
         and (((storage.foldername(name))[1] = (auth.uid())::text) or public.is_admin()));

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ policy 3 แถว
select policyname, cmd, roles::text as roles
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and (coalesce(qual, '') || coalesce(with_check, '')) ~ '(custom-boss-images|topup-slips)'
 order by policyname;
