-- ============================================================
-- ประกาศรับ M: ราคาอ้างอิงของตัวกัน ±50% ต้องมีเสมอ (ผลทดสอบ b4/b5 ของผู้ใช้ 29 ก.ย. 2569 — ผู้ใช้สั่ง "ทำเลย")
-- สาเหตุ: ราคาตั้งต้นของแอดมิน (servers.buy) เป็น 0 ทุกเซิร์ฟ → เซิร์ฟที่ยังไม่มีประกาศของคนอื่น ราคาอ้างอิง = 0
--   = ไม่ตรวจเลย ทั้งตอนลงใหม่ และตอนแก้ไขประกาศนั้นตลอดไป (แก้ 300 → 5000 ได้)
-- แก้ announcements_guard() เฉพาะส่วนคิดราคาอ้างอิง: 1) ประกาศล่าสุดของคนอื่นที่ยังไม่หมดอายุ 2) ราคาตั้งต้นแอดมิน > 0
--   3) ประกาศล่าสุดของเซิร์ฟนี้ของใครก็ได้ (รวมของตัวเอง/หมดอายุ) ภายใน 7 วัน 4) ไม่มีเลย = ราคาของประกาศนี้เอง
--   (แก้ไขในเซิร์ฟเดิม = ราคาก่อนแก้) · ประกาศเดิมที่ราคาอ้างอิงเป็น 0/ว่าง คิดใหม่ตอนแก้ครั้งถัดไป
--   ส่วนอื่นคงเดิมทุกตัวอักษร (ล็อกเวลา/ลิงก์ Facebook, ราคา > 0 และ < 1,000,000, ข้อความ "เกิน 50%")
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260929000500_announcement_ref_chain_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.announcements_guard()');
  if v_md5 is distinct from '1406e45ba19b3acc64826a3c504e1ec3' then
    raise exception 'announcements_guard ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
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
    -- ประกาศเก่าที่ราคาอ้างอิงเป็น 0/ว่าง (ลงตอนไม่มีราคาให้เทียบ) = คิดใหม่ตามลำดับด้านล่าง (เดิม 0 = แก้เป็นราคาเท่าไหร่ก็ได้ตลอด)
    new.ref_buy := case when new.server_id is distinct from old.server_id or coalesce(old.ref_buy, 0) <= 0 then null else old.ref_buy end;
  end if;
  -- ราคารับ M: ราคาอ้างอิง (±50% ต้องตรงกับ RATE_MAX_DEVIATION และ announcementRefBuy ใน assets/app.js) ตามลำดับ
  --   1) ประกาศล่าสุดที่ยังไม่หมดอายุของเซิร์ฟนี้ "ของคนอื่น" (ไม่นับของตัวเอง กันดันราคาต่อยอดจากราคาของตัวเอง)
  --   2) ราคาตั้งต้นของแอดมิน (servers.buy) ถ้าตั้งไว้มากกว่า 0
  --   3) ประกาศล่าสุดของเซิร์ฟนี้ ของใครก็ได้ รวมของตัวเองและที่หมดอายุแล้ว ภายใน 7 วัน (ไม่นับแถวนี้เอง)
  --      — เก่ากว่านั้นไม่ใช้ ราคาตลาดอาจเปลี่ยนไปมากแล้ว (ประกาศที่หมดอายุไม่ถูกลบ)
  --   4) ไม่มีเลย (ประกาศแรกของเซิร์ฟ) = ราคาของประกาศนี้เอง · แก้ไขในเซิร์ฟเดิม = ราคาก่อนแก้
  -- เดิมข้อ 2 เป็น 0 ทุกเซิร์ฟ → ไม่มีประกาศของคนอื่น = ไม่ตรวจเลย ทั้งตอนลงและตอนแก้ (ผลทดสอบ b4/b5 ผู้ใช้ 29 ก.ย.)
  if new.ref_buy is null then
    select a.buy into v_ref from public.announcements a
     where a.server_id = new.server_id and a.expires_at > now() and a.buy > 0 and a.buy < 1000000
       and a.user_id is distinct from auth.uid()
     order by a.created_at desc limit 1;
    if v_ref is null then
      select s.buy into v_ref from public.servers s where s.id = new.server_id and s.buy > 0;
    end if;
    if v_ref is null then
      select a.buy into v_ref from public.announcements a
       where a.server_id = new.server_id and a.buy > 0 and a.buy < 1000000
         and a.created_at > now() - interval '7 days' and a.id is distinct from new.id
       order by a.created_at desc limit 1;
    end if;
    if v_ref is null then
      v_ref := new.buy;
      if tg_op = 'UPDATE' then
        if new.server_id is not distinct from old.server_id and old.buy > 0 and old.buy < 1000000 then
          v_ref := old.buy;
        end if;
      end if;
    end if;
    new.ref_buy := v_ref;
  end if;
  -- NaN ของ numeric มากกว่าทุกตัวเลข (ผ่าน > 0) → ตรวจตรงๆ · เพดาน 1,000,000 กัน Infinity / เลขเกินจริง
  if new.buy is null or new.buy = 'NaN'::numeric or new.buy <= 0 or new.buy >= 1000000 then
    raise exception 'ราคารับ M ไม่ถูกต้อง';
  end if;
  if new.ref_buy > 0 and abs(new.buy - new.ref_buy) > new.ref_buy * 0.50 then
    raise exception 'ราคาต่างจากราคาปัจจุบัน (%บ) เกิน 50%% กรุณาตรวจสอบราคาอีกครั้ง', new.ref_buy;
  end if;
  return new;
end; $function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.announcements_guard()')) = 'b618021fffef0b89027c8405d554a59d'
    and exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                 and tgfoid = 'public.announcements_guard()'::regprocedure
                 and not tgisinternal and tgenabled <> 'D') as announcements_ref_chain_ok;
