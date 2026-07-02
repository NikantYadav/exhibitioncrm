This is different from INFRASTRCTURE_COSTS.md, that was an analysis done by AI. But this analysis has been done by me, by taking help from INFRASTRUCTURE_COSTS.md

### Fixed Costs

- Google Play Service:  $25
- Domain: $200/year
- Apple Developer: $99/year

### Infrastructure Costs

- Supabase (**Database + Auth + Storage + Realtime)**

$Formula (monthly):  25 + max(MAU-100000,0)×0.00325 + max(GB_egress-250,0)×0.09 + max(GB_db-8,0)×0.125 + max(GB_files-100,0)×0.021 + realtimeOverage$
    
    
    | Driver |  | Details | Experiment needed? | Code Changes Needed? |
    | --- | --- | --- | --- | --- |
    | **GB_Files** |  Cards (**`avg_card_MB` )** | 5MB hard cap per card | Log card scan image sizes, and get average |  |
    |  | Chat Attachments (**`avg_attachment_MB` )** | 15MB hard cap per file |  |  |
    |  | Contact Documents | 15MB hard cap per file, 
    total hard cap to be decided.  |  | Not wired in the frontend yet. |
    
    $GBfiles ≈ MAU × Months ofoperation × (cardsperuserpermonth × avgcardMB + attachmentsperuserpermo × avgattachmentMB + MAU*Totalcontactdocumentcap) / 1024$
    
    | Driver |  | Details | Experiment needed? | Code Changes Needed? |
    | --- | --- | --- | --- | --- |
    | GB_egress | initial + delta sync of ~10 tables (a few MB of rows) + viewing card images and chat attachments (each viewed file ≈ its stored size, possibly re-fetched after the 1-hr signed URL expires) + realtime deltas. | `initial_sync_payload` (one fresh login's `catchUpAll` ) and a realtime delta | measure the components locally on one device with the browser/dio network inspector |  |
    
    egress/user ≈ initial_sync_payload + (cards_viewed × avg_card_MB) + (attachments_viewed × avg_attachment_MB) + realtime_deltas
    
    GB_egress ≈ MAU × 0.1 GB/mo
    
    | Driver |  | Details | Experiment needed? | Code Changes Needed? |
    | --- | --- | --- | --- | --- |
    | GB_db | **`bytes_per_contact`** |  | create ~20 contacts + their captures/enrichments by hand in a local/staging DB, then `SELECT pg_total_relation_size('contacts') / count(*) FROM contacts;` (repeat per heavy table). True bytes/row incl. indexes & TOAST — no real users required. |  |
    | **`contacts_per_user_per_mo`** |  |  | estimate this |  |
    
    GB_db ≈ MAU × contacts_per_user_per_mo × bytes_per_contact × M_months / 1e9
    
    M_months = months of operation
    
    | Driver |  | Details | Experiment needed? | Code Changes Needed? |
    | --- | --- | --- | --- | --- |
    | **Realtime** | **`peak_concurrent_users`** |  | estimate |  |
    |  | **`fraction_in_chat`** | fraction of users using chat | estimate |  |
    
    peak_connections ≈ peak_concurrent_users × (1 +1·fraction_in_chat) realtime_overage = max(peak_connections − 500, 0) / 1000 × 10
    

- **Google Gemini API**
    
    model usage - gemini flash 3.5 or 2.5 and gemini-embedding-001
    
    **Cost variables:** cards scanned, voice clips transcribed, enrichments, assistant messages, tool steps per message, prompt+schema+history token size, audio length (multimodal tokens).
    
     **Formula (monthly):** `(input_tokens/1e6 * input_tokens_cost) + (output_tokens/1e6 * output_tokens_cost)` where `input_tokens ≈ (cards * card_prompt) + (voice_clips * audio_tokens) + (enrichments * enrich_prompt) + (assistant_msgs * steps * avg_prompt)`.
    
    Add logging for tokens
    

- **Exa Search API**
    
    Drivers: `contact_enrich/mo`, `company_enrich/mo`, `event_preps/mo`, `assistant_web_searches/mo`
    
    searches = 2·contact_enrich + 2·company_enrich + ~1.5·event_preps + ~1.5·assistant_searches 
    
    cost = max(searches − 20000, 0) × $0.007
    

- Deployment - A server that hosts both the backend and slayer.