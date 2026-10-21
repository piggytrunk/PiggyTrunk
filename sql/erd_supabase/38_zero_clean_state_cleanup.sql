-- ==============================================================================
-- 38_zero_clean_state_cleanup.sql
-- Piggy Trunk: Comprehensive Zero-Clean State Database Reset
-- ==============================================================================
-- TARGETS CLEARED:
--   1. All users for Hog Raiser (auth.users, app_users, hog_raisers, assignments, hogs, stock_requests, hog_reports)
--   2. All users for Partner Investor (auth.users, app_users, partner_investors, investments, investment_records)
--   3. All users for Cashier (auth.users, app_users, cashiers, cashier sales)
--   4. ALL notifications (admin_notifications, raiser_notifications, partner_notifications)
--   5. All profile pictures in Supabase Storage (bucket: profile_pictures)
--   6. Batches reset (batches table)
--
-- STRICTLY PRESERVED:
--   - POS Products: public.inventory_products, public.products, public.inventory_logs
--   - POS Images: Supabase Storage bucket 'product-images'
--   - POS Historical Sales: public.pos_sales
--   - Default Admin Accounts: auth.users and app_users where role = 'admin' / 'administrator'
--                            or email IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com')
-- ==============================================================================

BEGIN;

-- 1. Wipe ALL Notifications (Admin, Raiser, Partner) for a completely clean slate
DELETE FROM public.admin_notifications;
DELETE FROM public.raiser_notifications;
DELETE FROM public.partner_notifications;

-- 2. Clear all Hog Raiser activity & dependency records (reverse foreign key order)
DELETE FROM public.stock_requests;
DELETE FROM public.hog_reports;
DELETE FROM public.hogs;
DELETE FROM public.assignments;
DELETE FROM public.hog_raisers;

-- 3. Clear all Partner Investor activity & investment records
DELETE FROM public.investments;
DELETE FROM public.investment_records;
DELETE FROM public.partner_investors;

-- 4. Clear all Cashier records and transactions performed by non-admins
DELETE FROM public.cashiers;
DELETE FROM public.sales
WHERE performed_by IN (
  SELECT user_id FROM public.app_users
  WHERE LOWER(role) NOT IN ('admin', 'administrator', 'system administrator')
    AND LOWER(email) NOT IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com')
);

-- 5. Reset Batch shells so new cycles start cleanly from Batch 1
DELETE FROM public.batches;

-- 6. Delete non-admin users from Supabase Auth FIRST (before app_users is deleted)
-- (Allows re-registration with identical email addresses without "Already Registered" conflicts)
DELETE FROM auth.users
WHERE LOWER(email) NOT IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com')
  AND (
    LOWER(email) IN (
      SELECT LOWER(email) FROM public.app_users
      WHERE LOWER(role) NOT IN ('admin', 'administrator', 'system administrator')
    )
    OR LOWER(COALESCE(raw_user_meta_data->>'role', raw_app_meta_data->>'role', '')) IN (
      'hog_raiser', 'raiser', 'partner', 'investor', 'partner_investor', 'cashier'
    )
  );

-- 7. Delete non-admin app_users
DELETE FROM public.app_users
WHERE LOWER(role) NOT IN ('admin', 'administrator', 'system administrator')
  AND LOWER(email) NOT IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com');

-- 8. Wipe all profile and avatar pictures from Supabase Storage
-- (Bucket 'profile_pictures' only; 'product-images' is completely untouched)
DELETE FROM storage.objects
WHERE bucket_id = 'profile_pictures';

COMMIT;

-- ==============================================================================
-- VERIFICATION QUERIES (Execute after COMMIT to inspect the clean state)
-- ==============================================================================
-- 1. Confirm only Administrator remains in app_users:
-- SELECT user_id, email, role, status FROM public.app_users;

-- 2. Confirm only Administrator remains in auth.users:
-- SELECT id, email, created_at FROM auth.users;

-- 3. Confirm POS products are 100% intact:
-- SELECT count(*) AS pos_inventory_products_count FROM public.inventory_products;

-- 4. Confirm POS product images in storage are untouched:
-- SELECT count(*) AS pos_images_count FROM storage.objects WHERE bucket_id = 'product-images';

-- 5. Confirm zero notifications remain:
-- SELECT 
--   (SELECT count(*) FROM public.admin_notifications) AS admin_notifs,
--   (SELECT count(*) FROM public.raiser_notifications) AS raiser_notifs,
--   (SELECT count(*) FROM public.partner_notifications) AS partner_notifs;
