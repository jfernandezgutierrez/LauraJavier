begin;
insert into auth.users(id,email,email_confirmed_at) values('40000000-0000-4000-8000-000000000001','qa-arcade@example.invalid',now());
insert into public.wedding_profiles(id,full_name,alias) values('40000000-0000-4000-8000-000000000001','Prueba arcade','Arcade QA');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare c jsonb;begin
 c:=public.wedding_arcade_start('catch');
 if jsonb_array_length(c->'board')<>12 then raise exception 'FAIL board';end if;
 begin perform public.wedding_arcade_finish((c->>'id')::uuid,array[0,0,0,0,0,0,0,0,0,0,0,0]);raise exception 'FAIL early';exception when raise_exception then if sqlerrm='FAIL early' then raise;end if;end;
 begin update public.wedding_arcade_runs set completed=true;raise exception 'FAIL direct write';exception when insufficient_privilege then null;end;
 begin perform public.wedding_pet_action('play');raise exception 'FAIL free points';exception when raise_exception then if sqlerrm='FAIL free points' then raise;end if;end;
end $$;
reset role;
update public.wedding_arcade_runs set started_at=now()-interval '30 seconds' where user_id='40000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ declare r public.wedding_arcade_runs;v jsonb;again jsonb;p jsonb;begin
 select * into r from public.wedding_arcade_runs where user_id=auth.uid();
 begin perform public.wedding_arcade_finish(r.id,array[9,9,9,9,9,9,9,9,9,9,9,9]);raise exception 'FAIL forged lanes';exception when raise_exception then if sqlerrm='FAIL forged lanes' then raise;end if;end;
 v:=public.wedding_arcade_finish(r.id,r.board);again:=public.wedding_arcade_finish(r.id,r.board);
 p:=public.wedding_pet_action('visit');
 if v<>again or (v->>'coins')::int<>24 or (p->>'coins')::int<>84 or (p->>'xp')::int<>36 then raise exception 'FAIL rewards/idempotency';end if;
end $$;
reset role;
update public.wedding_pets set last_action_at=now()-interval '5 seconds' where user_id='40000000-0000-4000-8000-000000000001';
set local role authenticated;
select public.wedding_arcade_start('memory');
reset role;
update public.wedding_arcade_runs set started_at=now()-interval '30 seconds' where user_id='40000000-0000-4000-8000-000000000001' and kind='memory';
set local role authenticated;
do $$ declare r public.wedding_arcade_runs;v jsonb;steps integer[];begin
 select * into r from public.wedding_arcade_runs where user_id=auth.uid() and kind='memory';
 begin perform public.wedding_arcade_finish(r.id,array[0,0]);raise exception 'FAIL duplicate card';exception when raise_exception then if sqlerrm='FAIL duplicate card' then raise;end if;end;
 select array_agg(i-1 order by r.board[i],i) into steps from generate_series(1,12) i;
 v:=public.wedding_arcade_finish(r.id,steps);
 if (v->>'score')::int<>6 or (v->>'xp')::int<>36 then raise exception 'FAIL memory';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.wedding_arcade_runs) then raise exception 'FAIL privacy';end if;
 begin perform public.wedding_arcade_start('catch');raise exception 'FAIL no profile';exception when raise_exception then if sqlerrm='FAIL no profile' then raise;end if;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.wedding_arcade_start('catch');raise exception 'FAIL anonymous';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: authenticated games, rewards, replay safety, invalid moves, private runs and anonymous denial. No fixtures retained.' as result;
