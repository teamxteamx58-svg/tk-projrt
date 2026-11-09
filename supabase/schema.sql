-- BASSARI-ZIK : schéma de la bêta (sans argent réel)
-- À coller une seule fois dans Supabase > SQL Editor, puis cliquer sur « Run ».
-- Les règles (RLS) empêchent un utilisateur de modifier les données d'un autre.

-- ============ PROFILS ============
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 40),
  role text not null default 'fan' check (role in ('fan', 'artiste')),
  bio text not null default '' check (char_length(bio) <= 1000),
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_name_key on public.profiles (lower(name));

-- ============ CHANSONS ============
create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  price integer not null default 200 check (price >= 0),
  audio_path text not null,
  cover_path text,
  status text not null default 'published' check (status in ('published', 'hidden')),
  created_at timestamptz not null default now()
);
create index if not exists songs_artist_idx on public.songs (artist_id);

-- ============ COMMENTAIRES ============
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists comments_song_idx on public.comments (song_id, created_at);

-- ============ SIGNALEMENTS ============
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

-- ============ SÉCURITÉ (RLS) ============
alter table public.profiles enable row level security;
alter table public.songs enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;

-- Profils : tout le monde lit ; chacun modifie le sien uniquement
drop policy if exists "profils lisibles" on public.profiles;
create policy "profils lisibles" on public.profiles for select using (true);
drop policy if exists "profil propre à la création" on public.profiles;
create policy "profil propre à la création" on public.profiles for insert
  with check (auth.uid() = id);
drop policy if exists "profil propre à la modification" on public.profiles;
create policy "profil propre à la modification" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- Chansons : lecture publique des chansons publiées ; seul l'artiste publie les siennes
drop policy if exists "chansons publiées lisibles" on public.songs;
create policy "chansons publiées lisibles" on public.songs for select
  using (status = 'published' or artist_id = auth.uid());
drop policy if exists "artiste publie ses chansons" on public.songs;
create policy "artiste publie ses chansons" on public.songs for insert
  with check (
    auth.uid() = artist_id
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'artiste')
  );
drop policy if exists "artiste modifie ses chansons" on public.songs;
create policy "artiste modifie ses chansons" on public.songs for update
  using (auth.uid() = artist_id) with check (auth.uid() = artist_id);
drop policy if exists "artiste supprime ses chansons" on public.songs;
create policy "artiste supprime ses chansons" on public.songs for delete
  using (auth.uid() = artist_id);

-- Commentaires : lecture des non masqués ; un utilisateur connecté écrit en son nom
drop policy if exists "commentaires visibles" on public.comments;
create policy "commentaires visibles" on public.comments for select
  using (hidden = false or user_id = auth.uid());
drop policy if exists "commenter en son nom" on public.comments;
create policy "commenter en son nom" on public.comments for insert
  with check (auth.uid() = user_id);
drop policy if exists "supprimer son commentaire" on public.comments;
create policy "supprimer son commentaire" on public.comments for delete
  using (auth.uid() = user_id);

-- Signalements : chacun signale en son nom, personne ne lit les signalements des autres
drop policy if exists "signaler en son nom" on public.reports;
create policy "signaler en son nom" on public.reports for insert
  with check (auth.uid() = user_id);
drop policy if exists "voir ses signalements" on public.reports;
create policy "voir ses signalements" on public.reports for select
  using (auth.uid() = user_id);

-- ============ FICHIERS (stockage) ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('audio', 'audio', true, 52428800, array['audio/mpeg','audio/mp4','audio/x-m4a','audio/wav','audio/ogg']),
  ('covers', 'covers', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Chacun envoie des fichiers seulement dans son propre dossier (le dossier = son identifiant)
drop policy if exists "audio : envoi dans son dossier" on storage.objects;
create policy "audio : envoi dans son dossier" on storage.objects for insert
  with check (bucket_id = 'audio' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "covers : envoi dans son dossier" on storage.objects;
create policy "covers : envoi dans son dossier" on storage.objects for insert
  with check (bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "audio : lecture publique" on storage.objects;
create policy "audio : lecture publique" on storage.objects for select
  using (bucket_id in ('audio', 'covers'));
