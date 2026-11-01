-- ============================================================
-- ย้อนกลับ 20261101000100_server_slot_no_cap.sql — buy_server_slot กลับมามีเพดาน 12 ช่อง (ฉบับ 20260927001000 md5 4bc6cb58…)
-- บัญชีที่ซื้อเกิน 12 ไปแล้วยังเก็บช่องไว้ แค่ซื้อเพิ่มไม่ได้อีก · ต้องย้อนหน้าเว็บ (assets/app.js) ด้วย
-- ============================================================
begin;

set local lock_timeout = '5s';

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: เนื้อฟังก์ชันที่รันอยู่ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.buy_server_slot()');
  if v_md5 is distinct from '4542c727512afd27c98ad60b891966b0' then
    raise exception 'buy_server_slot ไม่ใช่ฉบับ 20261101000100 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end $guard$;

create or replace function public.buy_server_slot()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  cost int := 50;
  max_quota int := 12;
  cur_quota int;
  cur_points int;
  new_quota int;
begin
  if not public.is_active() then
    raise exception 'บัญชีหมดอายุ ต่ออายุก่อนจึงจะซื้อโควต้าเพิ่มได้';
  end if;

  select server_quota, points into cur_quota, cur_points
    from public.profiles where id = auth.uid() for update;
  if not found then
    raise exception 'ไม่พบโปรไฟล์';
  end if;

  if coalesce(cur_quota, 1) >= max_quota then
    raise exception 'มีช่องเซิร์ฟเวอร์ครบ % ช่องแล้ว (สูงสุด)', max_quota;
  end if;
  if coalesce(cur_points, 0) < cost then
    raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', cost;
  end if;

  update public.profiles
     set points = points - cost,
         server_quota = server_quota + 1
   where id = auth.uid()
   returning server_quota into new_quota;

  return new_quota;
end; $function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true (เนื้อฟังก์ชันตรงไฟล์นี้ · สิทธิ์เดิม: ผู้ล็อกอินเรียกได้ ผู้ไม่ล็อกอินเรียกไม่ได้)
select md5(replace(prosrc, E'\r', '')) = '4bc6cb58ef7f5a270bb84bcd86ec71f6'
       and has_function_privilege('authenticated', 'public.buy_server_slot()', 'execute')
       and not has_function_privilege('anon', 'public.buy_server_slot()', 'execute') as server_slot_cap_restored_ok
  from pg_proc where oid = to_regprocedure('public.buy_server_slot()');
