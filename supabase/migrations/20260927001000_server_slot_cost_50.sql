-- ============================================================
-- ราคาเพิ่มช่องเซิร์ฟเวอร์: 30 → 50 แต้มต่อช่อง — ต้องตรงกับ SERVER_SLOT_COST ใน assets/app.js
-- เปลี่ยนบรรทัดเดียว (cost int := 50) ส่วนอื่นคงเดิมทุกตัวอักษรจาก 20260924000100_server_slot_cap.sql
-- (เพดาน 12 ช่อง, ต้องไม่หมดอายุ, แต้มต้องพอ — เนื้อฟังก์ชันที่รันอยู่ md5 d8d6b377…)
-- ช่องที่ซื้อไปแล้วไม่กระทบ ไม่คิดย้อนหลัง · create or replace คงสิทธิ์ (grant/revoke) เดิมไว้
-- ============================================================
begin;

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: เนื้อฟังก์ชันที่รันอยู่ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare v_md5 text;
begin
  select md5(replace(p.prosrc, E'\r', '')) into v_md5
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'buy_server_slot';
  if v_md5 is distinct from 'd8d6b377a9f25d3ef320bdafd5c1e287' then
    raise exception 'buy_server_slot ในฐานข้อมูลไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้ ส่ง pg_get_functiondef มาให้ดูก่อน', v_md5;
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

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้: body_ok = true, cost_50 = true, keeps_cap_12 = true,
-- anon_exec = false, auth_exec = true
select md5(replace(p.prosrc, E'\r', '')) = '4bc6cb58ef7f5a270bb84bcd86ec71f6' as body_ok,
       p.prosrc like '%cost int := 50;%' as cost_50,
       p.prosrc like '%max_quota int := 12;%' as keeps_cap_12,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'buy_server_slot';
