-- Memory System Migration
-- Migration: 20260129_memory_system
-- Description: Add support for unified logging and document memory

-- Add references to interactions table
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS meeting_id UUID; -- Reference to meetings (if we had a meetings table, but we might just use events with type=meeting)
ALTER TABLE interactions ADD COLUMN IF NOT EXISTS document_id UUID; -- Reference to documents

-- Create Documents table for contact-specific files
-- Note: There was a documents table in initial schema, checking if it needs updates or if we should create a new one.
-- The initial schema had a 'documents' table. We will enhance it or assume it exists.
-- Re-creating/Enhancing documents table to be sure it has what we need
CREATE TABLE IF NOT EXISTS contact_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  file_type TEXT,
  file_size BIGINT,
  summary TEXT, -- AI Summary of the document
  key_points JSONB, -- Extracted key points
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for documents
CREATE INDEX IF NOT EXISTS idx_contact_documents_contact ON contact_documents(contact_id);

-- Trigger for updated_at
CREATE TRIGGER update_contact_documents_updated_at BEFORE UPDATE ON contact_documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
