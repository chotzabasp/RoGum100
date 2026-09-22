-- ============================================================
-- เพิ่มบอสใหม่ 15 ตัว (รอบ 1: เฉพาะรูปบอส + ชื่อ ตามที่ตกลง)
--   เวลาเกิดใหม่ (respawn_minutes), แมพ (map / map_image_url / map_location),
--   และไอเทมดรอป (items) ยังไม่ใส่ตอนนี้ — เว้นเป็นค่าว่างไว้ก่อน
--   พอมีข้อมูลครบจะส่ง SQL อีกไฟล์มาให้ "update" แถวพวกนี้ทีหลัง ไม่ต้องลบ/สร้างใหม่
--
-- ก่อนรัน: อัปโหลดไฟล์รูปบอสทั้ง 15 ไฟล์ (จากโฟลเดอร์ C:\Users\chot-\Downloads\บอสเพิ่มเติม\
-- เฉพาะไฟล์ระดับบนสุด ไม่รวมโฟลเดอร์ item/ และ แมพ/) เข้า Storage bucket "boss-images"
-- แบบลากไฟล์ไปวางตรงๆ ไม่ต้องเปลี่ยนชื่อไฟล์ — ชื่อไฟล์ต้องตรงกับที่อ้างในคำสั่งนี้เป๊ะ
--
-- รันครั้งเดียว รันซ้ำได้ไม่พัง (on conflict do nothing — ถ้ารันซ้ำแถวเดิมจะไม่ถูกทับ)
-- ============================================================
begin;

-- ช่อง respawn_minutes เดิมบังคับห้ามว่าง (NOT NULL) — ปลดล็อกให้เว้นว่างได้เหมือนช่องแมพ
-- (map ก็เว้นว่างได้อยู่แล้วในข้อมูลเดิม 7 แถว) ไม่กระทบเวลาเกิดของบอสเดิม 67 ตัวที่มีอยู่แล้ว
alter table public.bosses alter column respawn_minutes drop not null;

insert into public.bosses (id, name, image_url) values
  ('abysmalwitch', 'Abysmal Witch', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Abysmal%20Witch.gif'),
  ('ancienttaogunka', 'Ancient Tao Gunka', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ancient%20Tao%20Gunka.gif'),
  ('ancientwootendefender', 'Ancient Wooten Defender', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ancient%20Wooten%20Defender.gif'),
  ('bonedetardeurus', 'Bone Detardeurus', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Bone%20Detardeurus.gif'),
  ('burningfang', 'Burning Fang', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Burning%20Fang.gif'),
  ('deathwitch', 'Death Witch', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Death%20Witch.gif'),
  ('jewelungoliant', 'Jewel Ungoliant', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Jewel%20Ungoliant.gif'),
  ('lora', 'Lora', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Lora.gif'),
  ('mechaspider', 'Mechaspider', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Mechaspider.gif'),
  ('ominousturtlegeneral', 'Ominous Turtle General', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Ominous%20Turtle%20General.gif'),
  ('r001bestia', 'R001-Bestia', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/R001-Bestia.gif'),
  ('r4885bestia', 'R48-85-Bestia', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/R48-85-Bestia.gif'),
  ('rudo', 'Rudo', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Rudo.gif'),
  ('samuraisoheon', 'Samurai Soheon', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/Samurai%20Soheon.gif'),
  ('theone', 'The One', 'https://jnwckkcjurchnppekhpc.supabase.co/storage/v1/object/public/boss-images/The%20One.gif')
on conflict (id) do nothing;

commit;
