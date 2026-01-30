-- Add details column to notes table for storing metadata and large payloads like voice blobs
ALTER TABLE notes ADD COLUMN IF NOT EXISTS details JSONB;

-- Create index for faster jsonb querying if needed in future
CREATE INDEX IF NOT EXISTS idx_notes_details ON notes USING gin (details);
