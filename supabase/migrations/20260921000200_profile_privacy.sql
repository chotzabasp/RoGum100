-- ============================================================
--  Gum100 — ปิดไม่ให้สมาชิกปาร์ตี้อ่านข้อมูลส่วนตัวของกัน (วันเกิด, แต้ม, วันหมดอายุ, สิทธิ์แพ็กเกจ ฯลฯ)
--
--  ก่อนหน้านี้ ตาราง profiles อนุญาตให้สมาชิกปาร์ตี้อ่าน "ทุกคอลัมน์" ของกันและกันได้ผ่าน API
--  หลังรันไฟล์นี้: ผู้ใช้ทั่วไปอ่านได้แค่ id กับ display_name ของโปรไฟล์ (พอสำหรับแสดงชื่อในปาร์ตี้/ประวัติ)
--  ส่วนข้อมูลของตัวเองอ่านผ่านฟังก์ชัน my_profile() แทน
--
--  ⚠ ลำดับสำคัญ: รันไฟล์นี้ "หลังจากเว็บอัปเดตแล้วเท่านั้น" (หน้าเว็บรุ่นใหม่เรียก my_profile ได้เอง)
--     ถ้ารันก่อน เว็บรุ่นเก่าที่เปิดค้างอยู่จะโหลดโปรไฟล์ไม่ได้จนกว่าจะรีเฟรช (Ctrl+F5)
--
--  รันทั้งไฟล์รวดเดียวใน Supabase Dashboard -> SQL Editor -> New query -> Run
--  ช่วงที่ 2 มีการตรวจล่วงหน้า: ถ้าพบฟังก์ชัน/กติกาอื่นที่อ้างตาราง profiles ตรงๆ จะหยุดพร้อมบอกชื่อ
--  (ยังไม่ถอนสิทธิ์อะไร) — ให้ส่งข้อความที่ขึ้นมาให้ผมดู
--  ถ้าต้องการย้อนกลับ: grant select on public.profiles to authenticated;
-- ============================================================


-- ช่วงที่ 1: ฟังก์ชันอ่านโปรไฟล์ตัวเอง (ปลอดภัย รันก่อนอัปเดตเว็บก็ได้ ไม่กระทบอะไร)
begin;

create or replace function public.my_profile()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'display_name', p.display_name,
    'points', p.points,
    'role', p.role,
    'expires_at', p.expires_at,
    'username', p.username,
    'birth_date', p.birth_date,
    'servers', to_jsonb(p.servers),
    'server_quota', p.server_quota,
    'facebook_url', p.facebook_url,
    'legacy_unlimited', p.legacy_unlimited,
    'plan_bundle_expires_at', p.plan_bundle_expires_at,
    'plan_timers_expires_at', p.plan_timers_expires_at
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated, service_role;

commit;


-- ช่วงที่ 2: ถอนสิทธิ์อ่านคอลัมน์ส่วนตัว (รันหลังเว็บรุ่นใหม่ขึ้นแล้ว)
begin;

-- ตรวจล่วงหน้า: มีกติกา (policy) / view / ฟังก์ชันแบบ invoker ตัวอื่นที่อ้างตาราง profiles ตรงๆ ไหม
-- ถ้ามี การถอนสิทธิ์อาจทำให้ส่วนนั้นพัง จึงหยุดไว้ก่อนแล้วบอกชื่อ
do $$
declare offenders text;
begin
  select string_agg(x, E'\n') into offenders from (
    select 'policy ' || schemaname || '.' || tablename || ' :: ' || policyname as x
      from pg_policies
     where (coalesce(qual, '') ~* '\yprofiles\y' or coalesce(with_check, '') ~* '\yprofiles\y')
       and not (schemaname = 'public' and tablename = 'profiles')
    union all
    select 'view public.' || viewname
      from pg_views
     where schemaname = 'public' and definition ~* '\yprofiles\y'
    union all
    select 'function public.' || p.proname
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.prokind = 'f'
       and not p.prosecdef
       and p.proname <> 'my_profile'
       and p.prosrc ~* '\yprofiles\y'
  ) t;
  if offenders is not null then
    raise exception E'พบส่วนที่อ้างตาราง profiles ตรงๆ จึงยกเลิกการถอนสิทธิ์ (ยังไม่มีอะไรเปลี่ยน):\n%', offenders;
  end if;
end $$;

revoke select on public.profiles from anon, authenticated;
grant select (id, display_name) on public.profiles to authenticated;

commit;
