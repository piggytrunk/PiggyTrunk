-- ==============================================================================
-- 40_clean_state_with_sequence_resets.sql
-- Piggy Trunk: Comprehensive Zero-Clean State Reset with Identity Sequence Restarts
-- ==============================================================================
-- TARGETS CLEARED:
--   1. All Hog Raisers (auth.users, app_users, hog_raisers, assignments, hogs, stock_requests, hog_reports)
--   2. All Partner Investors (auth.users, app_users, partner_investors, investments, investment_records)
--   3. All Cashiers (auth.users, app_users, cashiers) - Clean slate for fresh registration
--   4. All Historical Sales & Transactions (sales, pos_sales, inventory_logs)
--   5. ALL System Notifications (admin_notifications, raiser_notifications, partner_notifications)
--   6. Batches reset (batches table)
--   7. Password resets (admin_password_resets table)
--   8. Test Products removed (specifically 'test product 123' from inventory and POS)
--   9. Legacy auto-insert trigger dropped (permanently prevents "Double the Hog" bug)
--  10. Identity sequences reset so all entity IDs start cleanly from 1
--
-- STRICTLY PRESERVED:
--   - Default Admin Accounts (auth.users & app_users where role = 'admin' / 'administrator')
--   - Admin Account aligned to user_id = 1, sequence restarted so next user = 2
--   - Valid POS / Inventory Products: public.inventory_products & public.products
--   - Master Hog Types: public.hog_types
--   - Mobile App Version Config: public.app_versions
--   - Storage bucket: 'product-images'
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Wipe ALL Notifications across the entire system
-- ------------------------------------------------------------------------------
DELETE FROM public.admin_notifications;
DELETE FROM public.raiser_notifications;
DELETE FROM public.partner_notifications;

-- ------------------------------------------------------------------------------
-- 2. Clear Hog Raiser Activity & Dependency Records (reverse FK hierarchy)
-- ------------------------------------------------------------------------------
DELETE FROM public.stock_requests;
DELETE FROM public.hog_reports;
DELETE FROM public.hogs;
DELETE FROM public.assignments;
DELETE FROM public.hog_raisers;

-- ------------------------------------------------------------------------------
-- 3. Clear Partner Investor Activity & Investment Records
-- ------------------------------------------------------------------------------
DELETE FROM public.investments;
DELETE FROM public.investment_records;
DELETE FROM public.partner_investors;

-- ------------------------------------------------------------------------------
-- 4. Clear Cashier Records & Historical Transaction Sales
-- ------------------------------------------------------------------------------
DELETE FROM public.cashiers;
DELETE FROM public.sales;
DELETE FROM public.pos_sales;
DELETE FROM public.inventory_logs;

-- ------------------------------------------------------------------------------
-- 5. Clear Batches & Temporary Password Resets
-- ------------------------------------------------------------------------------
DELETE FROM public.batches;
DELETE FROM public.admin_password_resets;

-- ------------------------------------------------------------------------------
-- 6. Delete Non-Admin Users from Supabase Auth & Public App Users
-- ------------------------------------------------------------------------------
-- Wipe non-admin auth.users FIRST (allows immediate re-registration with same emails)
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

-- Wipe non-admin public.app_users
DELETE FROM public.app_users
WHERE LOWER(role) NOT IN ('admin', 'administrator', 'system administrator')
  AND LOWER(email) NOT IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com');

-- ------------------------------------------------------------------------------
-- 7. Align Preserved Admin User ID to 1
-- ------------------------------------------------------------------------------
UPDATE public.app_users
SET user_id = 1
WHERE user_id = (
  SELECT user_id FROM public.app_users
  WHERE LOWER(role) IN ('admin', 'administrator', 'system administrator')
     OR LOWER(email) IN ('admin@piggytrunk.com', 'admin@gmail.com', 'piggytrunk@gmail.com')
  ORDER BY user_id ASC
  LIMIT 1
);

-- ------------------------------------------------------------------------------
-- 8. Reset All Identity Sequences so IDs Start From 1
-- ------------------------------------------------------------------------------
-- Entities starting at 1:
ALTER TABLE public.batches ALTER COLUMN batch_id RESTART WITH 1;
ALTER TABLE public.cashiers ALTER COLUMN cashier_id RESTART WITH 1;
ALTER TABLE public.partner_investors ALTER COLUMN partner_investor_id RESTART WITH 1;
ALTER TABLE public.hog_raisers ALTER COLUMN hog_raiser_id RESTART WITH 1;
ALTER TABLE public.assignments ALTER COLUMN assignment_id RESTART WITH 1;
ALTER TABLE public.hogs ALTER COLUMN hog_id RESTART WITH 1;
ALTER TABLE public.stock_requests ALTER COLUMN request_id RESTART WITH 1;
ALTER TABLE public.sales ALTER COLUMN sale_id RESTART WITH 1;
ALTER TABLE public.investments ALTER COLUMN investment_id RESTART WITH 1;
ALTER TABLE public.hog_reports ALTER COLUMN report_id RESTART WITH 1;
ALTER TABLE public.admin_notifications ALTER COLUMN notification_id RESTART WITH 1;
ALTER TABLE public.raiser_notifications ALTER COLUMN notification_id RESTART WITH 1;
ALTER TABLE public.partner_notifications ALTER COLUMN notification_id RESTART WITH 1;
ALTER TABLE public.admin_password_resets ALTER COLUMN id RESTART WITH 1;

-- Next app_user starts at 2 (since Admin occupies user_id = 1)
SELECT setval(pg_get_serial_sequence('public.app_users', 'user_id'), 1, true);

-- ------------------------------------------------------------------------------
-- 9. Remove Test Product 123 from Inventory & POS
-- ------------------------------------------------------------------------------
DELETE FROM public.inventory_products
WHERE LOWER(TRIM(name)) ILIKE '%test product 123%'
   OR LOWER(TRIM(name)) ILIKE '%test%123%'
   OR LOWER(TRIM(name)) = 'test product 123'
   OR barcode = '123';

DELETE FROM public.products
WHERE LOWER(TRIM(product_name)) ILIKE '%test product 123%'
   OR LOWER(TRIM(product_name)) ILIKE '%test%123%'
   OR LOWER(TRIM(product_name)) = 'test product 123';

-- ------------------------------------------------------------------------------
-- 10. Prevent "Double the Hog" Bug: Drop Redundant Auto-Insert Trigger
-- ------------------------------------------------------------------------------
-- Drops the legacy prototype trigger that automatically created duplicate hogs
-- on investment_records insert. Flutter's investment_form_view.dart already handles
-- real batch assignments, sow/fattening allocations, and exact hog counts.
DROP TRIGGER IF EXISTS trg_auto_create_batch_and_assignment ON public.investment_records;
DROP FUNCTION IF EXISTS public.fn_auto_create_batch_and_assignment();

-- ------------------------------------------------------------------------------
-- 11. Guarantee Remaining Inventory / POS Products are Active & Fetchable
-- ------------------------------------------------------------------------------
-- Unarchive all preserved products & reset sold counters to 0 for a fresh sales cycle
UPDATE public.inventory_products
SET is_archived = false,
    sold = 0;

-- Ensure Realtime publication includes inventory_products
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'inventory_products'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_products;
    END IF;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

COMMIT;

-- ==============================================================================
-- POST-RESET VERIFICATION QUERIES (Execute to inspect results in Supabase)
-- ==============================================================================
-- 1. Confirm Only Admin remains (user_id = 1):
-- SELECT user_id, email, role, status FROM public.app_users;

-- 2. Confirm Zero Notifications across all 3 tables:
-- SELECT 
--   (SELECT count(*) FROM public.admin_notifications) AS admin_notifs,
--   (SELECT count(*) FROM public.raiser_notifications) AS raiser_notifs,
--   (SELECT count(*) FROM public.partner_notifications) AS partner_notifs;

-- 3. Confirm Products are intact and active for Cashier:
-- SELECT count(*) AS total_active_products, sum(units) AS total_units_in_stock 
-- FROM public.inventory_products WHERE is_archived = false;

-- 4. Confirm Batches, Cashiers, Raisers, Investments are 0:
-- SELECT 
--   (SELECT count(*) FROM public.batches) AS batches,
--   (SELECT count(*) FROM public.cashiers) AS cashiers,
--   (SELECT count(*) FROM public.hog_raisers) AS raisers,
--   (SELECT count(*) FROM public.partner_investors) AS partners,
--   (SELECT count(*) FROM public.investments) AS investments,
--   (SELECT count(*) FROM public.hogs) AS hogs;

-- 5. Confirm Test Product 123 has been removed:
-- SELECT count(*) AS test_products_remaining 
-- FROM public.inventory_products 
-- WHERE LOWER(TRIM(name)) ILIKE '%test product 123%' OR LOWER(TRIM(name)) ILIKE '%test%123%';

-- 6. Confirm Redundant Hog Trigger is removed (returns 0):
-- SELECT count(*) AS duplicate_hog_trigger_count 
-- FROM pg_trigger 
-- WHERE tgname = 'trg_auto_create_batch_and_assignment';
