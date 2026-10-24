-- PostEarn Pakistan starter database for Supabase.
-- Run this entire file in Supabase Dashboard -> SQL Editor.
-- Security is enforced by Row Level Security (RLS). Never expose a service-role key in browser code.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Member' check (char_length(display_name) between 2 and 40),
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  body text not null check (char_length(body) between 10 and 5000),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  view_count bigint not null default 0 check (view_count >= 0),
  created_at timestamptz not null default now(),
  moderated_at timestamptz
);

create table if not exists public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id,user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 2 and 1000),
  created_at timestamptz not null default now()
);

-- One view per authenticated member per post. Anonymous views are intentionally not counted.
create table if not exists public.post_views (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id,user_id)
);

create index if not exists posts_status_created_idx on public.posts(status,created_at desc);
create index if not exists posts_author_idx on public.posts(author_id,created_at desc);
create index if not exists comments_post_created_idx on public.comments(post_id,created_at);

-- Create a profile automatically after a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(left(trim(new.raw_user_meta_data ->> 'display_name'),40),''),'Member')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Admin-only helper. Users cannot change their own role through the public API.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin');
$$;

-- Record one view per authenticated user and approved post.
create or replace function public.record_post_view(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if viewer is null then
    raise exception 'Login required';
  end if;
  if not exists (select 1 from public.posts p where p.id = target_post_id and p.status = 'approved') then
    return;
  end if;
  if exists (select 1 from public.posts p where p.id = target_post_id and p.author_id = viewer) then
    return;
  end if;
  insert into public.post_views(post_id,user_id)
  values (target_post_id,viewer)
  on conflict (post_id,user_id) do nothing;
  if found then
    update public.posts set view_count = view_count + 1 where id = target_post_id and status = 'approved';
  end if;
end;
$$;

-- Enable row-level security on every user-facing table.
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.post_views enable row level security;

-- Profiles: authenticated users can read public display names; users may update only their own display name.
drop policy if exists "Profiles are visible to authenticated users" on public.profiles;
create policy "Profiles are visible to authenticated users" on public.profiles
for select to authenticated using (true);
drop policy if exists "Users update own display name" on public.profiles;
create policy "Users update own display name" on public.profiles
for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
-- Prevent changing the role via ordinary table update grants; column-level grant allows display_name only.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Posts: everyone authenticated can see approved posts; authors can see their own; admins can see all.
drop policy if exists "Read approved own or admin posts" on public.posts;
create policy "Read approved own or admin posts" on public.posts
for select to authenticated using (status = 'approved' or author_id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists "Members submit own pending posts" on public.posts;
create policy "Members submit own pending posts" on public.posts
for insert to authenticated with check (author_id = (select auth.uid()) and status = 'pending' and view_count = 0 and moderated_at is null);
drop policy if exists "Admins moderate posts" on public.posts;
create policy "Admins moderate posts" on public.posts
for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
-- No member update/delete policy is created; members cannot change approved content or inflate view_count.

-- Likes: authenticated members can read likes on approved posts, and only like/unlike as themselves.
drop policy if exists "Read likes for approved posts" on public.likes;
create policy "Read likes for approved posts" on public.likes
for select to authenticated using (exists (select 1 from public.posts p where p.id = post_id and p.status = 'approved'));
drop policy if exists "Like approved posts as self" on public.likes;
create policy "Like approved posts as self" on public.likes
for insert to authenticated with check (user_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id and p.status = 'approved'));
drop policy if exists "Unlike own likes" on public.likes;
create policy "Unlike own likes" on public.likes
for delete to authenticated using (user_id = (select auth.uid()));

-- Comments: read only on approved posts; insert as the signed-in author; delete own or admin.
drop policy if exists "Read comments on approved posts" on public.comments;
create policy "Read comments on approved posts" on public.comments
for select to authenticated using (exists (select 1 from public.posts p where p.id = post_id and p.status = 'approved'));
drop policy if exists "Comment on approved posts as self" on public.comments;
create policy "Comment on approved posts as self" on public.comments
for insert to authenticated with check (author_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id and p.status = 'approved'));
drop policy if exists "Delete own comments or admin" on public.comments;
create policy "Delete own comments or admin" on public.comments
for delete to authenticated using (author_id = (select auth.uid()) or (select public.is_admin()));

-- Views: users cannot read or modify the raw view table. The controlled function records views.
revoke all on public.post_views from anon, authenticated;
revoke all on function public.record_post_view(uuid) from public;
grant execute on function public.record_post_view(uuid) to authenticated;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Grant only the table operations needed by the browser app.
grant select on public.profiles, public.posts, public.likes, public.comments to authenticated;
grant insert on public.posts, public.likes, public.comments to authenticated;
grant delete on public.likes, public.comments to authenticated;
grant update (status, moderated_at) on public.posts to authenticated;

-- IMPORTANT: after you create your own account, promote that user to admin manually in SQL Editor:
-- update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';
-- Find the UUID in Authentication -> Users. Never add a public admin-signup option.
