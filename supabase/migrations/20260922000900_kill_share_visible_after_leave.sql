-- ============================================================
-- ให้ผู้ที่เคยได้รับส่วนแบ่งไอเทม ยังมองเห็นรายการนั้นได้ตลอด แม้จะออกจากปาร์ตี้ไปแล้ว
-- (ไม่ใช่ปลดล็อกให้เห็นข้อมูลอื่นของปาร์ตี้ทั้งหมด — เห็นได้เฉพาะรายการที่ตัวเองมีชื่ออยู่ใน
-- "ผู้รับส่วนแบ่ง" (kill_items.shared_with) เท่านั้น)
--
-- เดิม policy เช็คแค่ auth.uid() = host_id หรือ is_party_member_of(host_id) — พอออกจากปาร์ตี้
-- (removed_at ถูกตั้ง) is_party_member_of() เป็น false ทันที เลยหลุดสิทธิ์เห็นยอดที่เคยได้ไปด้วย
-- ============================================================
begin;

drop policy if exists kill_items_select on public.kill_items;
create policy kill_items_select on public.kill_items
  for select using (
    auth.uid() = host_id
    or is_party_member_of(host_id)
    or auth.uid()::text = any(shared_with::text[])
  );

drop policy if exists kills_party on public.kills;
create policy kills_party on public.kills
  for select using (
    auth.uid() = host_id
    or is_party_member_of(host_id)
    or exists (
      select 1 from public.kill_items ki
      where ki.kill_id = kills.id and auth.uid()::text = any(ki.shared_with::text[])
    )
  );

commit;
