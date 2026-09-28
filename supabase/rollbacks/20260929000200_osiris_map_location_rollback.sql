-- ย้อนกลับ migration 20260929000200_osiris_map_location (รันเฉพาะเมื่อจำเป็น): คืนแผนที่ Osiris เป็น moc_pryd06
begin;

set local lock_timeout = '5s';

do $guard$
declare
  v_loc text;
begin
  select map_location into v_loc from public.bosses where id = 'osiris';
  if not found then
    raise exception 'ไม่พบบอส osiris — ไม่มีอะไรถูกแก้';
  end if;
  if v_loc is distinct from 'moc_pryd04' then
    raise exception 'แผนที่ Osiris ไม่ใช่ค่าจาก 20260929000200 (แผนที่ %) — ไม่มีอะไรถูกแก้', coalesce(v_loc, 'ว่าง');
  end if;
end;
$guard$;

update public.bosses set map_location = 'moc_pryd06' where id = 'osiris' and map_location = 'moc_pryd04';

commit;

notify pgrst, 'reload schema';

select map_location = 'moc_pryd06' as osiris_restored from public.bosses where id = 'osiris';
