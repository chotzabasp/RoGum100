-- ============================================================
-- ย้อนกลับ 20261008000200_announcement_12h_free.sql (เลิกให้ประกาศ 12 ชม. ฟรี)
--   post_announcement → ฉบับ 20260927000800 (md5 f7f03aa9…) — 12 ชม. กลับไปเป็น 12 แต้ม ไม่มีลิมิตต่อเซิร์ฟ
--   ลบ trigger announcements_free_limit_trg + ฟังก์ชัน announcements_free_limit()
-- ต้องย้อนหน้าเว็บคู่กันด้วย: ANNOUNCE_DURATION_OPTIONS ใน assets/app.js → 12 ชม. cost:12 (ไม่งั้นปุ่มขึ้น "ฟรี" แต่หัก 12 แต้ม)
-- ประกาศที่ลงฟรีไปแล้วไม่กระทบ อยู่จนหมดเวลาตามปกติ
-- ============================================================
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)');
  if v_md5 is distinct from '8c43bb3fa52265f640b5a594696d5ed7' then
    raise exception 'post_announcement ไม่ใช่ฉบับ 20261008000200 (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
end;
$guard$;

drop trigger if exists announcements_free_limit_trg on public.announcements;
drop function if exists public.announcements_free_limit();

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
    when 43200000 then 12  -- 12 ชม.
    else null
  end;
  if v_cost is null then
    raise exception 'ระยะเวลาไม่ถูกต้อง';
  end if;
  update public.profiles set points = points - v_cost where id = auth.uid() and points >= v_cost;
  if not found then
    raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_cost;
  end if;
  insert into public.announcements (server_id, buy, expires_at, facebook_url)
  values (p_server_id, p_buy, now() + (p_duration_ms || ' milliseconds')::interval,
          (select facebook_url from public.profiles where id = auth.uid()));
end; $function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)')) = 'f7f03aa953088949f9bfb83acca1d6b6'
    and to_regprocedure('public.announcements_free_limit()') is null
    and not exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass and tgname = 'announcements_free_limit_trg')
    and has_function_privilege('authenticated', 'public.post_announcement(text, numeric, bigint)', 'execute')
    and not has_function_privilege('anon', 'public.post_announcement(text, numeric, bigint)', 'execute') as rollback_ok;
