create table public.wedding_pets (
 user_id uuid primary key references public.wedding_profiles(id) on delete cascade,
 hunger integer not null default 65 check(hunger between 0 and 100),
 hygiene integer not null default 60 check(hygiene between 0 and 100),
 energy integer not null default 75 check(energy between 0 and 100),
 happiness integer not null default 65 check(happiness between 0 and 100),
 coins integer not null default 60 check(coins>=0),
 xp integer not null default 0 check(xp>=0),
 care_count integer not null default 0 check(care_count>=0),
 sleeping boolean not null default false,
 hidden boolean not null default false,
 updated_at timestamptz not null default now(),
 last_action_at timestamptz not null default '-infinity'
);
alter table public.wedding_pets enable row level security;
revoke all on public.wedding_pets from anon,authenticated;
grant select on public.wedding_pets to authenticated;
grant update(hidden) on public.wedding_pets to authenticated;
create policy pets_read on public.wedding_pets for select to authenticated using(user_id=(select auth.uid()) or wedding_private.is_admin());
create policy pets_moderate on public.wedding_pets for update to authenticated using(wedding_private.is_admin()) with check(wedding_private.is_admin());

create function wedding_private.pet_action(action text) returns jsonb language plpgsql security definer set search_path='' as $$
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
create function public.wedding_pet_action(action text) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.pet_action(action)$$;
create function wedding_private.pet_leaderboard() returns table(alias text,xp integer,care_count integer) language sql stable security definer set search_path='' as $$
 select p.alias,g.xp,g.care_count from public.wedding_pets g join public.wedding_profiles p on p.id=g.user_id where auth.uid() is not null and p.leaderboard_visible and not g.hidden and g.xp>0 order by g.xp desc,g.care_count desc,p.id limit 20
$$;
create function public.wedding_pet_leaderboard() returns table(alias text,xp integer,care_count integer) language sql stable security invoker set search_path='' as $$select * from wedding_private.pet_leaderboard()$$;
revoke all on function wedding_private.pet_action(text),public.wedding_pet_action(text),wedding_private.pet_leaderboard(),public.wedding_pet_leaderboard() from public,anon;
grant execute on function wedding_private.pet_action(text),public.wedding_pet_action(text),wedding_private.pet_leaderboard(),public.wedding_pet_leaderboard() to authenticated;
