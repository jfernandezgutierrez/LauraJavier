-- A bath restores full hygiene, including from zero. Existing RPC permissions are preserved.
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
    p.hygiene:=100;p.happiness:=least(100,p.happiness+3);gain:=8;
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
