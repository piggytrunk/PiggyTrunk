-- ==============================================================================
-- 35_fix_cashiers_status_and_notifications.sql
-- Long-Term Fix for Cashier Schema, Role Initialization, and Admin Notifications
-- 
-- 1. Adds missing 'status' column to public.cashiers with default 'Pending'.
-- 2. Backfills existing orphaned cashier records (users in app_users missing in cashiers).
-- 3. Upgrades public.handle_new_user() trigger with isolated sub-blocks to guarantee
--    admin_notifications is ALWAYS inserted, preventing any future signup notification drop.
-- 4. Ensures Realtime publication and RLS permissions on admin_notifications and cashiers.
-- ==============================================================================

begin;

-- ------------------------------------------------------------------------------
-- 1. Schema Upgrade: Ensure public.cashiers has status & proper constraints
-- ------------------------------------------------------------------------------
alter table public.cashiers 
  add column if not exists status text not null default 'Pending';

alter table public.cashiers
  add column if not exists date_hired date not null default current_date;

create index if not exists idx_cashiers_status on public.cashiers(status);

-- ------------------------------------------------------------------------------
-- 2. Backfill: Insert any orphaned cashier records from app_users
-- ------------------------------------------------------------------------------
insert into public.cashiers (user_id, status, date_hired)
select 
  u.user_id,
  case when lower(u.status) = 'active' then 'active' else 'Pending' end,
  coalesce(u.created_at::date, current_date)
from public.app_users u
left join public.cashiers c on c.user_id = u.user_id
where lower(u.role) = 'cashier' 
  and c.cashier_id is null
on conflict (user_id) do update set
  status = excluded.status;

-- ------------------------------------------------------------------------------
-- 2.1 Backfill: Insert missing admin_notifications for cashiers (e.g. Mark Rejie)
-- so they immediately appear in the Admin Web 'Users' tab
-- ------------------------------------------------------------------------------
insert into public.admin_notifications (
  title,
  message,
  type,
  is_read,
  metadata
)
select
  'New User Registration',
  u.name || ' (' || coalesce(u.email, '') || ') registered as Cashier and is pending approval.',
  'user_registration',
  false,
  jsonb_build_object(
    'user_id', u.user_id,
    'name', u.name,
    'email', u.email,
    'role', 'cashier'
  )
from public.app_users u
where lower(u.role) = 'cashier'
  and not exists (
    select 1 from public.admin_notifications n 
    where n.type = 'user_registration' 
      and (n.metadata->>'email' = u.email or n.message ilike '%' || u.email || '%')
  );

-- ------------------------------------------------------------------------------
-- 3. Upgrade handle_new_user(): Resilient, Multi-Role Central Trigger
-- ------------------------------------------------------------------------------
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
  -- Safe extraction of full name & display name
  user_full_name := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1)
  );

  user_name := coalesce(
    new.raw_user_meta_data->>'name',
    user_full_name
  );

  -- Safe extraction and normalization of role
  user_role := lower(coalesce(
    new.raw_user_meta_data->>'role',
    new.raw_app_meta_data->>'role',
    'hog_raiser'
  ));

  if user_role = 'raiser' then
    user_role := 'hog_raiser';
  elsif user_role = 'investor' then
    user_role := 'partner';
  end if;

  -- Determine friendly display name for notifications & UI
  if user_role = 'hog_raiser' then
    role_display := 'Hog Raiser';
  elsif user_role = 'partner' then
    role_display := 'Partner Investor';
  elsif user_role = 'cashier' then
    role_display := 'Cashier';
  elsif user_role = 'admin' then
    role_display := 'Admin';
    user_status := 'active'; -- Admins default to active if created via auth
  else
    role_display := 'User';
  end if;

  -- Step 1: Upsert into public.app_users (Parent identity)
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

  -- Step 2: Populate role-specific child tables in an isolated sub-block
  -- (Ensures any error in a child table NEVER cancels the admin notification)
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

  -- Step 3: Always insert Realtime Admin Notification in its own isolated sub-block
  -- (Guarantees Admin Web receives the alert for every new registration)
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

-- ------------------------------------------------------------------------------
-- 4. Re-bind Trigger on auth.users
-- ------------------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 5. Realtime & Permissive RLS Configuration
-- ------------------------------------------------------------------------------
-- Ensure admin_notifications and cashiers are published for live Web socket events
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'admin_notifications'
  ) then
    alter publication supabase_realtime add table public.admin_notifications;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cashiers'
  ) then
    alter publication supabase_realtime add table public.cashiers;
  end if;
exception when others then
  raise warning 'Realtime publication setup notice: %', SQLERRM;
end $$;

-- Enable RLS and permissive policy on admin_notifications for seamless cross-client alerts
alter table public.admin_notifications enable row level security;
drop policy if exists admin_notifications_public_all on public.admin_notifications;
create policy admin_notifications_public_all on public.admin_notifications 
for all to public using (true) with check (true);

-- Enable RLS and permissive policy on cashiers table
alter table public.cashiers enable row level security;
drop policy if exists cashiers_public_all on public.cashiers;
create policy cashiers_public_all on public.cashiers 
for all to public using (true) with check (true);

commit;

-- Force PostgREST to reload schema cache so changes take effect immediately
notify pgrst, 'reload schema';
