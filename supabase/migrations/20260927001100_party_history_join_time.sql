-- ============================================================
-- ประวัติการล่าของปาร์ตี้: สมาชิกเห็น/หารได้เฉพาะรอบที่ "อยู่ในปาร์ตี้ตอนนั้น" (ตามที่ผู้ใช้เลือก ก1 ข1 · 27 ก.ย. 2569)
--   ก1 = นับทุกช่วงที่เคยอยู่ (party_members เก็บทุกรอบ: ออก/ถูกเอาออก = ตั้ง removed_at, เข้าใหม่ = แถวใหม่)
--   ข1 = เผื่อ 1 นาที (เวลาตายพิมพ์เองไม่มีวินาที / นาฬิกาเครื่องเพี้ยน) — ต้องตรงกับ PARTY_JOIN_GRACE_MS ใน assets/app.js
--   เวลาที่ใช้เทียบ = kills.killed_at (เวลาบอสตาย = เวลาที่แสดงในประวัติ)
--
-- 1) ฟังก์ชันช่วย (SECURITY DEFINER — อ่าน party_members/kills โดยไม่ผ่าน RLS กันวนซ้ำ policy):
--    party_member_present_at(host, member, at) — ภายในเท่านั้น (ไม่ให้สิทธิ์ใคร)
--    party_kill_visible(host, killed_at, killed_by) — ผู้เรียกเป็นสมาชิกปาร์ตี้ปัจจุบัน (is_party_member_of เดิม)
--        และ (เป็นคนกด MVP รอบนั้น หรืออยู่ในปาร์ตี้ตอนบอสตาย)
--    party_item_visible(kill_id, host) — เหมือนข้างบน ดูจากรอบ (kills) ของไอเทมนั้น
-- 2) RLS: kills_party / kills_party_delete / kill_items_select / insert / update / delete
--    เปลี่ยนเฉพาะกิ่ง "สมาชิกปาร์ตี้" จาก is_party_member_of(host_id) เป็นฟังก์ชันข้างบน
--    กิ่งเจ้าของ (auth.uid() = host_id) และกิ่ง "ของที่หารให้ฉัน" (shared_with) คงเดิมทุกตัวอักษร
--    → ประวัติ ตัวเลขสรุป แท็บตามบอส (RPC boss_history_* เป็น SECURITY INVOKER) ตามไปเอง
--    → สมาชิกลบ/แก้ได้เฉพาะรายการที่ตัวเองเห็น ("ลบประวัติทั้งหมด" ไม่ไปลบของก่อนเข้าปาร์ตี้ของหัวปาร์ตี้)
-- 3) trigger kill_items_shared_with_guard: เพิ่มชื่อในการหารได้เฉพาะ หัวปาร์ตี้ / คนกด MVP / คนที่อยู่ในปาร์ตี้ตอนบอสตาย
--    เอาชื่อออกได้เสมอ · ชื่อที่ติ๊กไว้เดิมไม่เช็คซ้ำ (ข้อมูลเก่าไม่หาย)
-- 4) record_kill / record_custom_kill: สมาชิกกดบันทึกซ้ำกับรอบ (±60 วิ) ที่ตัวเองมองไม่เห็น (ก่อนเข้าปาร์ตี้)
--    → แจ้ง "รอบนี้ถูกบันทึกไว้ก่อนคุณเข้าปาร์ตี้แล้ว" (ไม่เพิ่มไอเทมเข้ารอบนั้น และไม่สร้างรอบซ้ำ) ส่วนอื่นคงเดิมทุกตัวอักษร
-- 5) set_kill_server: สมาชิกแก้เซิร์ฟได้เฉพาะรอบที่ตัวเองเห็น + ต้องมีแพ็กจับเวลาบอส + บัญชีไม่หมดอายุ
-- 6) ดัชนี party_members (host_id, member_id, created_at) ให้ค้นทุกรอบการเป็นสมาชิกได้เร็ว
-- ทุกอย่างอยู่ใน transaction เดียว — ตัวเช็คด้านบนไม่ผ่าน = ไม่มีอะไรถูกแก้
-- ย้อนกลับ (ถ้าจำเป็น): supabase/rollbacks/20260927001100_party_history_join_time_rollback.sql (ไม่ต้องรัน ถ้าไม่มีปัญหา)
-- ============================================================
begin;

-- ALTER POLICY ต้องล็อกตาราง — ถ้ามีคำสั่งอื่นค้างอยู่เกิน 5 วิ ให้ยกเลิกทั้งไฟล์ (ไม่มีอะไรถูกแก้) แทนการรอจนเว็บค้าง
set local lock_timeout = '5s';

-- ---------- กันเขียนทับของที่ถูกแก้จากที่อื่น ----------
do $guard$
declare
  v_md5 text; v_expr text; v_n int;
  c_member_write constant text := '(((( SELECT auth.uid() AS uid) = host_id) OR (is_party_member_of(host_id) AND ( SELECT has_timers_plan(( SELECT auth.uid() AS uid)) AS has_timers_plan))) AND ( SELECT is_active() AS is_active))';
begin
  -- ฟังก์ชันที่จะแก้ต้องตรงกับที่ repo รู้จัก
  select md5(replace(p.prosrc, E'\r', '')) into v_md5 from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'record_kill';
  if v_md5 is distinct from '816c34d205d9562f159019016710fce9' then
    raise exception 'record_kill ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', v_md5;
  end if;
  select md5(replace(p.prosrc, E'\r', '')) into v_md5 from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'record_custom_kill';
  if v_md5 is distinct from '7be3cdc025282c5e6b27ef61f8d90fed' then
    raise exception 'record_custom_kill ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', v_md5;
  end if;
  select md5(replace(p.prosrc, E'\r', '')) into v_md5 from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'set_kill_server';
  if v_md5 is distinct from '597a3a914182d517539eb4075c089722' then
    raise exception 'set_kill_server ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', v_md5;
  end if;
  select md5(replace(p.prosrc, E'\r', '')) into v_md5 from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'is_party_member_of';
  if v_md5 is distinct from '35d5cf80b0ad6a5f2cb34e715d9f3bde' then
    raise exception 'is_party_member_of ไม่ตรงกับที่คาดไว้ (md5 %) — ไม่มีอะไรถูกแก้', v_md5;
  end if;
  -- ชื่อใหม่ต้องยังไม่มี (กันรันซ้ำ)
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
              and proname in ('party_member_present_at', 'party_kill_visible', 'party_item_visible', 'kill_items_shared_with_guard')) then
    raise exception 'มีฟังก์ชันชุดนี้อยู่แล้ว (เคยรันไฟล์นี้ไปแล้ว?) — ไม่มีอะไรถูกแก้';
  end if;

  -- policy ของ kills / kill_items ต้องมีครบตามเดิม ไม่มีตัวอื่นเพิ่ม และข้อความตรงเดิม (เทียบแบบรวมช่องว่าง)
  select count(*) into v_n from pg_policy where polrelid = 'public.kills'::regclass;
  if v_n <> 2 then raise exception 'policy ของ kills มี % ตัว (คาดไว้ 2) — ไม่มีอะไรถูกแก้', v_n; end if;
  select count(*) into v_n from pg_policy where polrelid = 'public.kill_items'::regclass;
  if v_n <> 4 then raise exception 'policy ของ kill_items มี % ตัว (คาดไว้ 4) — ไม่มีอะไรถูกแก้', v_n; end if;

  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kills'::regclass and polname = 'kills_party';
  if v_expr is distinct from '((( SELECT auth.uid() AS uid) = host_id) OR is_party_member_of(host_id) OR (EXISTS ( SELECT 1 FROM kill_items ki WHERE ((ki.kill_id = kills.id) AND (ki.shared_with @> ARRAY[( SELECT auth.uid() AS uid)])))))' then
    raise exception 'policy kills_party ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kills'::regclass and polname = 'kills_party_delete';
  if v_expr is distinct from c_member_write then
    raise exception 'policy kills_party_delete ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kill_items'::regclass and polname = 'kill_items_select';
  if v_expr is distinct from '((( SELECT auth.uid() AS uid) = host_id) OR is_party_member_of(host_id) OR (shared_with @> ARRAY[( SELECT auth.uid() AS uid)]))' then
    raise exception 'policy kill_items_select ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
  select regexp_replace(pg_get_expr(polwithcheck, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kill_items'::regclass and polname = 'kill_items_insert';
  if v_expr is distinct from c_member_write then
    raise exception 'policy kill_items_insert ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g')
         || ' || ' || regexp_replace(pg_get_expr(polwithcheck, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kill_items'::regclass and polname = 'kill_items_update';
  if v_expr is distinct from c_member_write || ' || ' || c_member_write then
    raise exception 'policy kill_items_update ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
  select regexp_replace(pg_get_expr(polqual, polrelid), '\s+', ' ', 'g') into v_expr
    from pg_policy where polrelid = 'public.kill_items'::regclass and polname = 'kill_items_delete';
  if v_expr is distinct from c_member_write then
    raise exception 'policy kill_items_delete ไม่ตรงกับที่คาดไว้ — ไม่มีอะไรถูกแก้: %', v_expr;
  end if;
end $guard$;

-- ---------- 1) ฟังก์ชันช่วย ----------
-- สมาชิก p_member อยู่ในปาร์ตี้ของ p_host ตอน p_at ไหม — ทุกช่วงที่เคยอยู่ · เผื่อ 1 นาที (เข้าหลังบอสตายไม่เกิน 1 นาทีก็นับ)
create function public.party_member_present_at(p_host uuid, p_member uuid, p_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.party_members m
     where m.host_id = p_host and m.member_id = p_member
       and m.created_at <= p_at + interval '1 minute'
       and (m.removed_at is null or m.removed_at > p_at)
  );
$function$;

-- ผู้เรียกมองเห็นรอบนี้ในฐานะสมาชิกปาร์ตี้ไหม: เป็นสมาชิกปัจจุบัน (เงื่อนไขเดิม) และ (กด MVP รอบนั้นเอง หรืออยู่ในปาร์ตี้ตอนบอสตาย)
-- (หัวปาร์ตี้ไม่ได้ผ่านฟังก์ชันนี้ — policy มีกิ่ง auth.uid() = host_id แยกไว้)
create function public.party_kill_visible(p_host uuid, p_killed_at timestamptz, p_killed_by uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.is_party_member_of(p_host)
     and (coalesce(p_killed_by = auth.uid(), false) or public.party_member_present_at(p_host, auth.uid(), p_killed_at));
$function$;

-- เหมือน party_kill_visible แต่ดูจากรอบของไอเทม (อ่าน kills ข้าม RLS — ถ้าเขียนเป็น subquery ใน policy ตรงๆ จะวนซ้ำกับ kills_party)
-- เช็คความเป็นสมาชิกก่อน (ถูกกว่า) — แถวของปาร์ตี้ที่ไม่เกี่ยวข้องจบตรงนั้น ไม่ต้องค้นรอบ
create function public.party_item_visible(p_kill_id uuid, p_host uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.is_party_member_of(p_host)
     and exists (
       select 1 from public.kills k
        where k.id = p_kill_id and k.host_id = p_host
          and (coalesce(k.killed_by = auth.uid(), false) or public.party_member_present_at(p_host, auth.uid(), k.killed_at))
     );
$function$;

revoke all on function public.party_member_present_at(uuid, uuid, timestamptz) from public, anon, authenticated;
-- 2 ตัวนี้ถูกเรียกใน policy ของ kills / kill_items ซึ่งใช้กับทุก role — ต้องให้ anon เรียกได้ด้วย ไม่งั้นผู้เยี่ยมชมที่อ่านตารางจะได้ error แทนผลว่าง
-- (ไม่เปิดเผยอะไร: ไม่ได้ล็อกอิน = auth.uid() ว่าง = ได้ false เสมอ · ล็อกอินแล้วตอบได้แค่เรื่องของตัวเอง)
revoke all on function public.party_kill_visible(uuid, timestamptz, uuid) from public;
grant execute on function public.party_kill_visible(uuid, timestamptz, uuid) to anon, authenticated;
revoke all on function public.party_item_visible(uuid, uuid) from public;
grant execute on function public.party_item_visible(uuid, uuid) to anon, authenticated;

-- ดัชนีให้ party_member_present_at / หน้าเว็บ (loadPartyRoster) ค้นแถวสมาชิกทุกรอบของหัวปาร์ตี้ได้เร็ว
-- (ดัชนีเดิมเป็นแบบเฉพาะแถวที่ยังไม่ออก — ใช้กับการค้นที่รวมรอบเก่าไม่ได้)
create index if not exists party_members_host_member_idx on public.party_members (host_id, member_id, created_at);

-- ---------- 2) RLS ----------
-- kills: เช็ค is_party_member_of ก่อน (ถูกกว่า) — แถวของปาร์ตี้ที่ไม่เกี่ยวข้องเสียเท่าเดิม ไม่ต้องไปเรียกตัวเช็คเวลา
alter policy kills_party on public.kills
  using (((select auth.uid()) = host_id)
         or (public.is_party_member_of(host_id) and public.party_kill_visible(host_id, killed_at, killed_by))
         or (exists (select 1 from public.kill_items ki
                      where ki.kill_id = kills.id and ki.shared_with @> array[(select auth.uid())])));

alter policy kills_party_delete on public.kills
  using (((((select auth.uid()) = host_id)
           or (public.is_party_member_of(host_id)
               and public.party_kill_visible(host_id, killed_at, killed_by)
               and (select public.has_timers_plan((select auth.uid())))))
          and (select public.is_active())));

-- kill_items_select: เช็ค "หารให้ฉัน" (ถูก ใช้ดัชนี GIN) ก่อนตัวเช็คเวลา
alter policy kill_items_select on public.kill_items
  using (((select auth.uid()) = host_id)
         or (shared_with @> array[(select auth.uid())])
         or public.party_item_visible(kill_id, host_id));

alter policy kill_items_insert on public.kill_items
  with check (((((select auth.uid()) = host_id)
                or (public.party_item_visible(kill_id, host_id) and (select public.has_timers_plan((select auth.uid())))))
               and (select public.is_active())));

alter policy kill_items_update on public.kill_items
  using (((((select auth.uid()) = host_id)
           or (public.party_item_visible(kill_id, host_id) and (select public.has_timers_plan((select auth.uid())))))
          and (select public.is_active())))
  with check (((((select auth.uid()) = host_id)
                or (public.party_item_visible(kill_id, host_id) and (select public.has_timers_plan((select auth.uid())))))
               and (select public.is_active())));

alter policy kill_items_delete on public.kill_items
  using (((((select auth.uid()) = host_id)
           or (public.party_item_visible(kill_id, host_id) and (select public.has_timers_plan((select auth.uid())))))
          and (select public.is_active())));

-- ---------- 3) trigger กันเพิ่มคนที่ไม่ได้อยู่ในปาร์ตี้ตอนบอสตายเข้าการหาร ----------
-- + ห้ามย้ายไอเทมไปรอบอื่น/เปลี่ยนเจ้าของ (ไม่งั้นย้ายไอเทมที่หารให้ใครไว้ไปรอบก่อนคนนั้นเข้าปาร์ตี้ = หลบตัวกันนี้ได้)
-- + ไอเทมใหม่ต้องอยู่ในรอบของเจ้าของเดียวกัน (หน้าเว็บ/RPC ทำแบบนี้อยู่แล้วทุกที่)
-- ข้อความ error ไม่บอกชื่อคน (กันใช้เดาชื่อของคนอื่นจาก uuid)
create function public.kill_items_shared_with_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_host uuid; v_killed_at timestamptz; v_killed_by uuid; v_id uuid;
begin
  if tg_op = 'UPDATE' then
    if new.kill_id is distinct from old.kill_id or new.host_id is distinct from old.host_id then
      raise exception 'ย้ายไอเทมไปรอบอื่นหรือเปลี่ยนเจ้าของไม่ได้';
    end if;
    -- ไม่ได้เพิ่มชื่อ (ไม่เปลี่ยน / เอาออกอย่างเดียว) = ผ่านเลย
    if new.shared_with <@ coalesce(old.shared_with, '{}'::uuid[]) then return new; end if;
  end if;
  select k.host_id, k.killed_at, k.killed_by into v_host, v_killed_at, v_killed_by
    from public.kills k where k.id = new.kill_id;
  if tg_op = 'INSERT' and v_host is distinct from new.host_id then
    raise exception 'ไอเทมต้องอยู่ในรอบของเจ้าของเดียวกัน';
  end if;
  if new.shared_with is null or cardinality(new.shared_with) = 0 then return new; end if;
  foreach v_id in array new.shared_with loop
    -- ชื่อที่ติ๊กไว้เดิม ไม่เช็คซ้ำ (ข้อมูลเก่าไม่หาย)
    if tg_op = 'UPDATE' and v_id = any(coalesce(old.shared_with, '{}'::uuid[])) then continue; end if;
    if v_id = v_host or v_id = v_killed_by then continue; end if;
    if public.party_member_present_at(v_host, v_id, v_killed_at) then continue; end if;
    raise exception 'เพิ่มคนนี้ในการหารไม่ได้ — ยังไม่ได้อยู่ในปาร์ตี้ตอนได้ของชิ้นนี้';
  end loop;
  return new;
end;
$function$;

revoke all on function public.kill_items_shared_with_guard() from public, anon, authenticated;

create trigger kill_items_shared_with_guard_trg
  before insert or update on public.kill_items
  for each row execute function public.kill_items_shared_with_guard();

-- ---------- 4) record_kill: รอบซ้ำที่สมาชิกมองไม่เห็น → แจ้ง ไม่รวม ไม่สร้างซ้ำ ----------
CREATE OR REPLACE FUNCTION public.record_kill(p_boss_id text, p_boss_name text, p_killed_at timestamp with time zone, p_items text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  caller_host uuid;
  new_kill uuid;
  dup_kill uuid;
  dup_at timestamptz;
  dup_by uuid;
  it text;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if p_boss_id is null or char_length(p_boss_id) not between 1 and 200 then raise exception 'รหัสบอสไม่ถูกต้อง'; end if;
  if p_boss_name is null or char_length(btrim(p_boss_name)) not between 1 and 120 then raise exception 'ชื่อบอสไม่ถูกต้อง'; end if;
  if coalesce(cardinality(p_items), 0) > 50 then raise exception 'บันทึกไอเทมได้ไม่เกิน 50 ชิ้นต่อครั้ง'; end if;
  select host_id into caller_host from public.party_members
    where member_id = auth.uid() and removed_at is null limit 1;
  if caller_host is null then caller_host := auth.uid(); end if;

  if caller_host <> auth.uid() and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    if it is null or char_length(btrim(it)) not between 1 and 120 then raise exception 'ชื่อไอเทมไม่ถูกต้อง'; end if;
  end loop;

  -- ต่อคิวการบันทึกของบอสตัวนี้ในปาร์ตี้นี้ทีละคำสั่ง แล้วเช็คว่ามีรอบเดียวกันอยู่แล้วหรือยัง
  perform pg_advisory_xact_lock(hashtext('record_kill:' || caller_host::text || ':' || p_boss_id));
  select k.id, k.killed_at, k.killed_by into dup_kill, dup_at, dup_by
    from public.kills k
   where k.host_id = caller_host and k.boss_id = p_boss_id and k.custom_boss_id is null
     and p_killed_at is not null
     and k.killed_at between p_killed_at - interval '60 seconds' and p_killed_at + interval '60 seconds'
   order by abs(extract(epoch from (k.killed_at - p_killed_at)))
   limit 1;
  if dup_kill is not null then
    -- สมาชิกปาร์ตี้รวมได้เฉพาะรอบที่ตัวเองเห็น (อยู่ในปาร์ตี้ตอนนั้น) — รอบก่อนเข้าปาร์ตี้: ไม่เพิ่มไอเทม และไม่สร้างรอบซ้ำ
    if caller_host <> auth.uid() and not public.party_kill_visible(caller_host, dup_at, dup_by) then
      raise exception 'รอบนี้ถูกบันทึกไว้ก่อนคุณเข้าปาร์ตี้แล้ว';
    end if;
    insert into public.kill_items (kill_id, host_id, name)
      select dup_kill, caller_host, d.v
        from (select distinct v from unnest(coalesce(p_items, '{}'::text[])) as u(v)) d
       where not exists (select 1 from public.kill_items i where i.kill_id = dup_kill and i.name = d.v);
    return dup_kill;
  end if;

  insert into public.kills (host_id, boss_id, boss_name, killed_by, killed_at)
    values (caller_host, p_boss_id, p_boss_name, auth.uid(), p_killed_at)
    returning id into new_kill;

  foreach it in array coalesce(p_items, '{}'::text[]) loop
    insert into public.kill_items (kill_id, host_id, name) values (new_kill, caller_host, it);
  end loop;
  return new_kill;
end;
$function$;

-- ---------- 4b) record_custom_kill: เหมือนกัน ----------
CREATE OR REPLACE FUNCTION public.record_custom_kill(p_boss_id uuid, p_server_id text, p_killed_at timestamp with time zone, p_items text[], p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
  k public.kills; who text; target timestamptz;
BEGIN
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (เหมือน record_kill ของบอสปกติ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  IF p_request_id IS NULL OR p_killed_at IS NULL OR NOT isfinite(p_killed_at) THEN
    RAISE EXCEPTION 'Invalid request/time';
  END IF;
  IF p_killed_at > clock_timestamp() + interval '5 minutes' THEN
    RAISE EXCEPTION 'เวลาตายต้องไม่เกินเวลาปัจจุบัน';
  END IF;
  IF NOT public.cb_validate_items(p_items) OR NOT (p_items <@ b.items) THEN
    RAISE EXCEPTION 'Drops must be selected from this boss';
  END IF;
  SELECT * INTO k FROM public.kills WHERE id=p_request_id;
  IF FOUND THEN
    IF k.custom_boss_id IS DISTINCT FROM b.id OR k.host_id<>b.owner_id
      OR k.server_id IS DISTINCT FROM p_server_id OR k.killed_by IS DISTINCT FROM auth.uid()
      OR k.killed_at IS DISTINCT FROM p_killed_at
      OR (SELECT coalesce(array_agg(name ORDER BY name),'{}'::text[]) FROM public.kill_items WHERE kill_id=k.id)
        IS DISTINCT FROM (SELECT coalesce(array_agg(v ORDER BY v),'{}'::text[]) FROM unnest(p_items) AS u(v)) THEN
      RAISE EXCEPTION 'Request ID already used';
    END IF;
    RETURN k.id;
  END IF;
  PERFORM 1 FROM public.custom_boss_timers WHERE owner_id=b.owner_id
    AND custom_boss_id=b.id AND server_id=p_server_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
  -- รอบเดียวกัน (ห่างไม่เกิน 60 วิ) มีคนบันทึกไปแล้ว → คืนรายการเดิม + เพิ่มไอเทมที่ยังไม่มี
  SELECT * INTO k FROM public.kills
   WHERE host_id=b.owner_id AND custom_boss_id=b.id
     AND killed_at BETWEEN p_killed_at - interval '60 seconds' AND p_killed_at + interval '60 seconds'
   ORDER BY abs(extract(epoch from (killed_at - p_killed_at)))
   LIMIT 1;
  IF FOUND THEN
    -- สมาชิกปาร์ตี้รวมได้เฉพาะรอบที่ตัวเองเห็น (อยู่ในปาร์ตี้ตอนนั้น) — รอบก่อนเข้าปาร์ตี้: ไม่เพิ่มไอเทม ไม่สร้างรอบซ้ำ ไม่แตะเวลาเกิด
    IF auth.uid()<>b.owner_id AND NOT public.party_kill_visible(k.host_id, k.killed_at, k.killed_by) THEN
      RAISE EXCEPTION 'รอบนี้ถูกบันทึกไว้ก่อนคุณเข้าปาร์ตี้แล้ว';
    END IF;
    INSERT INTO public.kill_items(kill_id,host_id,name)
      SELECT k.id,b.owner_id,d.v FROM (SELECT DISTINCT v FROM unnest(p_items) AS u(v)) d
       WHERE NOT EXISTS (SELECT 1 FROM public.kill_items i WHERE i.kill_id=k.id AND i.name=d.v);
    -- คนที่กดคนแรก (เจ้าของรายการ) กดซ้ำ → เวลาเกิดนับใหม่ตามที่กด · คนอื่นกด → คงเวลาของคนแรก
    IF k.killed_by = auth.uid() THEN
      target=p_killed_at + b.respawn_minutes * interval '1 minute';
      SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
      UPDATE public.custom_boss_timers SET target_time=target,started_by=who
        WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
    END IF;
    RETURN k.id;
  END IF;
  target=p_killed_at + b.respawn_minutes * interval '1 minute';
  SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
  INSERT INTO public.kills(id,host_id,boss_id,boss_name,killed_by,killed_at,server_id,custom_boss_id)
    VALUES(p_request_id,b.owner_id,'custom:'||b.id::text,b.name,auth.uid(),p_killed_at,p_server_id,b.id);
  INSERT INTO public.kill_items(kill_id,host_id,name)
    SELECT p_request_id,b.owner_id,v FROM unnest(p_items) AS u(v);
  UPDATE public.custom_boss_timers SET target_time=target,started_by=who
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  RETURN p_request_id;
END $function$;

-- ---------- 5) set_kill_server: สมาชิกแก้เซิร์ฟได้เฉพาะรอบที่ตัวเองเห็น (+แพ็ก +บัญชีไม่หมดอายุ) ----------
CREATE OR REPLACE FUNCTION public.set_kill_server(p_kill_id uuid, p_server_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_host uuid;
  v_killed_at timestamptz;
  v_killed_by uuid;
begin
  select host_id, killed_at, killed_by into target_host, v_killed_at, v_killed_by from public.kills where id = p_kill_id;
  if target_host is null then
    raise exception 'ไม่พบประวัติการฆ่านี้';
  end if;
  -- สมาชิก: ต้องเห็นรอบนั้น + มีแพ็กจับเวลาบอส + บัญชีไม่หมดอายุ (เหมือนการแก้/ลบประวัติทางอื่น)
  if target_host <> auth.uid()
     and (not public.party_kill_visible(target_host, v_killed_at, v_killed_by)
          or not public.has_timers_plan(auth.uid()) or not public.is_active()) then
    raise exception 'ไม่มีสิทธิ์แก้ไขประวัตินี้';
  end if;
  update public.kills set server_id = p_server_id where id = p_kill_id;
end; $function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ true ทุกช่อง ยกเว้น 2 ช่องท้ายสุด (..._false) ต้องได้ false
select
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'record_kill') = 'd21bbaadadb4f82f2a05f8f0a703cf55' as record_kill_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'record_custom_kill') = 'c18a8fbf9d989824df8d970467b711f8' as record_custom_kill_ok,
  (select md5(replace(prosrc, E'\r', '')) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'set_kill_server') = '6a1302533ca78aab3949c6aecd49c748' as set_kill_server_ok,
  (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and prosecdef
     and proname in ('party_member_present_at', 'party_kill_visible', 'party_item_visible', 'kill_items_shared_with_guard')) = 4 as helpers_definer_4,
  (select bool_and(pg_get_expr(polqual, polrelid) like '%party_kill_visible%') from pg_policy
     where polrelid = 'public.kills'::regclass) as kills_policies_ok,
  (select bool_and(coalesce(pg_get_expr(polqual, polrelid), '') || coalesce(pg_get_expr(polwithcheck, polrelid), '') like '%party_item_visible%'
               and coalesce(pg_get_expr(polqual, polrelid), '') || coalesce(pg_get_expr(polwithcheck, polrelid), '') not like '%is_party_member_of%')
     from pg_policy where polrelid = 'public.kill_items'::regclass) as kill_items_policies_ok,
  exists(select 1 from pg_trigger where tgname = 'kill_items_shared_with_guard_trg' and not tgisinternal) as guard_trigger_on,
  exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'party_members_host_member_idx') as member_index_on,
  (has_function_privilege('authenticated', 'public.party_kill_visible(uuid,timestamptz,uuid)', 'execute')
     and has_function_privilege('authenticated', 'public.party_item_visible(uuid,uuid)', 'execute')) as visible_auth_exec_true,
  (has_function_privilege('anon', 'public.party_kill_visible(uuid,timestamptz,uuid)', 'execute')
     and has_function_privilege('anon', 'public.party_item_visible(uuid,uuid)', 'execute')) as visible_anon_exec_true,
  has_function_privilege('authenticated', 'public.party_member_present_at(uuid,uuid,timestamptz)', 'execute') as present_auth_exec_false,
  has_function_privilege('authenticated', 'public.kill_items_shared_with_guard()', 'execute') as guard_auth_exec_false;
