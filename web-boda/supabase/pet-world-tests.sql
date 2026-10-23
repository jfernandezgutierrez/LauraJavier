begin;
insert into wedding_private.admin_emails(email) values('qa-world-a@example.invalid'),('qa-world-b@example.invalid');
insert into auth.users(id,email,email_confirmed_at) values('60000000-0000-4000-8000-000000000001','qa-world-a@example.invalid',now()),('60000000-0000-4000-8000-000000000002','qa-world-b@example.invalid',now());
update wedding_private.admin_emails set email='unused-'||email where email in('qa-world-a@example.invalid','qa-world-b@example.invalid');
insert into public.wedding_profiles(id,full_name,alias) values('60000000-0000-4000-8000-000000000001','Prueba','QA A'),('60000000-0000-4000-8000-000000000002','Prueba','QA B');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare s jsonb;p jsonb;r jsonb;begin
 s:=public.wedding_pet_shop('visit');
 if jsonb_array_length(s->'catalog')<>7 then raise exception 'FAIL catalog';end if;
 begin perform public.wedding_pet_shop('accessory','bandana');raise exception 'FAIL unowned equip';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 s:=public.wedding_pet_shop('buy','bandana');s:=public.wedding_pet_shop('buy','bandana');
 p:=public.wedding_pet_action('visit');
 if (p->>'coins')::int<>35 then raise exception 'FAIL duplicate charge';end if;
 s:=public.wedding_pet_shop('accessory','bandana');
 if s->'style'->>'accessory'<>'bandana' then raise exception 'FAIL equip';end if;
 begin perform public.wedding_pet_shop('buy','hat');raise exception 'FAIL level lock';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_pet_shop('buy','rose');raise exception 'FAIL balance';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin insert into public.wedding_pet_inventory values(auth.uid(),'hat');raise exception 'FAIL inventory write';exception when insufficient_privilege then null;end;
 begin update public.wedding_pets set coins=9999 where user_id=auth.uid();raise exception 'FAIL wallet write';exception when insufficient_privilege then null;end;
 r:=public.wedding_flappy_start();perform set_config('test.run',r->>'id',true);
 begin perform public.wedding_flappy_finish((r->>'id')::uuid,array[]::int[],3600);raise exception 'FAIL early';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
update public.wedding_flappy_runs set seed=123456,started_at=now()-interval '70 seconds' where id=current_setting('test.run')::uuid;
set local role authenticated;
do $$ declare a jsonb;b jsonb;p jsonb;begin
 begin perform public.wedding_flappy_finish(current_setting('test.run')::uuid,array[2,2],41);raise exception 'FAIL duplicate taps';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_flappy_finish(current_setting('test.run')::uuid,array[]::int[],42);raise exception 'FAIL post collision';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_flappy_finish(current_setting('test.run')::uuid,array[]::int[],10);raise exception 'FAIL incomplete';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 a:=public.wedding_flappy_finish(current_setting('test.run')::uuid,array[7,39,61,78,103,134,166,197,229,267,299,330,347,377,409,440,495,526,557,584,616,647,684,716,747,778,810,841,873,890,907,924,941,968,998,1029,1061,1092,1129,1160,1191,1244,1275,1307,1324,1341,1358,1387,1419,1436,1465,1496,1528,1575,1605,1637,1676,1707,1738,1755,1772,1798,1830,1870,1902,1933,1970,2002,2033,2065,2104,2136,2167,2184,2202,2234,2265,2300,2331,2362,2394,2411,2443,2474,2506,2541,2572,2604,2645,2677,2708,2732,2764,2795,2826,2864,2896,2927,2955,2987,3018,3050,3067,3084,3101,3118,3147,3196,3227,3259,3276,3297,3329,3360,3401,3432,3464,3505,3537,3568,3599],3600);
 b:=public.wedding_flappy_finish(current_setting('test.run')::uuid,array[]::int[],41);
 p:=public.wedding_pet_action('visit');
 if (a->>'score')::int<>32 or (a->>'coins')::int<>60 or (a->>'xp')::int<>90 or a<>b or (p->>'coins')::int<>95 or (p->>'xp')::int<>90 then raise exception 'FAIL replay parity/capped rewards/idempotence';end if;
 if jsonb_array_length(public.wedding_flappy_records()->'ranking')<>0 then raise exception 'FAIL ranking opt in';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"60000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.wedding_pet_inventory) or exists(select 1 from public.wedding_flappy_runs) then raise exception 'FAIL row privacy';end if;
 begin perform public.wedding_flappy_finish(current_setting('test.run')::uuid,array[]::int[],41);raise exception 'FAIL foreign run';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
update public.wedding_pets set hunger=0,coins=0,last_action_at=now()-interval '5 seconds' where user_id='60000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.wedding_pet_shop('snack');
reset role;
update public.wedding_pets set hunger=0 where user_id='60000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 begin perform public.wedding_pet_shop('snack');raise exception 'FAIL free snack throttle';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.wedding_flappy_start();raise exception 'FAIL anon start';exception when insufficient_privilege then null;end;
 begin perform public.wedding_pet_shop('visit');raise exception 'FAIL anon shop';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: shop ownership, server prices, level locks, idempotent purchases/rewards, full 3600 tick JS/SQL parity, reward caps, invalid replay rejection, private rows, anonymous denial and free-snack throttle. Fixtures rolled back.' as result;

