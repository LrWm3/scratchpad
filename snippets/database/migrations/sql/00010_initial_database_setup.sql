--
-- Example database setup
--

-- Extensions
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

-- Speed up; see: https://github.com/pgvector/pgvector#exact-search
SET max_parallel_workers_per_gather = 4;

-- Schemas
CREATE SCHEMA IF NOT EXISTS embeddings;

-- Tables
CREATE TABLE IF NOT EXISTS embeddings.document_source (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS embeddings.document_source_half_life_setting (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id uuid NOT NULL REFERENCES embeddings.document_source(id),
    vector_half_life INTERVAL NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS embeddings.document (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id uuid NOT NULL REFERENCES embeddings.document_source(id),
    link TEXT NOT NULL,
    md5_hash uuid NOT NULL,
    metadata JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS embeddings.document_chunk_embedding (
    id uuid DEFAULT uuid_generate_v4(),
    source_id uuid NOT NULL REFERENCES embeddings.document_source(id),
    document_id uuid NOT NULL REFERENCES embeddings.document(id),
    chunk_start BIGINT NOT NULL,
    chunk_end BIGINT NOT NULL,
    embedding vector NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS embeddings.document_content (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id uuid NOT NULL REFERENCES embeddings.document(id),
    content TEXT NOT NULL
);

-- Create default document sources
INSERT INTO embeddings.document_source (name) VALUES ('slack');
INSERT INTO embeddings.document_source (name) VALUES ('confluence');
INSERT INTO embeddings.document_source (name) VALUES ('jira');
INSERT INTO embeddings.document_source (name) VALUES ('bitbucket');

-- Set up half life settings
-- Slack has a 60 day half life
WITH source_id AS (
    SELECT id FROM embeddings.document_source WHERE name = 'slack'
) INSERT INTO embeddings.document_source_half_life_setting (source_id, vector_half_life) VALUES ((SELECT id FROM source_id), '30 days');
-- Confluence has a 120 day half life
WITH source_id AS (
    SELECT id FROM embeddings.document_source WHERE name = 'confluence'
) INSERT INTO embeddings.document_source_half_life_setting (source_id, vector_half_life) VALUES ((SELECT id FROM source_id), '120 days');
-- Jira has a 120 day half life
WITH source_id AS (
    SELECT id FROM embeddings.document_source WHERE name = 'jira'
) INSERT INTO embeddings.document_source_half_life_setting (source_id, vector_half_life) VALUES ((SELECT id FROM source_id), '120 days');
-- Bitbucket is special and has a half life of 10 years
WITH source_id AS (
    SELECT id FROM embeddings.document_source WHERE name = 'bitbucket'
) INSERT INTO embeddings.document_source_half_life_setting (source_id, vector_half_life) VALUES ((SELECT id FROM source_id), '10 years');

-- Insert example document for slack
-- Shows how to insert a document and a vector for it
-- WITH source_id AS (
--     SELECT id FROM embeddings.document_source WHERE name = 'slack'
-- ) INSERT INTO embeddings.document (
--     source_id,
--     link,
--     metadata,
--     md5_hash,
--     created_at,
--     updated_at) 
-- VALUES (
--     (SELECT id FROM source_id),
--     'https://reeldata-workspace.slack.com/archives/D01L3JJMH0U/p1686768673177919',
--     '{"title": "Slack"}',
--     md5('https://reeldata-workspace.slack.com/archives/D01L3JJMH0U/p1686768673177919')::uuid,
--     NOW(),
--     NOW());
-- 
-- Insert example vector for slack
-- WITH source_id AS (
--     SELECT id FROM embeddings.document_source WHERE name = 'slack'
-- ), doc_id AS (
--     SELECT id FROM embeddings.document WHERE source_id = (SELECT id FROM source_id) AND link = 'https://reeldata-workspace.slack.com/archives/D01L3JJMH0U/p1686768673177919'    
-- ) INSERT INTO embeddings.document_chunk_embedding 
--     (source_id, document_id, chunk_start, chunk_end, embedding, updated_at)
-- VALUES (
--     (SELECT id FROM source_id),
--     (SELECT id FROM doc_id),
--     10,
--     20,
--     '[1,2,3]',
--     NOW()
-- );
-- 
-- -- Example of using cosign similarity to find similar documents and retrieve 
-- SELECT (1 - (embedding <=> '[3,1,2]')) AS similarity, embeddings.document_source.name, embeddings.document.link, metadata
-- FROM embeddings.document_chunk_embedding
-- JOIN embeddings.document_source ON embeddings.document_source.id = embeddings.document_chunk_embedding.source_id
-- JOIN embeddings.document ON embeddings.document.id = embeddings.document_chunk_embedding.document_id;
-- 
