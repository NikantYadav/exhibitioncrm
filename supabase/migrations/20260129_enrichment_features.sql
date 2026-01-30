-- Enrichment Features Migration
-- Migration: 20260129_enrichment_features
-- Description: Add enrichment tracking columns to contacts table

-- Add enrichment tracking columns
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS enrichment_status TEXT DEFAULT 'pending';
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS enrichment_confidence JSONB;
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS enrichment_suggestions JSONB;
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS last_enriched_at TIMESTAMPTZ;

-- Add index for enrichment status queries
CREATE INDEX IF NOT EXISTS idx_contacts_enrichment_status ON contacts(enrichment_status);
