-- ย้อนกลับ migration 20260929000300_announcement_rate_50 (รันเฉพาะเมื่อจำเป็น): คืน announcements_guard เป็น ±30% (เวอร์ชัน 20260929000100)
-- ถ้ารันไฟล์นี้ ต้องคืน RATE_MAX_DEVIATION ใน assets/app.js เป็น 0.30 ด้วย
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.announcements_guard()');
  if v_md5 is distinct from '1406e45ba19b3acc64826a3c504e1ec3' then
    raise exception 'announcements_guard ไม่ใช่เวอร์ชันของ 20260929000300 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

CREATE OR REPLACE FUNCTION public.announcements_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  min_exp timestamptz := now() + interval '1 minute';
  max_exp timestamptz := now() + interval '24 hours';
  v_ref numeric;
begin
  if tg_op = 'INSERT' then
    new.user_id    := auth.uid();
    select coalesce(p.display_name, 'สมาชิก') into new.user_name
      from public.profiles p where p.id = auth.uid();
    if new.user_name is null then new.user_name := 'สมาชิก'; end if;
    new.created_at := now();
    if new.expires_at is null or new.expires_at < min_exp then new.expires_at := min_exp; end if;
    if new.expires_at > max_exp then new.expires_at := max_exp; end if;
    new.ref_buy    := null;
  else
    -- แก้ไขประกาศ = เปลี่ยนได้แค่เซิร์ฟเวอร์กับราคา นาฬิกานับถอยหลังห้ามรีเซ็ต ลิงก์ Facebook ห้ามเปลี่ยน
    new.id           := old.id;
    new.user_id      := old.user_id;
    new.user_name    := old.user_name;
    new.created_at   := old.created_at;
    new.expires_at   := old.expires_at;
    new.facebook_url := old.facebook_url;
    -- ราคาอ้างอิงผู้ใช้แก้เองไม่ได้ · ไม่ได้แก้ราคา/เซิร์ฟเวอร์ = ไม่ต้องตรวจราคา
    if new.buy is not distinct from old.buy and new.server_id is not distinct from old.server_id then
      new.ref_buy := old.ref_buy;
      return new;
    end if;
    -- แก้ไขประกาศเทียบกับราคาอ้างอิงตอนลงประกาศ (แก้ซ้ำๆ ดันราคาขึ้นเองไม่ได้) · ย้ายเซิร์ฟ = คิดราคาอ้างอิงของเซิร์ฟใหม่
    new.ref_buy := case when new.server_id is distinct from old.server_id then null else old.ref_buy end;
  end if;
  -- ราคารับ M: ราคาอ้างอิง = ประกาศล่าสุดที่ยังไม่หมดอายุของเซิร์ฟนี้ "ของคนอื่น" · ไม่มี = ราคาตั้งต้นของแอดมิน (servers.buy)
  -- ไม่นับประกาศของตัวเอง (กันลงประกาศ/แก้ราคาต่อยอดจากราคาของตัวเอง) · ±30% ต้องตรงกับ RATE_MAX_DEVIATION ใน assets/app.js
  if new.ref_buy is null then
    select a.buy into v_ref from public.announcements a
     where a.server_id = new.server_id and a.expires_at > now() and a.buy > 0 and a.buy < 1000000
       and a.user_id is distinct from auth.uid()
     order by a.created_at desc limit 1;
    if v_ref is null then
      select s.buy into v_ref from public.servers s where s.id = new.server_id;
    end if;
    new.ref_buy := v_ref;
  end if;
  -- NaN ของ numeric มากกว่าทุกตัวเลข (ผ่าน > 0) → ตรวจตรงๆ · เพดาน 1,000,000 กัน Infinity / เลขเกินจริง
  if new.buy is null or new.buy = 'NaN'::numeric or new.buy <= 0 or new.buy >= 1000000 then
    raise exception 'ราคารับ M ไม่ถูกต้อง';
  end if;
  if new.ref_buy > 0 and abs(new.buy - new.ref_buy) > new.ref_buy * 0.30 then
    raise exception 'ราคาต่างจากราคาปัจจุบัน (%บ) เกิน 30%% กรุณาตรวจสอบราคาอีกครั้ง', new.ref_buy;
  end if;
  return new;
end; $function$;

commit;

notify pgrst, 'reload schema';

select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.announcements_guard()')) = 'fbc2e992f28e7705929ad04dbbb7c053'
    and exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                 and tgfoid = 'public.announcements_guard()'::regprocedure
                 and not tgisinternal and tgenabled <> 'D') as announcements_rate30_restored;
