-- ============================================================
-- ให้เจ้าของลบรูป Custom Boss ในโฟลเดอร์ของตัวเองได้ (ถัง custom-boss-images)
--
-- เดิมถังนี้มีแค่สิทธิ์อ่าน (custom_boss_images_read) กับอัปโหลด (custom_boss_images_upload)
-- ไม่มีสิทธิ์ลบเลย รูปเก่าจึงค้างในถังตลอดเมื่อ: เปลี่ยนรูปบอส / กด "ลบออก" บอส / อัปโหลดซ้ำในหน้าต่างแก้ไข
-- หน้าเว็บ (assets/app.js + assets/custom-boss-api.js) จะลบรูปที่ไม่ใช้แล้วผ่าน Storage API
-- (Supabase ไม่ให้ลบไฟล์ด้วย SQL ตรงๆ จึงต้องมี policy นี้)
--
-- ที่อยู่ไฟล์ = <owner_id>/<boss_id>/<uuid>.<ext> — ลบได้เฉพาะไฟล์ที่โฟลเดอร์แรกเป็น id ของตัวเอง
-- (เฉพาะเจ้าของบอส สมาชิกปาร์ตี้ลบของหัวปาร์ตี้ไม่ได้ เพราะโฟลเดอร์แรกเป็น id ของหัวปาร์ตี้)
-- รันซ้ำได้ (drop if exists ก่อน create)
-- ============================================================
begin;

drop policy if exists custom_boss_images_delete_own on storage.objects;
create policy custom_boss_images_delete_own on storage.objects
  for delete to authenticated
  using ((bucket_id = 'custom-boss-images'::text)
         and ((storage.foldername(name))[1] = (auth.uid())::text));

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ 3 แถว (read, upload, delete_own)
select policyname, cmd, roles::text as roles
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and (coalesce(qual, '') || coalesce(with_check, '')) ~ 'custom-boss-images'
 order by policyname;
