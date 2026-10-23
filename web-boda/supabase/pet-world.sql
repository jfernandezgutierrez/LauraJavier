-- Additive virtual-pet wardrobe, server-priced shop and deterministic Flappy replay.
create table public.wedding_pet_items(id text primary key,name text not null,kind text not null check(kind in('accessory','theme')),price integer not null check(price>=0),level integer not null check(level>=1));
insert into public.wedding_pet_items values
 ('bandana','Pañuelo terracota','accessory',25,1),('collar','Collar del bosque','accessory',35,1),('bow','Pajarita de fiesta','accessory',60,2),('hat','Sombrero de paseo','accessory',90,3),
 ('rose','Habitación rosa','theme',40,1),('sage','Habitación salvia','theme',40,1),('lavender','Habitación lavanda','theme',70,2);
alter table public.wedding_pet_items enable row level security;
revoke all on public.wedding_pet_items from anon,authenticated;
grant select on public.wedding_pet_items to authenticated;
create policy pet_catalog_read on public.wedding_pet_items for select to authenticated using(true);
create table public.wedding_pet_inventory(user_id uuid references public.wedding_profiles(id) on delete cascade,item_id text references public.wedding_pet_items(id),primary key(user_id,item_id));
create index pet_inventory_item on public.wedding_pet_inventory(item_id);
alter table public.wedding_pet_inventory enable row level security;
revoke all on public.wedding_pet_inventory from anon,authenticated;
grant select on public.wedding_pet_inventory to authenticated;
create policy pet_inventory_own on public.wedding_pet_inventory for select to authenticated using(user_id=(select auth.uid()));
create table public.wedding_pet_style(user_id uuid primary key references public.wedding_profiles(id) on delete cascade,accessory text not null default '',theme text not null default '',snack_at timestamptz not null default '-infinity');
alter table public.wedding_pet_style enable row level security;
revoke all on public.wedding_pet_style from anon,authenticated;
grant select on public.wedding_pet_style to authenticated;
create policy pet_style_own on public.wedding_pet_style for select to authenticated using(user_id=(select auth.uid()));

create function wedding_private.pet_shop(action text,item text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb; product public.wedding_pet_items; st public.wedding_pet_style;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Entra y completa tu perfil';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 p:=wedding_private.pet_action('visit');
 insert into public.wedding_pet_style(user_id) values(auth.uid()) on conflict do nothing;
 select * into st from public.wedding_pet_style where user_id=auth.uid() for update;
 if action='buy' then
  select * into product from public.wedding_pet_items where id=item;
  if not found then raise exception 'Artículo no disponible';end if;
  if not exists(select 1 from public.wedding_pet_inventory where user_id=auth.uid() and item_id=item) then
   if (p->>'xp')::int/100+1<product.level then raise exception 'Sube de nivel para desbloquear este artículo';end if;
   if (p->>'coins')::int<product.price then raise exception 'Te faltan monedas';end if;
   update public.wedding_pets set coins=coins-product.price where user_id=auth.uid();
   insert into public.wedding_pet_inventory values(auth.uid(),item);
  end if;
 elsif action in('accessory','theme') then
  if item<>'' and not exists(select 1 from public.wedding_pet_inventory i join public.wedding_pet_items c on c.id=i.item_id where i.user_id=auth.uid() and i.item_id=item and c.kind=action) then raise exception 'Primero compra este artículo';end if;
  if action='accessory' then update public.wedding_pet_style set accessory=item where user_id=auth.uid();else update public.wedding_pet_style set theme=item where user_id=auth.uid();end if;
 elsif action='snack' then
  if (p->>'sleeping')::boolean then raise exception 'Despierta al perrito para comer';end if;
  if (p->>'hunger')::int>=25 then raise exception 'El cuenco de ayuda aparece cuando tiene mucha hambre';end if;
  if now()-st.snack_at<interval '6 hours' then raise exception 'El cuenco gratuito se repone cada seis horas';end if;
  update public.wedding_pets set hunger=least(100,(p->>'hunger')::int+30),hygiene=(p->>'hygiene')::int,energy=(p->>'energy')::int,happiness=(p->>'happiness')::int,updated_at=now(),last_action_at=now() where user_id=auth.uid();
  update public.wedding_pet_style set snack_at=now() where user_id=auth.uid();
 elsif action<>'visit' or action is null then raise exception 'Acción desconocida';end if;
 return jsonb_build_object('catalog',(select jsonb_agg(to_jsonb(c) order by price,id) from public.wedding_pet_items c),'owned',coalesce((select jsonb_agg(item_id) from public.wedding_pet_inventory where user_id=auth.uid()),'[]'::jsonb),'style',(select to_jsonb(s)-'user_id' from public.wedding_pet_style s where user_id=auth.uid()));
end $$;
create function public.wedding_pet_shop(action text,item text default '') returns jsonb language sql security invoker set search_path='' as $$select wedding_private.pet_shop(action,item)$$;
revoke all on function wedding_private.pet_shop(text,text),public.wedding_pet_shop(text,text) from public,anon;
grant execute on function wedding_private.pet_shop(text,text),public.wedding_pet_shop(text,text) to authenticated;

create table public.wedding_flappy_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.wedding_profiles(id) on delete cascade,seed integer not null,started_at timestamptz not null default now(),completed boolean not null default false,result jsonb);
create index flappy_user_started on public.wedding_flappy_runs(user_id,started_at desc);
alter table public.wedding_flappy_runs enable row level security;
revoke all on public.wedding_flappy_runs from anon,authenticated;
grant select on public.wedding_flappy_runs to authenticated;
create policy flappy_own on public.wedding_flappy_runs for select to authenticated using(user_id=(select auth.uid()));

create function wedding_private.flappy_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb;r public.wedding_flappy_runs;
begin
 if auth.uid() is null or not exists(select 1 from public.wedding_profiles where id=auth.uid()) then raise exception 'Entra y completa tu perfil para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if (select count(*) from public.wedding_flappy_runs where user_id=auth.uid() and started_at>now()-interval '1 hour')>=40 then raise exception 'Descansa un ratito. Hay un máximo de 40 partidas por hora';end if;
 p:=wedding_private.pet_action('visit');
 if (p->>'sleeping')::boolean then raise exception 'Despierta a tu perrito antes de jugar';end if;
 if (p->>'energy')::int<3 or (p->>'hunger')::int<2 then raise exception 'Necesita comer o descansar antes de jugar';end if;
 if now()-(p->>'last_action_at')::timestamptz<interval '4 seconds' then raise exception 'Espera unos segundos antes de jugar';end if;
 update public.wedding_flappy_runs set completed=true,result='{"abandoned":true}' where user_id=auth.uid() and not completed;
 insert into public.wedding_flappy_runs(user_id,seed) values(auth.uid(),1+floor(random()*2147483645)::int) returning * into r;
 update public.wedding_pets set hunger=(p->>'hunger')::int-2,energy=(p->>'energy')::int-3,hygiene=greatest(0,(p->>'hygiene')::int-1),happiness=(p->>'happiness')::int,updated_at=now(),last_action_at=now() where user_id=auth.uid();
 return jsonb_build_object('id',r.id,'seed',r.seed);
end $$;

-- No client score/coins accepted. Replay every tick with integer arithmetic.
create function wedding_private.flappy_finish(run_id uuid,taps integer[],ticks integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.wedding_flappy_runs; t integer; v integer:=0;y integer:=24000;seed bigint;xs integer[]:='{}';centers integer[]:='{}';passed boolean[]:='{}';i integer;speed integer;dead boolean:=false;points integer:=0;prev integer:=0;tap integer;award jsonb;best integer;
begin
 if auth.uid() is null then raise exception 'Entra para jugar';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into r from public.wedding_flappy_runs where id=run_id and user_id=auth.uid() for update;
 if not found then raise exception 'Partida no disponible';end if;
 if r.completed then if r.result ? 'abandoned' then raise exception 'La partida fue abandonada';end if;return r.result;end if;
 if now()-r.started_at>interval '10 minutes' then raise exception 'La partida ha caducado';end if;
 if ticks is null or ticks not between 1 and 3600 or taps is null or cardinality(taps)>600 or array_ndims(taps)>1 or array_position(taps,null) is not null then raise exception 'Partida no válida';end if;
 if extract(epoch from now()-r.started_at)<ticks/60.0-1 then raise exception 'La partida ha llegado demasiado pronto. Reintenta guardar';end if;
 foreach tap in array taps loop
  if tap<1 or tap>ticks or (prev>0 and tap-prev<4) then raise exception 'Pulsaciones no válidas';end if;prev:=tap;
 end loop;
 seed:=r.seed;
 for t in 1..ticks loop
  if t=any(taps) then v:=-520;end if;v:=least(800,v+32);y:=y+v;
  if t>=60 and (t-60)%110=0 then seed:=seed*48271%2147483647;xs:=array_append(xs,40000);centers:=array_append(centers,13000+(seed%21000)::int);passed:=array_append(passed,false);end if;
  speed:=220+least(100,(t/600)*15);
  if cardinality(xs)>0 then for i in 1..cardinality(xs) loop
   xs[i]:=xs[i]-speed;
   if xs[i]<10200 and xs[i]+5200>7400 and (y-1400<centers[i]-7200 or y+1400>centers[i]+7200) then dead:=true;end if;
   if not passed[i] and xs[i]+5200<7400 then passed[i]:=true;points:=points+1;end if;
  end loop;end if;
  if y<1400 or y>46600 or t=3600 then dead:=true;end if;
  if dead and t<ticks then raise exception 'La partida continúa después de una colisión';end if;
 end loop;
 if not dead then raise exception 'Termina la partida antes de guardarla';end if;
 select greatest(points,coalesce(max((result->>'score')::int),0)) into best from public.wedding_flappy_runs where user_id=auth.uid() and completed;
 award:=jsonb_build_object('score',points,'coins',least(30,points)*2,'xp',least(30,points)*3,'best',best);
 update public.wedding_flappy_runs set completed=true,result=award where id=r.id;
 update public.wedding_pets set coins=coins+least(30,points)*2,xp=xp+least(30,points)*3,happiness=least(100,happiness+least(15,points)),care_count=care_count+case when points>0 then 1 else 0 end where user_id=auth.uid();
 return award;
end $$;
create function wedding_private.flappy_records() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entra para ver la clasificación';end if;
 return jsonb_build_object('best',(select coalesce(max((result->>'score')::int),0) from public.wedding_flappy_runs where user_id=auth.uid() and completed),'ranking',coalesce((select jsonb_agg(to_jsonb(x)) from (select p.alias,max((r.result->>'score')::int) as score from public.wedding_flappy_runs r join public.wedding_profiles p on p.id=r.user_id join public.wedding_pets pet on pet.user_id=p.id where r.completed and r.result ? 'score' and p.leaderboard_visible and not pet.hidden group by p.id,p.alias having max((r.result->>'score')::int)>0 order by score desc,p.alias limit 20) x),'[]'::jsonb));
end $$;
create function public.wedding_flappy_start() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.flappy_start()$$;
create function public.wedding_flappy_finish(run_id uuid,taps integer[],ticks integer) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.flappy_finish(run_id,taps,ticks)$$;
create function public.wedding_flappy_records() returns jsonb language sql security invoker set search_path='' as $$select wedding_private.flappy_records()$$;
revoke all on function wedding_private.flappy_start(),wedding_private.flappy_finish(uuid,integer[],integer),wedding_private.flappy_records(),public.wedding_flappy_start(),public.wedding_flappy_finish(uuid,integer[],integer),public.wedding_flappy_records() from public,anon;
grant execute on function wedding_private.flappy_start(),wedding_private.flappy_finish(uuid,integer[],integer),wedding_private.flappy_records(),public.wedding_flappy_start(),public.wedding_flappy_finish(uuid,integer[],integer),public.wedding_flappy_records() to authenticated;
