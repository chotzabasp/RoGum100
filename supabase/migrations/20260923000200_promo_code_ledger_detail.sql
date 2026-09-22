-- ============================================================
-- แสดงประวัติการแลกโค้ดโปรโมชันให้เห็นชื่อโค้ดจริง แทนที่จะขึ้นรวมเป็น "ปรับแต้ม" เฉยๆ
-- เดิม log_points_change() (trigger จับทุกครั้งที่ profiles.points เปลี่ยน) ไม่รู้จัก redeem_promo_code
-- เลยตกไปกลุ่ม 'other' และโค้ดแบบแจกวัน (ไม่แตะแต้มเลย) ไม่มีประวัติขึ้นที่ไหนเลย
--
-- เพิ่มคอลัมน์ points_ledger.detail (ข้อความอิสระ) — RPC ฝากชื่อโค้ดผ่าน session variable ชั่วคราว
-- (set_config ... true = ล้างเองตอนจบธุรกรรม) ให้ trigger อ่านไปเก็บ ส่วนโค้ดแบบแจกวัน insert
-- ประวัติเข้า points_ledger ตรงๆ เอง (delta=0 เพราะไม่กระทบแต้ม) จะได้เห็นในหน้าประวัติเดียวกัน
-- ============================================================
begin;

alter table public.points_ledger add column if not exists detail text;

create or replace function public.log_points_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  q text := lower(coalesce(current_query(), ''));
  r text;
  d text := nullif(current_setting('app.points_ledger_detail', true), '');
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
    when position('redeem_promo_code' in q) > 0 then 'promo_code'
    when position('spend_points' in q) > 0 then 'spend'
    else 'other'
  end;
  insert into public.points_ledger (user_id, delta, balance_after, reason, actor, detail)
  values (new.id, new.points - old.points, new.points, r, auth.uid(), d);
  return new;
end;
$function$;

create or replace function public.redeem_promo_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
  v_base timestamptz;
  v_new timestamptz;
  v_points_after int;
begin
  if auth.uid() is null then raise exception 'ต้องล็อกอินก่อน'; end if;
  if not public.is_active() then raise exception 'บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ'; end if;
  if v_code = '' then raise exception 'กรุณากรอกโค้ด'; end if;

  select * into v_row from public.promo_codes where code = v_code for update;
  if not found then raise exception 'ไม่พบโค้ดนี้ หรือโค้ดไม่ถูกต้อง'; end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then raise exception 'โค้ดนี้หมดอายุแล้ว'; end if;
  if v_row.used_count >= v_row.max_uses then raise exception 'โค้ดนี้ถูกใช้ครบจำนวนแล้ว'; end if;
  if exists(select 1 from public.promo_code_redemptions where code = v_code and user_id = auth.uid()) then
    raise exception 'คุณใช้โค้ดนี้ไปแล้ว';
  end if;

  insert into public.promo_code_redemptions (code, user_id) values (v_code, auth.uid());
  update public.promo_codes set used_count = used_count + 1 where code = v_code;

  if v_row.reward_type = 'plan_days' then
    select greatest(coalesce(plan_bundle_expires_at, now()), coalesce(plan_timers_expires_at, now()), now())
      into v_base from public.profiles where id = auth.uid();
    v_new := v_base + (v_row.plan_days || ' days')::interval;
    update public.profiles set plan_bundle_expires_at = v_new, plan_timers_expires_at = v_new where id = auth.uid();

    select points into v_points_after from public.profiles where id = auth.uid();
    insert into public.points_ledger (user_id, delta, balance_after, reason, actor, detail)
    values (auth.uid(), 0, v_points_after, 'promo_code', auth.uid(),
      'กรอกรหัสโปรโมชั่น '||v_code||' — แพ็กเกจ 4 in 1 จำนวน '||v_row.plan_days||' วัน');

    return jsonb_build_object('reward_type', 'plan_days', 'plan_days', v_row.plan_days, 'expires_at', v_new);
  else
    perform set_config('app.points_ledger_detail', 'กรอกรหัสโปรโมชั่น '||v_code, true);
    update public.profiles set points = points + v_row.points where id = auth.uid();
    return jsonb_build_object('reward_type', 'points', 'points', v_row.points);
  end if;
end;
$function$;

commit;
