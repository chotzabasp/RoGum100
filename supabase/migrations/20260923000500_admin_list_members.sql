-- ============================================================
-- หน้าลิสต์สมาชิกทั้งหมดในแผงแอดมิน (แท็บ "สมาชิก") ไล่ดูได้ทุกคนพร้อมแพ็กเกจ/วันหมดอายุ ไม่ต้องรู้
-- username ก่อนแล้วพิมพ์เจาะจงเหมือนช่องค้นหาเดิม (admin_find_member) — คืนค่าคอลัมน์ชุดเดียวกับที่
-- admin_find_member คืนอยู่แล้ว (ยืนยันจาก source จริงที่แก้ไปรอบก่อน) รวม feature_expiries (จาก
-- package_feature_entitlements) ใช้ชื่อ field ตรงกับที่ describeMemberPlans() ฝั่งเว็บรองรับอยู่แล้ว
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
  select role into v_role from public.profiles where id = auth.uid();
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
