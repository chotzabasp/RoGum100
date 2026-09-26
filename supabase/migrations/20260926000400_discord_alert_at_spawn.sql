-- ============================================================
-- แจ้งเตือน Discord: เพิ่มตัวเลือก "ตอนบอสเกิด" (lead_minutes = 0)
--   0 = ส่งเมื่อถึงเวลาเกิด (ตัวเช็คทำงานทุก 1 นาที จึงเข้าภายใน 0–60 วินาทีหลังเกิด) ข้อความ "เกิดแล้ว!"
--   รับเฉพาะรอบที่เพิ่งเกิดไม่เกิน 2 นาที กันแจ้งย้อนหลังบอสที่ค้างเวลาเก่า · 1/3/5/10 ทำงานเหมือนเดิม
-- แทนที่ 3 ฟังก์ชันจาก 20260926000300_discord_boss_alerts.sql (รันวันเดียวกัน ไม่มีการแก้นอก repo) ส่วนอื่นคงเดิม
-- ============================================================
begin;

alter table public.discord_alert_settings drop constraint if exists discord_alert_lead_check;
alter table public.discord_alert_settings add constraint discord_alert_lead_check check (lead_minutes in (0, 1, 3, 5, 10));

create or replace function public.discord_boss_alert_tick()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  s record;
  r record;
  v_lines text[];
  v_sent integer := 0;
begin
  delete from public.discord_alert_log where target_time < now() - interval '2 days';

  for s in
    select d.* from public.discord_alert_settings d
      join public.profiles p on p.id = d.owner_id
     where d.enabled
       and (coalesce(p.role, '') = 'admin' or p.expires_at > now())
  loop
    if not public.has_timers_plan(s.owner_id) then continue; end if;
    v_lines := '{}';
    for r in
      select 'b:' || ub.id::text as k, ub.target_time as t,
             coalesce(b.name, ub.boss_id) as name, coalesce(nullif(b.map_location, ''), b.map) as loc
        from public.user_bosses ub
        left join public.bosses b on b.id = ub.boss_id
       where ub.user_id = s.owner_id
         and ((s.lead_minutes > 0 and ub.target_time > now() and ub.target_time <= now() + make_interval(mins => s.lead_minutes))
           or (s.lead_minutes = 0 and ub.target_time <= now() and ub.target_time > now() - interval '2 minutes'))
      union all
      select 'c:' || t.id::text, t.target_time, cb.name, cb.map_location
        from public.custom_boss_timers t
        join public.custom_bosses cb on cb.id = t.custom_boss_id and cb.archived_at is null
       where t.owner_id = s.owner_id
         and ((s.lead_minutes > 0 and t.target_time > now() and t.target_time <= now() + make_interval(mins => s.lead_minutes))
           or (s.lead_minutes = 0 and t.target_time <= now() and t.target_time > now() - interval '2 minutes'))
      order by 2
    loop
      insert into public.discord_alert_log (owner_id, boss_key, target_time)
        values (s.owner_id, r.k, r.t) on conflict do nothing;
      if not found then continue; end if;
      v_lines := v_lines || format('⏰ **%s** %s · %s น.%s',
        public.discord_escape(r.name),
        case when r.t <= now() then 'เกิดแล้ว!'
             else 'เกิดในอีก ' || greatest(1, ceil(extract(epoch from (r.t - now())) / 60))::int || ' นาที' end,
        to_char(r.t at time zone 'Asia/Bangkok', 'HH24:MI'),
        case when coalesce(r.loc, '') <> '' then ' · ' || public.discord_escape(r.loc) else '' end);
    end loop;
    if coalesce(array_length(v_lines, 1), 0) = 0 then continue; end if;
    perform public.discord_send(s.webhook_url, s.mention, s.mention_id, array_to_string(v_lines[1:15], E'\n'));
    v_sent := v_sent + 1;
  end loop;
  return v_sent;
end;
$function$;

create or replace function public.save_my_discord_alert(
  p_webhook_url text, p_enabled boolean, p_lead_minutes integer, p_mention text, p_mention_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_url text := nullif(btrim(coalesce(p_webhook_url, '')), '');
  v_mention text := coalesce(p_mention, 'none');
  v_mention_id text := nullif(regexp_replace(coalesce(p_mention_id, ''), '[^0-9]', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if not public.has_timers_plan(auth.uid()) then
    raise exception 'แจ้งเตือน Discord ใช้ได้กับแพ็กเกจจับเวลาบอส หรือ 4 in 1';
  end if;
  if v_url is not null and v_url !~ '^https://((ptb|canary)\.)?discord(app)?\.com/api/webhooks/[0-9]{15,25}/[A-Za-z0-9_-]{20,200}$' then
    raise exception 'ลิงก์ Webhook ไม่ถูกต้อง — ต้องขึ้นต้นด้วย https://discord.com/api/webhooks/';
  end if;
  if coalesce(p_lead_minutes, 3) not in (0, 1, 3, 5, 10) then raise exception 'เวลาเตือนล่วงหน้าไม่ถูกต้อง'; end if;
  if v_mention not in ('none', 'here', 'user', 'role') then raise exception 'รูปแบบการแท็กไม่ถูกต้อง'; end if;
  if v_mention in ('user', 'role') and (v_mention_id is null or length(v_mention_id) not between 15 and 25) then
    raise exception 'กรอก Discord ID ของคนหรือยศที่จะแท็ก (ตัวเลข 17–20 หลัก)';
  end if;
  if v_mention in ('none', 'here') then v_mention_id := null; end if;

  if v_url is null then
    if not exists(select 1 from public.discord_alert_settings where owner_id = auth.uid()) then
      raise exception 'กรุณาวางลิงก์ Webhook';
    end if;
    update public.discord_alert_settings
       set enabled = coalesce(p_enabled, true), lead_minutes = coalesce(p_lead_minutes, 3),
           mention = v_mention, mention_id = v_mention_id, updated_at = now()
     where owner_id = auth.uid();
  else
    insert into public.discord_alert_settings (owner_id, webhook_url, enabled, lead_minutes, mention, mention_id)
    values (auth.uid(), v_url, coalesce(p_enabled, true), coalesce(p_lead_minutes, 3), v_mention, v_mention_id)
    on conflict (owner_id) do update
      set webhook_url = excluded.webhook_url, enabled = excluded.enabled, lead_minutes = excluded.lead_minutes,
          mention = excluded.mention, mention_id = excluded.mention_id, updated_at = now();
  end if;
  return public.get_my_discord_alert();
end;
$function$;

create or replace function public.test_my_discord_alert()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v public.discord_alert_settings%rowtype;
  v_id bigint;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if not public.has_timers_plan(auth.uid()) then
    raise exception 'แจ้งเตือน Discord ใช้ได้กับแพ็กเกจจับเวลาบอส หรือ 4 in 1';
  end if;
  select * into v from public.discord_alert_settings where owner_id = auth.uid() for update;
  if not found then raise exception 'บันทึกลิงก์ Webhook ก่อน แล้วค่อยกดทดสอบ'; end if;
  if v.last_test_at is not null and v.last_test_at > now() - interval '20 seconds' then
    raise exception 'เพิ่งส่งทดสอบไป รอสักครู่แล้วลองใหม่';
  end if;
  v_id := public.discord_send(v.webhook_url, v.mention, v.mention_id,
    '✅ เชื่อมต่อ Gum100 สำเร็จ — จะแจ้งเตือนเข้าห้องนี้'
    || case when v.lead_minutes = 0 then 'ตอนบอสในรายการเกิด' else 'ก่อนบอสในรายการเกิด ' || v.lead_minutes || ' นาที' end
    || case when v.enabled then '' else ' (ตอนนี้ปิดการแจ้งเตือนไว้)' end);
  update public.discord_alert_settings set last_test_at = now(), last_test_request_id = v_id where owner_id = auth.uid();
  return jsonb_build_object('request_id', v_id);
end;
$function$;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ lead0_allowed = true, tick_at_spawn = true, save_allows_0 = true,
--   tick_auth = false, save_auth = true, test_auth = true
select pg_get_constraintdef((select oid from pg_constraint where conname = 'discord_alert_lead_check')) like '%0, 1, 3, 5, 10%' as lead0_allowed,
       pg_get_functiondef('public.discord_boss_alert_tick()'::regprocedure) like '%เกิดแล้ว!%' as tick_at_spawn,
       pg_get_functiondef('public.save_my_discord_alert(text,boolean,integer,text,text)'::regprocedure) like '%(0, 1, 3, 5, 10)%' as save_allows_0,
       has_function_privilege('authenticated', 'public.discord_boss_alert_tick()', 'execute') as tick_auth,
       has_function_privilege('authenticated', 'public.save_my_discord_alert(text,boolean,integer,text,text)', 'execute') as save_auth,
       has_function_privilege('authenticated', 'public.test_my_discord_alert()', 'execute') as test_auth;
