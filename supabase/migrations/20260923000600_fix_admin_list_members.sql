-- ============================================================
-- แก้บั๊ก "column reference id is ambiguous" ของ admin_list_members
-- สาเหตุ: returns table มีคอลัมน์ชื่อ id ทำให้ไปชนกับ "where id = auth.uid()" ตอนเช็คสิทธิ์แอดมิน
-- (ไม่ได้ระบุว่าเป็น profiles.id) แก้ด้วยการตั้ง alias ให้ตาราง profiles ตรงจุดนั้นให้ชัดเจน
-- ============================================================
begin;

create or replace function public.admin_list_members()
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

commit;
