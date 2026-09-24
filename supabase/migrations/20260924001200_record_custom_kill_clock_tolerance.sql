-- ============================================================
-- แก้ "Invalid request/time" ที่ขึ้นบางครั้งตอนบันทึกการฆ่า Custom Boss
--
-- สาเหตุ: เว็บส่งเวลาตาย = เวลาตามนาฬิกาเครื่องผู้ใช้ (Date.now()) แต่ฟังก์ชันปฏิเสธทันทีถ้าเวลานั้น
-- เกิน clock_timestamp() ของเซิร์ฟเวอร์แม้แค่เสี้ยววินาที — เครื่องที่นาฬิกาเร็วกว่าเซิร์ฟเวอร์นิดเดียว
-- จึงโดนปฏิเสธเป็นพักๆ (บอสปกติ record_kill ไม่มีการเช็คนี้ เลยไม่เจอ)
--
-- แก้ (เปลี่ยนแค่บรรทัดเช็คเวลา ส่วนอื่นคงเดิมคำต่อคำจาก pg_get_functiondef ของฐานข้อมูลจริง 24 ก.ย. 2569):
--   - request id / เวลาว่าง / เวลาไม่ใช่ตัวเลขจริง → ข้อความเดิม 'Invalid request/time'
--   - เวลาตายเกินเวลาเซิร์ฟเวอร์ได้ไม่เกิน 5 นาที (เผื่อนาฬิกาเครื่องเร็ว) เกินกว่านั้นปฏิเสธเป็นภาษาไทย
--   เก็บ p_killed_at ตามที่ส่งมา (ไม่ปัดเวลา) เพื่อให้การกดซ้ำด้วย request id เดิมยังตรวจตรงกันได้
-- ============================================================
begin;

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
