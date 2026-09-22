-- ============================================================
-- ให้แอดมินดูได้ว่าโค้ดโปรโมชันแต่ละอันมีใครใช้ไปบ้าง (ชื่อ/username/อีเมล/เวลาที่ใช้)
-- ตาราง promo_code_redemptions มีข้อมูล user_id/redeemed_at อยู่แล้ว แต่ไม่มีชื่อ/อีเมลตรงๆ
-- (อีเมลอยู่ที่ auth.users ไม่ใช่ public.profiles) — ทำตามแพทเทิร์นเดียวกับ admin_find_member ที่มีอยู่แล้ว
-- คือ security definer RPC เช็ค role='admin' เองแล้ว join auth.users เอา แทนที่จะเปิด RLS ให้ query ตรงๆ
-- ============================================================
begin;

create or replace function public.admin_list_promo_redemptions(p_code text)
returns table (
  user_id uuid,
  display_name text,
  username text,
  email text,
  redeemed_at timestamptz
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_role text;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'admin' then raise exception 'ต้องเป็นแอดมินเท่านั้น'; end if;

  return query
    select r.user_id, p.display_name, p.username, u.email, r.redeemed_at
    from public.promo_code_redemptions r
    join public.profiles p on p.id = r.user_id
    join auth.users u on u.id = p.id
    where r.code = upper(btrim(coalesce(p_code, '')))
    order by r.redeemed_at desc;
end;
$function$;

revoke all on function public.admin_list_promo_redemptions(text) from public, anon;
grant execute on function public.admin_list_promo_redemptions(text) to authenticated;

commit;
