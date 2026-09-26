-- ============================================================
-- สถานะแจ้งเตือน Discord ของหัวปาร์ตี้ ให้สมาชิกปาร์ตี้เห็น (จุดบนปุ่ม + บรรทัดในการ์ด หน้าจับเวลาบอส)
--   ส่งกลับแค่ เปิด/ไม่เปิด และเวลาแจ้งเตือน — ไม่ส่งลิงก์ Webhook / การแท็ก / ห้อง
--   เรียกได้เฉพาะหัวปาร์ตี้เอง หรือสมาชิกที่อยู่ในปาร์ตี้นั้นจริง (is_party_member_of ตรวจ removed_at is null)
--   "เปิด" = ตั้งไว้ + เปิดใช้ + หัวปาร์ตี้มีแพ็กจับเวลาบอส/4 in 1 + บัญชีไม่หมดอายุ (เงื่อนไขเดียวกับตัวส่งจริง)
-- ============================================================
begin;

create or replace function public.party_discord_alert_status(p_host uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
stable
as $function$
declare
  v public.discord_alert_settings%rowtype;
  v_on boolean;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_host is null or (p_host <> auth.uid() and not public.is_party_member_of(p_host)) then
    raise exception 'ไม่มีสิทธิ์ดูสถานะนี้';
  end if;
  select * into v from public.discord_alert_settings where owner_id = p_host;
  v_on := found and v.enabled and public.has_timers_plan(p_host)
          and exists(select 1 from public.profiles p
                      where p.id = p_host and (coalesce(p.role, '') = 'admin' or p.expires_at > now()));
  return jsonb_build_object('enabled', coalesce(v_on, false),
                            'lead_minutes', case when coalesce(v_on, false) then v.lead_minutes end);
end;
$function$;

revoke all on function public.party_discord_alert_status(uuid) from public, anon;
grant execute on function public.party_discord_alert_status(uuid) to authenticated;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ has_fn = true, anon_exec = false, auth_exec = true
select to_regprocedure('public.party_discord_alert_status(uuid)') is not null as has_fn,
       has_function_privilege('anon', 'public.party_discord_alert_status(uuid)', 'execute') as anon_exec,
       has_function_privilege('authenticated', 'public.party_discord_alert_status(uuid)', 'execute') as auth_exec;
