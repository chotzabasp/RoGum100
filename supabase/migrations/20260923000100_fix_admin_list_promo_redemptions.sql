-- ============================================================
-- แก้บั๊ก "structure of query does not match function result type" ของ admin_list_promo_redemptions
-- สาเหตุ: username/email (โดยเฉพาะ auth.users.email) เป็นชนิด varchar ไม่ใช่ text ตรงๆ ไม่ตรงกับที่
-- ฟังก์ชันประกาศ returns table (... text ...) ไว้ — แก้ด้วยการ cast ::text ให้ตรงชนิดตอน select
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
    select r.user_id, p.display_name::text, p.username::text, u.email::text, r.redeemed_at
    from public.promo_code_redemptions r
    join public.profiles p on p.id = r.user_id
    join auth.users u on u.id = p.id
    where r.code = upper(btrim(coalesce(p_code, '')))
    order by r.redeemed_at desc;
end;
$function$;

commit;
