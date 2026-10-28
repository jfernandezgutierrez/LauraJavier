begin;
insert into wedding_private.admin_emails(email) values('qa-sprint-a@example.invalid'),('qa-sprint-b@example.invalid');
insert into auth.users(id,email,email_confirmed_at) values('71000000-0000-4000-8000-000000000001','qa-sprint-a@example.invalid',now()),('71000000-0000-4000-8000-000000000002','qa-sprint-b@example.invalid',now());
update wedding_private.admin_emails set email='unused-'||email where email in('qa-sprint-a@example.invalid','qa-sprint-b@example.invalid');
insert into public.wedding_profiles(id,full_name,alias) values('71000000-0000-4000-8000-000000000001','Prueba','QA A'),('71000000-0000-4000-8000-000000000002','Prueba','QA B');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare r jsonb;p jsonb;begin
 r:=public.wedding_sprint_start();perform set_config('test.run',r->>'id',true);
 p:=public.wedding_pet_action('visit');
 if (p->>'energy')::int<>72 or (p->>'hunger')::int<>63 then raise exception 'FAIL start cost';end if;
 begin perform public.wedding_sprint_finish((r->>'id')::uuid,array[]::int[],3600);raise exception 'FAIL early';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin insert into public.wedding_sprint_runs(user_id,seed) values(auth.uid(),1);raise exception 'FAIL direct write';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.wedding_sprint_runs set seed=123456,started_at=now()-interval '70 seconds' where id=current_setting('test.run')::uuid;
set local role authenticated;
do $$ declare a jsonb;b jsonb;p jsonb;begin
 begin perform public.wedding_sprint_finish(current_setting('test.run')::uuid,array[13,14],3600);raise exception 'FAIL duplicate';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_sprint_finish(current_setting('test.run')::uuid,array[]::int[],3600);raise exception 'FAIL post collision';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_sprint_finish(current_setting('test.run')::uuid,array[]::int[],10);raise exception 'FAIL incomplete';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 a:=public.wedding_sprint_finish(current_setting('test.run')::uuid,array[154,268,355,484,589,704,790,880,984,1092,1190,1283,1402,1500,1608,1732,1815,1904,2014,2142,2234,2320,2427,2547,2646,2755,2861,2974,3070,3172,3269,3397,3507],3600);
 b:=public.wedding_sprint_finish(current_setting('test.run')::uuid,array[]::int[],1);
 p:=public.wedding_pet_action('visit');
 if (a->>'score')::int<>930 or (a->>'coins')::int<>60 or (a->>'xp')::int<>90 or (a->>'cleared')::int<>33 or a<>b or (p->>'coins')::int<>120 or (p->>'xp')::int<>90 then raise exception 'FAIL parity/rewards/idempotence: % pet %',a,p;end if;
 if (public.wedding_sprint_records()->>'best')::int<>930 or jsonb_array_length(public.wedding_sprint_records()->'ranking')<>0 then raise exception 'FAIL records/privacy';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.wedding_sprint_runs) then raise exception 'FAIL row privacy';end if;
 begin perform public.wedding_sprint_finish(current_setting('test.run')::uuid,array[]::int[],1);raise exception 'FAIL foreign run';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.wedding_sprint_start();raise exception 'FAIL anon';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: full JS/SQL replay parity, start cost, rewards, caps, idempotence, invalid replay rejection, records, row privacy and anonymous denial. Fixtures rolled back.' as result;
