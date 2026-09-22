-- ============================================================
-- ถอด foreign key ของคอลัมน์ server_id ออกจาก 3 ตารางที่เกี่ยวกับหน้าจับเวลาบอส
-- (user_bosses, kills, custom_boss_timers) — เดิม server_id ต้องอ้างอิง servers.id จริง
-- แต่ตอนนี้หน้าจับเวลาบอสไม่แยกตามเซิร์ฟเวอร์แล้ว ฝั่งเว็บส่งค่าคงที่ '-' แทน จึงต้องถอด
-- constraint นี้ออกก่อน ไม่งั้น insert/update จะฟ้อง foreign key violation ทุกครั้ง
-- (พบจาก error จริง: "user_bosses_server_id_fkey" ตอนกดเพิ่มบอส)
--
-- ใช้วิธีค้นหาชื่อ constraint จริงจาก pg_constraint แทนการเดาชื่อ กันพลาดถ้าชื่อไม่ตรงที่คาด
-- ============================================================
begin;

do $$
declare
  r record;
begin
  for r in
    select con.conname, con.conrelid::regclass as tbl
    from pg_constraint con
    join pg_attribute att
      on att.attrelid = con.conrelid
     and att.attnum = any(con.conkey)
    where con.contype = 'f'
      and att.attname = 'server_id'
      and con.conrelid in (
        'public.user_bosses'::regclass,
        'public.kills'::regclass,
        'public.custom_boss_timers'::regclass
      )
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    raise notice 'dropped % on %', r.conname, r.tbl;
  end loop;
end $$;

commit;
