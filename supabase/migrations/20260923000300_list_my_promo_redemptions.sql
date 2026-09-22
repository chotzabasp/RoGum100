-- ============================================================
-- ให้ยูเซอทั่วไปดูประวัติการใช้โค้ดโปรโมชันของตัวเองได้ (แยกเป็นหัวข้อ "โค้ดโปรโมชัน" ในหน้าตั้งค่า)
-- ตาราง promo_code_redemptions / promo_codes ตอนนี้ RLS อนุญาตเฉพาะแอดมินอ่านตรงๆ (promo_codes_admin_write,
-- promo_code_redemptions_admin_read) ยูเซอทั่วไปเลยอ่านเองไม่ได้ — ใช้ security definer RPC แบบเดียวกับ
-- admin_list_promo_redemptions แทนที่จะเปิด RLS เพิ่ม (คงหลักเดิม: ยูเซอแลกโค้ดผ่าน RPC เท่านั้น ไม่ให้เห็น
-- ตารางโค้ด/การใช้โค้ดของคนอื่นตรงๆ)
--
-- ไม่กระทบ redeem_promo_code เดิมเลย (กันโค้ดซ้ำคนเดียว/เกิน max_uses ด้วย unique(code,user_id) + for update
-- lock อยู่แล้ว) — ฟังก์ชันนี้เป็นแค่ read-only ของตัวเอง
-- ============================================================
begin;

create or replace function public.list_my_promo_redemptions()
returns table (
  code text,
  reward_type text,
  points integer,
  plan_days integer,
  redeemed_at timestamptz
)
language sql
security definer
set search_path to 'public'
stable
as $function$
  select pc.code, pc.reward_type, pc.points, pc.plan_days, r.redeemed_at
  from public.promo_code_redemptions r
  join public.promo_codes pc on pc.code = r.code
  where r.user_id = auth.uid()
  order by r.redeemed_at desc;
$function$;

revoke all on function public.list_my_promo_redemptions() from public, anon;
grant execute on function public.list_my_promo_redemptions() to authenticated;

commit;
