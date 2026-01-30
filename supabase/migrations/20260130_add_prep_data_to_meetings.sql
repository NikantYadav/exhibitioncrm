-- Add prep_data column to meeting_briefs table
ALTER TABLE meeting_briefs 
ADD COLUMN IF NOT EXISTS prep_data JSONB;

-- Comment on column for clarity
COMMENT ON COLUMN meeting_briefs.prep_data IS 'Structured AI-generated preparation context for the meeting';
