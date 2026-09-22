-- ============================================================
-- ระบบโค้ดโปรโมชัน — โค้ดเดียวจำกัดจำนวนคนใช้รวม (ไม่ใช่สร้างหลายโค้ดไม่ซ้ำกัน) แลกแล้วได้แต้มตรงๆ
-- (1 บัญชีใช้โค้ดเดียวกันได้แค่ครั้งเดียว) มีวันหมดอายุได้ (เว้นว่าง = ไม่หมดอายุ)
--
-- แอดมินสร้าง/ลบ/แก้โค้ดตรงๆ ผ่าน RLS "admin เขียนได้เต็มที่" (แพทเทิร์นเดียวกับตาราง servers)
-- ผู้ใช้ทั่วไปแลกโค้ดผ่าน RPC redeem_promo_code เท่านั้น (security definer, ไม่มีสิทธิ์เข้าถึงตาราง
-- ตรงๆ เลย กันเห็นโค้ด/แก้แต้มตัวเองตรงๆ)
-- ============================================================
begin;

create table if not exists public.promo_codes (
  code text primary key,
  points integer not null check (points > 0),
  max_uses integer not null check (max_uses > 0),
  used_count integer not null default 0,
  expires_at timestamptz,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.promo_code_redemptions (
  id bigint generated always as identity primary key,
  code text not null references public.promo_codes(code) on delete cascade,
  user_id uuid not null references public.profiles(id),
  redeemed_at timestamptz not null default now(),
  unique (code, user_id)
);

alter table public.promo_codes enable row level security;
alter table public.promo_code_redemptions enable row level security;

drop policy if exists promo_codes_admin_write on public.promo_codes;
create policy promo_codes_admin_write on public.promo_codes
  for all using (is_admin()) with check (is_admin());

drop policy if exists promo_code_redemptions_admin_read on public.promo_code_redemptions;
create policy promo_code_redemptions_admin_read on public.promo_code_redemptions
  for all using (is_admin()) with check (is_admin());

revoke all on public.promo_codes, public.promo_code_redemptions from authenticated, anon;
grant select, insert, update, delete on public.promo_codes to authenticated;
grant select on public.promo_code_redemptions to authenticated;

create or replace function public.redeem_promo_code(p_code text)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.promo_codes%rowtype;
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
  update public.profiles set points = points + v_row.points where id = auth.uid();

  return v_row.points;
end;
$function$;

revoke all on function public.redeem_promo_code(text) from public, anon;
grant execute on function public.redeem_promo_code(text) to authenticated;

commit;
