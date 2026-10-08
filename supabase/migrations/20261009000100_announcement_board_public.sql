-- ============================================================
-- กระดานประกาศรับ M (ผู้ใช้สั่ง 9 ต.ค. 2569 — ช่วงแรกคนยังลงน้อย อยากให้เห็นกว้างขึ้น แต่กันคนป่วนไว้ก่อน)
-- 1) post_announcement(): ประกาศฟรี 12 ชม. ลงได้เฉพาะคนที่มีแพ็กเกจที่ยังไม่หมดอายุ (แพ็กไหนก็ได้:
--    1 in 1 / 2 in 1 / จับเวลาบอส / 3 in 1 / 4 in 1 · แอดมิน / บัญชีเก่าไม่จำกัด นับว่ามี — เหมือน hasBundlePlan ฯลฯ ในหน้าเว็บ)
--    ไม่มีแพ็ก = "คุณไม่มีแพ็กเกจ — ประกาศฟรี 12 ชม. สำหรับสมาชิกที่มีแพ็กเกจ" · 1 / 3 / 6 ชม. แบบเสียแต้ม ทุกคนลงได้เหมือนเดิม
--    ส่วนอื่นคงเดิมจาก 20261008000200 (ลิมิตประกาศฟรี 1 ประกาศต่อเซิร์ฟ ฯลฯ)
-- 2) announcements_guard(): รับแพงขึ้นได้ไม่เกิน 2 เท่าของราคาอ้างอิง (เดิมไม่จำกัด → ลงราคามั่วสูงๆ แล้วคนอื่น
--    ลงราคาปกติในเซิร์ฟนั้นไม่ได้ เพราะตัวกันลดเกิน 50% นับจากราคามั่ว) · ข้อความ "ราคารับสูงกว่าราคาปัจจุบัน (Xบ) เกิน 2 เท่า —
--    ต้องไม่เกิน Yบ" ต้องตรงกับ RATE_MAX_RISE ใน assets/app.js · ส่วนอื่นคงเดิมทุกตัวอักษรจาก 20260929000600
-- 3) public_announcements() + public_announcements_state(): ให้คนที่ยังไม่ล็อกอิน (anon) เห็นกระดาน
--    ส่งเฉพาะประกาศที่ยังไม่หมดเวลา และเฉพาะช่องที่กระดานโชว์ (id เซิร์ฟ ราคารับ ชื่อ ลิงก์ Facebook เวลา)
--    ไม่ส่ง user_id / ref_buy · ตาราง announcements ยังอ่านตรงได้เฉพาะสมาชิกเหมือนเดิม (RLS ไม่แตะ)
--    _state = จำนวน + ลายนิ้วมือของกระดาน ให้หน้าเว็บเช็คก่อนค่อยดึงทั้งกระดาน (แบบเดียวกับ announcements_state ของสมาชิก)
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20261009000100_announcement_board_public_rollback.sql
-- ============================================================
begin;

set local lock_timeout = '5s';

-- กันเขียนทับของที่ถูกแก้จากที่อื่น: ต้องตรงกับที่ repo รู้จัก ไม่งั้นหยุดทั้งไฟล์ (ไม่มีอะไรถูกแก้)
do $guard$
declare
  v_md5 text;
begin
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)');
  if v_md5 is distinct from '8c43bb3fa52265f640b5a594696d5ed7' then
    raise exception 'post_announcement ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  select md5(replace(prosrc, E'\r', '')) into v_md5 from pg_proc where oid = to_regprocedure('public.announcements_guard()');
  if v_md5 is distinct from '339f5d12681f1c5d14b5d2a32d0619d3' then
    raise exception 'announcements_guard ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', coalesce(v_md5, 'ไม่พบฟังก์ชัน');
  end if;
  -- ตัวเช็คแพ็กเกจที่ post_announcement จะเรียกใช้ ต้องมีครบ
  if to_regprocedure('public.has_bundle_plan(uuid)') is null or to_regprocedure('public.has_timers_plan(uuid)') is null
     or to_regprocedure('public.has_trade_plan(uuid)') is null or to_regprocedure('public.has_farm_plan(uuid)') is null then
    raise exception 'ไม่พบฟังก์ชันเช็คแพ็กเกจ (has_*_plan(uuid)) ครบ 4 ตัว — ไม่มีอะไรถูกแก้';
  end if;
  -- ของใหม่ต้องยังไม่มี (กันรันซ้ำ)
  if to_regprocedure('public.public_announcements()') is not null or to_regprocedure('public.public_announcements_state()') is not null then
    raise exception 'มี public_announcements อยู่แล้ว (เคยรันไฟล์นี้แล้ว?) — ไม่มีอะไรถูกแก้';
  end if;
end;
$guard$;

-- ---------- 1) post_announcement: ประกาศฟรี 12 ชม. เฉพาะคนที่มีแพ็กเกจ ----------
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
    when 43200000 then 0   -- 12 ชม. ฟรี เฉพาะคนที่มีแพ็กเกจ (1 ประกาศต่อเซิร์ฟเวอร์)
    else null
  end;
  if v_cost is null then
    raise exception 'ระยะเวลาไม่ถูกต้อง';
  end if;
  if v_cost = 0 then
    -- ลงฟรีเฉพาะคนที่มีแพ็กเกจที่ยังไม่หมดอายุ (แพ็กไหนก็ได้ · แอดมิน / บัญชีเก่าไม่จำกัด นับว่ามี)
    if not (public.has_bundle_plan(auth.uid()) or public.has_timers_plan(auth.uid())
            or public.has_trade_plan(auth.uid()) or public.has_farm_plan(auth.uid())) then
      raise exception 'คุณไม่มีแพ็กเกจ — ประกาศฟรี 12 ชม. สำหรับสมาชิกที่มีแพ็กเกจ';
    end if;
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

-- ---------- 2) announcements_guard: รับแพงขึ้นได้ไม่เกิน 2 เท่าของราคาอ้างอิง ----------
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
  -- ราคารับ M: ราคาอ้างอิง (ใช้ตรวจ "รับถูกลงได้ไม่เกิน 50%" ต้องตรงกับ RATE_MAX_DROP และ announcementRefBuy ใน assets/app.js) ตามลำดับ
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
  -- รับถูกลงได้ไม่เกิน 50% ของราคาอ้างอิง (ผู้ใช้กำหนด 29 ก.ย. 2569) · รับแพงขึ้นได้ไม่เกิน 2 เท่า (ผู้ใช้กำหนด 9 ต.ค. 2569 —
  -- เดิมไม่จำกัด ลงราคามั่วสูงๆ แล้วคนอื่นลงราคาปกติไม่ได้) — ต้องตรงกับ RATE_MAX_DROP / RATE_MAX_RISE ใน assets/app.js
  -- ตัวเลขในข้อความจัดรูปแบบเหมือนหน้าเว็บ (fmtNum: คั่นหลักพัน ทศนิยมไม่เกิน 2 ตำแหน่ง) เช่น 1,000 / 62.5
  if new.ref_buy > 0 and new.buy < new.ref_buy * 0.50 then
    raise exception 'ราคารับต่ำกว่าราคาปัจจุบัน (%บ) เกิน 50%% — ต้องไม่ต่ำกว่า %บ',
      rtrim(to_char(round(new.ref_buy, 2), 'FM999,999,999,990.99'), '.'),
      rtrim(to_char(round(new.ref_buy * 0.50, 2), 'FM999,999,999,990.99'), '.');
  end if;
  if new.ref_buy > 0 and new.buy > new.ref_buy * 2 then
    raise exception 'ราคารับสูงกว่าราคาปัจจุบัน (%บ) เกิน 2 เท่า — ต้องไม่เกิน %บ',
      rtrim(to_char(round(new.ref_buy, 2), 'FM999,999,999,990.99'), '.'),
      rtrim(to_char(round(new.ref_buy * 2, 2), 'FM999,999,999,990.99'), '.');
  end if;
  return new;
end; $function$;

-- ---------- 3) กระดานสำหรับคนที่ยังไม่ล็อกอิน ----------
create function public.public_announcements()
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
    from (select a.id, a.server_id, a.buy, a.user_name, a.facebook_url, a.created_at, a.expires_at
            from public.announcements a
           where a.expires_at > now()
           order by a.created_at desc
           limit 200) x;
$function$;

create function public.public_announcements_state()
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $function$
  select jsonb_build_object('n', count(*), 'h', md5(coalesce(string_agg(
           a.id::text || '|' || a.server_id || '|' || coalesce(a.buy::text, '') || '|' || coalesce(a.user_name, '') || '|' ||
           coalesce(a.facebook_url, '') || '|' || a.created_at::text || '|' || a.expires_at::text, ',' order by a.id::text), '')))
    from public.announcements a
   where a.expires_at > now();
$function$;

revoke all on function public.public_announcements() from public, anon, authenticated;
revoke all on function public.public_announcements_state() from public, anon, authenticated;
grant execute on function public.public_announcements() to anon;
grant execute on function public.public_announcements_state() to anon;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 1 แถว true ทั้ง 4 ช่อง
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.post_announcement(text, numeric, bigint)')) = '2662154200272f9d8fa0ef21539ec5d2' as post_announcement_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.announcements_guard()')) = 'b502ba51afd1ba1eb84a066274a3925f'
    and exists (select 1 from pg_trigger where tgrelid = 'public.announcements'::regclass
                 and tgname = 'announcements_guard_trg' and not tgisinternal and tgenabled <> 'D') as guard_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.public_announcements()')) = 'a279a6621f0569ff8fabe3ccfa76d761'
    and (select md5(replace(prosrc, E'\r', '')) from pg_proc where oid = to_regprocedure('public.public_announcements_state()')) = '16a5176380c0d947a9602f114e4c1e95' as public_fns_ok,
  has_function_privilege('anon', 'public.public_announcements()', 'execute')
    and has_function_privilege('anon', 'public.public_announcements_state()', 'execute')
    and not has_function_privilege('authenticated', 'public.public_announcements()', 'execute')
    and has_function_privilege('authenticated', 'public.post_announcement(text, numeric, bigint)', 'execute')
    and not has_function_privilege('anon', 'public.post_announcement(text, numeric, bigint)', 'execute') as grants_ok;
