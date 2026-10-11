-- ==============================================================================
-- 31_admin_auth_recovery_functions.sql
-- Functions:
-- 1. admin_request_password_reset_otp: Administrator password reset OTP request
-- 2. user_request_password_reset_otp: Mobile user password reset OTP request
-- 3. admin_verify_otp_and_reset_password: OTP verification, bcrypt password update, and account activation
-- 4. admin_check_account_status: First-time admin password activation check
-- ==============================================================================

begin;

-- 1. RPC to register password reset OTP for Administrators
create or replace function public.admin_request_password_reset_otp(
  target_email text,
  otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  cleaned_email text;
  user_role text;
begin
  cleaned_email := lower(trim(target_email));

  -- Fetch role from public.app_users
  select lower(trim(role)) into user_role
  from public.app_users
  where lower(email) = cleaned_email
  limit 1;

  if user_role is null then
    -- Also check auth.users metadata if not found in app_users
    select lower(coalesce(raw_user_meta_data->>'role', '')) into user_role
    from auth.users
    where lower(email) = cleaned_email
    limit 1;
  end if;

  if user_role is null or user_role = '' then
    return jsonb_build_object('success', false, 'message', 'No registered administrator account found for ' || cleaned_email || '.');
  end if;

  -- Strict Administrator verification (cashiers, hog raisers, and partners must use mobile)
  if user_role not in ('admin', 'system administrator', 'administrator') and user_role not like '%admin%' then
    return jsonb_build_object(
      'success', false,
      'message', 'This account is registered as a ' || initcap(replace(user_role, '_', ' ')) || '. Admin Portal password reset is exclusively for Administrator accounts. Please use the Piggy Trunk Mobile app.'
    );
  end if;

  -- Invalidate old unused OTPs
  update public.admin_password_resets
  set used = true
  where lower(email) = cleaned_email and used = false;

  -- Insert new 10-minute OTP
  insert into public.admin_password_resets (email, otp_code, expires_at, used)
  values (cleaned_email, otp_code, now() + interval '10 minutes', false);

  return jsonb_build_object(
    'success', true,
    'message', 'Password reset code registered successfully.'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'message', SQLERRM);
end;
$$;

-- 2. RPC for mobile user password reset (Hog Raiser, Cashier, Partner Investor)
create or replace function public.user_request_password_reset_otp(
  target_email text,
  otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  cleaned_email text;
  account_exists boolean := false;
begin
  cleaned_email := lower(trim(target_email));

  if exists (select 1 from public.app_users where lower(email) = cleaned_email) or
     exists (select 1 from auth.users where lower(email) = cleaned_email) then
    account_exists := true;
  end if;

  if not account_exists then
    return jsonb_build_object('success', false, 'message', 'No registered account found for ' || cleaned_email || '.');
  end if;

  -- Invalidate old unused OTPs
  update public.admin_password_resets
  set used = true
  where lower(email) = cleaned_email and used = false;

  -- Insert new 10-minute OTP
  insert into public.admin_password_resets (email, otp_code, expires_at, used)
  values (cleaned_email, otp_code, now() + interval '10 minutes', false);

  return jsonb_build_object(
    'success', true,
    'message', 'Password reset code registered successfully.'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'message', SQLERRM);
end;
$$;

-- 3. RPC to verify OTP and reset password
create or replace function public.admin_verify_otp_and_reset_password(
  target_email text,
  otp_code text,
  new_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
#variable_conflict use_column
declare
  cleaned_email text;
  reset_record record;
  target_user_id uuid;
  user_role text;
begin
  cleaned_email := lower(trim(target_email));

  -- Check valid unexpired OTP
  select * into reset_record
  from public.admin_password_resets apr
  where lower(apr.email) = cleaned_email
    and apr.otp_code = trim(admin_verify_otp_and_reset_password.otp_code)
    and apr.used = false
    and apr.expires_at > now()
  order by apr.created_at desc
  limit 1;

  if reset_record is null then
    return jsonb_build_object('success', false, 'message', 'Invalid or expired verification code. Please request a new code.');
  end if;

  -- Mark code as used
  update public.admin_password_resets
  set used = true
  where id = reset_record.id;

  -- Locate user in auth.users
  select id into target_user_id
  from auth.users
  where lower(email) = cleaned_email
  limit 1;

  if target_user_id is null then
    select supabase_user_id into target_user_id
    from public.app_users
    where lower(email) = cleaned_email
    limit 1;
  end if;

  if target_user_id is null then
    return jsonb_build_object('success', false, 'message', 'User account not found.');
  end if;

  -- Update encrypted password using standard Supabase bcrypt
  update auth.users
  set encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = target_user_id;

  -- Activate user in public.app_users so first-time setup is marked complete
  update public.app_users
  set status = 'Active',
      password_hash = 'managed_by_supabase_auth'
  where supabase_user_id = target_user_id
     or lower(email) = cleaned_email;

  -- Check user role before recording admin notification
  select role into user_role
  from public.app_users
  where supabase_user_id = target_user_id
     or lower(email) = cleaned_email
  limit 1;

  if user_role is null then
    select lower(coalesce(raw_user_meta_data->>'role', '')) into user_role
    from auth.users
    where id = target_user_id;
  end if;

  -- Record security notification in admin_notifications table ONLY if user is truly an Administrator
  if lower(coalesce(user_role, '')) in ('admin', 'administrator', 'system administrator') or lower(coalesce(user_role, '')) like '%admin%' then
    insert into public.admin_notifications (title, message, type, is_read, metadata)
    values (
      'Admin Password Reset',
      'Administrator account (' || cleaned_email || ') successfully verified OTP and updated login password.',
      'admin_profile',
      false,
      jsonb_build_object(
        'email', cleaned_email,
        'role', user_role,
        'updated_at', now()
      )
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Password updated successfully! You can now log in.'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'message', SQLERRM);
end;
$$;

-- 4. RPC for mobile user password reset verification (Hog Raiser, Cashier, Partner Investor)
create or replace function public.user_verify_otp_and_reset_password(
  target_email text,
  otp_code text,
  new_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
#variable_conflict use_column
declare
  cleaned_email text;
  reset_record record;
  target_user_id uuid;
  user_role text;
  user_fullname text;
  role_display text;
begin
  cleaned_email := lower(trim(target_email));

  -- Check valid unexpired OTP
  select * into reset_record
  from public.admin_password_resets apr
  where lower(apr.email) = cleaned_email
    and apr.otp_code = trim(user_verify_otp_and_reset_password.otp_code)
    and apr.used = false
    and apr.expires_at > now()
  order by apr.created_at desc
  limit 1;

  if reset_record is null then
    return jsonb_build_object('success', false, 'message', 'Invalid or expired verification code. Please request a new code.');
  end if;

  -- Mark code as used
  update public.admin_password_resets
  set used = true
  where id = reset_record.id;

  -- Locate user in auth.users
  select id into target_user_id
  from auth.users
  where lower(email) = cleaned_email
  limit 1;

  if target_user_id is null then
    select supabase_user_id into target_user_id
    from public.app_users
    where lower(email) = cleaned_email
    limit 1;
  end if;

  if target_user_id is null then
    return jsonb_build_object('success', false, 'message', 'User account not found.');
  end if;

  -- Update encrypted password using standard Supabase bcrypt
  update auth.users
  set encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = target_user_id;

  -- Activate user in public.app_users so account is ready
  update public.app_users
  set status = 'Active',
      password_hash = 'managed_by_supabase_auth'
  where supabase_user_id = target_user_id
     or lower(email) = cleaned_email;

  -- Note: User password reset is private authentication activity and is not broadcast to admin_notifications.

  return jsonb_build_object(
    'success', true,
    'message', 'Password updated successfully! You can now log in.'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'message', SQLERRM);
end;
$$;

-- 5. RPC to check if an admin account exists and whether it requires first-time password activation
create or replace function public.admin_check_account_status(
  email_input text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  cleaned_email text;
  found_record record;
  is_admin boolean := false;
  needs_act boolean := false;
begin
  cleaned_email := lower(trim(email_input));

  if cleaned_email = '' then
    return jsonb_build_object('exists', false, 'is_admin', false, 'needs_activation', false);
  end if;

  select user_id, name, email, role, status, password_hash
  into found_record
  from public.app_users
  where lower(email) = cleaned_email
  limit 1;

  if found_record is null then
    return jsonb_build_object('exists', false, 'is_admin', false, 'needs_activation', false);
  end if;

  if lower(trim(found_record.role)) in ('admin', 'system administrator', 'administrator') 
     or lower(trim(found_record.role)) like '%admin%' then
    is_admin := true;
  end if;

  -- Needs activation if it is an admin account and status is 'Pending' or password_hash is null/empty
  if is_admin and (
    coalesce(lower(trim(found_record.status)), 'pending') = 'pending'
    or found_record.password_hash is null
    or trim(found_record.password_hash) = ''
  ) then
    needs_act := true;
  end if;

  return jsonb_build_object(
    'exists', true,
    'is_admin', is_admin,
    'role', found_record.role,
    'status', found_record.status,
    'needs_activation', needs_act
  );
exception
  when others then
    return jsonb_build_object('exists', false, 'is_admin', false, 'needs_activation', false, 'error', SQLERRM);
end;
$$;

-- Grant permissions to functions
grant execute on function public.admin_request_password_reset_otp to anon, authenticated, service_role;
grant execute on function public.user_request_password_reset_otp to anon, authenticated, service_role;
grant execute on function public.admin_verify_otp_and_reset_password to anon, authenticated, service_role;
grant execute on function public.user_verify_otp_and_reset_password to anon, authenticated, service_role;
grant execute on function public.admin_check_account_status to anon, authenticated, service_role;

commit;
