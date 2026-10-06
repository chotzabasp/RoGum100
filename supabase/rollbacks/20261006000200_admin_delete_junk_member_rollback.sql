-- ============================================================
-- ย้อนกลับ 20261006000200_admin_delete_junk_member.sql
--   ลบ admin_delete_member / admin_delete_member_check / admin_member_delete_blockers
--   admin_list_members → ฉบับ 20260923000600 (ไม่มี role / email_confirmed_at / last_sign_in_at · md5 fafb790c…)
--   ลบตาราง admin_user_deletions — ประวัติการลบจะหายด้วย ถ้าอยากเก็บ ให้รัน select * from public.admin_user_deletions; แล้วคัดลอกไว้ก่อน
--   บัญชีที่ลบไปแล้วกู้คืนด้วยไฟล์นี้ไม่ได้ (ต้องกู้ backup ทั้งฐานข้อมูล)
-- ลำดับ: รันก่อนหรือหลังหน้าเว็บก็ได้ — หน้าเว็บที่ยังมีปุ่มลบจะขึ้นข้อความว่ายังไม่ได้ติดตั้ง
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.admin_list_members()');
  if v_md5 is distinct from 'c3a6ad6a62bd77ddaec976f6fe62e93b' then
    raise exception 'admin_list_members ไม่ใช่ฉบับ 20261006000200 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

drop function if exists public.admin_delete_member(uuid, text);
drop function if exists public.admin_delete_member_check(uuid);
drop function if exists public.admin_member_delete_blockers(uuid);
drop table if exists public.admin_user_deletions;

drop function public.admin_list_members();

create function public.admin_list_members()
returns table (
  id uuid,
  display_name text,
  username text,
  email text,
  points integer,
  legacy_unlimited boolean,
  plan_bundle_expires_at timestamptz,
  plan_timers_expires_at timestamptz,
  feature_expiries jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_role text;
begin
  select pr.role into v_role from public.profiles pr where pr.id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;

  return query
    select p.id, p.display_name::text, p.username::text, u.email::text, p.points, p.legacy_unlimited,
           p.plan_bundle_expires_at, p.plan_timers_expires_at,
           coalesce((
             select jsonb_object_agg(pfe.feature, pfe.expires_at)
             from public.package_feature_entitlements pfe
             where pfe.user_id = p.id and pfe.feature in ('farm','accountItems')
           ), '{}'::jsonb) as feature_expiries,
           p.created_at
    from public.profiles p
    join auth.users u on u.id = p.id
    order by p.created_at desc;
end;
$function$;

revoke all on function public.admin_list_members() from public, anon;
grant execute on function public.admin_list_members() to authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.admin_list_members()')) = 'fafb790cbf7be374b5006ff84dac45da'
    and to_regprocedure('public.admin_delete_member(uuid, text)') is null
    and to_regprocedure('public.admin_delete_member_check(uuid)') is null
    and to_regprocedure('public.admin_member_delete_blockers(uuid)') is null
    and to_regclass('public.admin_user_deletions') is null
    and has_function_privilege('authenticated', 'public.admin_list_members()', 'execute')
    and not has_function_privilege('anon', 'public.admin_list_members()', 'execute') as delete_junk_removed_ok;
