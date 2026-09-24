-- ============================================================
-- ปรับกฎสิทธิ์ (RLS) ให้เร็วขึ้นเมื่อข้อมูลโต — จาก Supabase Performance Advisor (25 ก.ย. 2569)
-- เขียนทีละกฎจากค่าจริงใน pg_policies (ดึงมาดูก่อนแล้ว) · ความหมายของสิทธิ์ "เหมือนเดิมทุกข้อ"
--
-- 1) auth_rls_initplan: auth.uid() → (select auth.uid()) ให้ฐานข้อมูลถาม "ใครเรียก" ครั้งเดียวต่อคำสั่ง
--    แทนที่จะถามทุกแถว · ฟังก์ชันที่ไม่มีอาร์กิวเมนต์ต่อแถว (is_admin(), is_active(), has_timers_plan(ตัวเอง))
--    ก็ครอบ (select ...) แบบเดียวกัน · ส่วนที่ขึ้นกับแถว เช่น is_party_member_of(host_id) คงเดิม
-- 2) auth.uid()::text = ANY(shared_with::text[])  →  shared_with @> array[(select auth.uid())]
--    ความหมายเดียวกัน (มีรหัสเราอยู่ในรายชื่อผู้รับส่วนแบ่ง) แต่ใช้ดัชนี kill_items_shared_with_gin ได้
-- 3) multiple_permissive_policies: กฎ "เขียน" ที่ตั้งเป็น FOR ALL (รวมการอ่านด้วย) ทำให้ตอนอ่านต้องเช็คซ้ำ
--    2 กฎทุกแถว → แยกเป็น INSERT / UPDATE / DELETE เงื่อนไขเดิม (bosses, items, servers, kill_items, user_bosses)
--    topup_transactions: รวม 2 กฎอ่าน (ของตัวเอง / แอดมิน) เป็นกฎเดียว เงื่อนไข OR เดิม
-- 4) ดัชนีสำหรับ foreign key ที่ยังไม่มี (Advisor: unindexed_foreign_keys) 5 ตัวที่ตารางโตได้
--
-- ทั้งไฟล์อยู่ใน transaction เดียว — ถ้าคำสั่งไหนพัง จะไม่มีอะไรเปลี่ยนเลย
-- ============================================================
begin;

-- ---------- announcements ----------
alter policy announcements_delete on public.announcements
  using (((select auth.uid()) = user_id) or (select is_admin()));
alter policy announcements_insert on public.announcements
  with check (((select auth.uid()) = user_id) and (select is_active()));
alter policy announcements_update on public.announcements
  using (((select auth.uid()) = user_id) and (select is_active()))
  with check ((select auth.uid()) = user_id);

-- ---------- farm_entries ----------
alter policy farm_entries_delete_own on public.farm_entries
  using ((user_id = (select auth.uid())) and (select is_active()));
alter policy farm_entries_insert_own on public.farm_entries
  with check ((user_id = (select auth.uid())) and (select is_active()));
alter policy farm_entries_select_own on public.farm_entries
  using (user_id = (select auth.uid()));
alter policy farm_entries_update_own on public.farm_entries
  using (user_id = (select auth.uid()))
  with check ((user_id = (select auth.uid())) and (select is_active()));

-- ---------- merchant_entries ----------
alter policy merchant_entries_delete_own on public.merchant_entries
  using ((user_id = (select auth.uid())) and (select is_active()));
alter policy merchant_entries_insert_own on public.merchant_entries
  with check ((user_id = (select auth.uid())) and (select is_active()));
alter policy merchant_entries_select_own on public.merchant_entries
  using (user_id = (select auth.uid()));
alter policy merchant_entries_update_own on public.merchant_entries
  using (user_id = (select auth.uid()))
  with check ((user_id = (select auth.uid())) and (select is_active()));

-- ---------- user_app_data ----------
alter policy user_app_data_delete_own on public.user_app_data
  using (user_id = (select auth.uid()));
alter policy user_app_data_insert_own on public.user_app_data
  with check (user_id = (select auth.uid()));
alter policy user_app_data_select_own on public.user_app_data
  using (user_id = (select auth.uid()));
alter policy user_app_data_update_own on public.user_app_data
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------- package_purchases / topup_requests / party_members ----------
alter policy package_purchases_select_own on public.package_purchases
  using (((select auth.uid()) = user_id) or (select is_admin()));
alter policy topup_select on public.topup_requests
  using (((select auth.uid()) = user_id) or (select is_admin()));
alter policy party_members_select on public.party_members
  using (((select auth.uid()) = host_id) or ((select auth.uid()) = member_id) or is_party_member_of(host_id));

-- ---------- topup_transactions: รวม 2 กฎอ่านเป็นกฎเดียว ----------
drop policy if exists "users can view own topups" on public.topup_transactions;
drop policy if exists topup_transactions_admin_select on public.topup_transactions;
create policy topup_transactions_select on public.topup_transactions
  for select to authenticated
  using ((user_id = (select auth.uid())) or (select is_admin()));

-- ---------- profiles ----------
alter policy profiles_select on public.profiles
  using (((select auth.uid()) = id) or (select is_admin()) or is_party_member_of(id) or is_my_party_member(id)
         or shares_party_with(id)
         or (exists (select 1 from public.kill_items ki
                      where ki.shared_with @> array[(select auth.uid()), profiles.id])));

-- ---------- kills ----------
alter policy kills_party on public.kills
  using (((select auth.uid()) = host_id) or is_party_member_of(host_id)
         or (exists (select 1 from public.kill_items ki
                      where ki.kill_id = kills.id and ki.shared_with @> array[(select auth.uid())])));
alter policy kills_party_delete on public.kills
  using ((((select auth.uid()) = host_id) or (is_party_member_of(host_id) and (select has_timers_plan((select auth.uid())))))
         and (select is_active()));

-- ---------- kill_items: อ่าน + แยกกฎเขียน ----------
alter policy kill_items_select on public.kill_items
  using (((select auth.uid()) = host_id) or is_party_member_of(host_id) or (shared_with @> array[(select auth.uid())]));
drop policy if exists kill_items_write on public.kill_items;
create policy kill_items_insert on public.kill_items for insert to public
  with check ((((select auth.uid()) = host_id) or (is_party_member_of(host_id) and (select has_timers_plan((select auth.uid())))))
              and (select is_active()));
create policy kill_items_update on public.kill_items for update to public
  using ((((select auth.uid()) = host_id) or (is_party_member_of(host_id) and (select has_timers_plan((select auth.uid())))))
         and (select is_active()))
  with check ((((select auth.uid()) = host_id) or (is_party_member_of(host_id) and (select has_timers_plan((select auth.uid())))))
              and (select is_active()));
create policy kill_items_delete on public.kill_items for delete to public
  using ((((select auth.uid()) = host_id) or (is_party_member_of(host_id) and (select has_timers_plan((select auth.uid())))))
         and (select is_active()));

-- ---------- user_bosses: อ่าน + แยกกฎเขียน ----------
alter policy user_bosses_select on public.user_bosses
  using (((select auth.uid()) = user_id) or is_party_member_of(user_id));
drop policy if exists user_bosses_write on public.user_bosses;
create policy user_bosses_insert on public.user_bosses for insert to public
  with check ((((select auth.uid()) = user_id) or is_party_member_of(user_id)) and (select is_active()));
create policy user_bosses_update on public.user_bosses for update to public
  using ((((select auth.uid()) = user_id) or is_party_member_of(user_id)) and (select is_active()))
  with check ((((select auth.uid()) = user_id) or is_party_member_of(user_id)) and (select is_active()));
create policy user_bosses_delete on public.user_bosses for delete to public
  using ((((select auth.uid()) = user_id) or is_party_member_of(user_id)) and (select is_active()));

-- ---------- bosses / items / servers: แยกกฎเขียนของแอดมิน ----------
drop policy if exists bosses_admin_write on public.bosses;
create policy bosses_admin_insert on public.bosses for insert to public with check ((select is_admin()));
create policy bosses_admin_update on public.bosses for update to public using ((select is_admin())) with check ((select is_admin()));
create policy bosses_admin_delete on public.bosses for delete to public using ((select is_admin()));

drop policy if exists items_admin_write on public.items;
create policy items_admin_insert on public.items for insert to public with check ((select is_admin()));
create policy items_admin_update on public.items for update to public using ((select is_admin())) with check ((select is_admin()));
create policy items_admin_delete on public.items for delete to public using ((select is_admin()));

drop policy if exists servers_admin_write on public.servers;
create policy servers_admin_insert on public.servers for insert to public with check ((select is_admin()));
create policy servers_admin_update on public.servers for update to public using ((select is_admin())) with check ((select is_admin()));
create policy servers_admin_delete on public.servers for delete to public using ((select is_admin()));

-- ---------- ดัชนี foreign key ที่ขาด ----------
create index if not exists announcements_user_id_idx on public.announcements (user_id);
create index if not exists app_events_user_id_idx on public.app_events (user_id) where user_id is not null;
create index if not exists kills_host_custom_boss_idx on public.kills (host_id, custom_boss_id);
create index if not exists promo_code_redemptions_user_id_idx on public.promo_code_redemptions (user_id);
create index if not exists user_bosses_boss_id_idx on public.user_bosses (boss_id);

commit;

-- ============================================================
-- ตรวจหลังรัน (อ่านอย่างเดียว)
-- ก) ต้องไม่เหลือ auth.uid() แบบเดิม (ไม่ครอบ select) ในกฎของ public → ได้ 0 แถว
select tablename, policyname
  from pg_policies
 where schemaname = 'public'
   and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ '(?<!SELECT )auth\.uid\(\)'
 order by 1, 2;
-- ข) กฎต่อตาราง/การกระทำ: ทุกตารางที่แก้ ต้องมีกฎอ่าน (SELECT) ตารางละ 1 กฎ และไม่มี ALL เหลือ
--    (ยกเว้น promo_codes / promo_code_redemptions ที่มีกฎแอดมินกฎเดียวอยู่แล้ว ไม่ได้แตะ)
select tablename, cmd, count(*) as policies, string_agg(policyname, ', ' order by policyname) as names
  from pg_policies
 where schemaname = 'public'
 group by tablename, cmd
 order by tablename, cmd;
