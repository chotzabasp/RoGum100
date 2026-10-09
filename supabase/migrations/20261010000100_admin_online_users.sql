-- ============================================================
-- แดชบอร์ดแอดมิน: กดดูรายชื่อคนที่ "ออนไลน์ตอนนี้" ได้ (ผู้ใช้ขอ 10 ต.ค. 2569 — เลือกแบบหน้าต่างเด้งขึ้น)
-- admin_online_users() (ใหม่): รายชื่อคนที่ออนไลน์ — ชื่อ · @ยูเซอ · หน้าที่อยู่ · เปิดดูอยู่/เปิดทิ้งไว้ · อุปกรณ์ · เห็นล่าสุด
--   นิยามเดียวกับตัวเลข "ออนไลน์ตอนนี้" ใน admin_live: มีสัญญาณใน 5 นาทีล่าสุด · ไม่นับบัญชีแอดมิน
--   แอดมินเท่านั้น · อ่านอย่างเดียว · หน้าแอดมินเรียกเฉพาะตอนกดดูรายชื่อ (และทุก 1 นาทีระหว่างหน้าต่างเปิดอยู่)
--   ส่งกลับไม่เกิน 500 คน (เปิดดูอยู่ก่อน แล้วเรียงตามเห็นล่าสุด) + total = จำนวนจริงทั้งหมด
-- ไม่แก้ฟังก์ชัน/ตารางเดิม (admin_live, user_presence เหมือนเดิมทุกอย่าง)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261010000100_admin_online_users_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
begin
  if to_regclass('public.user_presence') is null or to_regprocedure('public.is_admin()') is null then
    raise exception 'ไม่พบตาราง user_presence หรือฟังก์ชัน is_admin — ไม่มีอะไรถูกแก้';
  end if;
  if to_regprocedure('public.admin_online_users()') is not null then
    raise exception 'มีฟังก์ชัน admin_online_users อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

create function public.admin_online_users()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_cut timestamptz := now() - interval '5 minutes';
  v_out jsonb;
begin
  if not public.is_admin() then raise exception 'สำหรับแอดมินเท่านั้น'; end if;

  with
  -- นิยามเดียวกับ online_now / online_visible / online_pages ใน admin_live
  pres as (
    select p.display_name, p.username, coalesce(up.page, '-') as page,
           coalesce(up.visible_seen_at >= v_cut, false) as visible, up.device, up.last_seen_at
      from user_presence up join profiles p on p.id = up.user_id
     where up.last_seen_at >= v_cut and p.role is distinct from 'admin'
  ),
  shown as (
    select * from pres order by visible desc, last_seen_at desc limit 500
  )
  select jsonb_build_object(
    'generated_at', now(),
    'total', (select count(*) from pres),
    'users', (select coalesce(jsonb_agg(jsonb_build_object(
                         'name', display_name, 'username', username, 'page', page, 'visible', visible,
                         'device', device, 'last_seen_at', last_seen_at)
                       order by visible desc, last_seen_at desc), '[]'::jsonb)
                from shown)
  ) into v_out;
  return v_out;
end;
$function$;

revoke all on function public.admin_online_users() from public, anon;
grant execute on function public.admin_online_users() to authenticated;

-- ---------- ลองใช้จริงก่อน commit (พังตรงไหน = ยกเลิกทั้งหมด ไม่มีอะไรถูกแก้) ----------
do $check$
begin
  -- คอลัมน์ที่ฟังก์ชันใช้มีจริงทุกตัว (ตัวฟังก์ชันเรียกจาก SQL Editor ไม่ได้ เพราะไม่ได้ล็อกอินเป็นแอดมิน)
  perform p.display_name, p.username, p.role, up.page, up.visible_seen_at, up.device, up.last_seen_at
     from public.user_presence up join public.profiles p on p.id = up.user_id limit 1;
end;
$check$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
-- (ฟังก์ชันตรงกับไฟล์นี้ · แอดมินที่ล็อกอินเรียกได้ · คนที่ไม่ได้ล็อกอินเรียกไม่ได้)
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_online_users()')) = '399fabaf3f03555b0b50aa3b20d7df7a'
    and has_function_privilege('authenticated', 'public.admin_online_users()', 'execute')
    and not has_function_privilege('anon', 'public.admin_online_users()', 'execute') as online_users_ok;
