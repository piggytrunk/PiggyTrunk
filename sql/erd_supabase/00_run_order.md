# Piggy Trunk - Supabase Database Schema

Clean, synchronized schema files for the Piggy Trunk platform (Admin Web, Cashier POS, Partner Investor, and Hog Raiser Mobile Apps).

## Execution Order in Supabase SQL Editor

Run these files sequentially in the Supabase SQL Editor, or run `sql/combined_schema.sql` all at once:

### Core Tables (20 Tables)
1. `01_app_users.sql` - Core application users & authentication link
2. `02_cashiers.sql` - Cashier profiles & employee details
3. `03_partner_investors.sql` - Partner investor profiles
4. `04_batches.sql` - Hog batches
5. `05_hog_types.sql` - Hog categories/types & feed requirements
6. `06_hog_raisers.sql` - Raiser profiles & current farm status
7. `07_assignments.sql` - Batch-to-raiser assignments
8. `08_hogs.sql` - Individual hog records
9. `09_stock_requests.sql` - Raiser feed & supply requests
10. `10_products.sql` - POS product catalog
11. `11_inventory_products.sql` - Inventory with reorder points & lead times
12. `12_inventory_logs.sql` - Stock audit logs (add, restock, edit, archive)
13. `13_sales.sql` - POS sales transactions
14. `14_pos_sales.sql` - Time-series sales items for demand forecasting
15. `15_investments.sql` - Partner investor direct investments
16. `16_investment_records.sql` - Admin & Raiser investment management records
17. `17_hog_reports.sql` - Raiser hog health & mortality reports
18. `18_admin_notifications.sql` - Admin & Cashier notification queue
19. `19_raiser_notifications.sql` - Raiser mobile notification queue
20. `20_partner_notifications.sql` - Partner mobile notification queue
21. `29_admin_password_resets.sql` - Password reset OTP table (3NF, 6 columns)

### Views, Triggers, Functions & Security
22. `21_dashboard_summary_view.sql` - KPI aggregation view for dashboard
23. `22_auth_signup_trigger.sql` - Unified auto-registration trigger (`handle_new_user`)
24. `23_inventory_triggers.sql` - Real-time restock & low stock notifications
25. `24_investment_triggers.sql` - Direct investment confirmation & assignment triggers
26. `25_hog_triggers.sql` - Auto-creation of batches/hogs & health alert triggers
27. `26_force_delete_user_function.sql` - Clean cascade deletion RPC helper
28. `27_pos_seed_function.sql` - Historical sales generator for forecasting
29. `28_rls_policies.sql` - Complete Row Level Security policies
30. `30_admin_profile_email_function.sql` - Admin email update and in-app audit RPC
31. `31_admin_auth_recovery_functions.sql` - Admin & User OTP password recovery and activation RPCs

---

### Cleaning & Synchronizing an Existing Supabase Project
- `38_zero_clean_state_cleanup.sql` - Zero-clean state reset (clears hog raisers, partner investors, cashiers, profile avatars, and all notifications while preserving POS products, images, and admin account)
- `39_sync_completed_batch_investment_status.sql` - Automatic sync trigger & backfill for completed batches, assignments, and investments when hogs reach terminal stage (Selling/Lactation)
- If your Supabase project still has old prototype tables (`logs`, `supply`, `capital_infusions`, `hog_stage_logs`, `hog_stages`), run: `sql/cleanup_supabase_redundant_items.sql`
