-- ============================================================
-- เปิดสิทธิ์ระดับตาราง (GRANT) ให้ authenticated เขียนตาราง servers ได้ — เดิมมีแค่ SELECT
-- เท่านั้น (เพราะแอดมินจัดการผ่าน Table Editor มาตลอด ไม่เคยต้องพึ่ง GRANT นี้) พอมีหน้าแอดมิน
-- ในเว็บให้เขียนตรงๆ ผ่าน anon/authenticated role เลยต้องเปิดสิทธิ์นี้เพิ่ม
--
-- RLS policy "servers_admin_write" (for all using is_admin()) ยังคุมเหมือนเดิม — คนทั่วไปที่ไม่ใช่
-- แอดมินต่อให้มี GRANT นี้ก็ยังเขียนไม่ได้จริง เพราะ RLS บล็อกอยู่ชั้นถัดไป
-- ============================================================
begin;

grant insert, update, delete on public.servers to authenticated;

commit;
