-- ============================================================
--  Gum100 — ระบบจัดการเติมเงินสำหรับแอดมิน
--   1) แอดมินดูรายการเติมเงิน QR (topup_transactions) ได้ทุกสถานะ
--   2) admin_confirm_topup : ยืนยันรับเงินรายการที่ระบบแจ้งไม่ทัน/ต้องตรวจสอบ (เติมแต้มครั้งเดียว ล็อกแถวกันเติมซ้ำ)
--   3) admin_close_topup   : ปิดรายการรอชำระ/รอตรวจสอบที่ไม่ได้จ่ายจริง (ไม่เติมแต้ม)
--   4) admin_find_member   : ค้นสมาชิกด้วย username หรืออีเมล (เห็นชื่อ/แต้มก่อนเติม กันเติมผิดคน)
--   5) admin_grant_points  : เติมแต้มให้สมาชิกโดยตรง (กรณีโอนตรงผ่านเพจ FB) — บันทึกเป็นรายการ provider='manual' พร้อมหมายเหตุ
--  ทุกฟังก์ชันตรวจสิทธิ์แอดมินที่ฐานข้อมูลเอง ไม่พึ่งหน้าเว็บ
--  รันทั้งไฟล์รวดเดียวใน Supabase Dashboard -> SQL Editor -> New query -> Run (รันซ้ำได้อย่างปลอดภัย)
-- ============================================================
begin;

-- 1) แอดมินอ่านรายการเติมเงินของทุกคนได้ (ผู้ใช้ทั่วไปยังเห็นเฉพาะของตัวเองเหมือนเดิม)
drop policy if exists topup_transactions_admin_select on public.topup_transactions;
create policy topup_transactions_admin_select on public.topup_transactions
  for select to authenticated using (public.is_admin());


-- 2) ยืนยันรับเงิน: เติมแต้มตามยอดที่รับจริง (ถ้ามี) ไม่งั้นตามยอดที่ขอ — 1 บาท = 1 แต้ม
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
    updated_at = now(),
    provider_payload = (case when jsonb_typeof(provider_payload) = 'object' then provider_payload else '{}'::jsonb end)
      || jsonb_build_object('manual', jsonb_build_object(
           'action', 'confirm', 'by', auth.uid(), 'at', now(),
           'note', p_note, 'previous_status', v_prev, 'points', v_points))
  where id = tx.id;

  return jsonb_build_object('ok', true, 'points', v_points, 'previous_status', v_prev);
end;
$function$;


-- 3) ปิดรายการที่ไม่ได้จ่ายจริง (ไม่เติมแต้ม) — ถ้าเงินเข้ามาทีหลังยังกด "ยืนยันรับเงิน" ย้อนหลังได้
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

  update public.topup_transactions set
    status = 'expired',
    updated_at = now(),
    provider_payload = (case when jsonb_typeof(provider_payload) = 'object' then provider_payload else '{}'::jsonb end)
      || jsonb_build_object('manual', jsonb_build_object(
           'action', 'close', 'by', auth.uid(), 'at', now(),
           'note', p_note, 'previous_status', tx.status))
  where id = tx.id;

  return jsonb_build_object('ok', true, 'previous_status', tx.status);
end;
$function$;


-- 4) ค้นสมาชิกด้วย username หรืออีเมล (ตรงตัวเท่านั้น ไม่ค้นแบบเดาคำ)
create or replace function public.admin_find_member(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_key text := lower(btrim(coalesce(p_identifier, '')));
  r record;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;
  if char_length(v_key) < 3 then raise exception 'กรอก username หรืออีเมลอย่างน้อย 3 ตัวอักษร'; end if;

  if position('@' in v_key) > 0 then
    select p.id, p.display_name, p.username, p.points, u.email into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(u.email) = v_key;
  else
    select p.id, p.display_name, p.username, p.points, u.email into r
      from public.profiles p join auth.users u on u.id = p.id
     where lower(p.username) = v_key;
  end if;
  if not found then raise exception 'ไม่พบสมาชิกจาก username/อีเมลนี้'; end if;

  return jsonb_build_object('id', r.id, 'display_name', r.display_name, 'username', r.username,
                            'email', r.email, 'points', r.points);
end;
$function$;


-- 5) เติมแต้มให้สมาชิกโดยตรง (โอนตรงผ่านเพจ FB) — 1 บาท = 1 แต้ม, ต้องมีหมายเหตุ, บันทึกเป็นรายการในประวัติเติมเงินของสมาชิก
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
    (user_id, provider, requested_amount, received_amount, points, status, paid_at, credited_at, provider_payload)
  values
    (p_user_id, 'manual', p_points, p_points, p_points, 'credited', now(), now(),
     jsonb_build_object('manual', jsonb_build_object('action', 'grant', 'by', auth.uid(), 'at', now(), 'note', v_note)))
  returning id into v_tx;

  return jsonb_build_object('ok', true, 'transaction_id', v_tx, 'points', p_points, 'balance', v_balance);
end;
$function$;


-- สิทธิ์เรียก: เฉพาะผู้ล็อกอิน (และฟังก์ชันตรวจว่าเป็นแอดมินอีกชั้น) — คนไม่ล็อกอินเรียกไม่ได้
revoke all on function public.admin_confirm_topup(uuid, text) from public, anon;
grant execute on function public.admin_confirm_topup(uuid, text) to authenticated;
revoke all on function public.admin_close_topup(uuid, text) from public, anon;
grant execute on function public.admin_close_topup(uuid, text) to authenticated;
revoke all on function public.admin_find_member(text) from public, anon;
grant execute on function public.admin_find_member(text) to authenticated;
revoke all on function public.admin_grant_points(uuid, integer, text) from public, anon;
grant execute on function public.admin_grant_points(uuid, integer, text) to authenticated;

commit;
