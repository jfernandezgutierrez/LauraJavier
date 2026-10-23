-- Remote project schema. All client writes are constrained by grants and RLS.
create schema if not exists wedding_private;
revoke all on schema wedding_private from public;
grant usage on schema wedding_private to authenticated;
create table wedding_private.admin_emails(email text primary key check(email=lower(email)));
alter table wedding_private.admin_emails enable row level security;
create function wedding_private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users u join wedding_private.admin_emails a on lower(u.email)=a.email where u.id=auth.uid() and u.email_confirmed_at is not null)
$$;
revoke all on function wedding_private.is_admin() from public,anon;
grant execute on function wedding_private.is_admin() to authenticated;
create function public.wedding_is_admin() returns boolean language sql stable security invoker set search_path='' as $$ select wedding_private.is_admin() $$;
revoke all on function public.wedding_is_admin() from public,anon;
grant execute on function public.wedding_is_admin() to authenticated;

create table public.wedding_settings(id integer primary key check(id=1), content jsonb not null default '{}', updated_at timestamptz not null default now());
create table public.wedding_profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check(length(full_name) between 2 and 100),
 alias text not null check(length(alias) between 2 and 24),
 phone text not null default '' check(length(phone)<=30),
 email_updates boolean not null default false,
 in_app_updates boolean not null default true,
 leaderboard_visible boolean not null default false,
 consent_at timestamptz not null default now(), created_at timestamptz not null default now()
);
create table public.wedding_invitations(
 user_id uuid primary key references public.wedding_profiles(id) on delete cascade,
 max_guests integer not null default 1 check(max_guests between 1 and 10),
 approved boolean not null default false
);
create table public.wedding_rsvps(
 user_id uuid primary key references public.wedding_profiles(id) on delete cascade,
 attending boolean not null, guests integer not null check(guests between 0 and 10),
 guest_names text not null default '' check(length(guest_names)<=1000),
 dietary text not null default '' check(length(dietary)<=1000), bus boolean not null default false,
 updated_at timestamptz not null default now(), check((attending and guests>=1) or (not attending and guests=0))
);
create table public.wedding_songs(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.wedding_profiles(id) on delete cascade,
 title text not null check(length(title) between 1 and 150), artist text not null check(length(artist) between 1 and 150),
 spotify_url text not null default '' check(spotify_url='' or spotify_url ~ '^https://open\.spotify\.com/track/[A-Za-z0-9]{22}(\?.*)?$'),
 status text not null default 'pending' check(status in ('pending','approved','added','rejected')),
 created_at timestamptz not null default now(), unique(user_id,title,artist)
);
create unique index wedding_songs_track_unique on public.wedding_songs(spotify_url) where spotify_url<>'';
create index wedding_songs_user on public.wedding_songs(user_id);
create table public.wedding_announcements(id uuid primary key default gen_random_uuid(),title text not null check(length(title) between 1 and 120),body text not null check(length(body) between 1 and 3000),published boolean not null default false,created_at timestamptz not null default now());
create table public.wedding_game_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.wedding_profiles(id) on delete cascade,started_at timestamptz not null default now(),finished_at timestamptz,score integer,steps integer,hidden boolean not null default false);
create index wedding_game_runs_user on public.wedding_game_runs(user_id,started_at desc);

alter table public.wedding_settings enable row level security;
alter table public.wedding_profiles enable row level security;
alter table public.wedding_invitations enable row level security;
alter table public.wedding_rsvps enable row level security;
alter table public.wedding_songs enable row level security;
alter table public.wedding_announcements enable row level security;
alter table public.wedding_game_runs enable row level security;
revoke all on public.wedding_settings,public.wedding_profiles,public.wedding_invitations,public.wedding_rsvps,public.wedding_songs,public.wedding_announcements,public.wedding_game_runs from anon,authenticated;
grant select on public.wedding_settings to anon,authenticated;
grant update(content,updated_at) on public.wedding_settings to authenticated;
create policy settings_read on public.wedding_settings for select to anon,authenticated using(true);
create policy settings_admin on public.wedding_settings for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());
grant select,insert on public.wedding_profiles to authenticated;
grant update(full_name,alias,phone,email_updates,in_app_updates,leaderboard_visible) on public.wedding_profiles to authenticated;
create policy profiles_read on public.wedding_profiles for select to authenticated using(id=(select auth.uid()) or wedding_private.is_admin());
create policy profiles_insert on public.wedding_profiles for insert to authenticated with check(id=(select auth.uid()));
create policy profiles_update on public.wedding_profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
grant select,insert,update on public.wedding_invitations to authenticated;
create policy invitations_read on public.wedding_invitations for select to authenticated using(user_id=(select auth.uid()) or wedding_private.is_admin());
create policy invitations_insert on public.wedding_invitations for insert to authenticated with check(wedding_private.is_admin());
create policy invitations_update on public.wedding_invitations for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());
grant select,insert,update on public.wedding_rsvps to authenticated;
create policy rsvps_read on public.wedding_rsvps for select to authenticated using(user_id=(select auth.uid()) or wedding_private.is_admin());
create function wedding_private.rsvp_allowed(uid uuid,total integer) returns boolean language sql stable security invoker set search_path='' as $$
 select uid=auth.uid() and exists(select 1 from public.wedding_invitations i where i.user_id=uid and i.approved and total<=i.max_guests) and coalesce((select nullif(content->>'rsvp_deadline','')::timestamptz >= now() from public.wedding_settings where id=1),true)
$$;
revoke all on function wedding_private.rsvp_allowed(uuid,integer) from public,anon;
grant execute on function wedding_private.rsvp_allowed(uuid,integer) to authenticated;
create policy rsvp_insert on public.wedding_rsvps for insert to authenticated with check(wedding_private.rsvp_allowed(user_id,guests));
create policy rsvp_update on public.wedding_rsvps for update to authenticated using(user_id=(select auth.uid())) with check(wedding_private.rsvp_allowed(user_id,guests));
grant select on public.wedding_songs to authenticated;
grant insert(user_id,title,artist,spotify_url) on public.wedding_songs to authenticated;
grant update(status) on public.wedding_songs to authenticated;
create policy songs_read on public.wedding_songs for select to authenticated using(user_id=(select auth.uid()) or wedding_private.is_admin());
create policy songs_insert on public.wedding_songs for insert to authenticated with check(user_id=(select auth.uid()) and status='pending');
create policy songs_update on public.wedding_songs for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());
grant select,insert,update,delete on public.wedding_announcements to authenticated;
create policy announcements_read on public.wedding_announcements for select to authenticated using(wedding_private.is_admin() or (published and exists(select 1 from public.wedding_profiles p where p.id=(select auth.uid()) and p.in_app_updates)));
create policy announcements_insert on public.wedding_announcements for insert to authenticated with check(wedding_private.is_admin());
create policy announcements_update on public.wedding_announcements for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());
create policy announcements_delete on public.wedding_announcements for delete to authenticated using(wedding_private.is_admin());
grant select on public.wedding_game_runs to authenticated;
grant update(hidden) on public.wedding_game_runs to authenticated;
create policy games_read on public.wedding_game_runs for select to authenticated using(user_id=(select auth.uid()) or wedding_private.is_admin());
create policy games_moderate on public.wedding_game_runs for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());

create function wedding_private.leaderboard() returns table(alias text,score integer,steps integer) language sql stable security definer set search_path='' as $$
 select p.alias,max(g.score)::integer,min(g.steps)::integer from public.wedding_profiles p join public.wedding_game_runs g on g.user_id=p.id
 where auth.uid() is not null and p.leaderboard_visible and g.finished_at is not null and not g.hidden group by p.id,p.alias order by max(g.score) desc,min(g.steps),p.id limit 20
$$;
create function public.wedding_leaderboard() returns table(alias text,score integer,steps integer) language sql stable security invoker set search_path='' as $$ select * from wedding_private.leaderboard() $$;
create function wedding_private.start_game() returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Completa tu perfil para guardar partidas'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if (select count(*) from public.wedding_game_runs where user_id=auth.uid() and started_at>now()-interval '1 hour')>=30 then raise exception 'Has alcanzado el máximo de partidas por hora'; end if;
 insert into public.wedding_game_runs(user_id) values(auth.uid()) returning id into result; return result;
end $$;
create function public.wedding_start_game() returns uuid language sql security invoker set search_path='' as $$ select wedding_private.start_game() $$;
create function wedding_private.finish_game(run_id uuid,moves text) returns integer language plpgsql security definer set search_path='' as $$
declare g public.wedding_game_runs; x integer:=0; y integer:=5; r1 boolean:=false; r2 boolean:=false; c text; i integer; points integer;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 select * into g from public.wedding_game_runs where id=run_id and user_id=auth.uid() for update;
 if not found or g.finished_at is not null then raise exception 'Partida inexistente o ya guardada'; end if;
 if moves is null or length(moves)<1 or length(moves)>300 or moves !~ '^[UDLR]+$' then raise exception 'Recorrido inválido'; end if;
 if now()-g.started_at > interval '2 hours' or extract(epoch from now()-g.started_at)<length(moves)*0.09 then raise exception 'Duración de partida inválida'; end if;
 for i in 1..length(moves) loop
  c:=substr(moves,i,1);
  case c when 'U' then y:=y-1; when 'D' then y:=y+1; when 'L' then x:=x-1; when 'R' then x:=x+1; end case;
  if x<0 or x>7 or y<0 or y>5 or (x=3 and y in(1,2,3)) or (x=5 and y=4) then raise exception 'Movimiento inválido'; end if;
  if x=1 and y=1 then r1:=true; end if;
  if x=6 and y=4 then r2:=true; end if;
 end loop;
 if not r1 or not r2 or x<>7 or y<>0 then raise exception 'Faltan los anillos o llegar a la meta'; end if;
 points:=greatest(100,2000-length(moves)*20);
 update public.wedding_game_runs set finished_at=now(),score=points,steps=length(moves) where id=run_id; return points;
end $$;
create function public.wedding_finish_game(run_id uuid,moves text) returns integer language sql security invoker set search_path='' as $$ select wedding_private.finish_game(run_id,moves) $$;
revoke all on function wedding_private.leaderboard(),wedding_private.start_game(),wedding_private.finish_game(uuid,text),public.wedding_leaderboard(),public.wedding_start_game(),public.wedding_finish_game(uuid,text) from public,anon;
grant execute on function wedding_private.leaderboard(),wedding_private.start_game(),wedding_private.finish_game(uuid,text),public.wedding_leaderboard(),public.wedding_start_game(),public.wedding_finish_game(uuid,text) to authenticated;

-- Emails only exposed to approved administrators, with opt-in state from profiles.
create function wedding_private.guest_contacts() returns table(id uuid,email text) language sql stable security definer set search_path='' as $$ select u.id,u.email::text from auth.users u join public.wedding_profiles p on p.id=u.id where auth.uid() is not null and wedding_private.is_admin() $$;
create function public.wedding_guest_contacts() returns table(id uuid,email text) language sql stable security invoker set search_path='' as $$ select * from wedding_private.guest_contacts() $$;
revoke all on function wedding_private.guest_contacts(),public.wedding_guest_contacts() from public,anon;
grant execute on function wedding_private.guest_contacts(),public.wedding_guest_contacts() to authenticated;

insert into public.wedding_settings(id,content) values(1,'{"couple":"Laura y Javier","date":"","location":"","dog_name":"Nuestro compañero","welcome":"Hay caminos que merece la pena recorrer juntos. Y este, queremos compartirlo contigo.","ceremony_name":"","ceremony_address":"","ceremony_time":"","reception_name":"","reception_address":"","reception_time":"","spotify_playlist":"","rsvp_deadline":"","transport":"","accommodation":"","dress_code":"","contact":"","story":[{"title":"Cada paso, juntos","text":"De los pequeños momentos a los grandes recuerdos. Nuestra aventura continúa.","image":"couple"},{"title":"Un lugar al que llamar hogar","text":"Lo soñamos, lo trabajamos, lo conseguimos.","image":"home"},{"title":"Y unas huellas a nuestro lado","text":"Nuestra historia también se escribe a cuatro patas.","image":"dog"}],"schedule":[{"title":"La ceremonia","time":""},{"title":"Un brindis por nosotros","time":""},{"title":"Todos a la mesa","time":""},{"title":"Que empiece la fiesta","time":""}]}');
