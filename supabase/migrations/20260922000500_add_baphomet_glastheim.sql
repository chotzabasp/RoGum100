-- ============================================================
-- เพิ่มบอส Baphomet (Glast Heim2F) — คนละตัวกับ "Baphomet (Hidden)" ที่มีอยู่แล้ว
-- (id เดิม "baphomet", map prt_maze03) เพราะชื่อไม่เหมือนกัน
--
-- ใช้รูปบอส boss-images/Baphomet.gif ตัวเดิม (ไม่มีรูปใหม่แนบมา)
-- ใช้รูปแมพ gl_cas02.gif ที่ผู้ใช้เพิ่งอัพขึ้น bucket "Map BOSS"
-- รายการไอเทม copy มาจาก Baphomet (Hidden) ทั้งหมดตามที่ผู้ใช้สั่ง "เหมือนข้อมูลชุดเก่า"
--
-- รันครั้งเดียว รันซ้ำได้ไม่พัง (on conflict do nothing)
-- ============================================================
begin;

insert into public.bosses (id, name, image_url, respawn_minutes, map_location, map_image_url, items) values
  ('baphometgh', 'Baphomet (Glast Heim2F)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Baphomet.gif', 120, 'gl_cas02', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gl_cas02.gif', jsonb_build_array('Emperium', 'Oridecon', 'Elunium', 'Crescent Scythe', 'Crescent Scythe [1]', 'Majestic Goat', 'Majestic Goat [1]', 'Clip [1]', 'Zelunium', 'Baphomet Card', 'Mysterious Combination Bundle'))
on conflict (id) do nothing;

commit;
