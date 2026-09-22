-- ============================================================
-- บอสใหม่ 15 ตัว รอบ 2: เวลาเกิด, แมพ, ไอเทมดรอป (ต่อจากรอบ 1 ที่ใส่แค่ชื่อ+รูปบอส)
--   ก่อนรันไฟล์นี้ต้องอัปโหลดรูปไอเทมเข้าบัคเก็ต "ItemBOSSRO" และรูปแมพเข้าบัคเก็ต "Map BOSS"
--   เรียบร้อยแล้ว (คุณอัปโหลดไปแล้วตามที่บอก ผมตรวจสอบ URL ทุกไฟล์แล้วว่าเปิดได้จริงก่อนเขียนไฟล์นี้)
--
--   ไอเทม card ของแต่ละบอส (15 ใบ) ใช้รูปเดียวกันหมด (ItemBOSSRO/card.gif) ตามที่สั่ง แทนรูปเฉพาะตัว
--   ไอเทม "Burning Heart" ยังไม่มีรูปให้ ใส่เป็นไม่มีรูปไปก่อน (ปกติ มีของแบบนี้อยู่แล้ว 64 ชิ้นในระบบเดิม)
--   Siege Suit / Shoulder Protector / Abysmal Witch's Crown และแมพ ein_dun03 (Jewel Ungoliant)
--     เพิ่มรูปมาแล้วรอบล่าสุด — ใส่ครบแล้วในไฟล์นี้
--   หมายเหตุ: % อัตราดรอปที่ให้มาไม่ต้องสนใจ (ติดมาจากที่ก็อปปี้ ไม่ใช่ของที่ต้องเก็บ) ระบบก็ไม่มีที่เก็บ %
--     อยู่แล้วด้วย (ตารางเก็บแค่ชื่อไอเทม) เก็บเฉพาะชื่อไอเทมไว้เท่านั้น
--
-- รันครั้งเดียว รันซ้ำได้ไม่พัง
--
-- ไฟล์ซ้ำที่ค้างอยู่ใน Storage (อัปสองรอบ ไม่มีอะไรอ้างถึงไฟล์พวกนี้ ลบทิ้งได้เลยที่ Dashboard →
-- Storage เพราะ SQL รันเองลบไฟล์ใน Storage ไม่ได้): bucket "ItemBOSSRO" —
--   Gemstone (1).gif, Rare Rune (1).gif, Shadowdecon.png, Zelunium.png, Mystical Card Album.gif
-- ============================================================
begin;

-- 1) เพิ่มไอเทมใหม่เข้าตาราง items (ของที่มีรูปอยู่แล้วในระบบ 20 ชิ้น ข้ามไป ใช้รูปเดิม)
insert into public.items (name, image_url) values
  ('Abysmal Witch Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Abysmal Witch''s Crown', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Abysmal%20Witch''s%20Crown.png'),
  ('Abyssal Essence', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Abyssal%20Essence.gif'),
  ('Ancient Tao Gunka Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Ancient Wootan Defender Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Armed Guard Soheon Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Bone Detardeurus Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Burning Fang Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Burning Heart', null),
  ('Damaged Weapon', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Damaged%20Weapon.gif'),
  ('Death Witch Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Dragon Bone (Large)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dragon%20Bone%20(Large).png'),
  ('Dragon''s Energy (Blue)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dragon''s%20Energy%20(Blue)'),
  ('Dragon''s Energy (Green)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dragon''s%20Energy%20(Green).png'),
  ('Dragon''s Energy (Red)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dragon''s%20Energy%20(Red).png'),
  ('Dragon''s Energy (Silver)', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dragon''s%20Energy%20(Silver)'),
  ('Dynite', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Dynite.gif'),
  ('Ectoplasm', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Ectoplasm.gif'),
  ('Elder Branch', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Elder%20Branch.gif'),
  ('Fragment of Rock', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Fragment%20of%20Rock.gif'),
  ('Goibne''s Armor', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Goibne''s%20Armor.gif'),
  ('Goibne''s Greaves', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Goibne''s%20Greaves.gif'),
  ('Goibne''s Helm', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Goibne''s%20Helm.gif'),
  ('Goibne''s Spaulders', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Goibne''s%20Spaulders.gif'),
  ('Huuma Shuriken of Dancing Petals [2]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Huuma%20Shuriken%20of%20Dancing%20Petals.gif'),
  ('Jeweled Ungoliant Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Logbooks', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Logbooks.gif'),
  ('Mechaspider Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Megalithic Token', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Megalithic%20Token.gif'),
  ('Metal Stick [3]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Metal%20Stick.gif'),
  ('Mine Worker''s Pickaxe [2]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Mine%20Worker''s%20Pickaxe.gif'),
  ('Mysterious Component', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Mysterious%20Component.gif'),
  ('Ominous Turtle General Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('R001-Bestia Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('R48-85-BESTIA Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Rudo Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Shadowdecon Ore', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Shadowdecon%20Ore.gif'),
  ('Shoulder Protector', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Shoulder%20Protector.gif'),
  ('Siege Manteau [1]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Siege%20Manteau.gif'),
  ('Siege Shoes [1]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Siege%20Shoes.gif'),
  ('Siege Suit [1]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Siege%20Suit.gif'),
  ('The One Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Untouched Gemstone', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Untouched%20Gemstone.gif'),
  ('Vigilante Bow [2]', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Vigilante%20Bow.gif'),
  ('Warrior Lola Card', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/card.gif'),
  ('Wootan Defender''s Shield Piece', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Wootan%20Defender''s%20Shield%20Piece.gif'),
  ('Wootan''s Token', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Wootan''s%20Token.gif'),
  ('Zelunium Ore', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/ItemBOSSRO/Zelunium%20Ore.gif')
on conflict (name) do nothing;

-- 2) อัปเดตข้อมูลบอสใหม่ 15 ตัว (เวลาเกิด / แมพ / ไอเทมดรอป)
update public.bosses set respawn_minutes = 120, map_location = 'iz_d05_i', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/iz_d05_i.gif', items = jsonb_build_array('Abysmal Witch''s Crown', 'Morrigane''s Pendant', 'Morrigane''s Belt', 'Shadowdecon', 'Abyssal Essence', 'Abysmal Witch Card') where id = 'abysmalwitch';
update public.bosses set respawn_minutes = 120, map_location = 'com_d02_i', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/com_d02_i.gif', items = jsonb_build_array('Goibne''s Armor', 'Goibne''s Spaulders', 'Gemstone', 'Rare Rune', 'Megalithic Token', 'Fragment of Rock', 'Ancient Tao Gunka Card') where id = 'ancienttaogunka';
update public.bosses set respawn_minutes = 120, map_location = 'com_d02_i', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/com_d02_i.gif', items = jsonb_build_array('Goibne''s Greaves', 'Goibne''s Helm', 'Shoulder Protector', 'Elder Branch', 'Wootan''s Token', 'Wootan Defender''s Shield Piece', 'Ancient Wootan Defender Card') where id = 'ancientwootendefender';
update public.bosses set respawn_minutes = 180, map_location = 'abyss_04', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/abyss_04.png', items = jsonb_build_array('Dragon Bone (Large)', 'Shadowdecon', 'Zelunium', 'Dragon''s Energy (Green)', 'Dragon''s Energy (Silver)', 'Dragon''s Energy (Red)', 'Dragon''s Energy (Blue)', 'Bone Detardeurus Card') where id = 'bonedetardeurus';
update public.bosses set respawn_minutes = 360, map_location = 'oz_dun02', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/oz_dun02.gif', items = jsonb_build_array('Old Card Album', 'Old Purple Box', 'Burning Heart', 'Shadowdecon Ore', 'Zelunium Ore', 'Burning Fang Card') where id = 'burningfang';
update public.bosses set respawn_minutes = 360, map_location = 'nif_dun02', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/nif_dun02.gif', items = jsonb_build_array('Ectoplasm', 'Shadowdecon', 'Zelunium', 'Death Witch Card') where id = 'deathwitch';
update public.bosses set respawn_minutes = 120, map_location = 'ein_dun03', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/ein_dun03.gif', items = jsonb_build_array('Untouched Gemstone', 'Shadowdecon', 'Zelunium', 'Dynite', 'Jeweled Ungoliant Card') where id = 'jewelungoliant';
update public.bosses set respawn_minutes = 30, map_location = 'gld2_prt', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld2_prt.gif', items = jsonb_build_array('Old Card Album', 'Old Purple Box', 'Siege Manteau [1]', 'Warrior Lola Card', 'Advanced Weapons Box', 'WoE Weapon Supply Box', 'Siege White Potion Box', 'Siege Blue Potion Box') where id = 'lora';
update public.bosses set respawn_minutes = 120, map_location = 'rockmi1', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/rockmi1.gif', items = jsonb_build_array('Huuma Shuriken of Dancing Petals [2]', 'Vigilante Bow [2]', 'Shadowdecon', 'Mechaspider Card', 'Mine Worker''s Pickaxe [2]', 'Metal Stick [3]', 'Mysterious Combination Bundle') where id = 'mechaspider';
update public.bosses set respawn_minutes = 120, map_location = 'tur_d04_i', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/tur_d04_i.gif', items = jsonb_build_array('Union of Tribe', 'Immaterial Sword', 'War Axe [1]', 'Pole Axe [1]', 'Iron Driver', 'Logbooks', 'Ominous Turtle General Card') where id = 'ominousturtlegeneral';
update public.bosses set respawn_minutes = 360, map_location = 'sp_rudus4', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/sp_rudus4.gif', items = jsonb_build_array('Old Purple Box', 'Skeletal Armor Piece', 'Shadowdecon', 'Zelunium', 'R001-Bestia Card') where id = 'r001bestia';
update public.bosses set respawn_minutes = 360, map_location = 'sp_rudus2', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/sp_rudus2.gif', items = jsonb_build_array('Old Purple Box', 'Skeletal Armor Piece', 'Mysterious Component', 'Zelunium', 'R48-85-BESTIA Card', 'Mystical Card Album', 'Mysterious Combination Bundle', 'Damaged Weapon') where id = 'r4885bestia';
update public.bosses set respawn_minutes = 30, map_location = 'gld2_gef', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld2_gef.gif', items = jsonb_build_array('Old Card Album', 'Old Purple Box', 'Siege Shoes [1]', 'Rudo Card', 'Advanced Weapons Box', 'WoE Weapon Supply Box', 'Siege White Potion Box', 'Siege Blue Potion Box') where id = 'rudo';
update public.bosses set respawn_minutes = 30, map_location = 'gld2_pay', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/gld2_pay.gif', items = jsonb_build_array('Old Card Album', 'Old Purple Box', 'Armed Guard Soheon Card', 'Advanced Weapons Box', 'WoE Weapon Supply Box', 'Siege White Potion Box', 'Siege Blue Potion Box', 'Siege Suit [1]') where id = 'samuraisoheon';
update public.bosses set respawn_minutes = 360, map_location = 'amicitia2', map_image_url = 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/Map%20BOSS/amicitia2.gif', items = jsonb_build_array('Shadowdecon', 'Zelunium', 'The One Card') where id = 'theone';

commit;
