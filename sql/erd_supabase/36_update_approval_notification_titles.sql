-- ==============================================================================
-- PIGGY TRUNK MIGRATION 36: UPDATE HISTORICAL APPROVAL NOTIFICATION TITLES
-- Description:
--   Normalizes existing "Account Approved Notification" and related approval records 
--   in public.admin_notifications so they explicitly display the user's specific role
--   (e.g., "Account Approved for Cashier", "Account Approved for Hog Raiser", 
--   "Account Approved for Partner Investor").
-- ==============================================================================

-- 1. Update approval notifications by matching with app_users to get exact registered roles
update public.admin_notifications an
set title = case 
  when lower(coalesce(an.metadata->>'role', u.role, '')) in ('cashier') or lower(an.message) ilike '%cashier%' 
    then 'Account Approved for Cashier'
  when lower(coalesce(an.metadata->>'role', u.role, '')) in ('partner', 'investor', 'partner_investor') or lower(an.message) ilike '%partner%' or lower(an.message) ilike '%investor%' 
    then 'Account Approved for Partner Investor'
  when lower(coalesce(an.metadata->>'role', u.role, '')) in ('hog_raiser', 'raiser') or lower(an.message) ilike '%hog raiser%' or lower(an.message) ilike '%raiser%' 
    then 'Account Approved for Hog Raiser'
  else 'Account Approved for Hog Raiser'
end
from public.app_users u
where (an.type in ('approval_email', 'user_registration') or an.title ilike '%Account Approved%')
  and (
    lower(an.metadata->>'email') = lower(u.email)
    or lower(an.message) ilike '%' || lower(u.email) || '%'
  )
  and (an.title ilike '%Account Approved%' or an.title ilike '%Approved Notification%');

-- 2. Fallback update for any remaining approval notification without email match
update public.admin_notifications
set title = case 
  when lower(coalesce(metadata->>'role', '')) in ('cashier') or lower(message) ilike '%cashier%' then 'Account Approved for Cashier'
  when lower(coalesce(metadata->>'role', '')) in ('partner', 'investor') or lower(message) ilike '%partner%' or lower(message) ilike '%investor%' then 'Account Approved for Partner Investor'
  else 'Account Approved for Hog Raiser'
end
where (type = 'approval_email' or title ilike '%Account Approved%')
  and title not like 'Account Approved for %';
