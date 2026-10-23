begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000001','qa-guest-a@example.invalid',now()),('10000000-0000-4000-8000-000000000002','qa-guest-b@example.invalid',now()),('10000000-0000-4000-8000-000000000003','qa-admin@example.invalid',now());
insert into public.wedding_profiles(id,full_name,alias,leaderboard_visible) values('10000000-0000-4000-8000-000000000001','Invitado prueba A','Prueba A',true),('10000000-0000-4000-8000-000000000002','Invitado prueba B','Prueba B',false),('10000000-0000-4000-8000-000000000003','Admin prueba','Admin prueba',false);
insert into wedding_private.admin_emails values('qa-admin@example.invalid');
insert into public.wedding_invitations(user_id,approved,max_guests) values('10000000-0000-4000-8000-000000000001',true,2);
insert into public.wedding_game_runs(id,user_id,started_at) values('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',now()-interval '1 minute'),('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',now()-interval '1 minute');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.wedding_profiles)<>1 then raise exception 'FAIL profile isolation';end if;
 if public.wedding_is_admin() then raise exception 'FAIL admin escalation';end if;
 if (select count(*) from public.wedding_guest_contacts())<>0 then raise exception 'FAIL contacts leak';end if;
 begin insert into public.wedding_profiles(id,full_name,alias) values('10000000-0000-4000-8000-000000000002','Attack','Attack');raise exception 'FAIL cross-user insert';exception when insufficient_privilege then null;end;
 begin insert into public.wedding_rsvps(user_id,attending,guests) values('10000000-0000-4000-8000-000000000001',true,3);raise exception 'FAIL guest cap';exception when insufficient_privilege then null;end;
 insert into public.wedding_rsvps(user_id,attending,guests) values('10000000-0000-4000-8000-000000000001',true,2);
 update public.wedding_rsvps set guests=1 where user_id='10000000-0000-4000-8000-000000000001';
 begin insert into public.wedding_game_runs(user_id,score) values('10000000-0000-4000-8000-000000000001',99999);raise exception 'FAIL forged score';exception when insufficient_privilege then null;end;
 if public.wedding_finish_game('20000000-0000-4000-8000-000000000001','UUUURURRRRRDDDDRUUUU')<>1600 then raise exception 'FAIL score';end if;
 begin perform public.wedding_finish_game('20000000-0000-4000-8000-000000000001','UUUURURRRRRDDDDRUUUU');raise exception 'FAIL replay';exception when raise_exception then if sqlerrm='FAIL replay' then raise;end if;end;
 begin perform public.wedding_finish_game('20000000-0000-4000-8000-000000000002','UUUUURRRRRRR');raise exception 'FAIL missing rings';exception when raise_exception then if sqlerrm='FAIL missing rings' then raise;end if;end;
 if (select count(*) from public.wedding_leaderboard())<>1 then raise exception 'FAIL leaderboard';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.wedding_rsvps)<>0 then raise exception 'FAIL rsvp leak';end if;
 if (select count(*) from public.wedding_game_runs)<>0 then raise exception 'FAIL games leak';end if;
 begin insert into public.wedding_rsvps(user_id,attending,guests) values('10000000-0000-4000-8000-000000000002',true,1);raise exception 'FAIL unapproved invitation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
do $$ begin
 if not public.wedding_is_admin() then raise exception 'FAIL admin role';end if;
 if (select count(*) from public.wedding_profiles)<3 then raise exception 'FAIL admin profiles';end if;
 if (select count(*) from public.wedding_guest_contacts())<3 then raise exception 'FAIL admin contacts';end if;
 update public.wedding_game_runs set hidden=true where id='20000000-0000-4000-8000-000000000001';
 if exists(select 1 from public.wedding_leaderboard() where alias='Prueba A') then raise exception 'FAIL moderation';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 if (select count(*) from public.wedding_settings)<>1 then raise exception 'FAIL public settings';end if;
 begin perform * from public.wedding_profiles;raise exception 'FAIL anon profiles';exception when insufficient_privilege then null;end;
 begin perform public.wedding_start_game();raise exception 'FAIL anonymous game write';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: profile isolation, admin authorization, RSVP caps, score replay validation, leaderboard privacy, moderation, anonymous restrictions. All fixtures rolled back.' as result;
