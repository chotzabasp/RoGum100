-- ============================================================
-- เพิ่ม Mini Boss 6 ตัว: Ghostring, Dragon Fly, Deviling, Dark Illusion,
-- Archangeling, Angeling — บอสตัวไหนมีหลายแมพ แยกเป็นคนละแถว (คนละ "การ์ด")
-- ตามแพทเทิร์นเดิมที่มีอยู่แล้ว (เช่น Mistress ที่มี id "mistress" กับ "mistress (2)")
-- รวมทั้งหมด 17 แถวใหม่ในตาราง bosses
--
-- หมายเหตุที่ยืนยันกับผู้ใช้แล้ว:
--   * Ghostring แมพที่ 4: ข้อความพิมพ์ "treasure02" แต่ไฟล์จริงที่อัพคือ treasure01.gif
--     (treasure02.gif ไม่มีในระบบ) → ใช้ treasure01 ตามไฟล์จริง
--   * Deviling แมพที่ 2: พิมพ์ผิดเป็น "uno_fild03" ที่จริงคือ yuno_fild03 (มีรูปอยู่แล้ว)
--   * % อัตราดรอปไม่ได้เก็บ (ตาราง items ไม่มีช่องนี้ เหมือนรอบก่อน)
--   * การ์ดบอสทั้ง 6 ใบ ใช้รูป ItemBOSSRO/card.gif ร่วมกันตามที่สั่ง
--   * ชื่อการ์ดของ Archangeling สะกดว่า "Arc Angeling Card" (ไม่ตรงกับชื่อบอส
--     "Archangeling" เป๊ะ) — เก็บตามที่ให้มา ไม่ได้แก้ให้ตรงกัน
--   * ไอเทม 3 ชิ้นไม่มีรูปในไฟล์ที่ส่งมาและไม่มีในระบบเดิม (Sweet Gent,
--     Ragamuffin Manteau, Bone Helm) → ใส่แบบไม่มีรูปไปก่อน
--   * ไฟล์ซ้ำที่อัพเกินมา ต้องลบเองผ่าน Dashboard (ไม่ได้แก้ในไฟล์นี้):
--     ItemBOSSRO/Emperium (1).gif, ItemBOSSRO/Full Plate (1).gif, Map BOSS/gld2_gef (1).gif
--
-- รันครั้งเดียว รันซ้ำได้ไม่พัง (on conflict do nothing)
-- ============================================================
begin;

-- ไอเทมใหม่ 17 รายการ (ที่เหลือใช้รูปเดิมที่มีอยู่แล้วในระบบ ไม่ต้อง insert ซ้ำ)
insert into public.items (name, image_url) values
  ('Angel Wing', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Angel%20Wing.gif'),
  ('Evil Wing', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Evil%20Wing.gif'),
  ('Ghost Bandana', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Ghost%20Bandana.gif'),
  ('Thief Clothes [1]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Thief%20Clothes.gif'),
  ('Agate', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Agate.gif'),
  ('Turquoise', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Turquoise.gif'),
  ('Halo', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Halo.gif'),
  ('Scapulare [1]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Scapulare.gif'),
  ('Sweet Gent', null),
  ('Ragamuffin Manteau', null),
  ('Bone Helm', null),
  ('Ghostring Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Dragon Fly Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Deviling Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Dark Illusion Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Arc Angeling Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Angeling Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif')
on conflict (name) do nothing;

-- บอสใหม่ 17 แถว (6 ตัว x หลายแมพ)
insert into public.bosses (id, name, image_url, respawn_minutes, map_location, map_image_url, items) values
  ('ghostring', 'Ghostring', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ghostring.gif', 240, 'gld_dun04', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld_dun04.gif', jsonb_build_array('Old Blue Box', 'Emperium', 'Ghost Bandana', 'Thief Clothes [1]', 'Ghostring Card')),
  ('ghostring (2)', 'Ghostring', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ghostring.gif', 30, 'pay_fild04', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/pay_fild04.gif', jsonb_build_array('Old Blue Box', 'Emperium', 'Ghost Bandana', 'Thief Clothes [1]', 'Ghostring Card')),
  ('ghostring (3)', 'Ghostring', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ghostring.gif', 30, 'prt_maze03', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/prt_maze03.gif', jsonb_build_array('Old Blue Box', 'Emperium', 'Ghost Bandana', 'Thief Clothes [1]', 'Ghostring Card')),
  ('ghostring (4)', 'Ghostring', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ghostring.gif', 30, 'treasure01', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/treasure01.gif', jsonb_build_array('Old Blue Box', 'Emperium', 'Ghost Bandana', 'Thief Clothes [1]', 'Ghostring Card')),

  ('dragonfly', 'Dragon Fly', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dragon%20Fly.gif', 30, 'moc_fild18', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/moc_fild18.gif', jsonb_build_array('Sweet Gent', 'Clip [1]', 'Dragon Fly Card')),
  ('dragonfly (2)', 'Dragon Fly', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dragon%20Fly.gif', 30, 'moc_fild06', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/moc_fild06.gif', jsonb_build_array('Sweet Gent', 'Clip [1]', 'Dragon Fly Card')),

  ('deviling', 'Deviling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Deviling.gif', 120, 'pay_fild04', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/pay_fild04.gif', jsonb_build_array('Evil Wing', 'Deviling Card', 'Blade Lost in Darkness')),
  ('deviling (2)', 'Deviling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Deviling.gif', 60, 'yuno_fild03', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/yuno_fild03.gif', jsonb_build_array('Evil Wing', 'Deviling Card', 'Blade Lost in Darkness')),

  ('darkillusion', 'Dark Illusion', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dark%20Illusion.gif', 20, 'gld2_gef', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld2_gef.gif', jsonb_build_array('Broad Sword [2]', 'Evil Bone Wand', 'Ragamuffin Manteau', 'Bone Helm', 'Dark Illusion Card')),
  ('darkillusion (2)', 'Dark Illusion', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dark%20Illusion.gif', 20, 'gld_dun04', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld_dun04.gif', jsonb_build_array('Broad Sword [2]', 'Evil Bone Wand', 'Ragamuffin Manteau', 'Bone Helm', 'Dark Illusion Card')),
  ('darkillusion (3)', 'Dark Illusion', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dark%20Illusion.gif', 20, 'gld_dun04_2', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld_dun04_2.gif', jsonb_build_array('Broad Sword [2]', 'Evil Bone Wand', 'Ragamuffin Manteau', 'Bone Helm', 'Dark Illusion Card')),
  ('darkillusion (4)', 'Dark Illusion', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Dark%20Illusion.gif', 60, 'gl_church', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gl_church.gif', jsonb_build_array('Broad Sword [2]', 'Evil Bone Wand', 'Ragamuffin Manteau', 'Bone Helm', 'Dark Illusion Card')),

  ('archangeling', 'Archangeling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Archangeling.gif', 60, 'yuno_fild05', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/yuno_fild05.gif', jsonb_build_array('Angel Wing', 'Evil Wing', 'Full Plate [1]', 'Agate', 'Turquoise', 'Arc Angeling Card')),

  ('angeling', 'Angeling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Angeling.gif', 30, 'mjolnir_10', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/mjolnir_10.gif', jsonb_build_array('Emperium', 'Angel Wing', 'Halo', 'Scapulare [1]', 'Angeling Card')),
  ('angeling (2)', 'Angeling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Angeling.gif', 30, 'pay_fild04', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/pay_fild04.gif', jsonb_build_array('Emperium', 'Angel Wing', 'Halo', 'Scapulare [1]', 'Angeling Card')),
  ('angeling (3)', 'Angeling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Angeling.gif', 60, 'yuno_fild03', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/yuno_fild03.gif', jsonb_build_array('Emperium', 'Angel Wing', 'Halo', 'Scapulare [1]', 'Angeling Card')),
  ('angeling (4)', 'Angeling', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Angeling.gif', 30, 'xmas_dun01', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/xmas_dun01.gif', jsonb_build_array('Emperium', 'Angel Wing', 'Halo', 'Scapulare [1]', 'Angeling Card'))
on conflict (id) do nothing;

commit;
