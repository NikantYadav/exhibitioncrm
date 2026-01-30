-- Phase 1 & 2 Database Schema Updates
-- Migration: 20260128_phase1_phase2_features

-- ============================================
-- Phase 1: Email Attachments
-- ============================================

-- Attachments Table
CREATE TABLE IF NOT EXISTS attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email_draft_id UUID REFERENCES email_drafts(id) ON DELETE CASCADE,
  interaction_id UUID REFERENCES interactions(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_type TEXT,
  file_size INTEGER,
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attachments_email_draft ON attachments(email_draft_id);
CREATE INDEX IF NOT EXISTS idx_attachments_interaction ON attachments(interaction_id);

-- ============================================
-- Phase 1: Document Summarization
-- ============================================

-- Add AI summary fields to documents table
ALTER TABLE documents 
ADD COLUMN IF NOT EXISTS ai_summary TEXT,
ADD COLUMN IF NOT EXISTS summary_generated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS summary_model TEXT,
ADD COLUMN IF NOT EXISTS summary_confidence DECIMAL(3,2);

-- ============================================
-- Phase 2: Meeting Briefs
-- ============================================

-- Meeting Briefs Table
CREATE TABLE IF NOT EXISTS meeting_briefs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  meeting_date TIMESTAMPTZ NOT NULL,
  meeting_type TEXT DEFAULT 'in_person', -- in_person, virtual, phone
  meeting_location TEXT,
  ai_talking_points TEXT,
  interaction_summary TEXT,
  pre_meeting_notes TEXT,
  post_meeting_notes TEXT,
  action_items JSONB,
  status TEXT DEFAULT 'scheduled', -- scheduled, completed, cancelled, rescheduled
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_briefs_contact ON meeting_briefs(contact_id);
CREATE INDEX IF NOT EXISTS idx_meeting_briefs_company ON meeting_briefs(company_id);
CREATE INDEX IF NOT EXISTS idx_meeting_briefs_event ON meeting_briefs(event_id);
CREATE INDEX IF NOT EXISTS idx_meeting_briefs_date ON meeting_briefs(meeting_date);
CREATE INDEX IF NOT EXISTS idx_meeting_briefs_status ON meeting_briefs(status);

-- ============================================
-- Phase 2: Automated Reminders
-- ============================================

-- Reminders Table
CREATE TABLE IF NOT EXISTS reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  meeting_brief_id UUID REFERENCES meeting_briefs(id) ON DELETE CASCADE,
  reminder_type TEXT NOT NULL, -- follow_up, meeting, event, custom
  reminder_date TIMESTAMPTZ NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  priority TEXT DEFAULT 'medium', -- low, medium, high
  status TEXT DEFAULT 'pending', -- pending, sent, completed, snoozed, cancelled
  sent_at TIMESTAMPTZ,
  snoozed_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reminders_contact ON reminders(contact_id);
CREATE INDEX IF NOT EXISTS idx_reminders_meeting_brief ON reminders(meeting_brief_id);
CREATE INDEX IF NOT EXISTS idx_reminders_date ON reminders(reminder_date);
CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status);
CREATE INDEX IF NOT EXISTS idx_reminders_type ON reminders(reminder_type);

-- ============================================
-- Phase 2: Company Research Cache
-- ============================================

-- Company Research Table (caching AI research results)
CREATE TABLE IF NOT EXISTS company_research (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  research_type TEXT NOT NULL, -- overview, industry, competitors, news
  research_data JSONB NOT NULL,
  sources JSONB, -- URLs and references
  confidence_score DECIMAL(3,2),
  expires_at TIMESTAMPTZ, -- Cache expiration
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, research_type)
);

CREATE INDEX IF NOT EXISTS idx_company_research_company ON company_research(company_id);
CREATE INDEX IF NOT EXISTS idx_company_research_type ON company_research(research_type);
CREATE INDEX IF NOT EXISTS idx_company_research_expires ON company_research(expires_at);

-- ============================================
-- Triggers for updated_at
-- ============================================

CREATE TRIGGER update_attachments_updated_at BEFORE UPDATE ON attachments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meeting_briefs_updated_at BEFORE UPDATE ON meeting_briefs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reminders_updated_at BEFORE UPDATE ON reminders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_research_updated_at BEFORE UPDATE ON company_research
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Helper Views
-- ============================================

-- View for upcoming meetings with contact details
CREATE OR REPLACE VIEW upcoming_meetings AS
SELECT 
  mb.*,
  c.first_name,
  c.last_name,
  c.email,
  c.job_title,
  co.name as company_name,
  co.industry
FROM meeting_briefs mb
LEFT JOIN contacts c ON mb.contact_id = c.id
LEFT JOIN companies co ON mb.company_id = co.id
WHERE mb.status = 'scheduled' 
  AND mb.meeting_date >= NOW()
ORDER BY mb.meeting_date ASC;

-- View for pending reminders
CREATE OR REPLACE VIEW pending_reminders AS
SELECT 
  r.*,
  c.first_name,
  c.last_name,
  c.email,
  mb.meeting_date
FROM reminders r
LEFT JOIN contacts c ON r.contact_id = c.id
LEFT JOIN meeting_briefs mb ON r.meeting_brief_id = mb.id
WHERE r.status = 'pending'
  AND r.reminder_date <= NOW() + INTERVAL '7 days'
ORDER BY r.reminder_date ASC;
