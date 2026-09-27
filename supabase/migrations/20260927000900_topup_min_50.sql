-- ============================================================
-- เติมแต้มผ่าน QR (TMWEASY): ยอดขั้นต่ำ 50 บาท (เดิม 20) — ต้องตรงกับ TOPUP_MIN_AMOUNT ใน assets/app.js
--   เพิ่มการเช็คใน trigger topup_rate_guard() (BEFORE INSERT บน topup_transactions) เฉพาะ provider = 'tmweasy'
--   แอดมินเติมแต้มให้เอง (provider = 'manual') ไม่ติดขั้นต่ำนี้ · ส่วนจำกัด 5 ครั้ง/ชั่วโมง คงเดิมทุกตัวอักษร
--   Edge Function tmweasy-create-pay ไม่ต้องแก้/deploy — ยอด 20-49 ที่ยิงตรงไม่ผ่านหน้าเว็บจะถูก trigger นี้ปฏิเสธ
--   (Edge Function ตอบกลับข้อความกลาง "ไม่สามารถสร้างรายการเติมเงินได้")
-- เขียนจาก 20260922000100_hardening_round2.sql (เนื้อฟังก์ชันที่รันอยู่ md5 89c17b5e…) — เพิ่ม 3 บรรทัด + คอมเมนต์ 1 บรรทัด
-- create or replace ไม่แตะ trigger ที่ผูกอยู่ และคง revoke เดิมไว้
-- ============================================================
begin;

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: เนื้อฟังก์ชันที่รันอยู่ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare v_md5 text;
begin
  select md5(replace(p.prosrc, E'\r', '')) into v_md5
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'topup_rate_guard';
  if v_md5 is distinct from '89c17b5e9e22c8396da9fa39f1a77129' then
    raise exception 'topup_rate_guard ในฐานข้อมูลไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้ ส่ง pg_get_functiondef มาให้ดูก่อน', v_md5;
  end if;
end $guard$;

create or replace function public.topup_rate_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.provider = 'tmweasy' then
    -- ยอดเติมผ่าน QR ขั้นต่ำ 50 บาท (ตรงกับ TOPUP_MIN_AMOUNT ใน assets/app.js) — แอดมินเติมเอง (manual) ไม่ติด
    if new.requested_amount is null or new.requested_amount < 50 then
      raise exception 'ยอดเติมขั้นต่ำ 50 บาท';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('topup_rate:' || new.user_id::text, 0));
    if (select count(*) from public.topup_transactions
         where user_id = new.user_id and provider = 'tmweasy'
           and status in ('pending', 'failed', 'expired')
           and created_at > now() - interval '1 hour') >= 5 then
      raise exception 'คุณทำรายการมากเกินไป ติดต่อแอดมินเพื่อทำรายการ';
    end if;
  end if;
  return new;
end;
$function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้: body_ok = true, has_min_50 = true, keeps_rate_limit = true,
-- trigger_on = true, anon_exec = false, auth_exec = false
select md5(replace(p.prosrc, E'\r', '')) = '7e3870419c52d2c664f8f950b41e816f' as body_ok,
       p.prosrc like '%requested_amount < 50%' as has_min_50,
       p.prosrc like '%ทำรายการมากเกินไป%' as keeps_rate_limit,
       exists(select 1 from pg_trigger t
               where t.tgname = 'topup_rate_guard_trg'
                 and t.tgrelid = 'public.topup_transactions'::regclass
                 and not t.tgisinternal) as trigger_on,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'topup_rate_guard';
