-- User Profile Migration
-- Migration: 20260129_user_profile
-- Description: Add user_profiles table for storing company/individual information

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Profile Type
  profile_type TEXT NOT NULL DEFAULT 'company', -- company, individual, employee
  
  -- Basic Information
  name TEXT NOT NULL, -- Company name or individual name
  tagline TEXT, -- Short tagline or slogan
  industry TEXT,
  location TEXT,
  website TEXT,
  
  -- Business Details
  products_services TEXT, -- What they offer
  value_proposition TEXT, -- What makes them unique
  target_audience TEXT, -- Who they serve
  key_differentiators TEXT, -- What sets them apart from competitors
  
  -- Company-specific (optional)
  company_size TEXT, -- For company profiles
  founded_year INTEGER,
  
  -- Employee-specific (optional)
  employee_role TEXT, -- For employee profiles
  employee_department TEXT,
  representing_company TEXT, -- Company they represent
  
  -- Social Media & Contact
  linkedin_url TEXT,
  twitter_url TEXT,
  facebook_url TEXT,
  instagram_url TEXT,
  email TEXT,
  phone TEXT,
  
  -- AI Context
  additional_context TEXT, -- Free-form text for additional AI context
  ai_tone TEXT DEFAULT 'professional', -- professional, casual, formal, friendly
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_type ON user_profiles(profile_type);

-- Add trigger for updated_at
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert a default profile (can be updated by user)
INSERT INTO user_profiles (
  profile_type,
  name,
  tagline,
  industry,
  products_services,
  value_proposition,
  ai_tone
) VALUES (
  'company',
  'My Company',
  'Your company tagline',
  'Technology',
  'Describe your products or services',
  'What makes your company unique',
  'professional'
) ON CONFLICT DO NOTHING;
