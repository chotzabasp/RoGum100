-- ============================================================
-- บังคับลิมิตบัญชีฟรีที่ฐานข้อมูล (เดิมกันแค่หน้าเว็บ — เรียก API ตรงก็เลี่ยงได้)
--   บัญชีนักลงทุน (merchant_entries): บันทึกได้ 5 รายการต่อวัน · ปลดล็อกด้วย has_trade_plan
--     (2 in 1 = feature 'accountItems', 3 in 1 / 4 in 1 = has_bundle_plan)
--   ยอดนักฟาม (farm_entries):         บันทึกได้ 3 ครั้งต่อวัน   · ปลดล็อกด้วย has_farm_plan
--     (1 in 1 = feature 'farm', 3 in 1 / 4 in 1 = has_bundle_plan)
--   บัญชีเก่าไม่จำกัด (legacy_unlimited — อยู่ใน has_bundle_plan แล้ว) และแอดมิน ไม่โดนลิมิต
--
-- ตัวเลขต้องตรงกับหน้าเว็บ: FREE_TRADE_DAILY_MAX / FREE_FARM_DAILY_MAX ใน index.html
--
-- กติกาการนับ (ตรงกับหน้าเว็บ):
--   - 1 แถว = 1 ครั้งที่กดบันทึก · นับทุกเซิร์ฟเวอร์รวมกัน
--   - "วัน" = วันตามเวลาไทย ของเวลาที่อยู่ในรายการ (ts) — รายการที่บันทึกตอนออฟไลน์เมื่อวาน
--     แล้วเพิ่งซิงก์วันนี้ จะนับเป็นของเมื่อวาน ไม่ไปกินโควต้าวันนี้
--   - แก้ไขรายการเดิม: ระบบซิงก์ส่งด้วย upsert (insert ... on conflict update) ซึ่งยิง trigger
--     "before insert" ด้วย → ถ้า id นี้มีอยู่แล้ว = แก้ไข ไม่นับ
--   - ลบรายการของวันนั้นทิ้ง = ได้โควต้าคืน (หน้าเว็บก็นับแบบเดียวกัน)
--   - บัญชีฟรีห้ามตั้งเวลารายการล่วงหน้าเกิน 1 วัน (กันใส่วันในอนาคตเพื่อเลี่ยงโควต้า)
--   - ไม่มีผู้ใช้ล็อกอิน (auth.uid() ว่าง เช่น งานของระบบ/service role) = ไม่ตรวจ
-- ============================================================
begin;

create or replace function public.enforce_free_entry_limit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit int;
  v_label text;
  v_plan_name text;
  v_unit text;
  v_day date;
  v_start bigint;
  v_end bigint;
  v_count int;
  v_exists boolean;
begin
  if v_uid is null or new.user_id is distinct from v_uid then return new; end if;
  if public.is_admin() then return new; end if;

  if TG_TABLE_NAME = 'merchant_entries' then
    if public.has_trade_plan(v_uid) then return new; end if;
    v_limit := 5; v_label := 'บันทึกซื้อ–ขาย'; v_unit := 'รายการ'; v_plan_name := '2 in 1, 3 in 1 หรือ 4 in 1';
    select exists(select 1 from public.merchant_entries where user_id = v_uid and id = new.id) into v_exists;
  elsif TG_TABLE_NAME = 'farm_entries' then
    if public.has_farm_plan(v_uid) then return new; end if;
    v_limit := 3; v_label := 'บันทึกต้นทุนต่อกั้ม'; v_unit := 'ครั้ง'; v_plan_name := '1 in 1, 3 in 1 หรือ 4 in 1';
    select exists(select 1 from public.farm_entries where user_id = v_uid and id = new.id) into v_exists;
  else
    return new;
  end if;

  -- แก้ไขรายการเดิม ไม่นับโควต้า
  if v_exists then return new; end if;

  if new.ts > (extract(epoch from now()) * 1000)::bigint + 86400000 then
    raise exception 'เวลาของรายการไม่ถูกต้อง';
  end if;

  -- กันสองแท็บบันทึกพร้อมกันแล้วนับพลาด: ต่อคิวรายการของผู้ใช้คนเดียวกันทีละรายการ
  perform pg_advisory_xact_lock(hashtext(TG_TABLE_NAME || ':' || v_uid::text));

  v_day := (to_timestamp(new.ts / 1000.0) at time zone 'Asia/Bangkok')::date;
  v_start := (extract(epoch from (v_day::timestamp at time zone 'Asia/Bangkok')) * 1000)::bigint;
  v_end := v_start + 86400000;

  if TG_TABLE_NAME = 'merchant_entries' then
    select count(*) into v_count from public.merchant_entries
     where user_id = v_uid and ts >= v_start and ts < v_end;
  else
    select count(*) into v_count from public.farm_entries
     where user_id = v_uid and ts >= v_start and ts < v_end;
  end if;

  if v_count >= v_limit then
    raise exception 'บัญชีฟรี%ได้ % % ต่อวัน — วันนี้ครบแล้ว (สมัครแพ็กเกจ % เพื่อบันทึกไม่จำกัด)',
      v_label, v_limit, v_unit, v_plan_name;
  end if;

  return new;
end;
$function$;

revoke all on function public.enforce_free_entry_limit() from public, anon, authenticated;

drop trigger if exists merchant_entries_free_limit on public.merchant_entries;
create trigger merchant_entries_free_limit
  before insert on public.merchant_entries
  for each row execute function public.enforce_free_entry_limit();

drop trigger if exists farm_entries_free_limit on public.farm_entries;
create trigger farm_entries_free_limit
  before insert on public.farm_entries
  for each row execute function public.enforce_free_entry_limit();

commit;
