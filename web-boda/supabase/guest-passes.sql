-- Guests are reserved by the couple before they can create an account.
create table public.wedding_guest_passes (
 id uuid primary key default gen_random_uuid(),
 email text not null unique check(email=lower(trim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' and length(email)<=254),
 display_name text not null check(length(display_name) between 2 and 100),
 personal_message text not null default '' check(length(personal_message)<=1200),
 max_guests integer not null default 1 check(max_guests between 1 and 10),
 token_hash text not null unique,
 expires_at timestamptz not null default now()+interval '90 days',
 revoked boolean not null default false,
 claimed_by uuid references auth.users(id) on delete set null,
 claimed_at timestamptz,
 sent_at timestamptz,
 delivery_error text,
 last_attempt_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.wedding_guest_passes enable row level security;
revoke all on public.wedding_guest_passes from anon,authenticated;
grant select(id,email,display_name,personal_message,max_guests,expires_at,revoked,claimed_by,claimed_at,sent_at,delivery_error,created_at) on public.wedding_guest_passes to authenticated;
create policy guest_passes_admin_read on public.wedding_guest_passes for select to authenticated using(wedding_private.is_admin());
create index guest_passes_claimed on public.wedding_guest_passes(claimed_by);

create function wedding_private.manage_guest_pass(operation text,pass_id uuid default null,guest_email text default '',guest_name text default '',guest_message text default '',guest_limit integer default 1) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.wedding_guest_passes;t text;
begin
 if auth.uid() is null or not wedding_private.is_admin() then raise exception 'Solo los novios pueden gestionar invitaciones';end if;
 if operation='create' then
  t:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  insert into public.wedding_guest_passes(email,display_name,personal_message,max_guests,token_hash)
  values(lower(trim(guest_email)),trim(guest_name),trim(guest_message),guest_limit,encode(sha256(convert_to(t,'UTF8')),'hex')) returning * into p;
 elsif operation in ('renew','revoke') then
  select * into p from public.wedding_guest_passes where id=pass_id for update;
  if not found then raise exception 'Invitación no encontrada';end if;
  if p.claimed_by is not null then raise exception 'Esta invitación ya está activada. Gestiona su cupo en Invitados';end if;
  if operation='renew' then
   t:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
   update public.wedding_guest_passes set token_hash=encode(sha256(convert_to(t,'UTF8')),'hex'),expires_at=now()+interval '90 days',revoked=false,delivery_error=null,sent_at=null where id=p.id returning * into p;
  else update public.wedding_guest_passes set revoked=true where id=p.id;end if;
 else raise exception 'Operación no válida';end if;
 return jsonb_build_object('id',p.id,'token',t,'display_name',p.display_name,'email',p.email);
end $$;
create function public.wedding_manage_guest_pass(operation text,pass_id uuid default null,guest_email text default '',guest_name text default '',guest_message text default '',guest_limit integer default 1) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.manage_guest_pass(operation,pass_id,guest_email,guest_name,guest_message,guest_limit)$$;

create function wedding_private.guest_postcard(invite_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.wedding_guest_passes;
begin
 if invite_token is null or invite_token !~ '^[a-f0-9]{64}$' then return null;end if;
 select * into p from public.wedding_guest_passes where token_hash=encode(sha256(convert_to(invite_token,'UTF8')),'hex') and not revoked and expires_at>now();
 if not found or (p.claimed_by is not null and p.claimed_by is distinct from auth.uid()) then return null;end if;
 return jsonb_build_object('display_name',p.display_name,'personal_message',p.personal_message,'max_guests',p.max_guests,'claimed',p.claimed_by is not null);
end $$;
create function public.wedding_guest_postcard(invite_token text) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.guest_postcard(invite_token)$$;

create function wedding_private.claim_guest_pass(invite_token text,guest_name text,guest_alias text,guest_phone text,accept_data boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare p public.wedding_guest_passes;mail text;
begin
 if auth.uid() is null or accept_data is distinct from true then raise exception 'Inicia sesión y acepta el uso de tus datos';end if;
 select lower(email) into mail from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if mail is null then raise exception 'Confirma tu correo antes de activar la invitación';end if;
 select * into p from public.wedding_guest_passes where token_hash=encode(sha256(convert_to(invite_token,'UTF8')),'hex') for update;
 if not found or p.email<>mail or p.revoked or p.expires_at<=now() then raise exception 'El enlace no es válido para esta cuenta. Usa el correo al que te invitaron';end if;
 if p.claimed_by is not null then
  if p.claimed_by=auth.uid() then return true;end if;
  raise exception 'La invitación ya está activada';
 end if;
 insert into public.wedding_profiles(id,full_name,alias,phone,consent_at)
 values(auth.uid(),trim(guest_name),trim(guest_alias),trim(guest_phone),now())
 on conflict(id) do update set full_name=excluded.full_name,alias=excluded.alias,phone=excluded.phone;
 insert into public.wedding_invitations(user_id,approved,max_guests) values(auth.uid(),true,p.max_guests)
 on conflict(user_id) do update set approved=true,max_guests=excluded.max_guests;
 update public.wedding_guest_passes set claimed_by=auth.uid(),claimed_at=now() where id=p.id;
 return true;
end $$;
create function public.wedding_claim_guest_pass(invite_token text,guest_name text,guest_alias text,guest_phone text,accept_data boolean) returns boolean language sql security invoker set search_path='' as $$select wedding_private.claim_guest_pass(invite_token,guest_name,guest_alias,guest_phone,accept_data)$$;

-- A supplied token is checked against the protected invitation, never trusted as a role claim.
create function wedding_private.require_invited_signup() returns trigger language plpgsql security definer set search_path='' as $$
declare t text:=new.raw_user_meta_data->>'wedding_invite_token';
begin
 if exists(select 1 from wedding_private.admin_emails where email=lower(new.email)) then return new;end if;
 if t is null or t !~ '^[a-f0-9]{64}$' or not exists(
  select 1 from public.wedding_guest_passes where email=lower(new.email) and token_hash=encode(sha256(convert_to(t,'UTF8')),'hex') and not revoked and claimed_by is null and expires_at>now()
 ) then raise exception 'Necesitas una invitación personal de Laura y Javier para crear tu cuenta';end if;
 return new;
end $$;
create trigger wedding_invited_signup before insert on auth.users for each row execute function wedding_private.require_invited_signup();
revoke all on function wedding_private.require_invited_signup() from public,anon,authenticated;

create function wedding_private.prepare_invite_delivery(pass_id uuid,invite_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.wedding_guest_passes;
begin
 if auth.uid() is null or not wedding_private.is_admin() then raise exception 'Solo los novios pueden enviar invitaciones';end if;
 select * into p from public.wedding_guest_passes where id=pass_id for update;
 if not found or invite_token is null or invite_token !~ '^[a-f0-9]{64}$' or p.token_hash<>encode(sha256(convert_to(invite_token,'UTF8')),'hex') or p.revoked or p.expires_at<=now() or p.claimed_by is not null then raise exception 'Genera un enlace válido antes de enviar';end if;
 if p.last_attempt_at>now()-interval '1 minute' then raise exception 'Espera un minuto antes de reenviar';end if;
 update public.wedding_guest_passes set last_attempt_at=now() where id=p.id;
 return jsonb_build_object('email',p.email,'display_name',p.display_name,'personal_message',p.personal_message);
end $$;
create function public.wedding_prepare_invite_delivery(pass_id uuid,invite_token text) returns jsonb language sql security invoker set search_path='' as $$select wedding_private.prepare_invite_delivery(pass_id,invite_token)$$;

revoke all on function wedding_private.manage_guest_pass(text,uuid,text,text,text,integer),public.wedding_manage_guest_pass(text,uuid,text,text,text,integer),wedding_private.claim_guest_pass(text,text,text,text,boolean),public.wedding_claim_guest_pass(text,text,text,text,boolean),wedding_private.prepare_invite_delivery(uuid,text),public.wedding_prepare_invite_delivery(uuid,text) from public,anon;
grant execute on function wedding_private.manage_guest_pass(text,uuid,text,text,text,integer),public.wedding_manage_guest_pass(text,uuid,text,text,text,integer),wedding_private.claim_guest_pass(text,text,text,text,boolean),public.wedding_claim_guest_pass(text,text,text,text,boolean),wedding_private.prepare_invite_delivery(uuid,text),public.wedding_prepare_invite_delivery(uuid,text) to authenticated;
grant usage on schema wedding_private to anon;
revoke all on function wedding_private.guest_postcard(text),public.wedding_guest_postcard(text) from public;
grant execute on function wedding_private.guest_postcard(text),public.wedding_guest_postcard(text) to anon,authenticated;
