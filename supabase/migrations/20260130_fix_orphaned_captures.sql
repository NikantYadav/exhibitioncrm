-- Update captures table to CASCADE on contact deletion instead of SET NULL
-- This prevents "Unknown" captures from appearing after a contact is deleted

-- 1. Remove existing orphaned captures that were left as "Unknown"
DELETE FROM captures 
WHERE contact_id IS NULL AND status = 'completed';

-- 2. Update the foreign key constraint
ALTER TABLE captures
DROP CONSTRAINT IF EXISTS captures_contact_id_fkey,
ADD CONSTRAINT captures_contact_id_fkey 
  FOREIGN KEY (contact_id) 
  REFERENCES contacts(id) 
  ON DELETE CASCADE;
