-- ============================================================
-- เพิ่มดัชนี (index) ที่ขาด — จากการตรวจระบบ 25 ก.ย. 2569 (ดูรายการดัชนีจริงจาก pg_indexes แล้ว)
-- เพิ่มอย่างเดียว ไม่แตะข้อมูล ไม่เปลี่ยนการทำงาน · ตอนนี้ตารางเล็ก สร้างเสร็จทันที
-- รันซ้ำได้ (if not exists)
--
-- 1) kill_items(kill_id)         โหลดประวัติการฆ่า (kills + kill_items ที่ฝังมา) ทุกครั้งที่เปิดหน้า
--                                จับเวลาบอส / มีคนในปาร์ตี้กด MVP — เดิมต้องไล่ทั้งตาราง kill_items
-- 2) kill_items(shared_with) GIN "รายการที่แบ่งให้ฉัน" (.contains('shared_with', [uid]) = shared_with @> ...)
-- 3) kills(killed_by)            ตอนลบบัญชี (FK ON DELETE SET NULL ต้องหาแถวที่ชี้มาที่บัญชีนั้น)
-- 4) party_members(host_id)      รายชื่อสมาชิกที่ยังอยู่ในปาร์ตี้ (host_id = ? and removed_at is null)
-- ============================================================
begin;

create index if not exists kill_items_kill_id_idx on public.kill_items (kill_id);
create index if not exists kill_items_shared_with_gin on public.kill_items using gin (shared_with);
create index if not exists kills_killed_by_idx on public.kills (killed_by);
create index if not exists party_members_host_active_idx on public.party_members (host_id) where removed_at is null;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ 4 แถว
select tablename, indexname
  from pg_indexes
 where schemaname = 'public'
   and indexname in ('kill_items_kill_id_idx', 'kill_items_shared_with_gin', 'kills_killed_by_idx', 'party_members_host_active_idx')
 order by tablename, indexname;
