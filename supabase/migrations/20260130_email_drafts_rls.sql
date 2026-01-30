-- Enable RLS on email_drafts table
ALTER TABLE email_drafts ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations for now (since we don't have auth yet)
-- In production, you'd want to restrict this to authenticated users
CREATE POLICY "Allow all operations on email_drafts" ON email_drafts
    FOR ALL
    USING (true)
    WITH CHECK (true);
