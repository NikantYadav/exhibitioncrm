-- Enable the pgvector extension to work with embedding vectors
create extension if not exists vector;

-- Create a table to store document chunks
create table if not exists document_chunks (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid references marketing_assets(id) on delete cascade,
  content text not null,
  embedding vector(768), -- Gemini embedding dimension is 768
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on the table
alter table document_chunks enable row level security;

-- Create a policy to allow authenticated users to view chunks
create policy "Allow read access to authenticated users"
  on document_chunks for select
  to authenticated
  using (true);

-- Create a policy to allow authenticated users to insert chunks
create policy "Allow insert access to authenticated users"
  on document_chunks for insert
  to authenticated
  with check (true);

-- Create a policy to allow authenticated users to delete chunks
create policy "Allow delete access to authenticated users"
  on document_chunks for delete
  to authenticated
  using (true);

-- Create a function to search for similar documents
create or replace function match_documents (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns table (
  id uuid,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    document_chunks.id,
    document_chunks.content,
    document_chunks.metadata,
    1 - (document_chunks.embedding <=> query_embedding) as similarity
  from document_chunks
  where 1 - (document_chunks.embedding <=> query_embedding) > match_threshold
  order by document_chunks.embedding <=> query_embedding
  limit match_count;
end;
$$;
