# Exhibition CRM - Setup Guide

## Quick Start

This is an MVP of an Exhibition Personal Assistant + Relationship Memory CRM system. Follow these steps to get started:

### 1. Install Dependencies

```bash
npm install
```

### 2. Set Up Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Run the migration file to create tables:
   - Go to SQL Editor in Supabase Dashboard
   - Copy and paste the contents of `supabase/migrations/20260122_initial_schema.sql`
   - Run the query

### 3. Configure Environment Variables

Create a `.env.local` file in the root directory:

```bash
cp .env.example .env.local
```

Edit `.env.local` and add your credentials:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
OPENAI_API_KEY=your_openai_api_key
```

### 4. Run the Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Features Implemented

✅ **Core Infrastructure**
- Next.js 14 with TypeScript
- Supabase database (10 tables)
- Mobile-first responsive design
- Offline support with sync queue

✅ **Services**
- AI integration (OpenAI with LiteLLM pattern)
- OCR for business card scanning (Tesseract.js)
- Excel export/import
- AI-powered lead enrichment
- AI email generation

✅ **Pages**
- Dashboard with quick actions
- Business card capture (camera, upload, manual, QR)
- Contacts list with search
- Events management
- Settings

✅ **API Routes**
- `/api/captures` - Business card processing
- `/api/contacts` - Contact management
- `/api/events` - Event management
- `/api/emails/draft` - AI email generation
- `/api/export` - Excel export
- `/api/import` - Excel import

## Mobile Features

- Touch-optimized UI (44px minimum tap targets)
- Camera access for card scanning
- Offline capture with background sync
- Responsive layouts (portrait/landscape)
- Swipe gestures support

## Next Steps

The MVP includes the foundation. To complete the full feature set:

1. **Pre-Exhibition Research** - Company research interface and target lists
2. **Post-Exhibition Follow-up** - Follow-up tracking and reminders
3. **Meeting Intelligence** - Pre-meeting briefs and post-meeting notes
4. **Relationship Memory** - Interaction timeline and history
5. **Additional CRM Integrations** - HubSpot, Zoho, Salesforce

## Tech Stack

- **Frontend**: Next.js 14, React, TypeScript
- **Database**: Supabase (PostgreSQL)
- **AI**: OpenAI (easily swappable via LiteLLM pattern)
- **OCR**: Tesseract.js
- **Excel**: ExcelJS
- **Styling**: Vanilla CSS with modern design system

## Architecture Highlights

- **Offline-First**: Local caching with background sync
- **AI-Assisted**: AI suggests, user approves
- **Mobile-Optimized**: Camera access, touch gestures
- **Extensible**: Easy to add more AI providers or CRM integrations

## Support

For issues or questions, check the implementation plan in the brain directory.
