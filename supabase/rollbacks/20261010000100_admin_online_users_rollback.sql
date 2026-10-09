-- ============================================================
-- ย้อนกลับ 20261010000100_admin_online_users.sql
--   ลบฟังก์ชัน admin_online_users() — ไม่มีตาราง/ฟังก์ชันอื่นถูกแตะ
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (หน้าแอดมินที่เรียกไม่เจอ = หน้าต่างรายชื่อขึ้นข้อความ "ยังไม่ได้ติดตั้ง" เฉยๆ ตัวเลขเดิมยังแสดงปกติ)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_online_users()');
  if v_md5 is distinct from '399fabaf3f03555b0b50aa3b20d7df7a' then
    raise exception 'admin_online_users ไม่ใช่ฉบับ 20261010000100 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

drop function public.admin_online_users();

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select to_regprocedure('public.admin_online_users()') is null as online_users_removed_ok;
