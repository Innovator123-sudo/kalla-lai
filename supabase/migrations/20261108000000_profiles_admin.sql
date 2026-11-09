-- Kalla-Lai on Supabase: admin-configurable worker / employer (hirer) profiles.
--
-- Apply AFTER every file in server/src/db/migrations/*.sql has been applied
-- (the tables must already exist). `npm run supabase:setup` does both in order.
--
-- Design:
--   * The Express API connects as the table owner (postgres) through
--     SUPABASE_DB_URL, so it bypasses RLS and stays authoritative. These
--     policies are the guardrail for anything calling Supabase directly with
--     the publishable key (anon/authenticated roles).
--   * `is_staff` is SECURITY DEFINER so reading user_roles does not recurse
--     into user_roles' own RLS policies.
--   * Staff can CREATE, EDIT and REMOVE both profile sheets for ANY account.
--     Ordinary users can only touch their own sheet.
--   * Password hashes and identity documents are never granted to client roles.

-- ---------------------------------------------------------------------------
-- 1. Staff predicate
-- ---------------------------------------------------------------------------
create or replace function public.is_staff(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_user is not null and exists (
      select 1 from public.user_roles ur
       where ur.user_id = p_user
         and ur.role in ('MODERATOR', 'BILLING_ADMIN', 'ADMIN')
    ),
    false
  );
$$;

revoke all on function public.is_staff(uuid) from public;
grant execute on function public.is_staff(uuid) to anon, authenticated, service_role, postgres;

-- ---------------------------------------------------------------------------
-- 2. Grants (table grants are evaluated BEFORE RLS)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

-- Never expose password_hash, firebase_uid or identity documents.
revoke all on public.users from anon, authenticated;
grant select (id, email, full_name, phone, status, identity_status,
              onboarding_complete, created_at, updated_at)
  on public.users to authenticated;
grant update (full_name, phone) on public.users to authenticated;

revoke all on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;

revoke all on public.worker_profiles from anon, authenticated;
grant select on public.worker_profiles to anon, authenticated;
grant insert, update, delete on public.worker_profiles to authenticated;

revoke all on public.employer_profiles from anon, authenticated;
grant select on public.employer_profiles to anon, authenticated;
grant insert, update, delete on public.employer_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------------------
alter table public.users            enable row level security;
alter table public.user_roles       enable row level security;
alter table public.worker_profiles  enable row level security;
alter table public.employer_profiles enable row level security;

-- accounts ------------------------------------------------------------------
drop policy if exists users_select_self_or_staff on public.users;
create policy users_select_self_or_staff on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists users_update_self_or_staff on public.users;
create policy users_update_self_or_staff on public.users
  for update to authenticated
  using (id = auth.uid() or public.is_staff(auth.uid()))
  with check (id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists user_roles_select_self_or_staff on public.user_roles;
create policy user_roles_select_self_or_staff on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or public.is_staff(auth.uid()));

-- worker profiles -----------------------------------------------------------
drop policy if exists worker_profiles_public_read on public.worker_profiles;
create policy worker_profiles_public_read on public.worker_profiles
  for select to anon, authenticated
  using (true);

drop policy if exists worker_profiles_insert_self_or_staff on public.worker_profiles;
create policy worker_profiles_insert_self_or_staff on public.worker_profiles
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists worker_profiles_update_self_or_staff on public.worker_profiles;
create policy worker_profiles_update_self_or_staff on public.worker_profiles
  for update to authenticated
  using (user_id = auth.uid() or public.is_staff(auth.uid()))
  with check (user_id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists worker_profiles_delete_self_or_staff on public.worker_profiles;
create policy worker_profiles_delete_self_or_staff on public.worker_profiles
  for delete to authenticated
  using (user_id = auth.uid() or public.is_staff(auth.uid()));

-- employer / hirer profiles -------------------------------------------------
drop policy if exists employer_profiles_public_read on public.employer_profiles;
create policy employer_profiles_public_read on public.employer_profiles
  for select to anon, authenticated
  using (true);

drop policy if exists employer_profiles_insert_self_or_staff on public.employer_profiles;
create policy employer_profiles_insert_self_or_staff on public.employer_profiles
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists employer_profiles_update_self_or_staff on public.employer_profiles;
create policy employer_profiles_update_self_or_staff on public.employer_profiles
  for update to authenticated
  using (user_id = auth.uid() or public.is_staff(auth.uid()))
  with check (user_id = auth.uid() or public.is_staff(auth.uid()));

drop policy if exists employer_profiles_delete_self_or_staff on public.employer_profiles;
create policy employer_profiles_delete_self_or_staff on public.employer_profiles
  for delete to authenticated
  using (user_id = auth.uid() or public.is_staff(auth.uid()));

-- ---------------------------------------------------------------------------
-- 4. Staff RPCs: configure + edit profiles for either side of the marketplace.
--    Called with a Supabase Auth JWT whose user has a staff role. The Express
--    API does not use these; it writes through its own audited transaction.
-- ---------------------------------------------------------------------------
create or replace function public.admin_configure_worker_profile(
  p_user_id uuid,
  p_patch jsonb default '{}'::jsonb
)
returns public.worker_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_status text;
  v_result public.worker_profiles;
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'Only platform staff may configure worker profiles' using errcode = '42501';
  end if;

  select full_name into v_name from public.users where id = p_user_id;
  if v_name is null then
    raise exception 'Account % does not exist', p_user_id using errcode = 'P0002';
  end if;

  v_status := p_patch->>'verificationStatus';
  if v_status is not null and v_status not in ('UNVERIFIED','PENDING','VERIFIED','REJECTED') then
    raise exception 'Invalid worker verification status: %', v_status using errcode = '22023';
  end if;

  -- Create the sheet on demand: an admin can configure a brand-new worker
  -- profile before the worker finishes their own onboarding.
  insert into public.worker_profiles (user_id, public_name)
  values (p_user_id, coalesce(nullif(p_patch->>'publicName', ''), v_name))
  on conflict (user_id) do nothing;

  update public.worker_profiles wp set
    public_name         = coalesce(nullif(p_patch->>'publicName', ''), wp.public_name),
    base_area           = coalesce(p_patch->>'baseArea', wp.base_area),
    min_rate_npr        = coalesce((p_patch->>'minRateNpr')::bigint, wp.min_rate_npr),
    rate_negotiable     = coalesce((p_patch->>'rateNegotiable')::boolean, wp.rate_negotiable),
    availability        = coalesce(p_patch->>'availability', wp.availability),
    tagline             = coalesce(p_patch->>'tagline', wp.tagline),
    bio                 = coalesce(p_patch->>'bio', wp.bio),
    verification_status = coalesce(v_status, wp.verification_status),
    updated_at          = now()
   where wp.user_id = p_user_id
  returning * into v_result;

  return v_result;
end;
$$;

create or replace function public.admin_configure_employer_profile(
  p_user_id uuid,
  p_patch jsonb default '{}'::jsonb
)
returns public.employer_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_status text;
  v_result public.employer_profiles;
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'Only platform staff may configure hirer profiles' using errcode = '42501';
  end if;

  select full_name into v_name from public.users where id = p_user_id;
  if v_name is null then
    raise exception 'Account % does not exist', p_user_id using errcode = 'P0002';
  end if;

  v_status := p_patch->>'trustStatus';
  if v_status is not null and v_status not in ('UNVERIFIED','VERIFIED','SUSPENDED') then
    raise exception 'Invalid employer trust status: %', v_status using errcode = '22023';
  end if;

  insert into public.employer_profiles (user_id, display_name)
  values (p_user_id, coalesce(nullif(p_patch->>'displayName', ''), v_name))
  on conflict (user_id) do nothing;

  update public.employer_profiles ep set
    display_name = coalesce(nullif(p_patch->>'displayName', ''), ep.display_name),
    organization = coalesce(p_patch->>'organization', ep.organization),
    trust_status = coalesce(v_status, ep.trust_status),
    updated_at   = now()
   where ep.user_id = p_user_id
  returning * into v_result;

  return v_result;
end;
$$;

create or replace function public.admin_remove_profile(p_user_id uuid, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'Only platform staff may remove profiles' using errcode = '42501';
  end if;
  if p_kind = 'worker' then
    delete from public.worker_profiles where user_id = p_user_id;
  elsif p_kind = 'employer' then
    delete from public.employer_profiles where user_id = p_user_id;
  else
    raise exception 'p_kind must be worker or employer' using errcode = '22023';
  end if;
  return true;
end;
$$;

create or replace function public.admin_update_account(
  p_user_id uuid,
  p_patch jsonb default '{}'::jsonb,
  p_roles text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_identity text;
  v_role text;
  v_result jsonb;
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'Only platform staff may edit accounts' using errcode = '42501';
  end if;
  if not exists (select 1 from public.users where id = p_user_id) then
    raise exception 'Account % does not exist', p_user_id using errcode = 'P0002';
  end if;

  v_status := p_patch->>'status';
  if v_status is not null and v_status not in ('ACTIVE','SUSPENDED') then
    raise exception 'Invalid account status: %', v_status using errcode = '22023';
  end if;
  v_identity := p_patch->>'identityStatus';
  if v_identity is not null
     and v_identity not in ('NOT_STARTED','PENDING','NEEDS_ACTION','VERIFIED','REJECTED') then
    raise exception 'Invalid identity status: %', v_identity using errcode = '22023';
  end if;

  update public.users set
    full_name            = coalesce(nullif(p_patch->>'fullName', ''), full_name),
    phone                = coalesce(p_patch->>'phone', phone),
    status               = coalesce(v_status, status),
    identity_status      = coalesce(v_identity, identity_status),
    onboarding_complete  = coalesce((p_patch->>'onboardingComplete')::boolean, onboarding_complete),
    updated_at           = now()
   where id = p_user_id;

  if p_roles is not null then
    foreach v_role in array p_roles loop
      if v_role not in ('WORKER','EMPLOYER','MODERATOR','BILLING_ADMIN','ADMIN') then
        raise exception 'Invalid role: %', v_role using errcode = '22023';
      end if;
    end loop;
    delete from public.user_roles where user_id = p_user_id and not (role = any(p_roles));
    insert into public.user_roles (user_id, role)
      select p_user_id, t.role_name from unnest(p_roles) as t(role_name)
      on conflict do nothing;
  end if;

  select jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'fullName', u.full_name,
    'phone', u.phone,
    'status', u.status,
    'identityStatus', u.identity_status,
    'onboardingComplete', u.onboarding_complete,
    'roles', coalesce(
      (select jsonb_agg(ur.role order by ur.role) from public.user_roles ur where ur.user_id = u.id),
      '[]'::jsonb
    )
  ) into v_result
  from public.users u where u.id = p_user_id;

  return v_result;
end;
$$;

revoke all on function public.admin_configure_worker_profile(uuid, jsonb) from public;
revoke all on function public.admin_configure_employer_profile(uuid, jsonb) from public;
revoke all on function public.admin_remove_profile(uuid, text) from public;
revoke all on function public.admin_update_account(uuid, jsonb, text[]) from public;
grant execute on function public.admin_configure_worker_profile(uuid, jsonb) to authenticated, service_role, postgres;
grant execute on function public.admin_configure_employer_profile(uuid, jsonb) to authenticated, service_role, postgres;
grant execute on function public.admin_remove_profile(uuid, text) to authenticated, service_role, postgres;
grant execute on function public.admin_update_account(uuid, jsonb, text[]) to authenticated, service_role, postgres;
