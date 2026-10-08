-- ============================================================
-- ประกาศรับ M: 12 ชม. ลงฟรี (ผู้ใช้สั่ง 8 ต.ค. 2569 — อยากให้คนลองใช้ประกาศ) · 1 / 3 / 6 ชม. ยัง 3 / 5 / 8 แต้มเท่าเดิม
--   ต้องตรงกับ ANNOUNCE_DURATION_OPTIONS ใน assets/app.js (12 ชม. cost:0 → ปุ่มขึ้น "(ฟรี)")
-- ประกาศฟรีลงได้ 1 ประกาศต่อเซิร์ฟเวอร์ต่อคน (ที่ยังไม่หมดเวลา) — ลงหลายเซิร์ฟได้ · หมดเวลา/ยกเลิกแล้วลงฟรีใหม่ได้
--   ประกาศแบบเสียแต้ม (1 / 3 / 6 ชม.) ไม่นับ และยังลงได้ไม่จำกัดเหมือนเดิม
--   ประกาศฟรี = ยาว 12 ชม. พอดี (expires_at - created_at) — สองคอลัมน์นี้ announcements_guard ตั้งเองตอนลง
--   และล็อกไว้ตอนแก้ไข ผู้ใช้เปลี่ยนไม่ได้ · ประกาศ 12 ชม. ที่ลงแบบเสียแต้มก่อนรันไฟล์นี้ก็นับเป็นประกาศฟรีด้วย
--   (อยู่ได้ไม่เกิน 12 ชม. หลังรัน)
-- 1) post_announcement(): 12 ชม. = 0 แต้ม ไม่แตะแต้มเลย (ประวัติแต้มไม่ขึ้นบรรทัด 0 แต้ม) + ตรวจลิมิตก่อนลง
--    ส่วนอื่นคงเดิมจาก 20260927000800 (บัญชีต้องยังใช้งานได้ · ต้องมีลิงก์ Facebook · ราคาตรวจใน announcements_guard)
-- 2) announcements_free_limit() + trigger ใหม่ BEFORE UPDATE OF server_id — หน้าต่าง "แก้ไขประกาศ" ย้ายเซิร์ฟได้
--    กันลงฟรีในเซิร์ฟอื่นแล้วย้ายมาซ้อนในเซิร์ฟที่มีประกาศฟรีอยู่แล้ว (ไม่งั้นลิมิตข้อ 1 เลี่ยงได้ไม่จำกัด)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261008000200_announcement_12h_free_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)');
  if v_md5 is distinct from 'f7f03aa953088949f9bfb83acca1d6b6' then
    raise exception 'post_announcement ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  -- trigger ล็อกเวลาของประกาศต้องมีอยู่ (ลิมิตประกาศฟรีนับจาก created_at / expires_at ที่ trigger นี้ตั้งและล็อกไว้)
  if not exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                  and tgname = 'announcements_guard_trg' and not tgisinternal and tgenabled <> 'D') then
    raise exception 'ไม่พบ trigger announcements_guard_trg — ไม่มีอะไรถูกแก้';
  end if;
  -- ของใหม่ต้องยังไม่มี (กันรันซ้ำ)
  if to_regprocedure('public.announcements_free_limit()') is not null then
    raise exception 'มี announcements_free_limit อยู่แล้ว (เคยรันไฟล์นี้แล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) post_announcement: 12 ชม. ฟรี + ลิมิต 1 ประกาศฟรีต่อเซิร์ฟเวอร์ ----------
CREATE OR REPLACE FUNCTION public.post_announcement(p_server_id text, p_buy numeric, p_duration_ms bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_cost int;
begin
  if not public.is_active() then
    raise exception 'บัญชีหมดอายุ ต่ออายุก่อนลงประกาศ';
  end if;
  if coalesce(btrim((select facebook_url from public.profiles where id = auth.uid())), '') = '' then
    raise exception 'กรุณาใส่ลิงก์ Facebook ที่หน้า "ตั้งค่า" ก่อนลงประกาศ';
  end if;
  v_cost := case p_duration_ms
    when 3600000 then 3    -- 1 ชม.
    when 10800000 then 5   -- 3 ชม.
    when 21600000 then 8   -- 6 ชม.
    when 43200000 then 0   -- 12 ชม. ฟรี (1 ประกาศต่อเซิร์ฟเวอร์)
    else null
  end;
  if v_cost is null then
    raise exception 'ระยะเวลาไม่ถูกต้อง';
  end if;
  if v_cost = 0 then
    -- คิวเดียวกับ announcements_free_limit (กันสองแท็บลงฟรี/ย้ายเซิร์ฟพร้อมกันแล้วผ่านทั้งคู่)
    perform pg_advisory_xact_lock(hashtext('announce_free:' || auth.uid()::text));
    if exists (select 1 from public.announcements
                where user_id = auth.uid() and server_id = p_server_id and expires_at > now()
                  and expires_at - created_at = interval '12 hours') then
      raise exception 'ประกาศฟรี 12 ชม. ลงได้ 1 ประกาศต่อเซิร์ฟเวอร์ — เซิร์ฟนี้มีประกาศฟรีของคุณอยู่แล้ว (เปลี่ยนราคาได้ที่ "แก้ไขประกาศ")';
    end if;
  else
    update public.profiles set points = points - v_cost where id = auth.uid() and points >= v_cost;
    if not found then
      raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_cost;
    end if;
  end if;
  insert into public.announcements (server_id, buy, expires_at, facebook_url)
  values (p_server_id, p_buy, now() + (p_duration_ms || ' milliseconds')::interval,
          (select facebook_url from public.profiles where id = auth.uid()));
end; $function$;

-- ---------- 2) แก้ไขประกาศย้ายเซิร์ฟ: ประกาศฟรีห้ามย้ายไปซ้อนเซิร์ฟที่มีประกาศฟรีของตัวเองอยู่แล้ว ----------
-- ใช้ค่าของ OLD (created_at / expires_at / user_id ถูก announcements_guard ล็อกไว้) จึงไม่ขึ้นกับลำดับ trigger
create function public.announcements_free_limit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- นับเฉพาะประกาศฟรี (ยาว 12 ชม. พอดี) ที่ยังไม่หมดเวลา
  if old.expires_at - old.created_at is distinct from interval '12 hours' or old.expires_at <= now() then
    return new;
  end if;
  -- คิวเดียวกับ post_announcement
  perform pg_advisory_xact_lock(hashtext('announce_free:' || old.user_id::text));
  if exists (select 1 from public.announcements
              where user_id = old.user_id and server_id = new.server_id and id is distinct from old.id
                and expires_at > now() and expires_at - created_at = interval '12 hours') then
    raise exception 'ย้ายไปเซิร์ฟนี้ไม่ได้ — เซิร์ฟนี้มีประกาศฟรีของคุณอยู่แล้ว (ประกาศฟรี 12 ชม. ได้ 1 ประกาศต่อเซิร์ฟเวอร์)';
  end if;
  return new;
end;
$function$;

revoke all on function public.announcements_free_limit() from public, anon, authenticated;

create trigger announcements_free_limit_trg
  before update of server_id on public.announcements
  for each row when (old.server_id is distinct from new.server_id)
  execute function public.announcements_free_limit();

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true ทั้ง 3 ช่อง
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)')) = '8c43bb3fa52265f640b5a594696d5ed7' as post_announcement_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.announcements_free_limit()')) = 'ce650c5a301f79d054c913d64074bd8c'
    and exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                 and tgname = 'announcements_free_limit_trg' and not tgisinternal and tgenabled <> 'D') as free_limit_ok,
  has_function_privilege('authenticated', 'public.post_announcement(text, numeric, bigint)', 'execute')
    and not has_function_privilege('anon', 'public.post_announcement(text, numeric, bigint)', 'execute')
    and not has_function_privilege('authenticated', 'public.announcements_free_limit()', 'execute')
    and not has_function_privilege('anon', 'public.announcements_free_limit()', 'execute') as grants_ok;
