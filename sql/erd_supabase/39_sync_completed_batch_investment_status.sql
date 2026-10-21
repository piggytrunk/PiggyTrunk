-- ==============================================================================
-- 39_sync_completed_batch_investment_status.sql
-- Piggy Trunk: Automatic Lifecycle Sync for Batches, Assignments & Investments
-- ==============================================================================
-- PURPOSE:
--   When all hogs in a batch reach their terminal lifecycle stage (Stage 6:
--   Selling for Fattening, or Lactation/Complete for Sow/Breeding):
--     1. Automatically update assignments.status to 'completed'
--     2. Automatically update batches.status to 'Finished'
--     3. Automatically update investment_records.stage to 'completed'
--     4. Automatically update partner investments.status to 'completed'
--
-- COMPATIBILITY:
--   - Fully supports Fattening (Selling / Sold) and Sow/Breeding (Lactation / Completed)
--   - Non-destructive: preserves all historical logs, weights, and sales
--   - Includes a one-time backfill to sync existing finished batches (e.g. BATCH-01-2026)
-- ==============================================================================

BEGIN;

-- 1. Create or replace the sync function triggered by hog lifecycle updates
CREATE OR REPLACE FUNCTION public.fn_sync_hog_lifecycle_completion()
RETURNS TRIGGER AS $$
DECLARE
  v_assignment_id bigint;
  v_batch_id bigint;
  v_batch_name text;
  v_raiser_id bigint;
  v_total_hogs integer;
  v_finished_hogs integer;
  v_pending_assignments integer;
BEGIN
  v_assignment_id := COALESCE(NEW.assignment_id, OLD.assignment_id);
  IF v_assignment_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Resolve parent batch and raiser for this assignment
  SELECT batch_id, hog_raiser_id
  INTO v_batch_id, v_raiser_id
  FROM public.assignments
  WHERE assignment_id = v_assignment_id;

  IF v_batch_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT batch_name INTO v_batch_name
  FROM public.batches
  WHERE batch_id = v_batch_id;

  -- Count total living hogs vs finished hogs for this assignment
  -- Living hogs: health_status != 'Dead'
  -- Finished hogs: stage_id >= 6 OR status IN ('completed', 'archived') OR health_status = 'Dead'
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (
      WHERE stage_id >= 6 
         OR LOWER(COALESCE(status, '')) IN ('completed', 'archived')
         OR LOWER(COALESCE(health_status, '')) = 'dead'
    )
  INTO v_total_hogs, v_finished_hogs
  FROM public.hogs
  WHERE assignment_id = v_assignment_id;

  -- If all hogs in this assignment are finished/terminal, complete the assignment
  IF v_total_hogs > 0 AND v_total_hogs = v_finished_hogs THEN
    UPDATE public.assignments
    SET status = 'completed'
    WHERE assignment_id = v_assignment_id
      AND LOWER(status) NOT IN ('completed', 'archived');

    -- Check if ALL assignments for this batch are now completed
    SELECT COUNT(*)
    INTO v_pending_assignments
    FROM public.assignments
    WHERE batch_id = v_batch_id
      AND LOWER(status) NOT IN ('completed', 'archived');

    -- If all assignments in the batch are finished, mark batch and investments completed
    IF v_pending_assignments = 0 THEN
      -- A. Mark Batch Finished
      UPDATE public.batches
      SET status = 'Finished'
      WHERE batch_id = v_batch_id
        AND LOWER(status) NOT IN ('finished', 'completed', 'archived');

      -- B. Mark Direct Admin Investment Records Completed
      UPDATE public.investment_records
      SET stage = 'completed'
      WHERE (
        batch_id = v_batch_id::text
        OR batch_name = v_batch_name
        OR (
          (batch_id IS NULL OR batch_id = '') 
          AND hog_raiser_id = v_raiser_id::text
        )
      )
      AND LOWER(stage) NOT IN ('completed', 'archived');

      -- C. Mark Partner Investments Completed
      UPDATE public.investments
      SET status = 'completed'
      WHERE batch_id = v_batch_id
        AND LOWER(status) NOT IN ('completed', 'archived');
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Bind the trigger to the public.hogs table on stage/status updates
DROP TRIGGER IF EXISTS trg_sync_hog_lifecycle_completion ON public.hogs;
CREATE TRIGGER trg_sync_hog_lifecycle_completion
  AFTER INSERT OR UPDATE OF stage_id, status, health_status
  ON public.hogs
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_hog_lifecycle_completion();


-- ==============================================================================
-- 3. ONE-TIME BACKFILL: Synchronize any existing batches already at terminal stage
-- ==============================================================================

-- A. Complete assignments whose hogs are all stage >= 6 or dead
UPDATE public.assignments a
SET status = 'completed'
WHERE a.assignment_id IN (
  SELECT h.assignment_id
  FROM public.hogs h
  GROUP BY h.assignment_id
  HAVING COUNT(*) > 0 
     AND COUNT(*) = COUNT(*) FILTER (
       WHERE h.stage_id >= 6 
          OR LOWER(COALESCE(h.status, '')) IN ('completed', 'archived')
          OR LOWER(COALESCE(h.health_status, '')) = 'dead'
     )
)
AND LOWER(a.status) NOT IN ('completed', 'archived');

-- B. Mark Batches Finished if all their assignments are completed
UPDATE public.batches b
SET status = 'Finished'
WHERE b.batch_id IN (
  SELECT a.batch_id
  FROM public.assignments a
  GROUP BY a.batch_id
  HAVING COUNT(*) > 0
     AND COUNT(*) = COUNT(*) FILTER (
       WHERE LOWER(a.status) IN ('completed', 'archived')
     )
)
AND LOWER(b.status) NOT IN ('finished', 'completed', 'archived');

-- C. Mark direct investment_records completed for completed batches
UPDATE public.investment_records ir
SET stage = 'completed'
WHERE (
  ir.batch_id IN (
    SELECT b.batch_id::text 
    FROM public.batches b 
    WHERE LOWER(b.status) IN ('finished', 'completed')
  )
  OR ir.batch_name IN (
    SELECT b.batch_name 
    FROM public.batches b 
    WHERE LOWER(b.status) IN ('finished', 'completed')
  )
  OR ir.hog_raiser_id IN (
    SELECT a.hog_raiser_id::text
    FROM public.assignments a
    JOIN public.batches b ON b.batch_id = a.batch_id
    WHERE LOWER(b.status) IN ('finished', 'completed')
  )
)
AND LOWER(ir.stage) NOT IN ('completed', 'archived');

-- D. Mark partner investments completed for completed batches
UPDATE public.investments inv
SET status = 'completed'
WHERE inv.batch_id IN (
  SELECT b.batch_id 
  FROM public.batches b 
  WHERE LOWER(b.status) IN ('finished', 'completed')
)
AND LOWER(inv.status) NOT IN ('completed', 'archived');

COMMIT;

-- ==============================================================================
-- VERIFICATION QUERIES (Execute to inspect results after running)
-- ==============================================================================
-- 1. Check batch status (e.g. BATCH-01-2026 should now be 'Finished'):
-- SELECT batch_id, batch_name, status FROM public.batches;
--
-- 2. Check assignment status:
-- SELECT assignment_id, batch_id, hog_raiser_id, status FROM public.assignments;
--
-- 3. Check investment record stage:
-- SELECT id, raiser_name, batch_name, initial_capital, stage FROM public.investment_records;
--
-- 4. Check partner investments status:
-- SELECT investment_id, batch_id, amount, status FROM public.investments;
