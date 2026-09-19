-- Production backend snapshot for Gum100 package purchases and TMWEASY top-ups.
-- Generated from the live Production schema on 2026-09-20.
-- Contains no credentials or Edge Function secrets.

create extension if not exists pgcrypto;

alter table public.profiles add column if not exists points integer not null default 0;
alter table public.profiles add column if not exists plan_bundle_expires_at timestamptz;
alter table public.profiles add column if not exists plan_timers_expires_at timestamptz;

create table if not exists public.package_feature_entitlements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  feature text not null check (feature in ('farm','accountItems')),
  expires_at timestamptz not null,
  primary key (user_id, feature)
);

create table if not exists public.package_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_key text not null,
  plan_name text not null,
  cycle text not null check (cycle in ('monthly','yearly')),
  points_spent integer not null,
  days_added integer not null,
  expires_before timestamptz,
  expires_after timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.topup_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  ref1 text not null unique default gen_random_uuid()::text,
  provider text not null default 'tmweasy',
  provider_payment_id text unique,
  requested_amount numeric not null check (requested_amount > 0),
  received_amount numeric,
  points integer not null check (points > 0),
  status text not null default 'pending'
    check (status in ('pending','paid','credited','failed','expired','manual_review')),
  paid_at timestamptz,
  credited_at timestamptz,
  provider_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.package_feature_entitlements enable row level security;
alter table public.package_purchases enable row level security;
alter table public.topup_transactions enable row level security;

drop policy if exists package_feature_read_own on public.package_feature_entitlements;
create policy package_feature_read_own on public.package_feature_entitlements
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists package_purchases_select_own on public.package_purchases;
create policy package_purchases_select_own on public.package_purchases
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "users can view own topups" on public.topup_transactions;
create policy "users can view own topups" on public.topup_transactions
  for select to authenticated using (user_id = auth.uid());

create or replace function public.buy_plan(p_plan_key text, p_cycle text)
returns timestamptz
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_price integer;
  v_days integer;
  v_points integer;
  v_bundle timestamptz;
  v_timers timestamptz;
  v_before timestamptz;
  v_new timestamptz;
  v_bundle_new timestamptz;
  v_timers_new timestamptz;
  v_name text;
begin
  if v_uid is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if p_plan_key is null or p_plan_key not in ('farm','accountItems','all','bundle','timers') then raise exception 'แพ็กเกจไม่ถูกต้อง'; end if;
  if p_cycle is null or p_cycle not in ('monthly','yearly') then raise exception 'รอบการชำระไม่ถูกต้อง'; end if;
  if p_plan_key in ('farm','accountItems') and p_cycle <> 'monthly' then raise exception 'แพ็กเกจนี้รองรับเฉพาะรายเดือน'; end if;

  v_days := case p_cycle when 'monthly' then 30 else 365 end;
  v_price := case
    when p_cycle='yearly' and p_plan_key in ('bundle','timers') then 990
    when p_cycle='yearly' and p_plan_key='all' then 1750
    when p_plan_key='accountItems' then 149
    when p_plan_key='all' then 175
    else 99
  end;

  select points, plan_bundle_expires_at, plan_timers_expires_at
    into v_points, v_bundle, v_timers
    from public.profiles where id=v_uid for update;
  if not found then raise exception 'ไม่พบโปรไฟล์'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุ ต่ออายุก่อนสมัครแพ็กเกจ'; end if;
  if coalesce(v_points,0) < v_price then raise exception 'แต้มไม่พอ (ต้องการ % แต้ม)',v_price; end if;

  if p_plan_key in ('farm','accountItems') then
    select expires_at into v_before from public.package_feature_entitlements where user_id=v_uid and feature=p_plan_key;
    v_before := greatest(v_before,v_bundle);
    v_new := greatest(coalesce(v_before,now()),now()) + interval '30 days';
    insert into public.package_feature_entitlements(user_id,feature,expires_at)
      values(v_uid,p_plan_key,v_new)
      on conflict(user_id,feature) do update set expires_at=excluded.expires_at;
  elsif p_plan_key='bundle' then
    v_before := v_bundle;
    v_new := greatest(coalesce(v_bundle,now()),now()) + case when p_cycle='yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_bundle_expires_at=v_new where id=v_uid;
  elsif p_plan_key='timers' then
    v_before := v_timers;
    v_new := greatest(coalesce(v_timers,now()),now()) + case when p_cycle='yearly' then interval '1 year' else interval '30 days' end;
    update public.profiles set plan_timers_expires_at=v_new where id=v_uid;
  else
    v_bundle_new := greatest(coalesce(v_bundle,now()),now()) + case when p_cycle='yearly' then interval '1 year' else interval '30 days' end;
    v_timers_new := greatest(coalesce(v_timers,now()),now()) + case when p_cycle='yearly' then interval '1 year' else interval '30 days' end;
    v_before := least(coalesce(v_bundle,now()),coalesce(v_timers,now()));
    v_new := least(v_bundle_new,v_timers_new);
    update public.profiles set plan_bundle_expires_at=v_bundle_new,plan_timers_expires_at=v_timers_new where id=v_uid;
  end if;

  update public.profiles set points=points-v_price where id=v_uid;
  v_name := case p_plan_key when 'farm' then '1 in 1 — ยอดนักฟาม' when 'accountItems' then '2 in 1' when 'bundle' then '3 in 1' when 'timers' then 'จับเวลาบอส' else '4 in 1' end;
  if to_regclass('public.package_purchases') is not null then
    insert into public.package_purchases(user_id,plan_key,plan_name,cycle,points_spent,days_added,expires_before,expires_after)
      values(v_uid,p_plan_key,v_name,p_cycle,v_price,v_days,v_before,v_new);
  end if;
  return v_new;
end;
$function$;

create or replace function public.credit_tmweasy_topup(
  p_ref1 text,
  p_provider_payment_id text,
  p_received_amount numeric,
  p_provider_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  tx public.topup_transactions%rowtype;
begin
  if p_ref1 is null or btrim(p_ref1) = '' then raise exception 'Missing ref1'; end if;
  if p_provider_payment_id is null or btrim(p_provider_payment_id) = '' then raise exception 'Missing provider payment id'; end if;
  if p_received_amount is null or p_received_amount <= 0 then raise exception 'Invalid amount'; end if;

  select * into tx from public.topup_transactions
    where ref1=p_ref1 and provider='tmweasy' for update;
  if not found then return jsonb_build_object('ok',false,'status','not_found'); end if;

  if tx.status='credited' then
    if tx.provider_payment_id=p_provider_payment_id then
      return jsonb_build_object('ok',true,'status','already_credited','duplicate',true,'points',tx.points);
    end if;
    return jsonb_build_object('ok',false,'status','payment_id_conflict');
  end if;
  if tx.status not in ('pending','paid') then return jsonb_build_object('ok',false,'status',tx.status); end if;
  if tx.provider_payment_id is not null and tx.provider_payment_id<>p_provider_payment_id then
    return jsonb_build_object('ok',false,'status','payment_id_conflict');
  end if;

  if p_received_amount<>tx.requested_amount then
    update public.topup_transactions set
      provider_payment_id=p_provider_payment_id,
      received_amount=p_received_amount,
      provider_payload=p_provider_payload,
      status='manual_review', paid_at=now(), updated_at=now()
      where id=tx.id;
    return jsonb_build_object('ok',false,'status','amount_mismatch','expected',tx.requested_amount,'received',p_received_amount);
  end if;

  update public.profiles set points=points+tx.points where id=tx.user_id;
  if not found then raise exception 'Profile not found'; end if;
  update public.topup_transactions set
    provider_payment_id=p_provider_payment_id,
    received_amount=p_received_amount,
    provider_payload=p_provider_payload,
    status='credited', paid_at=coalesce(paid_at,now()), credited_at=now(), updated_at=now()
    where id=tx.id;
  return jsonb_build_object('ok',true,'status','credited','points',tx.points);
end;
$function$;

revoke all on function public.credit_tmweasy_topup(text,text,numeric,jsonb) from public, anon, authenticated;
grant execute on function public.credit_tmweasy_topup(text,text,numeric,jsonb) to service_role;
grant execute on function public.buy_plan(text,text) to authenticated;
