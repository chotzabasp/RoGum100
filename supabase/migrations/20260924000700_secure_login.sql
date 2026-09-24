-- ============================================================
-- ล็อกอินปลอดภัยขึ้น (รอบ 1 ของชุดความปลอดภัยการล็อกอิน)
--
-- ปัญหาเดิม: email_for_username(u) ใครก็เรียกได้โดยไม่ต้องล็อกอิน/ไม่ต้องรู้รหัส → รู้ username = ได้อีเมลของสมาชิก
-- แก้: email_for_login(ident, password) คืนอีเมลให้ "เฉพาะคนที่ใส่รหัสถูก" แล้วหน้าเว็บเอาอีเมลไปล็อกอินกับ
--      Supabase Auth ตามปกติ (Auth ตรวจรหัสซ้ำอีกชั้น) · ผิดตอบข้อความกลางๆ ไม่บอกว่า username มีจริงไหม
--      + ล็อกชั่วคราวเมื่อใส่ผิดซ้ำ แล้วปิด email_for_username ไม่ให้คนนอกเรียก
--
-- ล็อกชั่วคราว (นับความผิดในหน้าต่าง 30 นาที — ไม่ผิดเลย 30 นาที เริ่มนับใหม่ / ใส่ถูกล้างตัวนับของบัญชี+เครื่องนั้น):
--   บัญชีเดียวกันจาก IP เดียวกัน : ผิด 5 ครั้ง ล็อก 1 นาที · 8 ครั้ง 5 นาที · 11 ครั้งขึ้นไป 15 นาที
--     (ผูกกับ IP ด้วย กันคนอื่นแกล้งใส่ผิดจนเจ้าของบัญชีจริงเข้าไม่ได้)
--   บัญชีเดียวกันรวมทุก IP      : ผิด 20 ครั้ง ล็อก 15 นาที (กันสุ่มรหัสจากหลายเครื่อง)
--   IP เดียวกันรวมทุกบัญชี      : ผิด 30 ครั้ง ล็อก 15 นาที (กันไล่สุ่มหลายบัญชีจากเครื่องเดียว)
--
-- ผลลัพธ์เป็น jsonb (ไม่ raise error เพราะ raise แล้วตัวนับความผิดจะถูกยกเลิกไปด้วย):
--   {ok:true, email}  ·  {ok:false, error:'invalid'}  ·  {ok:false, error:'locked', wait_seconds}
-- ============================================================
begin;

create table if not exists public.login_attempts (
  key text primary key,          -- 'ui:<บัญชี>|<ip>'  'u:<บัญชี>'  'ip:<ip>'
  fails integer not null default 0,
  last_fail timestamptz,
  locked_until timestamptz
);
alter table public.login_attempts enable row level security;   -- ไม่มี policy = อ่าน/เขียนตรงไม่ได้ ผ่านฟังก์ชันเท่านั้น
revoke all on table public.login_attempts from anon, authenticated;

create or replace function public.email_for_login(p_ident text, p_password text)
returns jsonb
language plpgsql
volatile
security definer
set search_path to ''
as $function$
declare
  v_ident text := lower(btrim(coalesce(p_ident, '')));
  v_ip text;
  v_hdr text;
  v_uid uuid;
  v_email text;
  v_hash text;
  v_schema text;
  v_ok boolean := false;
  v_keys text[];
  v_wait int := 0;
  k text;
  r record;
  v_fails int;
  v_lock interval;
begin
  if v_ident = '' or p_password is null or p_password = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  -- IP ของผู้เรียก (Supabase ส่ง header มาให้ทาง request.headers) — หาไม่ได้ใช้ 'unknown'
  v_hdr := nullif(current_setting('request.headers', true), '');
  if v_hdr is not null then
    v_ip := nullif(btrim(split_part(coalesce(v_hdr::json ->> 'x-forwarded-for', v_hdr::json ->> 'x-real-ip', ''), ',', 1)), '');
  end if;
  v_ip := left(coalesce(v_ip, 'unknown'), 64);
  v_keys := array['ui:' || left(v_ident, 120) || '|' || v_ip, 'u:' || left(v_ident, 120), 'ip:' || v_ip];

  -- ติดล็อกอยู่ไหม (ถ้าล็อกอยู่ ไม่ตรวจรหัสเลย)
  for r in select key, locked_until from public.login_attempts where key = any(v_keys) and locked_until > now() loop
    v_wait := greatest(v_wait, ceil(extract(epoch from (r.locked_until - now())))::int);
  end loop;
  if v_wait > 0 then
    return jsonb_build_object('ok', false, 'error', 'locked', 'wait_seconds', v_wait);
  end if;

  if position('@' in v_ident) > 0 then
    select u.id, u.email, u.encrypted_password into v_uid, v_email, v_hash
      from auth.users u where lower(u.email) = v_ident limit 1;
  else
    select u.id, u.email, u.encrypted_password into v_uid, v_email, v_hash
      from public.profiles p join auth.users u on u.id = p.id
     where lower(p.username) = v_ident limit 1;
  end if;

  select n.nspname into v_schema
    from pg_catalog.pg_extension e join pg_catalog.pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pgcrypto';
  if v_schema is null then raise exception 'ระบบยังไม่มี pgcrypto'; end if;

  if v_hash is not null and v_hash <> '' then
    execute format('select %I.crypt($1, $2) = $2', v_schema) into v_ok using p_password, v_hash;
  else
    -- ไม่มีบัญชีนี้: ยังคำนวณ bcrypt ทิ้งหนึ่งรอบ ให้ใช้เวลาใกล้เคียงกรณีมีบัญชี (กันเดาจากความเร็วในการตอบ)
    -- cost 10 เท่ากับรหัสที่ Supabase Auth เก็บจริง (ค่าเริ่มต้นของ gen_salt คือ 6 ซึ่งเร็วกว่ามาก → ยังเดาได้)
    execute format('select %I.crypt($1, %I.gen_salt(''bf'', 10))', v_schema, v_schema) into v_hash using p_password;
    v_ok := false;
  end if;

  if v_ok then
    delete from public.login_attempts where key = v_keys[1];
    return jsonb_build_object('ok', true, 'email', v_email);
  end if;

  -- ใส่ผิด: นับทั้ง 3 กุญแจ แล้วตั้งเวลาล็อกตามเกณฑ์ของแต่ละแบบ
  foreach k in array v_keys loop
    insert into public.login_attempts as a (key, fails, last_fail)
    values (k, 1, now())
    on conflict (key) do update
      set fails = case when a.last_fail < now() - interval '30 minutes' then 1 else a.fails + 1 end,
          last_fail = now()
    returning a.fails into v_fails;
    v_lock := case
      when k like 'ui:%' then case when v_fails >= 11 then interval '15 minutes'
                                   when v_fails >= 8 then interval '5 minutes'
                                   when v_fails >= 5 then interval '1 minute' end
      when k like 'u:%' then case when v_fails >= 20 then interval '15 minutes' end
      else case when v_fails >= 30 then interval '15 minutes' end
    end;
    if v_lock is not null then
      update public.login_attempts set locked_until = now() + v_lock where key = k;
    end if;
  end loop;

  -- ล้างแถวเก่าที่ไม่ได้ใช้แล้วเป็นระยะ (ไม่ต้องตั้งงานตามเวลา)
  if random() < 0.02 then
    delete from public.login_attempts where last_fail < now() - interval '1 day' and (locked_until is null or locked_until < now());
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid');
end;
$function$;

revoke all on function public.email_for_login(text, text) from public;
grant execute on function public.email_for_login(text, text) to anon, authenticated;

-- ปิดฟังก์ชันเดิมที่เปิดเผยอีเมล (เหลือให้ระบบ/แอดมินใช้ใน SQL Editor ได้ แต่หน้าเว็บ/คนนอกเรียกไม่ได้แล้ว)
-- (หาจากชื่อ ไม่เดาชนิดพารามิเตอร์ — ถ้ามีหลายแบบก็ปิดทุกแบบ)
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as fn from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.proname = 'email_for_username' loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.fn);
    raise notice 'ปิด % แล้ว', r.fn;
  end loop;
end $$;

commit;
