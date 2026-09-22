-- ============================================================
-- เปลี่ยนข้อความ error ตอนบล็อกสมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ ให้ตรงกับข้อความฝั่งหน้าเว็บที่แก้ไปแล้ว
-- (เนื้อหาอื่นในฟังก์ชันเหมือนเดิมทุกจุด แก้แค่ข้อความ error 1 บรรทัดต่อฟังก์ชัน)
-- ============================================================
begin;

create or replace function public.add_boss_capped(p_owner uuid, p_boss_id text, p_server_id text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not (auth.uid() = p_owner or public.is_party_member_of(p_owner)) then
    raise exception 'ไม่มีสิทธิ์เพิ่มบอสให้บัญชีนี้';
  end if;
  if auth.uid() <> p_owner and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;
  if not public.has_timers_plan(p_owner) then
    if (select count(*) from public.user_bosses where user_id = p_owner) >= 1 then
      raise exception 'บัญชีฟรีจับเวลาบอสได้สูงสุด 1 ตัว — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อไม่จำกัด';
    end if;
  end if;
  insert into public.user_bosses (user_id, boss_id, server_id) values (p_owner, p_boss_id, p_server_id);
end;
$function$;

create or replace function public.record_kill(p_boss_id text, p_boss_name text, p_killed_at timestamp with time zone, p_items text[])
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  caller_host uuid;
  new_kill uuid;
  it text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if p_boss_id is null or char_length(p_boss_id) not between 1 and 200 then raise exception 'รหัสบอสไม่ถูกต้อง'; end if;
  if p_boss_name is null or char_length(btrim(p_boss_name)) not between 1 and 120 then raise exception 'ชื่อบอสไม่ถูกต้อง'; end if;
  if coalesce(cardinality(p_items), 0) > 50 then raise exception 'บันทึกไอเทมได้ไม่เกิน 50 ชิ้นต่อครั้ง'; end if;
  select host_id into caller_host from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host is null then caller_host := auth.uid(); end if;

  if caller_host <> auth.uid() and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;

  insert into public.kills (host_id, boss_id, boss_name, killed_by, killed_at)
    values (caller_host, p_boss_id, p_boss_name, auth.uid(), p_killed_at)
    returning id into new_kill;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    if it is null or char_length(btrim(it)) not between 1 and 120 then raise exception 'ชื่อไอเทมไม่ถูกต้อง'; end if;
    insert into public.kill_items (kill_id, host_id, name) values (new_kill, caller_host, it);
  end loop;
  return new_kill;
end;
$function$;

commit;
