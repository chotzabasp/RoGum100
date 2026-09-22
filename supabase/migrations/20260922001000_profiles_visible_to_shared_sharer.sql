-- ============================================================
-- ให้เห็นชื่อ (display_name) ของคนที่เคยได้รับส่วนแบ่งไอเทมชิ้นเดียวกันกับเราได้เสมอ แม้จะไม่ได้
-- อยู่ปาร์ตี้เดียวกันแล้วก็ตาม — เดิม profiles_select เช็คแค่ความสัมพันธ์ปาร์ตี้ปัจจุบัน
-- (is_party_member_of / is_my_party_member / shares_party_with) พอออกจากปาร์ตี้ไปแล้ว ชื่อคนที่
-- เคยหารของด้วยกันจะหายไป ขึ้น "ไม่ทราบชื่อ" แทน ทั้งที่ kills/kill_items เปิดให้ดูรายการนั้นได้แล้ว
-- (ดู migration 20260922000900_kill_share_visible_after_leave.sql)
-- ============================================================
begin;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (
    auth.uid() = id
    or is_admin()
    or is_party_member_of(id)
    or is_my_party_member(id)
    or shares_party_with(id)
    or exists (
      select 1 from public.kill_items ki
      where auth.uid()::text = any(ki.shared_with::text[])
        and profiles.id::text = any(ki.shared_with::text[])
    )
  );

commit;
