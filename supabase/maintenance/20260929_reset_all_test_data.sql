-- ============================================================
-- รีเซ็ตข้อมูลทดสอบทั้งหมดก่อนเปิดใช้งานจริง (ผู้ใช้สั่ง 29 ก.ย. 2569: "ลบทุกบัญชี ไม่เก็บ เดียวสร้าง id admin ใหม่เอง")
-- ลบ: ทุกบัญชี (auth.users 7 + profiles 7) และข้อมูลทุกอย่างในบัญชี (ตาม FK cascade ที่ตรวจจากฐานข้อมูลจริงแล้ว)
--     ข้อมูลการเงินทดสอบ (เติมเงิน / ประวัติแต้ม / ซื้อแพ็ก) · โค้ดโปรทดสอบ 4 ตัว (DGRP10, GRP1, GRP2, TEST10) + ประวัติการใช้
--     สถิติ/บันทึกของระบบ (ผู้เข้าชม เวลาใช้งาน ข้อผิดพลาด ประวัติการกดของแอดมิน ตัวนับกันยิงซ้ำ ล็อกล็อกอินผิด)
-- คงไว้: servers · bosses · items · ฟังก์ชัน/สิทธิ์/ตั้งค่าทั้งหมด · ไฟล์ใน Storage (ลบ item-images เองตามขั้นตอนใน Dashboard)
-- ย้อนกลับไม่ได้ด้วยไฟล์ — ถ้าจำเป็นต้องกู้ = กู้ backup ทั้งฐานข้อมูล (Database → Backups) · รันก่อนสร้างบัญชีแอดมินใหม่
-- ไม่อยู่ใน supabase/migrations เพราะเป็นงานครั้งเดียว ห้ามรันซ้ำกับฐานข้อมูลที่มีผู้ใช้จริง (ตัวเช็คด้านล่างกันไว้)
-- ============================================================
begin;

set local lock_timeout = '5s';

-- ตัวเช็ค: ต้องตรงกับที่ตรวจไว้ก่อนรีเซ็ต — มีบัญชีเพิ่ม (เช่น สร้างแอดมินใหม่ไปก่อน) / โค้ดโปรเปลี่ยน = หยุด ไม่ลบอะไร
do $guard$
declare
  v_users int;
  v_profiles int;
  v_codes text;
begin
  select count(*) into v_users from auth.users;
  select count(*) into v_profiles from public.profiles;
  select string_agg(code, ',' order by code) into v_codes from public.promo_codes;
  if v_users <> 7 or v_profiles <> 7 then
    raise exception 'จำนวนบัญชีไม่ใช่ 7 ตามที่ตรวจไว้ (auth.users %, profiles %) — มีบัญชีใหม่หรือไม่? ไม่มีอะไรถูกลบ (ส่งข้อความนี้ให้ Claude)', v_users, v_profiles;
  end if;
  if coalesce(v_codes, '') <> 'DGRP10,GRP1,GRP2,TEST10' then
    raise exception 'รายชื่อโค้ดโปรไม่ตรงกับที่ตรวจไว้ (%) — ไม่มีอะไรถูกลบ (ส่งข้อความนี้ให้ Claude)', coalesce(v_codes, 'ไม่มี');
  end if;
end;
$guard$;

-- 1) ตารางที่อ้างถึงบัญชีแบบ "no action" (ขวางการลบบัญชี) + บันทึกที่ผูกกับบัญชีแบบ set null
delete from public.promo_code_redemptions;   -- user_id no action
delete from public.promo_codes;              -- created_by no action · โค้ดทดสอบทั้ง 4 ตัว
delete from public.topup_transactions;       -- user_id no action · รายการเติมเงินทดสอบ (รวม 50 บาทที่จ่ายจริง)
delete from public.topup_requests;           -- reviewed_by no action (user_id cascade) · สลิประบบเก่า
delete from public.topup_admin_log;          -- user_id set null · ประวัติการกดของแอดมิน

-- 2) ทุกบัญชี: auth.users → profiles (cascade) → ข้อมูลทุกตารางในบัญชี (cascade ตาม FK ที่ตรวจแล้ว)
--    announcements, custom_boss_timers, custom_bosses, discord_alert_log, discord_alert_settings, farm_entries, kill_items,
--    kills, merchant_entries, package_feature_entitlements, package_purchases, party_members, points_ledger,
--    user_activity_hours, user_app_data, user_bosses, user_presence · auth.identities / sessions ตามไปเอง
delete from auth.users;

-- 3) สถิติ/บันทึกของระบบที่ไม่ได้ผูก FK กับบัญชี — ให้หน้าแอดมินเริ่มนับ 0 วันเปิด
delete from public.app_events;               -- user_id set null → ต้องลบเอง (ผู้เข้าชม / เปิดหน้า / ข้อผิดพลาด / หน้าแรก)
delete from public.app_event_budget;         -- ตัวนับกันยิงสถิติซ้ำ
delete from public.login_attempts;           -- ตัวนับล็อกอินผิด

-- ตัวเช็คสุดท้ายก่อน commit: ยังเหลือบัญชี = ยกเลิกทั้งหมด (ไม่มีอะไรถูกลบ)
do $final$
begin
  if exists (select 1 from auth.users) or exists (select 1 from public.profiles) then
    raise exception 'ยังเหลือบัญชีหลังลบ — ยกเลิกทั้งหมด ไม่มีอะไรถูกลบ (ส่งข้อความนี้ให้ Claude)';
  end if;
end;
$final$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว: 8 ช่องแรกเป็น 0 ทั้งหมด · 3 ช่องท้าย (ที่คงไว้) มากกว่า 0
select
  (select count(*) from auth.users) as users,
  (select count(*) from public.profiles) as profiles,
  (select count(*) from public.merchant_entries) + (select count(*) from public.farm_entries)
    + (select count(*) from public.user_app_data) as trade_farm_data,
  (select count(*) from public.kills) + (select count(*) from public.kill_items) + (select count(*) from public.user_bosses)
    + (select count(*) from public.custom_bosses) + (select count(*) from public.custom_boss_timers)
    + (select count(*) from public.party_members) as boss_party,
  (select count(*) from public.announcements) as announcements,
  (select count(*) from public.topup_transactions) + (select count(*) from public.topup_requests)
    + (select count(*) from public.topup_admin_log) + (select count(*) from public.points_ledger)
    + (select count(*) from public.package_purchases) + (select count(*) from public.package_feature_entitlements) as money,
  (select count(*) from public.promo_codes) + (select count(*) from public.promo_code_redemptions) as promo,
  (select count(*) from public.app_events) + (select count(*) from public.user_presence)
    + (select count(*) from public.user_activity_hours) + (select count(*) from public.app_event_budget)
    + (select count(*) from public.login_attempts) + (select count(*) from public.discord_alert_settings)
    + (select count(*) from public.discord_alert_log) as stats_logs,
  (select count(*) from public.servers) as servers_kept,
  (select count(*) from public.bosses) as bosses_kept,
  (select count(*) from public.items) as items_kept;
