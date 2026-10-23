-- Additive schema for authenticated, server-scored pet minigames.
create table public.wedding_arcade_runs (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.wedding_profiles(id) on delete cascade,
 kind text not null check(kind in ('catch','memory')),
 board integer[] not null,
 started_at timestamptz not null default now(),
 completed boolean not null default false,
 result jsonb
);
create index wedding_arcade_user_started on public.wedding_arcade_runs(user_id,started_at desc);
alter table public.wedding_arcade_runs enable row level security;
revoke all on public.wedding_arcade_runs from anon,authenticated;
grant select on public.wedding_arcade_runs to authenticated;
create policy arcade_read_own on public.wedding_arcade_runs for select to authenticated using(user_id=(select auth.uid()));

create function wedding_private.arcade_start(game_kind text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb; b integer[]; r public.wedding_arcade_runs;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Entra y completa tu perfil para jugar';end if;
 if game_kind is null or game_kind not in ('catch','memory') then raise exception 'Juego no válido';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if (select count(*) from public.wedding_arcade_runs where user_id=auth.uid() and started_at>now()-interval '1 hour')>=12 then raise exception 'Habéis jugado mucho. Vuelve en una hora para nuevas aventuras';end if;
 p:=wedding_private.pet_action('visit');
 if (p->>'sleeping')::boolean then raise exception 'Despierta a tu perrito antes de jugar';end if;
 if (p->>'energy')::int<10 or (p->>'hunger')::int<5 then raise exception 'Tu perrito necesita comer o descansar antes de jugar';end if;
 if now()-(p->>'last_action_at')::timestamptz<interval '4 seconds' then raise exception 'Espera unos segundos antes de jugar';end if;
 if game_kind='catch' then select array_agg(floor(random()*3)::int) into b from generate_series(1,12);
 else select array_agg(v order by random()) into b from (select (n-1)%6 v from generate_series(1,12) n) s;end if;
 update public.wedding_arcade_runs set completed=true,result='{"abandoned":true}'::jsonb where user_id=auth.uid() and not completed;
 insert into public.wedding_arcade_runs(user_id,kind,board) values(auth.uid(),game_kind,b) returning * into r;
 update public.wedding_pets set hunger=(p->>'hunger')::int-5,energy=(p->>'energy')::int-8,hygiene=greatest(0,(p->>'hygiene')::int-4),happiness=(p->>'happiness')::int,updated_at=now(),last_action_at=now() where user_id=auth.uid();
 return jsonb_build_object('id',r.id,'kind',r.kind,'board',r.board);
end $$;

create function wedding_private.arcade_finish(run_id uuid,actions integer[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.wedding_arcade_runs; points integer:=0; used integer[]:='{}'; a integer; b integer; i integer; n integer; award jsonb;
begin
 if auth.uid() is null then raise exception 'Entra para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into r from public.wedding_arcade_runs where id=run_id and user_id=auth.uid() for update;
 if not found then raise exception 'Partida no disponible';end if;
 if r.completed then
  if r.result ? 'abandoned' then raise exception 'Esta partida fue abandonada';end if;
  return r.result; -- A retried response never grants a second reward.
 end if;
 if now()-r.started_at>interval '10 minutes' then raise exception 'La partida ha caducado. Empieza otra';end if;
 if actions is null or array_ndims(actions)>1 or array_position(actions,null) is not null then raise exception 'Movimientos no válidos';end if;
 n:=coalesce(array_length(actions,1),0);
 if r.kind='catch' then
  if n<>12 or now()-r.started_at<interval '18 seconds' then raise exception 'Termina los doce premios antes de guardar';end if;
  for i in 1..12 loop
   if actions[i] not between 0 and 2 then raise exception 'Camino no válido';end if;
   if actions[i]=r.board[i] then points:=points+1;end if;
  end loop;
  award:=jsonb_build_object('coins',points*2,'xp',points*3,'score',points);
 else
  if n>48 or n%2<>0 or extract(epoch from now()-r.started_at)<greatest(3,n*0.2) then raise exception 'Movimientos o duración no válidos';end if;
  if n>0 then
   for i in 1..n by 2 loop
    a:=actions[i];b:=actions[i+1];
    if a not between 0 and 11 or b not between 0 and 11 or a=b or a=any(used) or b=any(used) then raise exception 'Pareja no válida';end if;
    if r.board[a+1]=r.board[b+1] then points:=points+1;used:=used||array[a,b];end if;
   end loop;
  end if;
  award:=jsonb_build_object('coins',points*4,'xp',points*6,'score',points);
 end if;
 update public.wedding_arcade_runs set completed=true,result=award where id=r.id;
 update public.wedding_pets set coins=coins+(award->>'coins')::int,xp=xp+(award->>'xp')::int,care_count=care_count+case when points>0 then 1 else 0 end where user_id=auth.uid();
 return award;
end $$;
create function public.wedding_arcade_start(game_kind text) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.arcade_start(game_kind)$$;
create function public.wedding_arcade_finish(run_id uuid,actions integer[]) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.arcade_finish(run_id,actions)$$;
revoke all on function wedding_private.arcade_start(text),public.wedding_arcade_start(text),wedding_private.arcade_finish(uuid,integer[]),public.wedding_arcade_finish(uuid,integer[]) from public,anon;
grant execute on function wedding_private.arcade_start(text),public.wedding_arcade_start(text),wedding_private.arcade_finish(uuid,integer[]),public.wedding_arcade_finish(uuid,integer[]) to authenticated;

-- Retire click-only rewards, including direct calls.
create or replace function wedding_private.pet_action(action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.wedding_pets; elapsed double precision; gain integer:=0; cost integer:=0; hunger_gain integer:=0;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Completa tu perfil para guardar a tu perrito'; end if;
 if action is null or action not in('visit','feed','apple','bone','wash','play','pet','sleep','wake') then raise exception 'Acción desconocida';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 insert into public.wedding_pets(user_id) values(auth.uid()) on conflict do nothing;
 select * into p from public.wedding_pets where user_id=auth.uid() for update;
 elapsed:=greatest(0,extract(epoch from now()-p.updated_at)/3600);
 p.hunger:=greatest(0,p.hunger-floor(elapsed*3)::integer);
 p.hygiene:=greatest(0,p.hygiene-floor(elapsed*2)::integer);
 p.happiness:=greatest(0,p.happiness-floor(elapsed*2)::integer);
 if p.sleeping then p.energy:=least(100,p.energy+floor(elapsed*120)::integer);else p.energy:=greatest(0,p.energy-floor(elapsed*2)::integer);end if;
 if action<>'visit' then
  if now()-p.last_action_at<interval '4 seconds' then raise exception 'Dale un momento a tu perrito antes del siguiente cuidado';end if;
  if p.sleeping and action not in('wake','sleep') then raise exception 'Tu perrito está dormido. Despiértalo primero';end if;
  case action
   when 'feed','apple','bone' then
    if p.hunger>=95 then raise exception '¡La barriguita ya está llena!';end if;
    cost:=case action when 'feed' then 6 when 'apple' then 10 else 18 end;
    hunger_gain:=case action when 'feed' then 25 when 'apple' then 40 else 60 end;
    if p.coins<cost then raise exception 'Te faltan monedas. Juega a la pelota para conseguir más';end if;
    p.coins:=p.coins-cost;p.hunger:=least(100,p.hunger+hunger_gain);p.happiness:=least(100,p.happiness+4);gain:=8;
   when 'wash' then
    if p.hygiene>=95 then raise exception 'Tu perrito ya está reluciente';end if;
    p.hygiene:=least(100,p.hygiene+35);p.happiness:=least(100,p.happiness+3);gain:=8;
   when 'play' then
    raise exception 'Elige un minijuego en la habitación Juegos';
    if p.energy<10 then raise exception 'Necesita una siesta antes de seguir jugando';end if;
    if p.hunger<5 then raise exception 'Necesita comer algo antes de jugar';end if;
    p.happiness:=least(100,p.happiness+20);p.energy:=greatest(0,p.energy-8);p.hygiene:=greatest(0,p.hygiene-9);p.hunger:=greatest(0,p.hunger-5);p.coins:=p.coins+8;gain:=12;
   when 'pet' then
    if p.happiness>=95 then raise exception '¡Está feliz como una perdiz! Prueba otro cuidado';end if;
    p.happiness:=least(100,p.happiness+15);gain:=3;
   when 'sleep' then p.sleeping:=true;
   when 'wake' then p.sleeping:=false;
  end case;
  p.xp:=p.xp+gain;
  if gain>0 then p.care_count:=p.care_count+1;end if;
  p.last_action_at:=now();
 end if;
 -- Visits calculate from the last stored action without writing the snapshot.
 -- Refreshing cannot repeatedly credit the same elapsed sleep time.
 if action<>'visit' then
  p.updated_at:=now();
  update public.wedding_pets set hunger=p.hunger,hygiene=p.hygiene,energy=p.energy,happiness=p.happiness,coins=p.coins,xp=p.xp,care_count=p.care_count,sleeping=p.sleeping,updated_at=p.updated_at,last_action_at=p.last_action_at where user_id=auth.uid();
 end if;
 return jsonb_build_object('hunger',p.hunger,'hygiene',p.hygiene,'energy',p.energy,'happiness',p.happiness,'coins',p.coins,'xp',p.xp,'care_count',p.care_count,'sleeping',p.sleeping,'updated_at',p.updated_at,'last_action_at',p.last_action_at);
end $$;
