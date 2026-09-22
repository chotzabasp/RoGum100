-- ============================================================
-- ปรับราคาเพิ่มเพื่อนเข้าปาร์ตี้จาก 20 แต้ม เป็น 50 แต้ม
-- (เนื้อหาอื่นในฟังก์ชันเหมือนเดิมทุกจุด แก้แค่ตัวเลขราคา 2 จุด)
-- ============================================================
begin;

create or replace function public.add_party_member(member_email text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$declare
  target_id uuid;
  caller_host_id uuid;
  ident text := lower(trim(member_email));
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

  update public.profiles set points = points - 50 where id = auth.uid() and points >= 50;
  if not found then raise exception 'แต้มไม่พอ (ต้องการ 50 แต้ม)'; end if;

  insert into public.party_members (host_id, member_id) values (caller_host_id, target_id);
end;$function$;

commit;
