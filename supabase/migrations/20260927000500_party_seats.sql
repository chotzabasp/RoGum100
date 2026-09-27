-- ============================================================
-- เพิ่มเพื่อนเข้าปาร์ตี้: ฟรีถ้าเพื่อนมีแพ็กเกจ "จับเวลาบอส" (2026-09-27)
--   · เพื่อนมีแพ็กเกจจับเวลาบอส (รวม 4 in 1) → เพิ่มฟรี (seat = 'plan')
--     แพ็กหมดอายุเมื่อไหร่ = ใช้ข้อมูลปาร์ตี้ไม่ได้ (is_party_member_of เป็น false) จนกว่าจะ
--     ต่ออายุ (กลับมาใช้ได้เอง) หรือจ่าย 50 แต้มเองผ่าน buy_party_seat() → seat = 'paid' (ถาวร แบบแพ็กฟรี)
--   · เพื่อนไม่มีแพ็กเกจ → คนกดเพิ่มจ่าย 50 แต้ม (seat = 'paid' ถาวร) เหมือนเดิม
--   · สมาชิกที่มีอยู่แล้วทั้งหมด = 'paid' (จ่ายแล้ว ไม่กระทบ)
--   1) party_members.seat
--   2) is_party_member_of(): เพิ่มเงื่อนไข seat = 'paid' หรือยังมีแพ็กเกจจับเวลาบอส (เนื้อเดิมจากฐานข้อมูลจริง md5 323e03b4a441e3a43961af6ebdd91a1b)
--   3) add_party_member(member_email, p_expected_cost default null) คืนชื่อ/ราคา/ประเภท — เว็บรุ่นเก่าที่ส่งค่าเดียวยังใช้ได้
--   4) party_add_quote(): ให้กล่องเพิ่มเพื่อนโชว์ชื่อ + ราคาก่อนยืนยัน (ตรวจเงื่อนไขเดียวกัน ข้อความเดียวกัน ไม่แก้อะไร)
--   5) buy_party_seat(): สมาชิกที่เข้าฟรีจ่าย 50 แต้มเองเพื่ออยู่ถาวร
-- leave_party ไม่ได้ใช้ is_party_member_of — คนที่แพ็กหมดยังกดออกจากปาร์ตี้ได้ตามปกติ
-- มีตัวกันในไฟล์: ถ้าฟังก์ชันในฐานข้อมูลไม่ตรงกับที่ตรวจไว้ จะหยุดทันที ไม่มีอะไรถูกแก้
-- ============================================================
begin;

do $guard$
declare v text; bad text := '';
begin
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.add_party_member(text)'::regprocedure;
  if v is distinct from 'e8a1548f40dc3a9cd1ce22bdf690827c' then bad := bad || ' add_party_member=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.is_party_member_of(uuid)'::regprocedure;
  if v is distinct from '323e03b4a441e3a43961af6ebdd91a1b' then bad := bad || ' is_party_member_of=' || coalesce(v, '-'); end if;
  if bad <> '' then raise exception 'หยุด: ฟังก์ชันในฐานข้อมูลไม่ตรงกับที่ตรวจไว้ —% · ไม่มีอะไรถูกแก้', bad; end if;
end
$guard$;

alter table public.party_members add column if not exists seat text not null default 'paid';
alter table public.party_members drop constraint if exists party_members_seat_check;
alter table public.party_members add constraint party_members_seat_check check (seat in ('paid', 'plan'));

CREATE OR REPLACE FUNCTION public.is_party_member_of(host uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1 from public.party_members
    where host_id = host and member_id = auth.uid() and removed_at is null
      and (seat = 'paid' or public.has_timers_plan(auth.uid()))
  );
$function$;

drop function public.add_party_member(text);

create function public.add_party_member(member_email text, p_expected_cost integer default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$declare
  target_id uuid;
  caller_host_id uuid;
  ident text := lower(trim(member_email));
  v_cost integer;
  v_seat text;
  v_name text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if ident is null or ident = '' then raise exception 'กรุณากรอกอีเมลหรือ Username ของเพื่อน'; end if;

  select host_id into caller_host_id from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host_id is null then
    caller_host_id := auth.uid();
  end if;

  select p.id into target_id from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = ident or p.username = ident
   limit 1;
  if target_id is null then raise exception 'ไม่พบบัญชีที่ใช้อีเมลหรือ Username นี้'; end if;
  if target_id = caller_host_id then raise exception 'เพิ่มคนนี้ไม่ได้ (เป็นหัวปาร์ตี้อยู่แล้ว)'; end if;

  if exists(select 1 from public.party_members where host_id=caller_host_id and member_id=target_id and removed_at is null) then
    raise exception 'เพื่อนคนนี้อยู่ในปาร์ตี้อยู่แล้ว';
  end if;
  if exists(select 1 from public.party_members where member_id=target_id and removed_at is null) then
    raise exception 'คนนี้เข้าร่วมปาร์ตี้อื่นอยู่แล้ว ต้องออกจากปาร์ตี้เดิมก่อนถึงจะเพิ่มเข้าปาร์ตี้นี้ได้';
  end if;

  -- เพื่อนมีแพ็กเกจ "จับเวลาบอส" = เข้าฟรี (seat 'plan' ใช้ได้ตราบที่แพ็กยังไม่หมด) · ไม่มี = คนกดเพิ่มจ่าย 50 แต้ม (seat 'paid' ถาวร)
  if public.has_timers_plan(target_id) then
    v_cost := 0; v_seat := 'plan';
  else
    v_cost := 50; v_seat := 'paid';
  end if;
  -- หน้าเว็บส่งราคาที่ผู้ใช้เห็นมาด้วย — แพ็กเกจเพื่อนเปลี่ยนระหว่างนั้น = ไม่เพิ่ม กันเสียแต้มโดยไม่รู้ตัว
  if p_expected_cost is not null and p_expected_cost <> v_cost then
    raise exception 'ค่าเข้าปาร์ตี้ของเพื่อนคนนี้เปลี่ยนไปแล้ว — กดตรวจสอบใหม่อีกครั้ง';
  end if;
  if v_cost > 0 then
    update public.profiles set points = points - v_cost where id = auth.uid() and points >= v_cost;
    if not found then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_cost; end if;
  end if;

  insert into public.party_members (host_id, member_id, seat) values (caller_host_id, target_id, v_seat);
  select display_name into v_name from public.profiles where id = target_id;
  return jsonb_build_object('display_name', v_name, 'cost', v_cost, 'seat', v_seat);
end;$function$;

revoke all on function public.add_party_member(text, integer) from public, anon;
grant execute on function public.add_party_member(text, integer) to authenticated;

create or replace function public.party_add_quote(member_email text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$declare
  target_id uuid;
  caller_host_id uuid;
  ident text := lower(trim(member_email));
  v_name text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if ident is null or ident = '' then raise exception 'กรุณากรอกอีเมลหรือ Username ของเพื่อน'; end if;

  select host_id into caller_host_id from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host_id is null then
    caller_host_id := auth.uid();
  end if;

  select p.id into target_id from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = ident or p.username = ident
   limit 1;
  if target_id is null then raise exception 'ไม่พบบัญชีที่ใช้อีเมลหรือ Username นี้'; end if;
  if target_id = caller_host_id then raise exception 'เพิ่มคนนี้ไม่ได้ (เป็นหัวปาร์ตี้อยู่แล้ว)'; end if;

  if exists(select 1 from public.party_members where host_id=caller_host_id and member_id=target_id and removed_at is null) then
    raise exception 'เพื่อนคนนี้อยู่ในปาร์ตี้อยู่แล้ว';
  end if;
  if exists(select 1 from public.party_members where member_id=target_id and removed_at is null) then
    raise exception 'คนนี้เข้าร่วมปาร์ตี้อื่นอยู่แล้ว ต้องออกจากปาร์ตี้เดิมก่อนถึงจะเพิ่มเข้าปาร์ตี้นี้ได้';
  end if;

  select display_name into v_name from public.profiles where id = target_id;
  return jsonb_build_object('display_name', v_name,
                            'cost', case when public.has_timers_plan(target_id) then 0 else 50 end);
end;$function$;

revoke all on function public.party_add_quote(text) from public, anon;
grant execute on function public.party_add_quote(text) to authenticated;

create or replace function public.buy_party_seat()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.party_members%rowtype;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  select * into v_row from public.party_members
   where member_id = auth.uid() and removed_at is null
   limit 1
   for update;
  if not found then raise exception 'คุณไม่ได้อยู่ในปาร์ตี้ของใคร'; end if;
  if v_row.seat = 'paid' then raise exception 'คุณเป็นสมาชิกถาวรของปาร์ตี้นี้อยู่แล้ว'; end if;
  perform set_config('app.points_ledger_detail', 'จ่าย 50 แต้ม อยู่ปาร์ตี้ถาวร (แบบแพ็กฟรี)', true);
  update public.profiles set points = points - 50 where id = auth.uid() and points >= 50;
  if not found then raise exception 'แต้มไม่พอ (ต้องการ 50 แต้ม)'; end if;
  update public.party_members set seat = 'paid'
   where host_id = v_row.host_id and member_id = auth.uid() and removed_at is null;
end;
$function$;

revoke all on function public.buy_party_seat() from public, anon;
grant execute on function public.buy_party_seat() to authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 4 แถว · has_seat = true · seats = paid:<จำนวนสมาชิกเดิม> ทุกแถว:
--   add_party_member(text,integer) a9a158bf94be92763cb7240e2c98f13e anon=false auth=true (ต้องไม่มี add_party_member(text) เหลือ)
--   buy_party_seat() 89431b10e9951527d555f7e7c9c5f9a5 anon=false auth=true
--   is_party_member_of(uuid) 35d5cf80b0ad6a5f2cb34e715d9f3bde
--   party_add_quote(text) e4fc9b1ee9ee5a6153a3c180bfd9a853 anon=false auth=true
select p.oid::regprocedure as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       exists(select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'party_members' and column_name = 'seat') as has_seat,
       (select string_agg(seat || ':' || n, ', ') from (select seat, count(*) n from public.party_members group by seat) s) as seats
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('add_party_member', 'buy_party_seat', 'is_party_member_of', 'party_add_quote')
 order by 1;
