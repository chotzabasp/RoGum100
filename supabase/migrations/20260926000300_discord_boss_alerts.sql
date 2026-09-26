-- ============================================================
-- แจ้งเตือนบอสจะเกิด เข้าห้อง Discord (Webhook) — ทำงานบนเซิร์ฟเวอร์ แม้ไม่มีใครเปิดเว็บ
--   เจ้าของรายการบอส (หัวปาร์ตี้ / คนล่าเดี่ยว) ตั้งได้ 1 Webhook · ใช้ได้กับแพ็กจับเวลาบอส / 4 in 1 (has_timers_plan)
--   pg_cron เรียก discord_boss_alert_tick() ทุก 1 นาที → หาบอสที่จะเกิดภายใน lead_minutes (1/3/5/10)
--   ส่งครั้งเดียวต่อรอบเกิด (discord_alert_log กันซ้ำ) รวมหลายตัวในข้อความเดียวต่อรอบ · pg_net ส่ง HTTP ออก
-- ความปลอดภัย:
--   ลิงก์ Webhook เก็บในตารางที่ไม่มีใครอ่านตรงได้ (ไม่มีสิทธิ์ตาราง) เข้าถึงผ่าน RPC ของเจ้าของเท่านั้น และส่งกลับแบบซ่อนรหัส
--   รับเฉพาะ https://discord.com/api/webhooks/<id>/<token> (กันส่งไปเว็บอื่น) · ชื่อบอส/แผนที่ที่ผู้ใช้ตั้งเองถูกกัน @ ไม่ให้แท็กคน
--   allowed_mentions ของ Discord อนุญาตแท็กเฉพาะที่ผู้ใช้เลือก (ไม่แท็ก / @here / คน / ยศ)
-- ============================================================
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

begin;

create table if not exists public.discord_alert_settings (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  webhook_url text not null,
  enabled boolean not null default true,
  lead_minutes integer not null default 3,
  mention text not null default 'none',
  mention_id text,
  last_test_at timestamptz,
  last_test_request_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint discord_alert_webhook_check check (webhook_url ~ '^https://((ptb|canary)\.)?discord(app)?\.com/api/webhooks/[0-9]{15,25}/[A-Za-z0-9_-]{20,200}$'),
  constraint discord_alert_lead_check check (lead_minutes in (1, 3, 5, 10)),
  constraint discord_alert_mention_check check (
    (mention in ('none', 'here') and mention_id is null) or
    (mention in ('user', 'role') and mention_id ~ '^[0-9]{15,25}$'))
);
alter table public.discord_alert_settings enable row level security;
revoke all on public.discord_alert_settings from public, anon, authenticated;

create table if not exists public.discord_alert_log (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  boss_key text not null,
  target_time timestamptz not null,
  sent_at timestamptz not null default now(),
  primary key (owner_id, boss_key, target_time)
);
alter table public.discord_alert_log enable row level security;
revoke all on public.discord_alert_log from public, anon, authenticated;

-- กัน @ ในข้อความที่มาจากผู้ใช้ (ชื่อบอสที่สร้างเอง/แผนที่) ไม่ให้กลายเป็นการแท็ก + ตัดความยาว
create or replace function public.discord_escape(p text)
returns text
language sql
immutable
set search_path to ''
as $function$
  select left(replace(replace(coalesce(p, ''), '@', '@' || chr(8203)), '`', ''''), 100);
$function$;

-- ส่งข้อความเข้า Webhook (แท็กเฉพาะที่ตั้งไว้) คืน id ของคำขอ pg_net
create or replace function public.discord_send(p_url text, p_mention text, p_mention_id text, p_text text)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_prefix text;
  v_allowed jsonb;
  v_id bigint;
begin
  v_prefix := case p_mention
    when 'here' then '@here '
    when 'user' then '<@' || p_mention_id || '> '
    when 'role' then '<@&' || p_mention_id || '> '
    else '' end;
  v_allowed := case p_mention
    when 'here' then jsonb_build_object('parse', jsonb_build_array('everyone'))
    when 'user' then jsonb_build_object('parse', '[]'::jsonb, 'users', jsonb_build_array(p_mention_id))
    when 'role' then jsonb_build_object('parse', '[]'::jsonb, 'roles', jsonb_build_array(p_mention_id))
    else jsonb_build_object('parse', '[]'::jsonb) end;
  select net.http_post(
    url := p_url,
    body := jsonb_build_object(
      'content', left(v_prefix || p_text, 1990),
      'username', 'Gum100',
      'avatar_url', 'https://gum100.com/logo-gum100.png?v=2',
      'allowed_mentions', v_allowed),
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 5000
  ) into v_id;
  return v_id;
end;
$function$;

-- ทุก 1 นาที: หาบอสที่จะเกิดภายในเวลาที่ตั้งของแต่ละเจ้าของ แล้วส่งครั้งเดียวต่อรอบเกิด
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
         and ub.target_time > now() and ub.target_time <= now() + make_interval(mins => s.lead_minutes)
      union all
      select 'c:' || t.id::text, t.target_time, cb.name, cb.map_location
        from public.custom_boss_timers t
        join public.custom_bosses cb on cb.id = t.custom_boss_id and cb.archived_at is null
       where t.owner_id = s.owner_id
         and t.target_time > now() and t.target_time <= now() + make_interval(mins => s.lead_minutes)
      order by 2
    loop
      insert into public.discord_alert_log (owner_id, boss_key, target_time)
        values (s.owner_id, r.k, r.t) on conflict do nothing;
      if not found then continue; end if;
      v_lines := v_lines || format('⏰ **%s** เกิดในอีก %s นาที · %s น.%s',
        public.discord_escape(r.name),
        greatest(1, ceil(extract(epoch from (r.t - now())) / 60))::int,
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

-- ---------- RPC ของเจ้าของ (หน้าตั้งค่า) ----------
create or replace function public.get_my_discord_alert()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
stable
as $function$
declare
  v public.discord_alert_settings%rowtype;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  select * into v from public.discord_alert_settings where owner_id = auth.uid();
  if not found then
    return jsonb_build_object('configured', false, 'has_plan', public.has_timers_plan(auth.uid()));
  end if;
  return jsonb_build_object(
    'configured', true,
    'has_plan', public.has_timers_plan(auth.uid()),
    'enabled', v.enabled,
    'lead_minutes', v.lead_minutes,
    'mention', v.mention,
    'mention_id', v.mention_id,
    'webhook_hint', regexp_replace(v.webhook_url, '^https://([^/]+)/api/webhooks/([0-9]+)/.*(.{4})$', '\1/api/webhooks/\2/••••\3'));
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
  if coalesce(p_lead_minutes, 3) not in (1, 3, 5, 10) then raise exception 'เวลาเตือนล่วงหน้าไม่ถูกต้อง'; end if;
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

create or replace function public.delete_my_discord_alert()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  delete from public.discord_alert_settings where owner_id = auth.uid();
  delete from public.discord_alert_log where owner_id = auth.uid();
end;
$function$;

-- ส่งข้อความทดสอบ (เว้น 20 วินาทีต่อครั้ง) · ผลการส่งอ่านด้วย check_my_discord_test()
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
    '✅ เชื่อมต่อ Gum100 สำเร็จ — จะแจ้งเตือนเข้าห้องนี้ก่อนบอสในรายการเกิด ' || v.lead_minutes || ' นาที'
    || case when v.enabled then '' else ' (ตอนนี้ปิดการแจ้งเตือนไว้)' end);
  update public.discord_alert_settings set last_test_at = now(), last_test_request_id = v_id where owner_id = auth.uid();
  return jsonb_build_object('request_id', v_id);
end;
$function$;

create or replace function public.check_my_discord_test()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_req bigint;
  v_code integer;
  v_err text;
  v_timed_out boolean;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  select last_test_request_id into v_req from public.discord_alert_settings where owner_id = auth.uid();
  if v_req is null then return jsonb_build_object('status', 'none'); end if;
  select status_code, error_msg, timed_out into v_code, v_err, v_timed_out from net._http_response where id = v_req;
  if not found then return jsonb_build_object('status', 'pending'); end if;
  if v_code between 200 and 299 then return jsonb_build_object('status', 'ok', 'code', v_code); end if;
  return jsonb_build_object('status', 'failed', 'code', v_code, 'timed_out', coalesce(v_timed_out, false));
end;
$function$;

revoke all on function public.discord_escape(text) from public, anon, authenticated;
revoke all on function public.discord_send(text, text, text, text) from public, anon, authenticated;
revoke all on function public.discord_boss_alert_tick() from public, anon, authenticated;
revoke all on function public.get_my_discord_alert() from public, anon;
revoke all on function public.save_my_discord_alert(text, boolean, integer, text, text) from public, anon;
revoke all on function public.delete_my_discord_alert() from public, anon;
revoke all on function public.test_my_discord_alert() from public, anon;
revoke all on function public.check_my_discord_test() from public, anon;
grant execute on function public.get_my_discord_alert() to authenticated;
grant execute on function public.save_my_discord_alert(text, boolean, integer, text, text) to authenticated;
grant execute on function public.delete_my_discord_alert() to authenticated;
grant execute on function public.test_my_discord_alert() to authenticated;
grant execute on function public.check_my_discord_test() to authenticated;

commit;

-- ตั้งเวลา: ทุก 1 นาทีเช็คบอส · ทุกวันตี 4 ล้างประวัติการรันของ pg_cron ที่เก่ากว่า 3 วัน (กันตารางโต)
select cron.unschedule(jobid) from cron.job where jobname in ('gum100-discord-boss-alerts', 'gum100-cron-history-cleanup');
select cron.schedule('gum100-discord-boss-alerts', '* * * * *', $$select public.discord_boss_alert_tick()$$);
select cron.schedule('gum100-cron-history-cleanup', '0 21 * * *', $$delete from cron.job_run_details where end_time < now() - interval '3 days'$$);

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ ext_net = true, ext_cron = true, jobs = 2, tables = 2,
--   settings_anon = false, settings_auth = false, tick_auth = false, save_auth = true
select exists(select 1 from pg_extension where extname = 'pg_net') as ext_net,
       exists(select 1 from pg_extension where extname = 'pg_cron') as ext_cron,
       (select count(*) from cron.job where jobname in ('gum100-discord-boss-alerts', 'gum100-cron-history-cleanup')) as jobs,
       (select count(*) from pg_tables where schemaname = 'public' and tablename in ('discord_alert_settings', 'discord_alert_log')) as tables,
       has_table_privilege('anon', 'public.discord_alert_settings', 'SELECT') as settings_anon,
       has_table_privilege('authenticated', 'public.discord_alert_settings', 'SELECT') as settings_auth,
       has_function_privilege('authenticated', 'public.discord_boss_alert_tick()', 'execute') as tick_auth,
       has_function_privilege('authenticated', 'public.save_my_discord_alert(text,boolean,integer,text,text)', 'execute') as save_auth;
