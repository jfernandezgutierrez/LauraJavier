begin;
insert into wedding_private.admin_emails(email) values('qa-profile-update@example.invalid');
insert into auth.users(id,email,email_confirmed_at) values('73000000-0000-4000-8000-000000000001','qa-profile-update@example.invalid',now());
update wedding_private.admin_emails set email='unused-qa-profile-update@example.invalid' where email='qa-profile-update@example.invalid';
insert into public.wedding_profiles(id,full_name,alias) values('73000000-0000-4000-8000-000000000001','Prueba perfil','QA perfil');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$ declare rows_updated integer;begin
 if public.wedding_is_admin() then raise exception 'FAIL fixture must be a guest';end if;
 begin
  update public.wedding_profiles set id=auth.uid(),full_name='Nombre nuevo' where id=auth.uid();
  raise exception 'FAIL protected column update';
 exception when insufficient_privilege then null;end;
 update public.wedding_profiles set full_name='Nombre nuevo',alias='Alias nuevo',phone='',email_updates=false,in_app_updates=true,leaderboard_visible=false where id=auth.uid();
 get diagnostics rows_updated=row_count;
 if rows_updated<>1 or not exists(select 1 from public.wedding_profiles where id=auth.uid() and alias='Alias nuevo') then raise exception 'FAIL own profile update';end if;
 if public.wedding_is_admin() then raise exception 'FAIL profile must not grant admin';end if;
end $$;
reset role;
rollback;
select 'PASS: old payload with id denied; editable fields saved by a guest without admin rights. Fixtures rolled back.' as result;
