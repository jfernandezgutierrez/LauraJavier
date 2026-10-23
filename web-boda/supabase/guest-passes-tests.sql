begin;
insert into wedding_private.admin_emails(email) values('qa-postcard-admin@example.invalid');
insert into auth.users(id,email,email_confirmed_at) values('50000000-0000-4000-8000-000000000001','qa-postcard-admin@example.invalid',now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"50000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare p jsonb;begin
 p:=public.wedding_manage_guest_pass('create',null,'qa-postcard-guest@example.invalid','Familia de prueba','Nos vemos en la boda',3);
 perform set_config('test.pass_id',p->>'id',true);perform set_config('test.invite_token',p->>'token',true);
 if length(p->>'token')<>64 then raise exception 'FAIL token';end if;
end $$;
reset role;
set local role anon;
do $$ declare p jsonb;begin
 p:=public.wedding_guest_postcard(current_setting('test.invite_token'));
 if p->>'display_name'<>'Familia de prueba' or p ? 'email' then raise exception 'FAIL public postcard';end if;
 if public.wedding_guest_postcard('bad') is not null then raise exception 'FAIL invalid token';end if;
 begin perform email from public.wedding_guest_passes;raise exception 'FAIL list exposure';exception when insufficient_privilege then null;end;
 begin perform public.wedding_manage_guest_pass('create');raise exception 'FAIL anon create';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin insert into auth.users(id,email) values('50000000-0000-4000-8000-000000000003','uninvited@example.invalid');raise exception 'FAIL open signup';exception when raise_exception then if sqlerrm='FAIL open signup' then raise;end if;end;
 begin insert into auth.users(id,email,raw_user_meta_data) values('50000000-0000-4000-8000-000000000003','wrong-address@example.invalid',jsonb_build_object('wedding_invite_token',current_setting('test.invite_token')));raise exception 'FAIL email binding';exception when raise_exception then if sqlerrm='FAIL email binding' then raise;end if;end;
end $$;
insert into auth.users(id,email,raw_user_meta_data) values('50000000-0000-4000-8000-000000000002','qa-postcard-guest@example.invalid',jsonb_build_object('wedding_invite_token',current_setting('test.invite_token')));
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"50000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ begin
 begin perform public.wedding_claim_guest_pass(current_setting('test.invite_token'),'Nombre invitado','Mi alias','',true);raise exception 'FAIL unverified';exception when raise_exception then if sqlerrm='FAIL unverified' then raise;end if;end;
 begin perform public.wedding_manage_guest_pass('create');raise exception 'FAIL nonadmin';exception when raise_exception then if sqlerrm='FAIL nonadmin' then raise;end if;end;
 if exists(select id from public.wedding_guest_passes) then raise exception 'FAIL list privacy';end if;
end $$;
reset role;
update auth.users set email_confirmed_at=now() where id='50000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin
 begin perform public.wedding_claim_guest_pass(current_setting('test.invite_token'),'Nombre invitado','Mi alias','',false);raise exception 'FAIL consent';exception when raise_exception then if sqlerrm='FAIL consent' then raise;end if;end;
 perform public.wedding_claim_guest_pass(current_setting('test.invite_token'),'Nombre invitado','Mi alias','',true);
 perform public.wedding_claim_guest_pass(current_setting('test.invite_token'),'Ignored','Ignored','',true);
 if not exists(select 1 from public.wedding_invitations where user_id=auth.uid() and approved and max_guests=3) then raise exception 'FAIL cup';end if;
 if not exists(select 1 from public.wedding_profiles where id=auth.uid() and alias='Mi alias') then raise exception 'FAIL profile/replay';end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"50000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare p jsonb;q jsonb;begin
 p:=public.wedding_manage_guest_pass('create',null,'qa-rotate@example.invalid','Rotación','',1);
 q:=public.wedding_manage_guest_pass('renew',(p->>'id')::uuid);
 if public.wedding_guest_postcard(p->>'token') is not null or public.wedding_guest_postcard(q->>'token') is null then raise exception 'FAIL rotation';end if;
 begin perform public.wedding_prepare_invite_delivery((p->>'id')::uuid,null);raise exception 'FAIL null token send';exception when raise_exception then if sqlerrm='FAIL null token send' then raise;end if;end;
 perform public.wedding_prepare_invite_delivery((p->>'id')::uuid,q->>'token');
 begin perform public.wedding_prepare_invite_delivery((p->>'id')::uuid,q->>'token');raise exception 'FAIL email throttle';exception when raise_exception then if sqlerrm='FAIL email throttle' then raise;end if;end;
 perform public.wedding_manage_guest_pass('revoke',(p->>'id')::uuid);
 if public.wedding_guest_postcard(q->>'token') is not null then raise exception 'FAIL revoke';end if;
end $$;
reset role;
rollback;
select 'PASS: admin creation, private guest data, invitation-only signup, verified email binding, personalization, cup, replay, renewal, revocation and email throttle. No accounts or invitations retained.' as result;
