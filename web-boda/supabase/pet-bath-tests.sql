begin;
insert into wedding_private.admin_emails(email) values('qa-bath@example.invalid');
insert into auth.users(id,email,email_confirmed_at) values('72000000-0000-4000-8000-000000000001','qa-bath@example.invalid',now());
update wedding_private.admin_emails set email='unused-qa-bath@example.invalid' where email='qa-bath@example.invalid';
insert into public.wedding_profiles(id,full_name,alias) values('72000000-0000-4000-8000-000000000001','Prueba baño','QA baño');
insert into public.wedding_pets(user_id,hygiene) values('72000000-0000-4000-8000-000000000001',0);
select set_config('request.jwt.claims','{"sub":"72000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$ declare p jsonb;v jsonb;begin
 p:=public.wedding_pet_action('wash');v:=public.wedding_pet_action('visit');
 if (p->>'hygiene')::int<>100 or (v->>'hygiene')::int<>100 or (p->>'xp')::int<>8 or (p->>'care_count')::int<>1 or (p->>'coins')::int<>60 then raise exception 'FAIL dirty bath: %',p;end if;
 begin perform public.wedding_pet_action('wash');raise exception 'FAIL cooldown';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
update public.wedding_pets set last_action_at=now()-interval '5 seconds' where user_id='72000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 begin perform public.wedding_pet_action('wash');raise exception 'FAIL repeated clean bath';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 if (public.wedding_pet_action('visit')->>'xp')::int<>8 then raise exception 'FAIL duplicate XP';end if;
end $$;
reset role;
update public.wedding_pets set hygiene=4,last_action_at=now()-interval '5 seconds' where user_id='72000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 if (public.wedding_pet_action('wash')->>'hygiene')::int<>100 then raise exception 'FAIL near-zero bath';end if;
end $$;
reset role;
update public.wedding_pets set hygiene=39,last_action_at=now()-interval '5 seconds' where user_id='72000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 if (public.wedding_pet_action('wash')->>'hygiene')::int<>100 then raise exception 'FAIL dirty threshold bath';end if;
end $$;
reset role;
update public.wedding_pets set hygiene=0,sleeping=true,last_action_at=now()-interval '5 seconds' where user_id='72000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
 begin perform public.wedding_pet_action('wash');raise exception 'FAIL sleeping bath';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
 begin perform public.wedding_pet_action('play');raise exception 'FAIL legacy play reenabled';exception when raise_exception then if sqlerrm like 'FAIL%' then raise;end if;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.wedding_pet_action('wash');raise exception 'FAIL anonymous bath';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: bath restores and persists 100 hygiene from 0, 4 and 39; XP awarded once; cooldown, clean-pet rejection, sleeping guard and anonymous denial preserved. Fixtures rolled back.' as result;
