-- ============================================================
-- กลุ่มโค้ด (แคมเปญ) — 1 บัญชีใช้ได้ 1 โค้ดต่อกลุ่ม (2026-09-27)
--   ตัวอย่าง: โค้ดแจก 4 in 1 7 วัน ให้สตรีมเมอร์ 3 คน คนละรหัส (นับยอดคนใช้แยกรายคนได้เหมือนเดิม)
--   ใส่กลุ่มเดียวกัน เช่น STREAMER-OCT — คนที่กรอกโค้ดที่ 2 ในกลุ่มเดียวกันจะถูกปฏิเสธ (ไม่ได้ 21 วัน)
--   1) promo_codes.group_key (ว่าง = ไม่มีกลุ่ม ทำงานเหมือนเดิมทุกอย่าง) ตัวพิมพ์ใหญ่ ตัดช่องว่างหัวท้าย
--   2) promo_group_check(): ตรวจกติกากลุ่ม (ใช้ภายในเท่านั้น) ล็อกคู่บัญชี+กลุ่ม กันกรอกพร้อมกันหลุดทั้งคู่
--   3) redeem_promo_code (ช่องโค้ดหน้าตั้งค่า) และ discount_code_check (โค้ดส่วนลดตอนซื้อ) เรียกตัวตรวจนี้
-- เนื้อฟังก์ชันเดิมคัดลอกตรงตัวจาก 20260927000300_discount_codes.sql (ตรวจ md5 ตรงกับฐานข้อมูลจริง) เพิ่มแค่ 1 บรรทัดต่อฟังก์ชัน
-- มีตัวกันในไฟล์: ถ้าฟังก์ชันในฐานข้อมูลไม่ตรงกับ repo จะหยุดทันที ไม่มีอะไรถูกแก้
-- ============================================================
begin;

do $guard$
declare v text; bad text := '';
begin
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.redeem_promo_code(text)'::regprocedure;
  if v is distinct from '336945b83ac777012af5a071f079327f' then bad := bad || ' redeem_promo_code=' || coalesce(v, '-'); end if;
  select md5(replace(prosrc, E'\r', '')) into v from pg_proc where oid = 'public.discount_code_check(text, text, uuid, boolean)'::regprocedure;
  if v is distinct from 'a8008419a2c6c598d37d9a43888b7b4a' then bad := bad || ' discount_code_check=' || coalesce(v, '-'); end if;
  if bad <> '' then raise exception 'หยุด: ฟังก์ชันในฐานข้อมูลไม่ตรงกับ repo —% · ไม่มีอะไรถูกแก้', bad; end if;
end
$guard$;

alter table public.promo_codes add column if not exists group_key text;
alter table public.promo_codes drop constraint if exists promo_codes_group_key_check;
alter table public.promo_codes add constraint promo_codes_group_key_check check (
  group_key is null or (group_key = upper(btrim(group_key)) and length(group_key) between 1 and 40)
);
create index if not exists promo_codes_group_key_idx on public.promo_codes (group_key) where group_key is not null;

create or replace function public.promo_group_check(p_group text, p_uid uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_used text;
begin
  if p_group is null then return; end if;
  -- ล็อกคู่ (บัญชี, กลุ่ม) จนจบธุรกรรม กันกรอก 2 โค้ดในกลุ่มเดียวกันพร้อมกันแล้วหลุดทั้งคู่
  perform pg_advisory_xact_lock(hashtextextended('promo_group:' || p_uid::text || ':' || p_group, 0));
  select r.code into v_used
    from public.promo_code_redemptions r
    join public.promo_codes pc on pc.code = r.code
   where r.user_id = p_uid and pc.group_key = p_group
   limit 1;
  if v_used is not null then
    raise exception 'คุณใช้โค้ดในแคมเปญนี้ไปแล้ว (โค้ด %) — 1 บัญชีใช้ได้ 1 โค้ดต่อแคมเปญ', v_used;
  end if;
end;
$function$;

revoke all on function public.promo_group_check(text, uuid) from public, anon, authenticated;

create or replace function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
  v_plan text;
  v_name text;
  v_bundle timestamptz;
  v_timers timestamptz;
  v_before timestamptz;
  v_base timestamptz;
  v_new timestamptz;
  v_points_after int;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;

  select * into v_row from public.promo_codes where code = v_code for update;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.reward_type = 'discount' then raise exception 'โค้ดนี้เป็นโค้ดส่วนลด ใช้ตอนกดซื้อแพ็กเกจ (กรอกในกล่องยืนยันการซื้อ)'; end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = auth.uid()) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;
  perform public.promo_group_check(v_row.group_key, auth.uid());

  insert into public.promo_code_redemptions (code, user_id) values (v_code, auth.uid());
  update public.promo_codes set used_count = used_count + 1 where code = v_code;

  if v_row.reward_type = 'plan_days' then
    v_plan := coalesce(v_row.plan_key, 'all');
    v_name := case v_plan
      when 'bundle' then '3 in 1'
      when 'timers' then 'จับเวลาบอส'
      when 'farm' then '1 in 1'
      when 'accountItems' then '2 in 1'
      else '4 in 1' end;
    select plan_bundle_expires_at, plan_timers_expires_at into v_bundle, v_timers
      from public.profiles where id = auth.uid() for update;

    if v_plan = 'bundle' then
      v_new := greatest(coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_bundle_expires_at = v_new where id = auth.uid();
    elsif v_plan = 'timers' then
      v_new := greatest(coalesce(v_timers, now()), now()) + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_timers_expires_at = v_new where id = auth.uid();
    elsif v_plan in ('farm', 'accountItems') then
      select expires_at into v_before from public.package_feature_entitlements
        where user_id = auth.uid() and feature = v_plan;
      v_new := greatest(coalesce(v_before, now()), coalesce(v_bundle, now()), now()) + (v_row.plan_days || ' days')::interval;
      insert into public.package_feature_entitlements (user_id, feature, expires_at) values (auth.uid(), v_plan, v_new)
        on conflict (user_id, feature) do update set expires_at = excluded.expires_at;
    else
      v_base := greatest(coalesce(v_bundle, now()), coalesce(v_timers, now()), now());
      v_new := v_base + (v_row.plan_days || ' days')::interval;
      update public.profiles set plan_bundle_expires_at = v_new, plan_timers_expires_at = v_new where id = auth.uid();
    end if;

    select points into v_points_after from public.profiles where id = auth.uid();
    insert into public.points_ledger (user_id, delta, balance_after, reason, actor, detail)
    values (auth.uid(), 0, v_points_after, 'promo_code', auth.uid(),
      'กรอกรหัสโปรโมชั่น '||v_code||' — แพ็กเกจ '||v_name||' จำนวน '||v_row.plan_days||' วัน');

    return jsonb_build_object('reward_type', 'plan_days', 'plan_key', v_plan, 'plan_days', v_row.plan_days, 'expires_at', v_new);
  else
    perform set_config('app.points_ledger_detail', 'กรอกรหัสโปรโมชั่น '||v_code, true);
    update public.profiles set points = points + v_row.points where id = auth.uid();
    return jsonb_build_object('reward_type', 'points', 'points', v_row.points);
  end if;
end;
$function$;

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;

create or replace function public.discount_code_check(p_code text, p_plan_key text, p_uid uuid, p_lock boolean)
returns public.promo_codes
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
begin
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;
  if p_lock then
    select * into v_row from public.promo_codes where code = v_code for update;
  else
    select * into v_row from public.promo_codes where code = v_code;
  end if;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.reward_type <> 'discount' then
    raise exception 'โค้ดนี้ไม่ใช่โค้ดส่วนลด — ใช้ที่ช่อง "โค้ดโปรโมชัน" หน้าตั้งค่า';
  end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = p_uid) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;
  perform public.promo_group_check(v_row.group_key, p_uid);
  if v_row.plan_key is not null and v_row.plan_key <> p_plan_key then
    raise exception 'โค้ดนี้ใช้ได้กับแพ็กเกจ % เท่านั้น', case v_row.plan_key
      when 'all' then '4 in 1' when 'bundle' then '3 in 1' when 'timers' then 'จับเวลาบอส'
      when 'accountItems' then '2 in 1' else '1 in 1' end;
  end if;
  return v_row;
end;
$function$;

revoke all on function public.discount_code_check(text, text, uuid, boolean) from public, anon, authenticated;

commit;

notify pgrst, 'reload schema';

-- ตรวจหลังรัน (อ่านอย่างเดียว) ต้องได้ 3 แถว + has_group_key = true:
--   discount_code_check eafd22df586d5f758c12b8e0bd2360b6 anon=false auth=false
--   promo_group_check c0ddad1624466070e82f3feb79a442c7 anon=false auth=false
--   redeem_promo_code 315a380671dae7a1a942bf7258af3975 anon=false auth=true
select p.oid::regprocedure as fn,
       md5(replace(p.prosrc, E'\r', '')) as md5,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       exists(select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'promo_codes' and column_name = 'group_key') as has_group_key
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('redeem_promo_code', 'discount_code_check', 'promo_group_check')
 order by 1;
