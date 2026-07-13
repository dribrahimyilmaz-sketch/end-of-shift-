-- ============================================================
-- End of Shift — Supabase güvenlik + temizlik kurulumu
-- Nasıl uygulanır:
--   1. https://supabase.com/dashboard → projen (vriammjvjuyyrevbsvwf)
--   2. Sol menü → SQL Editor → New query
--   3. Bu dosyanın TAMAMINI yapıştır → Run
-- Kararlar (2026-07-13): skor limiti 5000, online sayaç isimsiz +
-- 1 saat sonra silinir, skorlar: 5 günden eski VE 100 altı silinir.
-- ============================================================

-- ---------- 1) scores tablosu: eksik kolonlar ----------
alter table public.scores add column if not exists created_at timestamptz not null default now();
alter table public.scores add column if not exists room_code text;

-- ---------- 2) active_players: isim kolonunu kaldır (veri minimizasyonu) ----------
alter table public.active_players drop column if exists name;

-- ---------- 3) RLS (Row Level Security) aç ----------
alter table public.scores enable row level security;
alter table public.active_players enable row level security;

-- Eski/çakışan politikaları temizle
drop policy if exists "scores_select" on public.scores;
drop policy if exists "scores_insert" on public.scores;
drop policy if exists "active_select" on public.active_players;
drop policy if exists "active_insert" on public.active_players;
drop policy if exists "active_update" on public.active_players;
-- Supabase'in tablo oluştururken eklediği varsayılan geniş politikalar varsa
-- Dashboard → Authentication → Policies ekranından onları da silmen iyi olur.

-- SCORES: herkes okuyabilir, sadece mantıklı kayıtlar eklenebilir,
-- UPDATE/DELETE anon için tamamen kapalı (politika yok = yasak).
create policy "scores_select" on public.scores
  for select to anon using (true);

create policy "scores_insert" on public.scores
  for insert to anon
  with check (
    score >= 0 and score <= 5000
    and level >= 1 and level <= 99
    and char_length(name) between 2 and 16
    and (room_code is null or room_code ~ '^[A-Z0-9]{1,10}$')
  );

-- ACTIVE_PLAYERS: sadece oturum kimliği + zaman. Upsert için insert+update gerekli.
create policy "active_select" on public.active_players
  for select to anon using (true);

create policy "active_insert" on public.active_players
  for insert to anon
  with check (char_length(session_id) <= 64);

create policy "active_update" on public.active_players
  for update to anon
  using (true)
  with check (char_length(session_id) <= 64);

-- ---------- 4) Otomatik temizlik (pg_cron) ----------
-- Not: Önce Dashboard → Database → Extensions → "pg_cron" u etkinleştir.
create extension if not exists pg_cron;

-- Varsa eski işleri kaldır (tekrar çalıştırılabilir olsun diye)
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('eos_scores_cleanup', 'eos_active_cleanup');
exception when others then null;
end $$;

-- Menüdeki kurala birebir: 5 günden eski VE 100 altındaki skorlar silinir (her gece 03:00 UTC)
select cron.schedule(
  'eos_scores_cleanup', '0 3 * * *',
  $$delete from public.scores where score < 100 and created_at < now() - interval '5 days'$$
);

-- Online sayaç kayıtları 1 saat sonra silinir (saat başı)
select cron.schedule(
  'eos_active_cleanup', '30 * * * *',
  $$delete from public.active_players where last_seen < now() - interval '1 hour'$$
);

-- ---------- 5) Kontrol ----------
-- Çalıştıktan sonra şunu ayrıca çalıştırıp iki işi görmelisin:
--   select jobname, schedule from cron.job;
