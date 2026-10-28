-- Huellas Sprint: per-user records, deterministic replay and bounded rewards.
create table public.wedding_sprint_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.wedding_profiles(id) on delete cascade,seed integer not null,started_at timestamptz not null default now(),completed boolean not null default false,result jsonb);
create index sprint_user_started on public.wedding_sprint_runs(user_id,started_at desc);
alter table public.wedding_sprint_runs enable row level security;
revoke all on public.wedding_sprint_runs from anon,authenticated;
grant select on public.wedding_sprint_runs to authenticated;
create policy sprint_own on public.wedding_sprint_runs for select to authenticated using(user_id=(select auth.uid()));

create function wedding_private.sprint_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb;r public.wedding_sprint_runs;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Entra y completa tu perfil para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if (select count(*) from public.wedding_sprint_runs where user_id=auth.uid() and started_at>now()-interval '1 hour')>=40 then raise exception 'Descansa un ratito. Hay un máximo de 40 carreras por hora';end if;
 p:=wedding_private.pet_action('visit');
 if (p->>'sleeping')::boolean then raise exception 'Despierta a tu perrito antes de jugar';end if;
 if (p->>'energy')::int<3 or (p->>'hunger')::int<2 then raise exception 'Necesita comer o descansar antes de jugar';end if;
 if now()-(p->>'last_action_at')::timestamptz<interval '4 seconds' then raise exception 'Espera unos segundos antes de jugar';end if;
 update public.wedding_sprint_runs set completed=true,result='{"abandoned":true}' where user_id=auth.uid() and not completed;
 insert into public.wedding_sprint_runs(user_id,seed) values(auth.uid(),1+floor(random()*2147483645)::int) returning * into r;
 update public.wedding_pets set hunger=(p->>'hunger')::int-2,energy=(p->>'energy')::int-3,hygiene=greatest(0,(p->>'hygiene')::int-1),happiness=(p->>'happiness')::int,updated_at=now(),last_action_at=now() where user_id=auth.uid();
 return jsonb_build_object('id',r.id,'seed',r.seed);
end $$;

-- inputs are jump ticks, replayed at 60 Hz with the same integer physics as src/lib/sprint.ts.
create function wedding_private.sprint_finish(run_id uuid,inputs integer[],ticks integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.wedding_sprint_runs;seed bigint;t integer;i integer;y integer:=0;velocity integer:=0;next_spawn integer:=60;cleared integer:=0;points integer;dead boolean:=false;speed integer;xs integer[]:='{}';widths integer[]:='{}';heights integer[]:='{}';passed boolean[]:='{}';kind integer;entry integer;prev integer:=-10;cursor_pos integer:=1;n integer;award jsonb;best integer;
begin
 if auth.uid() is null then raise exception 'Entra para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into r from public.wedding_sprint_runs where id=run_id and user_id=auth.uid() for update;
 if not found then raise exception 'Carrera no disponible';end if;
 if r.completed then if r.result ? 'abandoned' then raise exception 'La carrera fue abandonada';end if;return r.result;end if;
 if now()-r.started_at>interval '10 minutes' then raise exception 'La carrera ha caducado';end if;
 if ticks is null or ticks not between 1 and 3600 or inputs is null or cardinality(inputs)>900 or array_ndims(inputs)>1 or array_position(inputs,null) is not null or (cardinality(inputs)>0 and array_lower(inputs,1)<>1) then raise exception 'Carrera no válida';end if;
 if extract(epoch from now()-r.started_at)<ticks/60.0-1 then raise exception 'La carrera ha llegado demasiado pronto. Reintenta guardar';end if;
 foreach entry in array inputs loop
  if entry<1 or entry>ticks or entry-prev<4 then raise exception 'Controles no válidos';end if;prev:=entry;
 end loop;
 seed:=r.seed;n:=cardinality(inputs);
 for t in 1..ticks loop
  if cursor_pos<=n and inputs[cursor_pos]=t then
   if y=0 then velocity:=140;end if;
   cursor_pos:=cursor_pos+1;
  end if;
  y:=greatest(0,y+velocity);velocity:=case when y>0 then velocity-7 else 0 end;
  if t=next_spawn then
   seed:=seed*48271%2147483647;kind:=seed%3;
   xs:=array_append(xs,6500);widths:=array_append(widths,case when kind=2 then 640 else 380 end);heights:=array_append(heights,case when kind=1 then 650 else 450 end);passed:=array_append(passed,false);
   seed:=seed*48271%2147483647;next_spawn:=t+85+(seed%46)::int;
  end if;
  speed:=50+least(35,(t/600)*7);
  for i in 1..cardinality(xs) loop
   xs[i]:=xs[i]-speed;
   if xs[i]<1340 and xs[i]+widths[i]>900 and y+70<heights[i] then dead:=true;end if;
   if not dead and not passed[i] and xs[i]+widths[i]<=900 then passed[i]:=true;cleared:=cleared+1;end if;
  end loop;
  if t=3600 then dead:=true;end if;
  if dead and t<ticks then raise exception 'La carrera continúa después de una colisión';end if;
 end loop;
 if not dead then raise exception 'Termina la carrera antes de guardarla';end if;
 points:=ticks/6+cleared*10;
 select greatest(points,coalesce(max((result->>'score')::int),0)) into best from public.wedding_sprint_runs where user_id=auth.uid() and completed;
 award:=jsonb_build_object('score',points,'coins',least(60,cleared*2+ticks/600),'xp',least(90,ticks/60+cleared),'best',best,'cleared',cleared);
 update public.wedding_sprint_runs set completed=true,result=award where id=r.id;
 update public.wedding_pets set coins=coins+(award->>'coins')::int,xp=xp+(award->>'xp')::int,happiness=least(100,happiness+least(15,cleared)),care_count=care_count+case when (award->>'xp')::int>0 then 1 else 0 end where user_id=auth.uid();
 return award;
end $$;

create function wedding_private.sprint_records() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entra para ver la clasificación';end if;
 return jsonb_build_object('best',(select coalesce(max((result->>'score')::int),0) from public.wedding_sprint_runs where user_id=auth.uid() and completed),'ranking',coalesce((select jsonb_agg(to_jsonb(x)) from (select p.alias,max((r.result->>'score')::int) as score from public.wedding_sprint_runs r join public.wedding_profiles p on p.id=r.user_id join public.wedding_pets pet on pet.user_id=p.id where r.completed and r.result ? 'score' and p.leaderboard_visible and not pet.hidden group by p.id,p.alias having max((r.result->>'score')::int)>0 order by score desc,p.alias limit 20) x),'[]'::jsonb));
end $$;
create function public.wedding_sprint_start() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.sprint_start()$$;
create function public.wedding_sprint_finish(run_id uuid,inputs integer[],ticks integer) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.sprint_finish(run_id,inputs,ticks)$$;
create function public.wedding_sprint_records() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.sprint_records()$$;
revoke all on function wedding_private.sprint_start(),wedding_private.sprint_finish(uuid,integer[],integer),wedding_private.sprint_records(),public.wedding_sprint_start(),public.wedding_sprint_finish(uuid,integer[],integer),public.wedding_sprint_records() from public,anon;
grant execute on function wedding_private.sprint_start(),wedding_private.sprint_finish(uuid,integer[],integer),wedding_private.sprint_records(),public.wedding_sprint_start(),public.wedding_sprint_finish(uuid,integer[],integer),public.wedding_sprint_records() to authenticated;
