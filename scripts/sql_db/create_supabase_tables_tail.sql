
-- Script: create_supabase_tables_tail.sql

-----------------------
-- For Supabase only --
-----------------------

DROP FUNCTION IF EXISTS get_tables();
CREATE OR REPLACE FUNCTION get_tables()
RETURNS text[] AS $$
BEGIN
    RETURN (
        SELECT array_agg(t.table_name::text)
        FROM information_schema.tables AS t
        WHERE t.table_schema = 'public'
    );
END;
$$ LANGUAGE plpgsql; 

DROP FUNCTION IF EXISTS get_columns(text);
CREATE OR REPLACE FUNCTION get_columns(target_table_name text DEFAULT NULL)
RETURNS TABLE (
    table_name text,
    column_name text,
    data_type text,
    character_maximum_length int
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cols.table_name::text,
        cols.column_name::text,
        cols.data_type::text,
        cols.character_maximum_length::int
    FROM information_schema.columns AS cols
    WHERE cols.table_schema = 'public'
      -- If target_table_name is null, return all. Otherwise, filter.
      AND (target_table_name IS NULL OR cols.table_name = target_table_name)
    ORDER BY cols.table_name, cols.ordinal_position;
END;
$$; 

DROP FUNCTION IF EXISTS get_primary_keys(text);
CREATE OR REPLACE FUNCTION get_primary_keys(target_table_name text DEFAULT NULL)
RETURNS TABLE (
    table_name text,
    primary_key text
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.table_name:: text,
        k.column_name:: text AS primary_key
    FROM information_schema.table_constraints t
      JOIN information_schema.key_column_usage k 
        ON k.constraint_name = t.constraint_name
        AND k.table_schema = t.table_schema
    WHERE t.constraint_type = 'PRIMARY KEY'
        AND k.table_schema = 'public'
        AND (target_table_name IS NULL OR t.table_name = target_table_name);
END;
$$; 

-- Optionally:

-- CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- GRANT USAGE ON SCHEMA information_schema TO postgres, anon, authenticated, service_role;
-- GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO postgres, anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA "public" TO postgres, authenticated, anon, service_role;

-- NOTIFY pgrst, 'reload schema';
