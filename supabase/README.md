# Gum100 Supabase backup

This directory keeps the source for the two deployed TMWEASY Edge Functions and a restorable SQL snapshot of the Production package/top-up backend.

Secrets are intentionally excluded. Configure them in Supabase Edge Function Secrets using the variable names in `.env.example`. Never commit real values or a service-role key.

The SQL migration was reconstructed from the live Production table metadata, policies, and function definitions on 2026-09-20. Review it before applying to a new project because it depends on the existing `public.profiles`, `public.is_active()`, and `public.is_admin()` objects.
