-- Huellas Surfer: per-user records, deterministic replay and bounded rewards.
create table public.wedding_runner_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.wedding_profiles(id) on delete cascade,seed integer not null,started_at timestamptz not null default now(),completed boolean not null default false,result jsonb);
create index runner_user_started on public.wedding_runner_runs(user_id,started_at desc);
alter table public.wedding_runner_runs enable row level security;
revoke all on public.wedding_runner_runs from anon,authenticated;
grant select on public.wedding_runner_runs to authenticated;
create policy runner_own on public.wedding_runner_runs for select to authenticated using(user_id=(select auth.uid()));

create function wedding_private.runner_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb;r public.wedding_runner_runs;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Entra y completa tu perfil para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if (select count(*) from public.wedding_runner_runs where user_id=auth.uid() and started_at>now()-interval '1 hour')>=40 then raise exception 'Descansa un ratito. Hay un máximo de 40 carreras por hora';end if;
 p:=wedding_private.pet_action('visit');
 if (p->>'sleeping')::boolean then raise exception 'Despierta a tu perrito antes de jugar';end if;
 if (p->>'energy')::int<3 or (p->>'hunger')::int<2 then raise exception 'Necesita comer o descansar antes de jugar';end if;
 if now()-(p->>'last_action_at')::timestamptz<interval '4 seconds' then raise exception 'Espera unos segundos antes de jugar';end if;
 update public.wedding_runner_runs set completed=true,result='{"abandoned":true}' where user_id=auth.uid() and not completed;
 insert into public.wedding_runner_runs(user_id,seed) values(auth.uid(),1+floor(random()*2147483645)::int) returning * into r;
 update public.wedding_pets set hunger=(p->>'hunger')::int-2,energy=(p->>'energy')::int-3,hygiene=greatest(0,(p->>'hygiene')::int-1),happiness=(p->>'happiness')::int,updated_at=now(),last_action_at=now() where user_id=auth.uid();
 return jsonb_build_object('id',r.id,'seed',r.seed);
end $$;

-- inputs encode tick * 10 + action (1 left, 2 right, 3 jump, 4 duck).
create function wedding_private.runner_finish(run_id uuid,inputs integer[],ticks integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.wedding_runner_runs;seed bigint;t integer;i integer;lane integer:=1;jump integer:=0;duck integer:=0;tokens integer:=0;points integer;dead boolean:=false;speed integer;progress integer[]:='{}';lanes integer[]:='{}';kinds integer[]:='{}';coin_lanes integer[]:='{}';a integer;entry integer;event_tick integer;prev integer:=-10;cursor_pos integer:=1;n integer;award jsonb;best integer;
begin
 if auth.uid() is null then raise exception 'Entra para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into r from public.wedding_runner_runs where id=run_id and user_id=auth.uid() for update;
 if not found then raise exception 'Carrera no disponible';end if;
 if r.completed then if r.result ? 'abandoned' then raise exception 'La carrera fue abandonada';end if;return r.result;end if;
 if now()-r.started_at>interval '10 minutes' then raise exception 'La carrera ha caducado';end if;
 if ticks is null or ticks not between 1 and 3600 or inputs is null or cardinality(inputs)>900 or array_ndims(inputs)>1 or array_position(inputs,null) is not null or (cardinality(inputs)>0 and array_lower(inputs,1)<>1) then raise exception 'Carrera no válida';end if;
 if extract(epoch from now()-r.started_at)<ticks/60.0-1 then raise exception 'La carrera ha llegado demasiado pronto. Reintenta guardar';end if;
 foreach entry in array inputs loop
  event_tick:=entry/10;a:=entry%10;
  if event_tick<1 or event_tick>ticks or event_tick-prev<4 or a not between 1 and 4 then raise exception 'Controles no válidos';end if;prev:=event_tick;
 end loop;
 seed:=r.seed;n:=cardinality(inputs);
 for t in 1..ticks loop
  jump:=greatest(0,jump-1);duck:=greatest(0,duck-1);a:=0;
  if cursor_pos<=n and inputs[cursor_pos]/10=t then a:=inputs[cursor_pos]%10;cursor_pos:=cursor_pos+1;end if;
  if a=1 then lane:=greatest(0,lane-1);elsif a=2 then lane:=least(2,lane+1);elsif a=3 and jump=0 and duck=0 then jump:=42;elsif a=4 and jump=0 and duck=0 then duck:=42;end if;
  if (t-1)%90=0 then
   seed:=seed*48271%2147483647;lanes:=array_append(lanes,(seed%3)::int);
   seed:=seed*48271%2147483647;kinds:=array_append(kinds,1+(seed%3)::int);
   seed:=seed*48271%2147483647;coin_lanes:=array_append(coin_lanes,(seed%3)::int);progress:=array_append(progress,0);
  end if;
  speed:=55+least(35,(t/600)*7);
  for i in 1..cardinality(progress) loop
   if progress[i]<10000 then
    progress[i]:=progress[i]+speed;
    if progress[i]>=10000 then
     if lane=lanes[i] and not(kinds[i]=1 and jump>0) and not(kinds[i]=2 and duck>0) then dead:=true;end if;
     if not dead and lane=coin_lanes[i] then tokens:=tokens+1;end if;
    end if;
   end if;
  end loop;
  if t=3600 then dead:=true;end if;
  if dead and t<ticks then raise exception 'La carrera continúa después de una colisión';end if;
 end loop;
 if not dead then raise exception 'Termina la carrera antes de guardarla';end if;
 points:=ticks/6+tokens*20;
 select greatest(points,coalesce(max((result->>'score')::int),0)) into best from public.wedding_runner_runs where user_id=auth.uid() and completed;
 award:=jsonb_build_object('score',points,'coins',least(60,tokens*2+ticks/600),'xp',least(90,ticks/60+tokens),'best',best,'tokens',tokens);
 update public.wedding_runner_runs set completed=true,result=award where id=r.id;
 update public.wedding_pets set coins=coins+(award->>'coins')::int,xp=xp+(award->>'xp')::int,happiness=least(100,happiness+least(15,tokens)),care_count=care_count+case when (award->>'xp')::int>0 then 1 else 0 end where user_id=auth.uid();
 return award;
end $$;

create function wedding_private.runner_records() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entra para ver la clasificación';end if;
 return jsonb_build_object('best',(select coalesce(max((result->>'score')::int),0) from public.wedding_runner_runs where user_id=auth.uid() and completed),'ranking',coalesce((select jsonb_agg(to_jsonb(x)) from (select p.alias,max((r.result->>'score')::int) as score from public.wedding_runner_runs r join public.wedding_profiles p on p.id=r.user_id join public.wedding_pets pet on pet.user_id=p.id where r.completed and r.result ? 'score' and p.leaderboard_visible and not pet.hidden group by p.id,p.alias having max((r.result->>'score')::int)>0 order by score desc,p.alias limit 20) x),'[]'::jsonb));
end $$;
create function public.wedding_runner_start() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.runner_start()$$;
create function public.wedding_runner_finish(run_id uuid,inputs integer[],ticks integer) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.runner_finish(run_id,inputs,ticks)$$;
create function public.wedding_runner_records() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.runner_records()$$;
revoke all on function wedding_private.runner_start(),wedding_private.runner_finish(uuid,integer[],integer),wedding_private.runner_records(),public.wedding_runner_start(),public.wedding_runner_finish(uuid,integer[],integer),public.wedding_runner_records() from public,anon;
grant execute on function wedding_private.runner_start(),wedding_private.runner_finish(uuid,integer[],integer),wedding_private.runner_records(),public.wedding_runner_start(),public.wedding_runner_finish(uuid,integer[],integer),public.wedding_runner_records() to authenticated;
