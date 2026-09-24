-- ============================================================
-- เช็ครหัสผ่านเดิมตอนเปลี่ยนรหัส (หน้าตั้งค่า) — แทนการล็อกอินซ้ำเพื่อเช็ค
-- เหตุผล: พอเปิด Captcha ใน Supabase Auth การล็อกอิน (signInWithPassword) ต้องแนบ captchaToken ทุกครั้ง
-- หน้าตั้งค่าไม่มีกล่อง Captcha → เปลี่ยนรหัสจะพัง จึงย้ายการเช็ครหัสเดิมมาทำในฐานข้อมูล (เฉพาะรหัสของตัวเอง)
--
-- verify_my_password(p_password) → {ok:true} | {ok:false, error:'invalid'} | {ok:false, error:'locked', wait_seconds}
-- ใส่ผิด 5 ครั้งใน 30 นาที ล็อก 5 นาที (กันใครแอบมาใช้เครื่องที่ค้างล็อกอินไว้แล้วสุ่มรหัส) — ใช้ตาราง login_attempts เดิม
-- ไม่ raise error เพราะ raise แล้วตัวนับความผิดจะถูกยกเลิกไปด้วย
-- ============================================================
begin;

create or replace function public.verify_my_password(p_password text)
returns jsonb
language plpgsql
volatile
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_hash text;
  v_schema text;
  v_ok boolean := false;
  v_locked timestamptz;
  v_fails int;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  v_key := 'self:' || v_uid::text;

  select locked_until into v_locked from public.login_attempts where key = v_key;
  if v_locked is not null and v_locked > now() then
    return jsonb_build_object('ok', false, 'error', 'locked',
                              'wait_seconds', ceil(extract(epoch from (v_locked - now())))::int);
  end if;

  select encrypted_password into v_hash from auth.users where id = v_uid;
  select n.nspname into v_schema
    from pg_catalog.pg_extension e join pg_catalog.pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pgcrypto';
  if v_schema is null then raise exception 'ระบบยังไม่มี pgcrypto'; end if;
  if p_password is not null and p_password <> '' and v_hash is not null and v_hash <> '' then
    execute format('select %I.crypt($1, $2) = $2', v_schema) into v_ok using p_password, v_hash;
  end if;

  if v_ok then
    delete from public.login_attempts where key = v_key;
    return jsonb_build_object('ok', true);
  end if;

  insert into public.login_attempts as a (key, fails, last_fail)
  values (v_key, 1, now())
  on conflict (key) do update
    set fails = case when a.last_fail < now() - interval '30 minutes' then 1 else a.fails + 1 end,
        last_fail = now()
  returning a.fails into v_fails;
  if v_fails >= 5 then
    update public.login_attempts set locked_until = now() + interval '5 minutes' where key = v_key;
  end if;
  return jsonb_build_object('ok', false, 'error', 'invalid');
end;
$function$;

revoke all on function public.verify_my_password(text) from public, anon;
grant execute on function public.verify_my_password(text) to authenticated;

commit;
