# Implementation Plan: Contact Documents — pure file storage (NO AI)

**Audience:** Sonnet 4.6 implementing agent. Follow exactly. Do NOT improvise identifiers — every table/column/route/bucket name here was verified against the live DB + code on 2026-07-01. If a cited line number is off (files shift), grep for the cited symbol instead.

**Purpose (important — keep scope tight):** This is a **plain storage space** where a user keeps links/files a contact shared with them. **There is NO AI involvement** — no text extraction, no embeddings, no RAG, no summaries, no assistant tool. Do not add any of those. If you find yourself importing `document-extraction.ts`, `litellm`, or touching `document_chunks` / `match_*` RPCs / the assistant, you have gone out of scope — stop.

**Project ref for all Supabase MCP calls:** `ezammzqvbjgpuzleqmla`

**Upload path decision (already made):** files go **through the backend** (multipart → backend stores via service role in a private bucket → row inserted). Mirrors how `chat-attachments` and `contact-cards` already work. NOT direct client→Storage.

---

## 0. Background: what exists today (verified — do not re-derive)

Three similar-sounding things; keep distinct:

1. **`contacts.contact_assets`** (jsonb, default `'[]'`). A list of `{type, title, url}` objects shown by the "Links & Files" sheet ([exono/lib/screens/contact_links_files_sheet.dart](exono/lib/screens/contact_links_files_sheet.dart)). **Links (`type:'link'`) stay here, unchanged.** The sheet's current **ADD FILE** button (`_addFile`, ~line 267) is a hack: it picks a gallery **image** via `image_picker` and uploads it to the **`contact-avatars`** bucket, then appends a `ContactAsset(type:'file')` to this jsonb array. We are REPLACING that file hack with real document storage. The link half is untouched.

2. **`contact_documents`** table (0 rows, RLS on). Verified columns:
   `id uuid pk`, `contact_id uuid fk->contacts.id`, `name text NOT NULL`, `description text`, `file_url text NOT NULL`, `file_type text`, `file_size bigint`, `summary text`, `key_points jsonb`, `created_at`, `updated_at`. **No `user_id` column.** RLS policies already scope it via `contact_id -> contacts.user_id` (verified policies: `contact_documents_select_own/insert_own/update_own/delete_own`, all checking `EXISTS(select 1 from contacts c where c.id = contact_documents.contact_id and c.user_id = auth.uid())`, plus a `slayer_readonly_select` policy `qual=true` for the read-only AI DB role). The backend route [backend/src/routes/documents.ts](backend/src/routes/documents.ts) is a **dead stub** (`POST /` inserts a client-supplied `file_url` string only — no multer, no bucket). No Flutter code calls it.
   - `summary` / `key_points` columns exist but are AI-era leftovers. We are NOT using them. Leave them in the table (don't drop), just never write them.

3. **No `contact-documents` Storage bucket exists** (verified: only `chat-attachments`, `contact-avatars`, `contact-cards`). We create one.

**Storage write pattern to copy (for mechanics ONLY, ignore its extraction/RAG parts):** [backend/src/routes/conversations.ts](backend/src/routes/conversations.ts) `POST /:id/attachments/upload` (~line 258) shows: multer memoryStorage + 15MB limit, server-generated path `userId/.../randomUUID().ext`, `supabaseAdmin.storage.from(bucket).upload(...)`, then `createSignedUrl`. Copy ONLY those storage mechanics. Skip everything from its line ~342 onward (the extraction/embedding block) — not in scope.

---

## What the user asked for (deliverables)
1. A private `contact-documents` bucket + real backend upload/list/delete, storing files a contact shared.
2. Flutter: the existing **ADD FILE** button uploads a real file (any allowed type) into this storage; the sheet lists files (open / delete). Links stay as-is.
3. Stop misusing the `contact-avatars` bucket for files (it's for avatars only).

---

## PART A — Database (Supabase MCP `apply_migration`, project `ezammzqvbjgpuzleqmla`)

### A.1 Create the private `contact-documents` bucket
NO bucket exists yet. Create a **private** one (do NOT make public):

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'contact-documents', 'contact-documents', false,
  15728640,  -- 15 MB
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/msword','application/vnd.ms-excel','application/vnd.ms-powerpoint',
    'text/csv','text/plain',
    'image/jpeg','image/png','image/webp',
    'application/zip','application/octet-stream'
  ]
)
on conflict (id) do nothing;
```
> The backend uses `supabaseAdmin` (service role) for storage ops, which bypasses storage RLS — so NO storage.objects policies are needed for the app to function. Do NOT add public-read policies (these are private). `application/octet-stream` is included so odd-but-legitimate file types from `file_picker` aren't rejected at the bucket layer (the 15 MB limit + the app's extension allowlist are the real guards).

### A.2 Add a durable storage pointer + owner to `contact_documents`
The table has `file_url` but a signed URL expires (1 h), so we need the durable storage location to re-sign and to delete. Also add `user_id` so a row carries its owner explicitly (cheaper, clearer ownership than the join everywhere).

```sql
alter table public.contact_documents
  add column if not exists user_id uuid references auth.users(id),
  add column if not exists bucket text,
  add column if not exists storage_path text;
```
- `bucket` + `storage_path`: durable pointer (e.g. `'contact-documents'`, `'<userId>/<contactId>/<uuid>.pdf'`). `file_url` keeps a freshly-signed URL for display only.
- `user_id`: stamp from `req.user!.id` server-side ONLY. Never from client input.
- Do NOT add extraction/status columns. Not in scope.

### A.3 Do NOT touch `document_chunks`, `match_document_chunks`, or any RPC. No AI = no RAG schema changes.

### A.4 Verify
- `list_tables` (verbose) → confirm `contact_documents` now has `user_id`, `bucket`, `storage_path`.
- `list_storage_buckets` → confirm `contact-documents` exists, `public=false`.
- No schema-drift bookkeeping needed: `contact_documents` is NOT in the drift-check's writable-table set (only contacts/events/email_drafts are), and we are not changing how the AI reads it. (`USER_ID_TABLES` auto-derives `user_id` at next boot; that's automatic and harmless.)

---

## PART B — Backend: rewrite `backend/src/routes/documents.ts`. Verify with `npx tsc --noEmit` from `backend/`.

Keep the existing `ownsContact(db, userId, contactId)` helper (lines 7–16) — it's correct, reuse it. Keep `POST /summarize` deleted/removed (it was AI; remove it — see B.5). Replace the rest.

### B.1 Imports to add at top of `documents.ts`
```ts
import multer from 'multer';
import { randomUUID } from 'crypto';
import { supabase as supabaseAdmin } from '../config/supabase';
import {
  checkScopedRateLimit, DOC_UPLOAD_SCOPE, DOC_UPLOAD_MAX, DOC_UPLOAD_WINDOW_MS,
} from '../utils/rateLimit';
```
> Verify these rate-limit symbols exist in `backend/src/utils/rateLimit.ts` (they do — `conversations.ts` imports them). Do NOT import `document-extraction`, `litellm`, `imageValidation`, or `imageCompression` — out of scope (we store the file as-is; no recompression, no sniff-based extraction). Storing as-is is fine for a passive file vault.

Add multer:
```ts
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 15 * 1024 * 1024 } });
const DOC_BUCKET = 'contact-documents';
```

### B.2 `POST /` — real multipart upload (replaces the dead stub at lines 18–71)
`multipart/form-data` with fields: `file` (required), `contact_id` (uuid, required), `description` (optional).

```
router.post('/', upload.single('file'), async (req, res) => {
  try {
    const supabase = req.supabase!;          // user client (RLS) for the DB row
    const userId = req.user!.id;
    const { contact_id, description } = req.body;
    if (!contact_id) return 400 'contact_id required';
    if (!req.file) return 400 'Missing file';

    // ownership (defense-in-depth; RLS also enforces)
    if (!(await ownsContact(supabase, userId, contact_id))) return 403 'Forbidden';

    // rate limit (each upload is a storage write)
    const rate = await checkScopedRateLimit(userId, DOC_UPLOAD_SCOPE, DOC_UPLOAD_MAX, DOC_UPLOAD_WINDOW_MS);
    if (!rate.ok) { res.setHeader('Retry-After', String(rate.retryAfterSeconds)); return 429 'Too many uploads...'; }

    // server-generated path (NEVER client-controlled) — mirrors conversations.ts ext IIFE
    const original = req.file.originalname || 'file';
    const ext = (() => {
      const idx = original.lastIndexOf('.');
      if (idx === -1) return '';
      const e = original.slice(idx).toLowerCase();
      return /^[.][a-z0-9]{1,10}$/.test(e) ? e : '';
    })();
    const storage_path = `${userId}/${contact_id}/${randomUUID()}${ext}`;

    // store via service role (private bucket)
    const { error: upErr } = await supabaseAdmin.storage.from(DOC_BUCKET)
      .upload(storage_path, req.file.buffer, { contentType: req.file.mimetype, upsert: false });
    if (upErr) return 500 upErr.message;

    // signed URL for immediate display
    const { data: signed } = await supabaseAdmin.storage.from(DOC_BUCKET).createSignedUrl(storage_path, 60 * 60);

    // insert row via user client (RLS-checked)
    const { data: doc, error } = await supabase.from('contact_documents').insert({
      contact_id,
      user_id: userId,
      name: original,
      description: description ?? null,
      file_url: signed?.signedUrl ?? '',
      file_type: ext.replace('.', ''),
      file_size: req.file.size,
      bucket: DOC_BUCKET,
      storage_path,
    }).select('*').single();
    if (error) {
      // best-effort rollback of the stored object so we don't orphan it
      await supabaseAdmin.storage.from(DOC_BUCKET).remove([storage_path]);
      return 500 'Failed to save document';
    }

    // NO interaction logging. Do NOT insert an `interactions` row on upload — the
    // old stub did (lines 54-64); that behavior is intentionally removed. This is
    // a passive file vault; an upload is not a contact interaction.

    res.json({ success: true, document: doc });
  } catch (e) { console.error('Documents upload error:', e); res.status(500).json({ error: 'Internal server error' }); }
});
```

### B.3 `GET /` — list + re-sign (the current handler returns rows with stale URLs)
Keep the ownership check. After fetching rows, re-sign each row's `storage_path` (signed URLs expire) and overwrite `file_url`:
```
router.get('/', async (req, res) => {
  const supabase = req.supabase!;
  const { contact_id } = req.query;
  if (!contact_id) return 400;
  if (!(await ownsContact(supabase, req.user!.id, contact_id as string))) return 403;
  const { data: documents, error } = await supabase.from('contact_documents')
    .select('*').eq('contact_id', contact_id).order('created_at', { ascending: false });
  if (error) return 500;
  const withUrls = await Promise.all((documents ?? []).map(async (d) => {
    if (!d.storage_path || !d.bucket) return d;  // defensive; post-migration all have it
    const { data: s } = await supabaseAdmin.storage.from(d.bucket).createSignedUrl(d.storage_path, 60 * 60);
    return { ...d, file_url: s?.signedUrl ?? d.file_url };
  }));
  res.json({ documents: withUrls });
});
```

### B.4 `DELETE /:id` — new
```
router.delete('/:id', async (req, res) => {
  const supabase = req.supabase!;
  const { data: doc } = await supabase.from('contact_documents')
    .select('id, contact_id, bucket, storage_path').eq('id', req.params.id).maybeSingle();
  if (!doc) return 404;
  if (!(await ownsContact(supabase, req.user!.id, doc.contact_id))) return 403;
  if (doc.storage_path && doc.bucket) {
    await supabaseAdmin.storage.from(doc.bucket).remove([doc.storage_path]); // best-effort
  }
  const { error } = await supabase.from('contact_documents').delete().eq('id', req.params.id);
  if (error) return 500;
  res.json({ success: true });
});
```
> The DB delete via `req.supabase!` is RLS-scoped, so a foreign id matches zero rows — but we also fetched + ownsContact-checked first, so this is doubly safe.

### B.5 Remove the AI bits from `documents.ts`
- DELETE the `POST /summarize` handler (lines ~102–148) and the `import { AIService } from '../config/ai';` line — AI is out of scope. Confirm via grep that nothing else imports from this route's summarize endpoint (the Flutter app never called it).
- Do NOT add `parse_contact_document` or any assistant tool. The AI does not read these files.

### B.6 Verify backend
- `npx tsc --noEmit` → clean.
- `npm run check:schema-drift` → clean.
- grep: `AIService` no longer referenced in `documents.ts`; `multer`, `DOC_BUCKET`, `createSignedUrl` are.

---

## PART C — Flutter (`exono/`). Verify with `flutter analyze <file>` from `exono/`.

### C.1 `ApiService` — three methods ([exono/lib/services/api_service.dart](exono/lib/services/api_service.dart))
Use the EXISTING multipart pattern from `importContacts` (lines ~1098–1113) for upload; standard `_send`/`_headers`/`checkUnauthorized` for GET/DELETE. Route is mounted at `/documents` (`backend/src/routes/index.ts` line 42).

```dart
static Future<Map<String, dynamic>> uploadContactDocument(
    String contactId, Uint8List fileBytes, String fileName, {String? description}) async {
  final uri = Uri.parse('${ApiConfig.baseUrl}/documents');
  final request = http.MultipartRequest('POST', uri);
  final hdrs = await _headers();
  if (hdrs.containsKey('Authorization')) request.headers['Authorization'] = hdrs['Authorization']!;
  request.fields['contact_id'] = contactId;
  if (description != null && description.isNotEmpty) request.fields['description'] = description;
  request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
  final streamed = await request.send();
  final body = await streamed.stream.bytesToString();
  if (streamed.statusCode == 401) throw UnauthorizedException();
  if (streamed.statusCode == 200) return (json.decode(body))['document'] as Map<String, dynamic>;
  throw Exception('Upload failed');
}

static Future<List<Map<String, dynamic>>> getContactDocuments(String contactId) async {
  final response = await _send(() async => http.get(
    Uri.parse('${ApiConfig.baseUrl}/documents?contact_id=$contactId'), headers: await _headers()));
  checkUnauthorized(response);
  if (response.statusCode == 200) {
    final body = json.decode(response.body);
    return (body['documents'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  throw Exception('Failed to load documents');
}

static Future<void> deleteContactDocument(String documentId) async {
  final response = await _send(() async => http.delete(
    Uri.parse('${ApiConfig.baseUrl}/documents/$documentId'), headers: await _headers()));
  checkUnauthorized(response);
  if (response.statusCode != 200) throw Exception('Delete failed');
}
```
> Confirm `UnauthorizedException` is the symbol used in this file (it is — see `_addFile`'s `on UnauthorizedException`). Confirm `Uint8List` import exists (`dart:typed_data` is imported, line 3). If `ApiConfig` has no documents constant, hardcode `/documents` as shown.

### C.2 Rewire ADD FILE in `contact_links_files_sheet.dart` → real document upload
Change ONLY the file path; leave links alone.

1. **Imports:** add `import 'package:file_picker/file_picker.dart';`. After replacing `_addFile`, remove `import 'package:image_picker/image_picker.dart';` (grep-confirm `_addFile` was its only user in this file). Also grep `Supabase`/`supabase_flutter` in this file — if the old `_addFile`'s direct Storage upload was its only use, remove that import too; if used elsewhere, keep it.

2. **State** (in `_ContactLinksFilesSheetState`):
   ```dart
   List<Map<String, dynamic>> _documents = [];
   bool _loadingDocs = true;
   ```
   Add `@override void initState()` calling `_loadDocuments()`:
   ```dart
   Future<void> _loadDocuments() async {
     try {
       final docs = await ApiService.getContactDocuments(widget.contactId);
       if (mounted) setState(() { _documents = docs; _loadingDocs = false; });
     } on UnauthorizedException { rethrow; }
     catch (_) { if (mounted) setState(() => _loadingDocs = false); }
   }
   ```

3. **Replace `_addFile()`** (lines ~267–303) entirely:
   ```dart
   Future<void> _addFile() async {
     final result = await FilePicker.platform.pickFiles(
       allowMultiple: false, withData: true, type: FileType.custom,
       allowedExtensions: const ['pdf','doc','docx','ppt','pptx','xls','xlsx','csv','txt','jpg','jpeg','png','webp'],
     );
     if (result == null || result.files.isEmpty) return;
     final f = result.files.first;
     final bytes = f.bytes;
     if (bytes == null || !mounted) return;
     setState(() => _uploading = true);
     try {
       final doc = await ApiService.uploadContactDocument(widget.contactId, bytes, f.name);
       if (mounted) setState(() { _documents.insert(0, doc); _uploading = false; });
     } on UnauthorizedException { rethrow; }
     catch (_) { if (mounted) { setState(() => _uploading = false); showAppToast(context, 'Upload failed. Please try again.'); } }
   }
   ```
   (Extension list mirrors the chat picker at [exono/lib/widgets/exo_chat_view.dart](exono/lib/widgets/exo_chat_view.dart) ~line 487, plus `txt`.)

4. **UI — show a Documents section.** The `Expanded` child in `build` currently is `_assets.isEmpty ? _buildEmptyState() : _buildAssetList()`. Replace with a single scrollable column containing TWO parts:
   - **Documents** (from `_documents`): if `_loadingDocs` show a centered `FCircularProgress()`; else a list of `AppCard` rows, each showing `doc['name']` (bold), a subtitle = `doc['file_type']?.toUpperCase()` + size if present, an open-tap, and a delete button. Tap → open `doc['file_url']` via the EXISTING `_openAsset`-style `launchUrl` with the `_allowedUrlSchemes` guard (lines 242–259) — `file_url` is an `https` signed URL so it passes. Delete → `await ApiService.deleteContactDocument(doc['id']); setState(remove)` (wrap try/catch + toast on failure).
   - **Links** (existing `_buildAssetList`, but it now effectively only renders `type:'link'` items since file-add is gone). Keep `_buildAssetList` for these.
   Match the existing card styling in `_buildAssetList` (lines 173–240). Use ONLY `App*` wrappers + theme tokens already in this file — do NOT drop to raw forui/Material.

5. **Bottom buttons** (lines ~111–131): KEEP both ADD LINK and ADD FILE. ADD FILE now calls the new `_addFile`. No other change.

6. **Return value / persistence:** documents persist immediately via their own API calls (upload/delete), NOT through `contact_assets`. The sheet still returns `_assets` (links) on close, round-tripped by `_openLinksFiles` in `contact_detail_screen.dart` (line ~336) into `contacts.contact_assets` — that path is unchanged. Do NOT put documents into `_assets`.

### C.3 Avatars cleanup verification
After C.2, nothing in Flutter uploads files into `contact-avatars`. Verify: `grep -rn "contact-avatars" exono/lib` — remaining hits must be genuine avatar reads/writes only. Do NOT delete the bucket or touch `avatar_url` logic. If a non-avatar file write remains, report it; don't fix out of scope.

### C.4 Verify Flutter
`flutter analyze lib/screens/contact_links_files_sheet.dart lib/services/api_service.dart lib/screens/contact_detail_screen.dart` → "No issues found". Resolve any unused-import warnings from removed `image_picker`/`supabase_flutter`.

---

## PART D — Final verification checklist
1. `cd backend && npx tsc --noEmit` → clean.
2. `cd backend && npm run check:schema-drift` → clean.
3. `cd exono && flutter analyze lib/screens/contact_links_files_sheet.dart lib/services/api_service.dart lib/screens/contact_detail_screen.dart` → clean.
4. MCP `list_storage_buckets` → `contact-documents` exists, `public=false`.
5. MCP `list_tables` verbose → `contact_documents` has `user_id`, `bucket`, `storage_path`.
6. grep → `documents.ts` no longer imports `AIService`; the file vault has POST(multipart)/GET/DELETE.

---

## Hard DON'Ts (anti-hallucination / scope guards)
- NO AI. Do NOT touch `document_chunks`, `match_document_chunks`, `document-extraction.ts`, `litellm`, the assistant, the system prompt, or add any tool. This is passive storage.
- Do NOT make `contact-documents` public.
- Do NOT touch the chat-attachment path (`conversations.ts`, `message_attachments`) — only borrow its storage mechanics by reading, not editing it.
- Do NOT store `user_id` from client input — always `req.user!.id`.
- Do NOT remove/alter `contacts.contact_assets` or its LINK behavior; only the file-into-avatars hack is replaced.
- Do NOT drop the `summary`/`key_points` columns on `contact_documents` (leave them; just never write them).
- Do NOT log an `interactions` row on upload/delete (the old stub did — that is removed). No interaction logging at all.
- Do NOT hand-roll raw forui/Material in the sheet — use existing `App*` wrappers.
- If a cited line number is off, grep for the cited symbol/string instead of trusting it.
