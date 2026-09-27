-- ============================================================
-- ป้ายสิทธิ์สมาชิกในแผงปาร์ตี้ (2026-09-27)
--   party_roster(p_host): รายชื่อหัวปาร์ตี้ + สมาชิก พร้อม
--     · seat: เข้าแบบไหน ('paid' จ่าย 50 แต้มถาวร / 'plan' เข้าฟรีเพราะมีแพ็กเกจจับเวลาบอส) — หัวปาร์ตี้ = ว่าง
--     · has_timers: ตอนนี้มีสิทธิ์ "จับเวลาบอส" ไหม (ใช้ได้เต็ม / แพ็กฟรี)
--     · timers_label: ชื่อแพ็กที่ให้สิทธิ์นั้น (4 in 1 / จับเวลาบอส / แอดมิน / ไม่จำกัด) — ไม่มีสิทธิ์ = ว่าง
--     · timers_expires_at: วันหมดอายุแพ็กจับเวลาบอส เฉพาะคนที่เข้าฟรี (วันนั้นคือวันที่จะโดนพักสิทธิ์) — คนอื่น = ว่าง
--   ตาราง profiles ปิดคอลัมน์แพ็กเกจไว้ (เห็นได้แค่ชื่อ) จึงอ่านผ่านฟังก์ชันนี้ ซึ่งเปิดให้เฉพาะหัวปาร์ตี้
--   และสมาชิกของปาร์ตี้นั้น (is_party_member_of) — คนอื่นเรียกแล้วได้รายการว่าง
-- ฟังก์ชันใหม่ ไม่ได้แก้ของเดิม
-- ============================================================
begin;

create or replace function public.party_roster(p_host uuid)
returns table (
  member_id uuid,
  display_name text,
  is_host boolean,
  seat text,
  has_timers boolean,
  timers_label text,
  timers_expires_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select p.id,
         p.display_name,
         p.id = p_host,
         m.seat,
         public.has_timers_plan(p.id),
         case
           when coalesce(p.role, '') = 'admin' then 'แอดมิน'
           when p.legacy_unlimited then 'ไม่จำกัด'
           when p.plan_timers_expires_at > now() and p.plan_bundle_expires_at > now() then '4 in 1'
           when p.plan_timers_expires_at > now() then 'จับเวลาบอส'
         end,
         case when m.seat = 'plan' and coalesce(p.role, '') <> 'admin' and not coalesce(p.legacy_unlimited, false)
              then p.plan_timers_expires_at end
    from public.profiles p
    left join public.party_members m
      on m.member_id = p.id and m.host_id = p_host and m.removed_at is null
   where (auth.uid() = p_host or public.is_party_member_of(p_host))
     and (p.id = p_host or m.member_id is not null)
   order by p.id = p_host desc, m.created_at;
$function$;

revoke all on function public.party_roster(uuid) from public, anon;
grant execute on function public.party_roster(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว: anon_exec = false · auth_exec = true
select p.oid::regprocedure as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'party_roster';
