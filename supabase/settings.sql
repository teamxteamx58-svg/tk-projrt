-- Interrupteur des paiements et rôle administrateur
-- À exécuter une fois dans Supabase > SQL Editor, après schema.sql.

-- 1. Autoriser le rôle « admin » dans les profils
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('fan', 'artiste', 'admin'));

-- 2. Réglages du site (lisibles par tous, modifiables par l'administrateur seulement)
create table if not exists public.settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.settings enable row level security;

drop policy if exists "reglages lisibles" on public.settings;
create policy "reglages lisibles" on public.settings for select using (true);

drop policy if exists "reglages modifiables par l'administrateur" on public.settings;
create policy "reglages modifiables par l'administrateur" on public.settings for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- 3. Paiements désactivés au départ (mode gratuit)
insert into public.settings (key, value) values ('payments_enabled', 'false'::jsonb)
on conflict (key) do nothing;

-- 4. Vous donner le rôle administrateur avec votre adresse e-mail
--    (remplacez l'adresse ; le compte doit déjà exister, créé dans le site)
-- update public.profiles set role = 'admin'
--   where id = (select id from auth.users where email = 'VOTRE-ADRESSE@exemple.com');
