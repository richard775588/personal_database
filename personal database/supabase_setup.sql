-- ============================================================
-- Supabase setup for the Personal Knowledge Base Assistant
-- Run this once in the Supabase dashboard -> SQL Editor.
--
-- Embeddings: Cohere embed-multilingual-v3.0  ->  1024 dimensions.
-- If you switch to a different embedding model, change vector(1024)
-- in BOTH the table and the function to match the new dimension.
-- ============================================================

-- 1. Enable the pgvector extension
create extension if not exists vector;

-- 2. Table that stores note chunks + their embeddings
create table if not exists documents (
  id        bigserial primary key,
  content   text,
  metadata  jsonb,
  embedding vector(1024)
);

-- 3. Similarity-search function used by the n8n Supabase Vector Store node.
--    Column references are qualified with the table name (documents.*) to
--    avoid the "column reference is ambiguous" (42702) error that occurs
--    when an output column name collides with a table column name.
create or replace function match_documents (
  query_embedding vector(1024),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
) language plpgsql as $$
begin
  return query
  select
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where documents.metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;
