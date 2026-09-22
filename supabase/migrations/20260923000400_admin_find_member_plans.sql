-- ============================================================
-- ให้แอดมินเห็นแพ็กเกจ/วันหมดอายุของสมาชิกตอนค้นหาในแผงแอดมิน (จุดเดียวกับที่ใช้เติม/หักแต้ม)
-- แก้ admin_find_member เพิ่ม legacy_unlimited, plan_bundle_expires_at, plan_timers_expires_at,
-- feature_expiries (จาก package_feature_entitlements) — ใช้ชื่อ field เดียวกับที่ฝั่งเว็บใช้อยู่แล้ว
-- ใน App.profile.feature_expiries (ดู applyProfile()) จะได้เอาไปเข้า settingsPackageRows() ตัวเดิมได้เลย
-- ไม่ต้องเขียนตรรกะแปลผลซ้ำ — source เดิมของฟังก์ชันนี้ตรวจสอบจากของจริงในระบบแล้วก่อนแก้ (คอลัมน์/ตาราง
-- ทั้งหมดที่อ้างถึงมีอยู่จริง ยืนยันจาก has_farm_plan/has_trade_plan และ applyProfile() ในโค้ดฝั่งเว็บ)
-- ============================================================
begin;

create or replace function public.admin_find_member(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_role text;
  v_key text := lower(btrim(coalesce(p_identifier, '')));
  r record;
  v_scoped jsonb;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if char_length(v_key) < 3 then raise exception 'กรอก username หรืออีเมลอย่างน้อย 3 ตัวอักษร'; end if;

  if position('@' in v_key) > 0 then
    select p.id, p.display_name, p.username, p.points, u.email,
           p.legacy_unlimited, p.plan_bundle_expires_at, p.plan_timers_expires_at into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(u.email) = v_key;
  else
    select p.id, p.display_name, p.username, p.points, u.email,
           p.legacy_unlimited, p.plan_bundle_expires_at, p.plan_timers_expires_at into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(p.username) = v_key;
  end if;
  if not found then raise exception 'ไม่พบสมาชิกจาก username/อีเมลนี้'; end if;

  select coalesce(jsonb_object_agg(feature, expires_at), '{}'::jsonb) into v_scoped
    from public.package_feature_entitlements
   where user_id = r.id and feature in ('farm','accountItems');

  return jsonb_build_object('id', r.id, 'display_name', r.display_name, 'username', r.username,
                            'email', r.email, 'points', r.points,
                            'legacy_unlimited', r.legacy_unlimited,
                            'plan_bundle_expires_at', r.plan_bundle_expires_at,
                            'plan_timers_expires_at', r.plan_timers_expires_at,
                            'feature_expiries', v_scoped);
end;
$function$;

commit;
