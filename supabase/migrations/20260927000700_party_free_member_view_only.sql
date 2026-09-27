-- ============================================================
-- สมาชิกปาร์ตี้แพ็กฟรี = ดูเวลาบอสได้อย่างเดียว ให้ฐานข้อมูลกันจริง (2026-09-27)
--   เดิมกันแค่ "เพิ่มบอส" (add_boss_capped) กับ "บันทึกการฆ่า" (record_kill) — แต่สมาชิกแพ็กฟรียังลบบอส (×),
--   เคลียร์เวลา, แก้เวลาตาย, ปักหมุดแผนที่ ในรายการของปาร์ตี้ได้ และบอส Custom ยังเพิ่ม/ลบ/ตั้งเวลา/ปักหมุด/บันทึกการฆ่าได้
--   1) user_bosses insert/update/delete: ต้องเป็นเจ้าของรายการ (หัวปาร์ตี้) หรือสมาชิกที่มีแพ็กเกจจับเวลาบอส
--      (แบบเดียวกับ kills / kill_items ที่กันไว้แล้ว) · การอ่าน (select) เหมือนเดิม
--   2) ฟังก์ชันบอส Custom 5 ตัว: add_custom_boss_timer, remove_custom_boss_timer, set_custom_boss_time,
--      set_custom_boss_marker, record_custom_kill — คนที่ไม่ใช่เจ้าของบอสต้องมีแพ็กเกจจับเวลาบอส
--      ข้อความเดียวกับของเดิม: 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น'
-- เนื้อฟังก์ชันเดิมคัดลอกตรงตัว (repo 2 ตัว + ของจริงจากฐานข้อมูล 3 ตัว ตรวจ md5 แล้ว) เพิ่มแค่ส่วนเช็คแพ็ก
-- มีตัวกันในไฟล์: ถ้าฟังก์ชัน/กฎในฐานข้อมูลไม่ตรงกับที่ตรวจไว้ จะหยุดทันที ไม่มีอะไรถูกแก้
-- ============================================================
begin;

do $guard$
declare v text; bad text := '';
begin
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.add_custom_boss_timer(uuid, text)'::regprocedure;
  if v is distinct from '138bcd0ec1060a74c5d1de2d31b03248' then bad := bad || ' add_custom_boss_timer=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.record_custom_kill(uuid, text, timestamp with time zone, text[], uuid)'::regprocedure;
  if v is distinct from 'e66c1c634ec8b875bd2605d72b88b182' then bad := bad || ' record_custom_kill=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.remove_custom_boss_timer(uuid, text)'::regprocedure;
  if v is distinct from '0c755321891e3c2b63cb82de1c46e3b3' then bad := bad || ' remove_custom_boss_timer=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.set_custom_boss_time(uuid, text, timestamp with time zone)'::regprocedure;
  if v is distinct from '6efa3021cbf431bc4277e21a133df8e4' then bad := bad || ' set_custom_boss_time=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.set_custom_boss_marker(uuid, text, numeric, numeric)'::regprocedure;
  if v is distinct from '6eae90e88d204c7b78e77c01ab074545' then bad := bad || ' set_custom_boss_marker=' || coalesce(v, '-'); end if;
  select with_check into v from pg_policies where schemaname = 'public' and tablename = 'user_bosses' and policyname = 'user_bosses_insert';
  if v is distinct from '(((( SELECT auth.uid() AS uid) = user_id) OR is_party_member_of(user_id)) AND ( SELECT is_active() AS is_active))' then bad := bad || ' user_bosses_insert.with_check=' || coalesce(v, '-'); end if;
  select qual into v from pg_policies where schemaname = 'public' and tablename = 'user_bosses' and policyname = 'user_bosses_update';
  if v is distinct from '(((( SELECT auth.uid() AS uid) = user_id) OR is_party_member_of(user_id)) AND ( SELECT is_active() AS is_active))' then bad := bad || ' user_bosses_update.qual=' || coalesce(v, '-'); end if;
  select with_check into v from pg_policies where schemaname = 'public' and tablename = 'user_bosses' and policyname = 'user_bosses_update';
  if v is distinct from '(((( SELECT auth.uid() AS uid) = user_id) OR is_party_member_of(user_id)) AND ( SELECT is_active() AS is_active))' then bad := bad || ' user_bosses_update.with_check=' || coalesce(v, '-'); end if;
  select qual into v from pg_policies where schemaname = 'public' and tablename = 'user_bosses' and policyname = 'user_bosses_delete';
  if v is distinct from '(((( SELECT auth.uid() AS uid) = user_id) OR is_party_member_of(user_id)) AND ( SELECT is_active() AS is_active))' then bad := bad || ' user_bosses_delete.qual=' || coalesce(v, '-'); end if;
  if bad <> '' then raise exception 'หยุด: ฐานข้อมูลไม่ตรงกับที่ตรวจไว้ —% · ไม่มีอะไรถูกแก้', bad; end if;
end
$guard$;

-- ---------- 1) user_bosses: เขียนได้เฉพาะเจ้าของรายการ หรือสมาชิกที่มีแพ็กเกจจับเวลาบอส ----------
drop policy user_bosses_insert on public.user_bosses;
create policy user_bosses_insert on public.user_bosses for insert to public
  with check ((((select auth.uid()) = user_id) or (is_party_member_of(user_id) and (select has_timers_plan((select auth.uid()))))) and (select is_active()));
drop policy user_bosses_update on public.user_bosses;
create policy user_bosses_update on public.user_bosses for update to public
  using ((((select auth.uid()) = user_id) or (is_party_member_of(user_id) and (select has_timers_plan((select auth.uid()))))) and (select is_active()))
  with check ((((select auth.uid()) = user_id) or (is_party_member_of(user_id) and (select has_timers_plan((select auth.uid()))))) and (select is_active()));
drop policy user_bosses_delete on public.user_bosses;
create policy user_bosses_delete on public.user_bosses for delete to public
  using ((((select auth.uid()) = user_id) or (is_party_member_of(user_id) and (select has_timers_plan((select auth.uid()))))) and (select is_active()));

-- ---------- 2) บอส Custom ----------
create or replace function public.add_custom_boss_timer(p_boss_id uuid, p_server_id text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare b public.custom_bosses := public.cb_lock_boss(p_boss_id); t uuid;
begin
  perform public.cb_require_server(b.owner_id, p_server_id);
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  if auth.uid() <> b.owner_id and not public.has_timers_plan(auth.uid()) then
    raise exception 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  end if;
  select id into t from public.custom_boss_timers
    where owner_id = b.owner_id and custom_boss_id = b.id and server_id = p_server_id;
  if t is not null then return t; end if;
  if not public.boss_slot_available(b.owner_id) then
    raise exception 'บัญชีฟรีจับเวลาบอสได้สูงสุด 1 ตัว — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อไม่จำกัด';
  end if;
  insert into public.custom_boss_timers(owner_id, custom_boss_id, server_id)
    values (b.owner_id, b.id, p_server_id) returning id into t;
  return t;
end $function$;

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

CREATE OR REPLACE FUNCTION public.remove_custom_boss_timer(p_boss_id uuid, p_server_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  DELETE FROM public.custom_boss_timers WHERE owner_id=b.owner_id
    AND custom_boss_id=b.id AND server_id=p_server_id;
END $function$;

CREATE OR REPLACE FUNCTION public.set_custom_boss_time(p_boss_id uuid, p_server_id text, p_target_time timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id); who text;
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  IF p_target_time IS NOT NULL AND NOT isfinite(p_target_time) THEN RAISE EXCEPTION 'Invalid target time'; END IF;
  SELECT display_name INTO who FROM public.profiles WHERE id=auth.uid();
  UPDATE public.custom_boss_timers SET target_time=p_target_time,
    started_by=CASE WHEN p_target_time IS NULL THEN NULL ELSE who END
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
END $function$;

CREATE OR REPLACE FUNCTION public.set_custom_boss_marker(p_boss_id uuid, p_server_id text, p_x numeric, p_y numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE b public.custom_bosses:=public.cb_lock_boss(p_boss_id);
BEGIN
  -- สมาชิกปาร์ตี้ที่ไม่มีแพ็กเกจ "จับเวลาบอส" = ดูอย่างเดียว (หัวปาร์ตี้/เจ้าของบอสทำได้เสมอ)
  IF auth.uid()<>b.owner_id AND NOT public.has_timers_plan(auth.uid()) THEN
    RAISE EXCEPTION 'แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น';
  END IF;
  PERFORM public.cb_require_server(b.owner_id,p_server_id);
  UPDATE public.custom_boss_timers SET marker_x=p_x,marker_y=p_y
    WHERE owner_id=b.owner_id AND custom_boss_id=b.id AND server_id=p_server_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Timer not found'; END IF;
END $function$;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 8 แถว ok = true ทุกแถว:
--   policy user_bosses_delete / user_bosses_insert / user_bosses_update (มี has_timers_plan)
--   function add_custom_boss_timer bb2f0bfcd2bc9b5cf8a369ca2ff545fd · record_custom_kill 7be3cdc025282c5e6b27ef61f8d90fed
--            remove_custom_boss_timer e72d569fc7f53af915995098211bc446 · set_custom_boss_marker e55be35db49e2f0daa91a8501c74398e
--            set_custom_boss_time c5a884dab7c016749c192819fc703619 (ok = auth เรียกได้ และ anon เรียกไม่ได้ เหมือนเดิม)
select 'policy' as kind, policyname::text as name, cmd::text as detail,
       coalesce(qual, '') || coalesce(with_check, '') like '%has_timers_plan%' as ok
  from pg_policies
 where schemaname = 'public' and tablename = 'user_bosses' and policyname <> 'user_bosses_select'
union all
select 'function', p.oid::regprocedure::text, md5(replace(p.prosrc, E'\r', '')),
       has_function_privilege('authenticated', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('add_custom_boss_timer', 'record_custom_kill', 'remove_custom_boss_timer', 'set_custom_boss_time', 'set_custom_boss_marker')
 order by 1, 2;
