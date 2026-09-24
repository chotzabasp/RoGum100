-- ============================================================
-- กันบันทึกการฆ่าซ้ำ: บอสตัวเดียวกัน ปาร์ตี้เดียวกัน เวลาตายห่างกันไม่เกิน 60 วินาที = รอบเดียวกัน
--   (เช่น สมาชิก 2 คนกด MVP พร้อมกันคนละเครื่อง / กดรัวจากหลายแท็บ)
--   → ไม่สร้างรายการใหม่ คืนรหัสรายการเดิม และเพิ่มไอเทมที่รายการเดิมยังไม่มี (ไอเทมไม่หาย)
--   บอสที่เกิดเร็วที่สุดยังใช้เวลาหลายนาที การฆ่าตัวเดียวกันห่างกันไม่ถึง 1 นาทีจึงเป็นรอบเดียวกันแน่นอน
--
-- record_kill (บอสปกติ): เขียนจาก pg_get_functiondef ของฐานข้อมูลจริง (25 ก.ย. 2569) คงทุกอย่างเดิม
--   เพิ่ม pg_advisory_xact_lock ต่อ (ปาร์ตี้, บอส) กัน 2 คำสั่งเช็คพร้อมกันแล้วต่างคนต่างสร้าง
-- record_custom_kill (บอส Custom): จากฉบับล่าสุด 20260924001200 คงทุกอย่างเดิม
--   ใช้ล็อกแถว custom_boss_timers (FOR UPDATE) ที่มีอยู่แล้วเป็นตัวต่อคิว แล้วเช็คหลังได้ล็อก
-- หน้าเว็บ: ถ้าได้รายการของคนอื่นกลับมา จะแจ้ง "มีคนในปาร์ตี้บันทึกการฆ่านี้ไปแล้ว"
-- ============================================================
begin;

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
  select k.id into dup_kill
    from public.kills k
   where k.host_id = caller_host and k.boss_id = p_boss_id and k.custom_boss_id is null
     and p_killed_at is not null
     and k.killed_at between p_killed_at - interval '60 seconds' and p_killed_at + interval '60 seconds'
   order by abs(extract(epoch from (k.killed_at - p_killed_at)))
   limit 1;
  if dup_kill is not null then
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

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ true ทั้งสองแถว
select p.proname, pg_get_functiondef(p.oid) like '%60 seconds%' as has_dedupe
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('record_kill', 'record_custom_kill')
 order by 1;
