-- ============================================================
-- ย้อนกลับ 20261010000200_admin_user_usage.sql
--   ลบ 5 ฟังก์ชันของ "การใช้งานรายคน" — ไม่มีตาราง/ฟังก์ชันอื่นถูกแตะ
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ (หน้าแอดมินที่เรียกไม่เจอ = ซ่อนการ์ด "การใช้งานรายคน" เฉยๆ ส่วนอื่นแสดงปกติ)
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  r record;
  v_md5 text;
begin
  for r in select * from (values
      ('public.admin_user_usage(integer)', '33b97516e52da3c890bc1239964ecd28'),
      ('public.admin_user_usage_day(date)', 'c75c46dcadce2f83f51b4bfe99a21123'),
      ('public.admin_user_usage_detail(uuid, integer)', 'e458195b5b818cccab7920c859c0a100'),
      ('public.admin_usage_daily(date, date, uuid)', '88f117ca5458658f53f39fd12db431c8'),
      ('public.admin_usage_plan(uuid)', 'c8be7459960c27c752dd29085aba290b')) v(fn, expect) loop
    select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure(r.fn);
    if v_md5 is distinct from r.expect then
      raise exception '% ไม่ใช่ฉบับ 20261010000200 (md5 %) — ไม่มีอะไรถูกแก้', r.fn, coalesce(v_md5, 'ไม่พบฟังก์ชัน');
    end if;
  end loop;
end;
$guard$;

drop function public.admin_user_usage(integer);
drop function public.admin_user_usage_day(date);
drop function public.admin_user_usage_detail(uuid, integer);
drop function public.admin_usage_daily(date, date, uuid);
drop function public.admin_usage_plan(uuid);

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select to_regprocedure('public.admin_user_usage(integer)') is null
   and to_regprocedure('public.admin_user_usage_day(date)') is null
   and to_regprocedure('public.admin_user_usage_detail(uuid, integer)') is null
   and to_regprocedure('public.admin_usage_daily(date, date, uuid)') is null
   and to_regprocedure('public.admin_usage_plan(uuid)') is null as user_usage_removed_ok;
