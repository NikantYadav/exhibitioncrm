-- Follow-Up System Migration
-- Migration: 20260129_followup_system
-- Description: Add follow-up tracking columns and marketing assets table

-- Add follow-up tracking to contacts
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS follow_up_status TEXT DEFAULT 'not_contacted'; -- not_contacted, needs_follow_up, followed_up, ignore
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS follow_up_urgency TEXT DEFAULT 'medium'; -- low, medium, high
ALTER TABLE contacts ADD COLUMN IF NOT EXISTS last_contacted_at TIMESTAMPTZ;

-- Marketing Assets Table (Brochures, PDFs, etc.)
CREATE TABLE IF NOT EXISTS marketing_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  asset_type TEXT DEFAULT 'brochure', -- brochure, catalog, whitepaper, other
  file_size BIGINT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_contacts_follow_up_status ON contacts(follow_up_status);
CREATE INDEX IF NOT EXISTS idx_marketing_assets_active ON marketing_assets(is_active);

-- Trigger for updated_at on marketing_assets
CREATE TRIGGER update_marketing_assets_updated_at BEFORE UPDATE ON marketing_assets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
