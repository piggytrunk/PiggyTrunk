-- 22_auth_signup_trigger.sql
-- Unified handle_new_user() trigger for Supabase Auth (Email & Google signups).
-- Automatically syncs auth.users -> public.app_users and role-specific tables.

begin;

-- 1. Drop old conflicting triggers and functions
drop trigger if exists trigger_notify_and_initialize_new_user on public.app_users;
drop function if exists public.notify_and_initialize_new_user();

drop trigger if exists trigger_on_new_raiser_insert on public.hog_raisers;
drop trigger if exists trigger_on_hog_raiser_insert on public.hog_raisers;
drop function if exists public.notify_admin_on_new_raiser();

drop trigger if exists trigger_on_partner_investor_insert on public.partner_investors;
drop function if exists public.notify_admin_on_new_partner();

drop trigger if exists trigger_on_cashier_insert on public.cashiers;
drop function if exists public.notify_admin_on_new_cashier();

-- 2. Create or replace unified handle_new_user function
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  user_full_name text;
  user_name text;
  user_role text;
  user_status text := 'Pending';
  new_app_user_id bigint;
  role_display text;
begin
  -- Extract metadata safely
  user_full_name := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1)
  );

  user_name := coalesce(
    new.raw_user_meta_data->>'name',
    user_full_name
  );

  user_role := lower(coalesce(
    new.raw_user_meta_data->>'role',
    'hog_raiser'
  ));

  -- Normalize role names
  if user_role = 'raiser' then
    user_role := 'hog_raiser';
  elsif user_role = 'investor' then
    user_role := 'partner';
  end if;

  -- Compute friendly English display name
  if user_role = 'hog_raiser' then
    role_display := 'Hog Raiser';
  elsif user_role = 'partner' then
    role_display := 'Partner Investor';
  elsif user_role = 'cashier' then
    role_display := 'Cashier';
  else
    role_display := 'User';
  end if;

  -- 1. Upsert into public.app_users
  insert into public.app_users (
    supabase_user_id,
    email,
    name,
    role,
    status
  ) values (
    new.id,
    new.email,
    user_name,
    user_role,
    user_status
  )
  on conflict (email) do update set
    supabase_user_id = excluded.supabase_user_id,
    name = excluded.name,
    role = excluded.role,
    status = coalesce(public.app_users.status, excluded.status)
  returning user_id into new_app_user_id;

  if new_app_user_id is null then
    select user_id into new_app_user_id
    from public.app_users
    where email = new.email
    limit 1;
  end if;

  -- 2. Populate specific role tables safely in isolated sub-block
  begin
    if user_role = 'partner' then
      insert into public.partner_investors (user_id)
      values (new_app_user_id)
      on conflict (user_id) do nothing;

    elsif user_role = 'hog_raiser' then
      insert into public.hog_raisers (
        user_id,
        name,
        email,
        phone,
        address,
        status,
        account_status,
        pig_type,
        lifecycle_stage
      ) values (
        new_app_user_id,
        user_name,
        new.email,
        coalesce(new.raw_user_meta_data->>'phone', 'N/A'),
        coalesce(new.raw_user_meta_data->>'address', 'N/A'),
        'Inactive',
        'Pending',
        'N/A',
        'N/A'
      )
      on conflict (user_id) do update set
        name = excluded.name,
        email = excluded.email;

    elsif user_role = 'cashier' then
      insert into public.cashiers (user_id, status, date_hired)
      values (new_app_user_id, user_status, current_date)
      on conflict (user_id) do update set
        status = excluded.status;
    end if;
  exception when others then
    raise warning 'handle_new_user: Role table child insert notice: %', SQLERRM;
  end;

  -- 3. Always dispatch admin notification for non-admin signups
  if user_role != 'admin' then
    begin
      insert into public.admin_notifications (
        title,
        message,
        type,
        is_read,
        metadata
      ) values (
        'New User Registration',
        user_name || ' (' || coalesce(new.email, '') || ') registered as ' || role_display || ' and is pending approval.',
        'user_registration',
        false,
        jsonb_build_object(
          'user_id', new_app_user_id,
          'name', user_name,
          'email', new.email,
          'role', user_role
        )
      );
    exception when others then
      raise warning 'handle_new_user: admin_notifications insert notice: %', SQLERRM;
    end;
  end if;

  return new;
exception
  when others then
    raise warning 'handle_new_user top-level exception: %', SQLERRM;
    return new;
end;
$$;

-- 4. Rebind single trigger on auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

commit;
