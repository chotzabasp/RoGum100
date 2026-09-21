-- ============================================================
--  Gum100 — ชุดปรับปรุงรอบที่ 2 (2026-09-22)
--   1) ราคารายปี 3 in 1 / จับเวลาบอส: ราคาเต็ม 1,990 · ช่วงโปร 990 (buy_plan)
--   2) ล้างข้อมูลบอส: ตัดช่องว่างหน้า/หลังชื่อไอเทม และลบไอเทมซ้ำในบอสตัวเดียวกัน (ไม่แตะ id / ชื่อบอส)
--   3) จำกัดสร้าง QR เติมเงินที่ยังไม่สำเร็จ (รอชำระ/ไม่สำเร็จ/หมดอายุ) ไม่เกิน 5 ครั้งต่อชั่วโมงต่อคน — รายการที่จ่ายสำเร็จแล้วไม่นับ
--   4) บันทึกประวัติการใช้แต้ม points_ledger (trigger บนตาราง profiles จับทุกครั้งที่แต้มเปลี่ยน)
--   5) บันทึกการกระทำของแอดมินแยกตาราง topup_admin_log (สมาชิกอ่านไม่ได้) + ย้ายหมายเหตุเดิมออกจาก provider_payload
--      + ฟังก์ชันใหม่ admin_reverse_topup (ยกเลิกรายการเติมเงิน) / admin_deduct_points (หักแต้ม) + สถานะ 'reversed'
--
--  ⚠ ลำดับ: รันไฟล์นี้ "หลังเว็บรุ่นใหม่ขึ้นแล้วเท่านั้น" (หน้าแอดมินรุ่นเก่าจะไม่เห็นหมายเหตุหลังข้อ 5)
--  (การล็อกอินด้วย username ยังใช้ได้ตามเดิม ไฟล์นี้ไม่แตะ email_for_username)
--  รันทั้งไฟล์รวดเดียวใน Supabase Dashboard -> SQL Editor -> New query -> Run
--  แต่ละช่วงครอบ begin/commit และรันซ้ำได้อย่างปลอดภัย
-- ============================================================


-- ============================================================
-- ช่วง 1: buy_plan — ราคารายปีของ 3 in 1 / จับเวลาบอส
--   ช่วงโปร (ก่อน promo_active หมด): รายเดือน 99 · รายปี 990     หลังโปร: รายเดือน 199 · รายปี 1,990
--   4 in 1: โปร 175 / 1,750 · ปกติ 349 / 3,490    1 in 1 = 99 · 2 in 1 = 149 (ไม่มีโปร)
-- ============================================================
begin;

create or replace function public.buy_plan(p_plan_key text, p_cycle text)
returns timestamp with time zone
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_price integer; v_days integer; v_points integer;
  v_bundle timestamptz; v_timers timestamptz; v_before timestamptz; v_new timestamptz;
  v_bundle_new timestamptz; v_timers_new timestamptz; v_name text;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then
    raise exception 'แพ็กเกจไม่ถูกต้อง';
  end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  if p_plan_key in ('farm','accountItems') and p_cycle <> 'monthly' then
    raise exception 'แพ็กเกจนี้รองรับเฉพาะรายเดือน';
  end if;
  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  v_price := case
    when p_plan_key in ('bundle','timers') and p_cycle = 'yearly' and public.promo_active() then 990
    when p_plan_key in ('bundle','timers') and p_cycle = 'yearly' then 1990
    when p_plan_key in ('bundle','timers') and public.promo_active() then 99
    when p_plan_key in ('bundle','timers') then 199
    when p_plan_key = 'all' and public.promo_active() then (case p_cycle when 'yearly' then 1750 else 175 end)
    when p_plan_key = 'all' then (case p_cycle when 'yearly' then 3490 else 349 end)
    when p_plan_key = 'accountItems' then 149
    else 99
  end;
  select points, plan_bundle_expires_at, plan_timers_expires_at into v_points, v_bundle, v_timers
    from public.profiles where id = v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points, 0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)', v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id = v_uid and feature = p_plan_key;
    v_before := greatest(v_before, v_bundle);
    v_new := greatest(coalesce(v_before, now()), now()) + interval '30 days';
    insert into public.package_feature_entitlements(user_id, feature, expires_at) values (v_uid, p_plan_key, v_new)
      on conflict (user_id, feature) do update set expires_at = excluded.expires_at;
  elsif p_plan_key = 'bundle' then
    v_before := v_bundle;
    v_new := greatest(coalesce(v_bundle, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_bundle_expires_at = v_new where id = v_uid;
  elsif p_plan_key = 'timers' then
    v_before := v_timers;
    v_new := greatest(coalesce(v_timers, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_timers_expires_at = v_new where id = v_uid;
  else
    v_bundle_new := greatest(coalesce(v_bundle, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    v_timers_new := greatest(coalesce(v_timers, now()), now()) +
      case when p_cycle = 'yearly' then interval '1 year' else interval '30 days' end;
    v_before := least(coalesce(v_bundle, now()), coalesce(v_timers, now()));
    v_new := least(v_bundle_new, v_timers_new);
    update public.profiles set plan_bundle_expires_at = v_bundle_new, plan_timers_expires_at = v_timers_new where id = v_uid;
  end if;
  update public.profiles set points = points - v_price where id = v_uid;
  v_name := case p_plan_key
    when 'farm' then '1 in 1 — ยอดนักฟาม'
    when 'accountItems' then '2 in 1'
    when 'bundle' then '3 in 1'
    when 'timers' then 'จับเวลาบอส'
    else '4 in 1' end;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id, plan_key, plan_name, cycle, points_spent, days_added, expires_before, expires_after)
    values (v_uid, p_plan_key, v_name, p_cycle, v_price, v_days, v_before, v_new);
  end if;
  return v_new;
end;
$function$;

commit;


-- ============================================================
-- ช่วง 2: ล้างข้อมูลบอส (เปลี่ยนเฉพาะบอสที่มีไอเทมซ้ำหรือมีช่องว่างเกิน — ตอนนี้คือ Egnigem Cenia, Kades, Stormy Knight)
--   ไม่แตะ id / ชื่อบอส / ลำดับไอเทมที่เหลือ
-- ============================================================
begin;

update public.bosses b
   set items = c.items
  from (
    select id, coalesce(jsonb_agg(x order by ord), '[]'::jsonb) as items
      from (
        select distinct on (b2.id, btrim(v)) b2.id, btrim(v) as x, o as ord
          from public.bosses b2
          cross join lateral jsonb_array_elements_text(b2.items) with ordinality as t(v, o)
         where jsonb_typeof(b2.items) = 'array' and btrim(v) <> ''
         order by b2.id, btrim(v), o
      ) d
     group by id
  ) c
 where b.id = c.id
   and b.items is distinct from c.items;

commit;


-- ============================================================
-- ช่วง 3: จำกัดสร้าง QR เติมเงินไม่เกิน 5 ครั้งต่อชั่วโมงต่อคน
--   นับเฉพาะรายการ QR ที่ "ยังไม่สำเร็จ" (รอชำระ / ไม่สำเร็จ / หมดอายุ) — รายการที่จ่ายสำเร็จแล้ว, ต้องตรวจสอบ, ยกเลิกแล้ว และที่แอดมินเติมให้ ไม่นับ
-- ============================================================
begin;

create or replace function public.topup_rate_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.provider = 'tmweasy' then
    perform pg_advisory_xact_lock(hashtextextended('topup_rate:' || new.user_id::text, 0));
    if (select count(*) from public.topup_transactions
         where user_id = new.user_id and provider = 'tmweasy'
           and status in ('pending', 'failed', 'expired')
           and created_at > now() - interval '1 hour') >= 5 then
      raise exception 'คุณทำรายการมากเกินไป ติดต่อแอดมินเพื่อทำรายการ';
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists topup_rate_guard_trg on public.topup_transactions;
create trigger topup_rate_guard_trg
  before insert on public.topup_transactions
  for each row execute function public.topup_rate_guard();

-- หน้าเว็บเรียกก่อนสร้าง QR เพื่อขึ้นข้อความให้เข้าใจ (ตัวบังคับจริงคือ trigger ข้างบน)
create or replace function public.topup_attempts_left()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select greatest(0, 5 - count(*))::integer
    from public.topup_transactions
   where user_id = auth.uid() and provider = 'tmweasy' and status in ('pending', 'failed', 'expired')
     and created_at > now() - interval '1 hour';
$$;

revoke all on function public.topup_attempts_left() from public, anon;
grant execute on function public.topup_attempts_left() to authenticated;
revoke all on function public.topup_rate_guard() from public, anon, authenticated;

commit;


-- ============================================================
-- ช่วง 4: ประวัติการใช้แต้ม — ทุกครั้งที่ profiles.points เปลี่ยน ฐานข้อมูลบันทึกเองอัตโนมัติ
--   (ประวัติเริ่มนับจากวันที่รันไฟล์นี้ ไม่ย้อนหลัง) เหตุผลของรายการอนุมานจากฟังก์ชันที่เรียกใช้อยู่
-- ============================================================
begin;

create table if not exists public.points_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  delta integer not null,
  balance_after integer not null,
  reason text not null,
  actor uuid,
  created_at timestamptz not null default now()
);
create index if not exists points_ledger_user_time_idx on public.points_ledger (user_id, created_at desc);

alter table public.points_ledger enable row level security;
drop policy if exists points_ledger_select on public.points_ledger;
create policy points_ledger_select on public.points_ledger
  for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());
revoke all on public.points_ledger from anon, authenticated;
grant select on public.points_ledger to authenticated;

create or replace function public.log_points_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  q text := lower(coalesce(current_query(), ''));
  r text;
begin
  r := case
    when position('credit_tmweasy_topup' in q) > 0 then 'topup'
    when position('admin_grant_points' in q) > 0 then 'admin_grant'
    when position('admin_confirm_topup' in q) > 0 then 'admin_confirm_topup'
    when position('admin_reverse_topup' in q) > 0 then 'admin_reverse'
    when position('admin_deduct_points' in q) > 0 then 'admin_deduct'
    when position('approve_topup' in q) > 0 then 'slip_topup'
    when position('buy_plan' in q) > 0 then 'plan_purchase'
    when position('buy_server_slot' in q) > 0 then 'server_slot'
    when position('add_party_member' in q) > 0 then 'party_slot'
    when position('post_announcement' in q) > 0 then 'announcement'
    when position('spend_points' in q) > 0 then 'spend'
    else 'other'
  end;
  insert into public.points_ledger (user_id, delta, balance_after, reason, actor)
  values (new.id, new.points - old.points, new.points, r, auth.uid());
  return new;
end;
$function$;

revoke all on function public.log_points_change() from public, anon, authenticated;

drop trigger if exists points_ledger_trg on public.profiles;
create trigger points_ledger_trg
  after update of points on public.profiles
  for each row
  when (old.points is distinct from new.points)
  execute function public.log_points_change();

commit;


-- ============================================================
-- ช่วง 5: บันทึกการกระทำของแอดมิน (topup_admin_log) + ฟังก์ชันแอดมินชุดใหม่
--   หมายเหตุ/ผู้กดเดิมอยู่ใน topup_transactions.provider_payload ซึ่งสมาชิกอ่านของตัวเองได้ผ่าน API → ย้ายมาตารางนี้
--   ที่ไม่มีนโยบายให้สมาชิกอ่านเลย (แอดมินเท่านั้น)
-- ============================================================
begin;

create table if not exists public.topup_admin_log (
  id bigint generated always as identity primary key,
  transaction_id uuid references public.topup_transactions(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in ('confirm', 'close', 'grant', 'reverse', 'deduct')),
  points integer,
  note text,
  admin_id uuid,
  previous_status text,
  created_at timestamptz not null default now()
);
create index if not exists topup_admin_log_tx_idx on public.topup_admin_log (transaction_id);
create index if not exists topup_admin_log_user_idx on public.topup_admin_log (user_id, created_at desc);

alter table public.topup_admin_log enable row level security;
drop policy if exists topup_admin_log_admin_select on public.topup_admin_log;
create policy topup_admin_log_admin_select on public.topup_admin_log
  for select to authenticated using (public.is_admin());
revoke all on public.topup_admin_log from anon, authenticated;
grant select on public.topup_admin_log to authenticated;

-- ย้ายหมายเหตุเดิมที่แอดมินเคยกดไว้ (ยืนยัน/ปิด/เติมโดยตรง) จาก provider_payload มาตารางใหม่ แล้วลบออกจาก payload
insert into public.topup_admin_log (transaction_id, user_id, action, points, note, admin_id, previous_status, created_at)
select t.id, t.user_id,
       t.provider_payload -> 'manual' ->> 'action',
       coalesce(nullif(t.provider_payload -> 'manual' ->> 'points', '')::integer,
                case when t.provider_payload -> 'manual' ->> 'action' = 'grant' then t.points end),
       t.provider_payload -> 'manual' ->> 'note',
       nullif(t.provider_payload -> 'manual' ->> 'by', '')::uuid,
       t.provider_payload -> 'manual' ->> 'previous_status',
       coalesce((t.provider_payload -> 'manual' ->> 'at')::timestamptz, t.updated_at, now())
  from public.topup_transactions t
 where jsonb_typeof(t.provider_payload) = 'object'
   and jsonb_typeof(t.provider_payload -> 'manual') = 'object'
   and (t.provider_payload -> 'manual' ->> 'action') in ('confirm', 'close', 'grant')
   and not exists (select 1 from public.topup_admin_log l where l.transaction_id = t.id);

update public.topup_transactions
   set provider_payload = provider_payload - 'manual'
 where jsonb_typeof(provider_payload) = 'object'
   and (provider_payload -> 'manual') is not null;

-- เพิ่มสถานะ 'reversed' (ยกเลิกรายการที่เติมไปแล้ว)
alter table public.topup_transactions drop constraint if exists topup_transactions_status_check;
do $$
declare c text;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'public.topup_transactions'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%manual_review%'
  loop
    execute format('alter table public.topup_transactions drop constraint %I', c);
  end loop;
end $$;
alter table public.topup_transactions
  add constraint topup_transactions_status_check
  check (status in ('pending', 'paid', 'credited', 'failed', 'expired', 'manual_review', 'reversed'));

-- ยืนยันรับเงิน (เขียนใหม่: บันทึกลง topup_admin_log แทน provider_payload)
create or replace function public.admin_confirm_topup(p_transaction_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  tx public.topup_transactions%rowtype;
  v_points integer;
  v_prev text;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;

  select * into tx from public.topup_transactions where id = p_transaction_id for update;
  if not found then raise exception 'ไม่พบรายการนี้'; end if;
  if tx.status = 'credited' then raise exception 'รายการนี้เติมแต้มไปแล้ว'; end if;
  if tx.status not in ('pending', 'paid', 'manual_review', 'expired', 'failed') then
    raise exception 'สถานะรายการไม่รองรับ';
  end if;

  v_points := floor(coalesce(tx.received_amount, tx.requested_amount))::integer;
  if v_points is null or v_points < 1 or v_points > 100000 then raise exception 'จำนวนแต้มไม่ถูกต้อง'; end if;

  update public.profiles set points = points + v_points where id = tx.user_id;
  if not found then raise exception 'ไม่พบบัญชีสมาชิก'; end if;

  v_prev := tx.status;
  update public.topup_transactions set
    status = 'credited',
    received_amount = coalesce(received_amount, v_points),
    paid_at = coalesce(paid_at, now()),
    credited_at = now(),
    updated_at = now()
  where id = tx.id;

  insert into public.topup_admin_log (transaction_id, user_id, action, points, note, admin_id, previous_status)
  values (tx.id, tx.user_id, 'confirm', v_points, nullif(btrim(coalesce(p_note, '')), ''), auth.uid(), v_prev);

  return jsonb_build_object('ok', true, 'points', v_points, 'previous_status', v_prev);
end;
$function$;

-- ปิดรายการที่ไม่ได้จ่ายจริง (เขียนใหม่: บันทึกลง topup_admin_log)
create or replace function public.admin_close_topup(p_transaction_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  tx public.topup_transactions%rowtype;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;

  select * into tx from public.topup_transactions where id = p_transaction_id for update;
  if not found then raise exception 'ไม่พบรายการนี้'; end if;
  if tx.status not in ('pending', 'manual_review') then
    raise exception 'ปิดได้เฉพาะรายการรอชำระหรือรอตรวจสอบ';
  end if;

  update public.topup_transactions set status = 'expired', updated_at = now() where id = tx.id;

  insert into public.topup_admin_log (transaction_id, user_id, action, note, admin_id, previous_status)
  values (tx.id, tx.user_id, 'close', nullif(btrim(coalesce(p_note, '')), ''), auth.uid(), tx.status);

  return jsonb_build_object('ok', true, 'previous_status', tx.status);
end;
$function$;

-- เติมแต้มให้สมาชิกโดยตรง (เขียนใหม่: บันทึกลง topup_admin_log)
create or replace function public.admin_grant_points(p_user_id uuid, p_points integer, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_note text := btrim(coalesce(p_note, ''));
  v_balance integer;
  v_tx uuid;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if p_user_id is null then raise exception 'ไม่ได้ระบุสมาชิก'; end if;
  if p_points is null or p_points < 1 or p_points > 100000 then
    raise exception 'จำนวนแต้มต้องอยู่ระหว่าง 1 - 100,000';
  end if;
  if char_length(v_note) < 3 or char_length(v_note) > 200 then
    raise exception 'กรุณาใส่หมายเหตุ 3-200 ตัวอักษร (เช่น โอนผ่านเพจ FB วันที่ ... ยอด ... บาท)';
  end if;

  update public.profiles set points = points + p_points where id = p_user_id returning points into v_balance;
  if not found then raise exception 'ไม่พบบัญชีสมาชิก'; end if;

  insert into public.topup_transactions
    (user_id, provider, requested_amount, received_amount, points, status, paid_at, credited_at)
  values
    (p_user_id, 'manual', p_points, p_points, p_points, 'credited', now(), now())
  returning id into v_tx;

  insert into public.topup_admin_log (transaction_id, user_id, action, points, note, admin_id)
  values (v_tx, p_user_id, 'grant', p_points, v_note, auth.uid());

  return jsonb_build_object('ok', true, 'transaction_id', v_tx, 'points', p_points, 'balance', v_balance);
end;
$function$;

-- ยกเลิกรายการเติมเงินที่เติมสำเร็จไปแล้ว: หักแต้มที่เติมออกจากสมาชิก (หักไม่ได้ถ้าสมาชิกใช้แต้มไปจนไม่พอ) และเปลี่ยนสถานะเป็น reversed
create or replace function public.admin_reverse_topup(p_transaction_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_note text := btrim(coalesce(p_note, ''));
  tx public.topup_transactions%rowtype;
  v_points integer;
  v_balance integer;
  v_cur integer;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if char_length(v_note) < 3 or char_length(v_note) > 200 then
    raise exception 'กรุณาใส่หมายเหตุ 3-200 ตัวอักษร';
  end if;

  select * into tx from public.topup_transactions where id = p_transaction_id for update;
  if not found then raise exception 'ไม่พบรายการนี้'; end if;
  if tx.status <> 'credited' then raise exception 'ยกเลิกได้เฉพาะรายการที่เติมแต้มสำเร็จแล้ว'; end if;

  -- แต้มที่เติมไปจริง: ถ้าแอดมินเคยยืนยัน/เติมให้ ใช้ตามบันทึก ไม่งั้นใช้แต้มของรายการ
  select l.points into v_points from public.topup_admin_log l
   where l.transaction_id = tx.id and l.action in ('confirm', 'grant') and l.points is not null
   order by l.id desc limit 1;
  v_points := coalesce(v_points, tx.points);

  update public.profiles set points = points - v_points
   where id = tx.user_id and points >= v_points
   returning points into v_balance;
  if not found then
    select points into v_cur from public.profiles where id = tx.user_id;
    raise exception 'สมาชิกใช้แต้มไปแล้ว แต้มคงเหลือ % ไม่พอที่จะหัก % แต้ม', coalesce(v_cur, 0), v_points;
  end if;

  update public.topup_transactions set status = 'reversed', updated_at = now() where id = tx.id;

  insert into public.topup_admin_log (transaction_id, user_id, action, points, note, admin_id, previous_status)
  values (tx.id, tx.user_id, 'reverse', v_points, v_note, auth.uid(), tx.status);

  return jsonb_build_object('ok', true, 'points', v_points, 'balance', v_balance);
end;
$function$;

-- หักแต้มโดยตรง (เช่น เติมผิดคน/ผิดยอด แล้วต้องหักกลับ) — หักได้ไม่เกินแต้มคงเหลือ
create or replace function public.admin_deduct_points(p_user_id uuid, p_points integer, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_note text := btrim(coalesce(p_note, ''));
  v_balance integer;
  v_cur integer;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if p_user_id is null then raise exception 'ไม่ได้ระบุสมาชิก'; end if;
  if p_points is null or p_points < 1 or p_points > 100000 then
    raise exception 'จำนวนแต้มต้องอยู่ระหว่าง 1 - 100,000';
  end if;
  if char_length(v_note) < 3 or char_length(v_note) > 200 then
    raise exception 'กรุณาใส่หมายเหตุ 3-200 ตัวอักษร';
  end if;

  update public.profiles set points = points - p_points
   where id = p_user_id and points >= p_points
   returning points into v_balance;
  if not found then
    select points into v_cur from public.profiles where id = p_user_id;
    if not found then raise exception 'ไม่พบบัญชีสมาชิก'; end if;
    raise exception 'แต้มคงเหลือ % ไม่พอที่จะหัก % แต้ม', coalesce(v_cur, 0), p_points;
  end if;

  insert into public.topup_admin_log (user_id, action, points, note, admin_id)
  values (p_user_id, 'deduct', p_points, v_note, auth.uid());

  return jsonb_build_object('ok', true, 'points', p_points, 'balance', v_balance);
end;
$function$;

revoke all on function public.admin_reverse_topup(uuid, text) from public, anon;
grant execute on function public.admin_reverse_topup(uuid, text) to authenticated;
revoke all on function public.admin_deduct_points(uuid, integer, text) from public, anon;
grant execute on function public.admin_deduct_points(uuid, integer, text) to authenticated;

commit;
