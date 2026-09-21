# Gum100 Supabase backup

This directory keeps the source for the two deployed TMWEASY Edge Functions and a restorable SQL snapshot of the Production package/top-up backend.

Secrets are intentionally excluded. Configure them in Supabase Edge Function Secrets using the variable names in `.env.example`. Never commit real values or a service-role key.

The SQL migration was reconstructed from the live Production table metadata, policies, and function definitions on 2026-09-20. Review it before applying to a new project because it depends on the existing `public.profiles`, `public.is_active()`, and `public.is_admin()` objects.

## Migrations (run in this order in Supabase → SQL Editor)

| File | What it does |
|---|---|
| `20260920000100_backend_snapshot.sql` | Snapshot of the package / top-up backend (tables, RLS, `buy_plan`, `credit_tmweasy_topup`) |
| `20260921000100_security_hardening.sql` | Free accounts never expire (2099 sentinel), revoke direct writes, close slip top-ups, promo end (`promo_active`), boss cap (`boss_slot_available`) |
| `20260921000200_profile_privacy.sql` | `profiles` readable by members only for `id, display_name`; own profile via `my_profile()` |
| `20260921000300_admin_topup_manage.sql` | Admin top-up management (`admin_confirm_topup`, `admin_close_topup`, `admin_find_member`, `admin_grant_points`) |
| `20260922000100_hardening_round2.sql` | Yearly price 1,990 / promo 990, boss data cleanup, QR rate limit (5 unfinished attempts/hour; successful top-ups do not count), `points_ledger`, `topup_admin_log`, `admin_reverse_topup`, `admin_deduct_points` |

Important: the tables and functions created before 2026-09-20 (bosses, kills, custom bosses, announcements, party, cloud data …) are **not** in this folder. They only exist in the live Supabase project, so this repo alone cannot rebuild the database. Keep Supabase backups enabled (Pro plan) and export the full schema periodically (`supabase db dump --schema public -f supabase/schema.sql`).

Deploy order rule: ship the new `index.html` first, then run the newest migration (a migration may remove things the previous web version still calls).
