-- ============================================================
-- ประวัติการฆ่าบอส: ให้ฐานข้อมูลคำนวณยอด + แบ่งหน้าให้ (แก้ปัญหาเกิน 1,000 แถว)
--
-- ปัญหาเดิม: หน้าเว็บดึง "ประวัติการฆ่าทั้งหมด" ของปาร์ตี้มาคำนวณเอง แต่ API ส่งได้สูงสุด 1,000 แถว
--   → เกิน 1,000 การฆ่า ประวัติเก่าหาย + ตัวเลขการ์ดสรุป/ส่วนแบ่งผิด
--   → ประวัติที่คนอื่นแบ่งให้ ดึงด้วย in(id...) ใส่รหัสทุกรายการลงลิงก์ → ยาวเกินจนโหลดไม่ได้
--
-- ฟังก์ชันใหม่ทั้งหมดเป็น SECURITY INVOKER — ทำงานด้วยสิทธิ์ของผู้เรียก RLS เดิมของ kills / kill_items /
-- profiles คุมเหมือนเดิมทุกอย่าง (เห็นเท่าที่เคยเห็นผ่าน API ตรงๆ ไม่มากกว่านั้น) · อ่านอย่างเดียว
--
-- "ขอบเขต" เดียวกับที่หน้าเว็บเคยรวมไว้ (loadKillsForActiveOwner):
--   การฆ่าของปาร์ตี้ที่กำลังดู (p_host) + ของตัวเอง (ถ้ากำลังดูปาร์ตี้คนอื่น: p_include_self)
--   + ทุกการฆ่าที่มีไอเทมแบ่งให้เรา (แม้ออกจากปาร์ตี้นั้นไปแล้ว)
-- ============================================================
begin;

-- 0) ขอบเขตประวัติ
create or replace function public.boss_history_scope(p_host uuid, p_include_self boolean)
returns setof public.kills
language sql
stable
security invoker
set search_path = ''
as $$
  select k.*
    from public.kills k
   where k.host_id = p_host
      or (coalesce(p_include_self, false) and k.host_id = auth.uid())
      or exists (select 1 from public.kill_items i
                  where i.kill_id = k.id and i.shared_with @> array[auth.uid()]);
$$;

-- 1) ประวัติทีละหน้า (ใหม่ → เก่า) พร้อมไอเทม + ชื่อคนกด — เลื่อนหน้าด้วย (killed_at, id) ของรายการสุดท้าย
create or replace function public.boss_history_page(
  p_host uuid, p_include_self boolean,
  p_before timestamptz default null, p_before_id uuid default null,
  p_limit integer default 200)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(s) order by s.killed_at desc, s.id desc), '[]'::jsonb)
    from (
      select k.id, k.host_id, k.boss_id, k.boss_name, k.killed_at, k.killed_by, k.server_id,
             (select p.display_name from public.profiles p where p.id = k.killed_by) as killer_name,
             coalesce((select jsonb_agg(jsonb_build_object(
                                 'id', i.id, 'name', i.name, 'shared_with', i.shared_with,
                                 'sold_amount', i.sold_amount, 'sold_currency', i.sold_currency,
                                 'sold_at', i.sold_at, 'kept_at', i.kept_at) order by i.name)
                         from public.kill_items i where i.kill_id = k.id), '[]'::jsonb) as items
        from public.boss_history_scope(p_host, p_include_self) k
       where p_before is null
          or (p_before_id is null and k.killed_at < p_before)
          or (p_before_id is not null and (k.killed_at, k.id) < (p_before, p_before_id))
       order by k.killed_at desc, k.id desc
       limit least(greatest(coalesce(p_limit, 200), 1), 1000)
    ) s;
$$;

-- 2) ยอดรวม (การ์ดสรุปหน้าจับเวลาบอส + สรุปแท็บไอเทม) — p_since = null คือทั้งหมด
--    สูตรเดียวกับ computeLootTotals เดิม: ขายแล้ว = sold_amount ไม่ว่าง, สกุลเงินว่าง = zeny,
--    ส่วนแบ่งของฉัน = ยอดขาย / จำนวนคนหาร เฉพาะชิ้นที่มีชื่อเราใน shared_with
create or replace function public.boss_history_stats(
  p_host uuid, p_include_self boolean, p_since timestamptz default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with k as (
    select s.id from public.boss_history_scope(p_host, p_include_self) s
     where p_since is null or s.killed_at >= p_since
  ), i as (
    select it.sold_amount, coalesce(it.sold_currency, 'zeny') as cur, it.shared_with
      from public.kill_items it join k on k.id = it.kill_id
  )
  select jsonb_build_object(
    'kills',      (select count(*) from k),
    'items',      (select count(*) from i),
    'sold_count', (select count(*) from i where sold_amount is not null),
    'sold_zeny',  (select coalesce(sum(sold_amount), 0) from i where sold_amount is not null and cur = 'zeny'),
    'sold_baht',  (select coalesce(sum(sold_amount), 0) from i where sold_amount is not null and cur = 'baht'),
    'mine_count', (select count(*) from i where sold_amount is not null and shared_with @> array[auth.uid()]),
    'mine_zeny',  (select coalesce(sum(sold_amount / cardinality(shared_with)), 0) from i
                    where sold_amount is not null and cur = 'zeny' and shared_with @> array[auth.uid()]),
    'mine_baht',  (select coalesce(sum(sold_amount / cardinality(shared_with)), 0) from i
                    where sold_amount is not null and cur = 'baht' and shared_with @> array[auth.uid()])
  );
$$;

-- 3) มุมมอง "ตามบอส" — รวมยอดต่อ (บอส, เซิร์ฟเวอร์) + รายชื่อคนกดพร้อมจำนวน
--    p_killer: null/'all' = ทุกคน, 'none' = รอบที่ไม่รู้ว่าใครกด, อื่นๆ = uuid ของคนกด
--    ลำดับทุกอย่าง = ล่าสุดก่อน (ตรงกับที่หน้าเว็บเคยเรียงจากรายการ ใหม่ → เก่า)
create or replace function public.boss_history_by_boss(
  p_host uuid, p_include_self boolean,
  p_since timestamptz default null, p_today_start timestamptz default null,
  p_killer text default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with base as (
    select s.id, s.boss_id, s.boss_name, s.server_id, s.killed_at, s.killed_by,
           coalesce(s.killed_by::text, 'none') as killer_key,
           case when s.killed_by is null then 'ไม่ระบุ'
                else coalesce((select p.display_name from public.profiles p where p.id = s.killed_by), 'ไม่ทราบชื่อ') end as killer_name
      from public.boss_history_scope(p_host, p_include_self) s
     where p_since is null or s.killed_at >= p_since
  ), scoped as (
    select * from base
     where p_killer is null or p_killer = 'all' or killer_key = p_killer
  ), killers as (
    select killer_key, min(killer_name) as name, count(*) as cnt, max(killed_at) as last_at
      from base group by killer_key
  ), grp as (
    select boss_id, coalesce(server_id, '') as sv,
           (array_agg(boss_name order by killed_at desc, id desc))[1] as boss_name,
           count(*) as kills,
           count(*) filter (where p_today_start is not null and killed_at >= p_today_start) as today,
           max(killed_at) as last_at
      from scoped group by boss_id, coalesce(server_id, '')
  ), by_killer as (
    select boss_id, coalesce(server_id, '') as sv, killer_name, count(*) as cnt, max(killed_at) as last_at
      from scoped group by boss_id, coalesce(server_id, ''), killer_name
  ), item_counts as (
    select sc.boss_id, coalesce(sc.server_id, '') as sv, it.name, count(*) as cnt, max(sc.killed_at) as last_at
      from scoped sc join public.kill_items it on it.kill_id = sc.id
     group by sc.boss_id, coalesce(sc.server_id, ''), it.name
  )
  select jsonb_build_object(
    'killers', coalesce((select jsonb_agg(jsonb_build_object('id', killer_key, 'name', name, 'count', cnt)
                                          order by last_at desc) from killers), '[]'::jsonb),
    'groups', coalesce((select jsonb_agg(jsonb_build_object(
        'boss_id', g.boss_id, 'server_id', nullif(g.sv, ''), 'boss_name', g.boss_name,
        'kills', g.kills, 'today', g.today, 'last_at', g.last_at,
        'by', coalesce((select jsonb_agg(jsonb_build_object('name', b.killer_name, 'count', b.cnt) order by b.last_at desc)
                          from by_killer b where b.boss_id = g.boss_id and b.sv = g.sv), '[]'::jsonb),
        'items', coalesce((select jsonb_agg(jsonb_build_object('name', ic.name, 'count', ic.cnt) order by ic.last_at desc, ic.name)
                             from item_counts ic where ic.boss_id = g.boss_id and ic.sv = g.sv), '[]'::jsonb)
      ) order by g.last_at desc) from grp g), '[]'::jsonb)
  );
$$;

-- 4) "ส่วนแบ่งของฉัน" ตลอดชีพ (ทุกปาร์ตี้ รวมปาร์ตี้ที่ออกไปแล้ว) — คำนวณในฐานข้อมูล ไม่ดึงทุกแถวมานับ
create or replace function public.my_lifetime_share()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'count', count(*),
    'zeny', coalesce(sum(sold_amount / cardinality(shared_with)) filter (where coalesce(sold_currency, 'zeny') = 'zeny'), 0),
    'baht', coalesce(sum(sold_amount / cardinality(shared_with)) filter (where sold_currency = 'baht'), 0))
    from public.kill_items
   where sold_amount is not null and shared_with @> array[auth.uid()];
$$;

revoke all on function public.boss_history_scope(uuid, boolean) from public, anon;
revoke all on function public.boss_history_page(uuid, boolean, timestamptz, uuid, integer) from public, anon;
revoke all on function public.boss_history_stats(uuid, boolean, timestamptz) from public, anon;
revoke all on function public.boss_history_by_boss(uuid, boolean, timestamptz, timestamptz, text) from public, anon;
revoke all on function public.my_lifetime_share() from public, anon;
grant execute on function public.boss_history_scope(uuid, boolean) to authenticated;
grant execute on function public.boss_history_page(uuid, boolean, timestamptz, uuid, integer) to authenticated;
grant execute on function public.boss_history_stats(uuid, boolean, timestamptz) to authenticated;
grant execute on function public.boss_history_by_boss(uuid, boolean, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.my_lifetime_share() to authenticated;

commit;

-- ตรวจหลังรัน (อ่านอย่างเดียว): ต้องได้ 5 แถว
select p.proname, pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('boss_history_scope', 'boss_history_page', 'boss_history_stats', 'boss_history_by_boss', 'my_lifetime_share')
 order by p.proname;
