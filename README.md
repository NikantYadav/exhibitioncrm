# Exhibition Personal Assistant + Relationship Memory CRM

A comprehensive personal assistant for exhibitions and meetings that captures leads, remembers interactions, enriches data with AI, and integrates with Excel.

## Features

- 📸 **Exhibition Capture Mode**: Scan business cards, QR codes, and capture notes offline
- 🤖 **AI Lead Enrichment**: Automatic company research and data enrichment
- 📧 **Smart Follow-ups**: AI-generated personalized emails
- 🎯 **Pre-Event Research**: Company research and target list creation
- 💼 **Meeting Intelligence**: Pre-meeting briefs with interaction history
- 📊 **Excel Integration**: Export/import contacts and companies
- 📱 **Mobile-First**: Fully responsive, touch-optimized, camera access
- 🔄 **Offline Support**: Works without internet, syncs when online

## Tech Stack

- **Frontend**: Next.js 14+ with TypeScript
- **Database**: Supabase (PostgreSQL)
- **AI**: LiteLLM (supports OpenAI, Gemini, Claude, etc.)
- **OCR**: Tesseract.js
- **Styling**: Vanilla CSS with modern design

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env.local
```

Add your Supabase and AI API credentials.

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000)

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=https://ezammzqvbjgpuzleqmla.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# At least one AI provider is required
OPENAI_API_KEY=your_openai_api_key
GEMINI_API_KEY=your_gemini_api_key
```

## License

MIT
