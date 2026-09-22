-- ============================================================
-- RPC ให้สมาชิกปาร์ตี้เช็คได้ว่า "หัวปาร์ตี้กำลังดูเซิร์ฟเวอร์ไหนอยู่" (หน้าจับเวลาบอส)
-- เดิมค่า timersServer เป็นข้อมูลส่วนตัวในตาราง user_app_data (RLS อ่านได้แค่เจ้าของแถว)
-- อ่านข้ามบัญชีไม่ได้ ฟังก์ชันนี้เป็น security definer ให้สมาชิกปาร์ตี้ (หรือหัวปาร์ตี้เอง)
-- อ่านค่านี้ของ "หัวปาร์ตี้" ได้ ใช้เทียบกับเซิร์ฟเวอร์ที่ตัวเองเลือกอยู่ เพื่อเตือน/บล็อกถ้าไม่ตรงกัน
-- ============================================================
begin;

create or replace function public.party_active_server(p_host uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_server text;
begin
  if not (auth.uid() = p_host or public.is_party_member_of(p_host)) then
    raise exception 'ไม่มีสิทธิ์เข้าถึงปาร์ตี้นี้';
  end if;
  select value #>> '{}' into v_server
  from public.user_app_data
  where user_id = p_host and key = 'timersServer';
  return v_server;
end;
$$;

revoke all on function public.party_active_server(uuid) from public, anon;
grant execute on function public.party_active_server(uuid) to authenticated;

commit;
