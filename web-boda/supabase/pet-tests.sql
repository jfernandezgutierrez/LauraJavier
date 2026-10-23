begin;
insert into auth.users(id,email,email_confirmed_at) values('30000000-0000-4000-8000-000000000001','qa-pet@example.invalid',now());
insert into public.wedding_profiles(id,full_name,alias,leaderboard_visible) values('30000000-0000-4000-8000-000000000001','Prueba mascota','Mascota QA',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare p jsonb;begin
 p:=public.wedding_pet_action('visit');if (p->>'coins')::integer<>60 then raise exception 'FAIL initial state';end if;
 p:=public.wedding_pet_action('feed');if (p->>'coins')::integer<>54 or (p->>'hunger')::integer<>90 or (p->>'xp')::integer<>8 then raise exception 'FAIL feed';end if;
 begin perform public.wedding_pet_action('play');raise exception 'FAIL cooldown';exception when raise_exception then if sqlerrm='FAIL cooldown' then raise;end if;end;
 begin update public.wedding_pets set coins=99999 where user_id=auth.uid();raise exception 'FAIL forged coins';exception when insufficient_privilege then null;end;
 if not exists(select 1 from public.wedding_pet_leaderboard() where alias='Mascota QA' and xp=8) then raise exception 'FAIL leaderboard';end if;
end $$;
reset role;
update public.wedding_pets set sleeping=true,energy=20,updated_at=now()-interval '10 minutes',last_action_at=now()-interval '10 minutes' where user_id='30000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ declare a jsonb;b jsonb;begin
 a:=public.wedding_pet_action('visit');b:=public.wedding_pet_action('visit');
 if (a->>'energy')::integer<>40 or (b->>'energy')::integer<>40 then raise exception 'FAIL duplicate sleep recovery';end if;
 begin perform public.wedding_pet_action('play');raise exception 'FAIL sleeping play';exception when raise_exception then if sqlerrm='FAIL sleeping play' then raise;end if;end;
 a:=public.wedding_pet_action('wake');if (a->>'sleeping')::boolean then raise exception 'FAIL wake';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.wedding_pets) then raise exception 'FAIL pet privacy';end if;
 begin perform public.wedding_pet_action('visit');raise exception 'FAIL no profile';exception when raise_exception then if sqlerrm='FAIL no profile' then raise;end if;end;
end $$;
reset role;
rollback;
select 'PASS: pet costs, XP, cooldown, coin forgery denied, sleep/wake, repeat-poll recovery, leaderboard and private state. No fixtures retained.' as result;
