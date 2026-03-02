
-- Script: create_supabase_tables_tail.sql

-----------------------
-- For Supabase only --
-----------------------

-- DROP FUNCTION IF EXISTS get_tables();
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

-- DROP FUNCTION IF EXISTS get_columns(text);
CREATE OR REPLACE FUNCTION get_columns( in tablename text, out column_names text[], out data_types text[], out character_maximum_lengths text[] )
RETURNS SETOF record AS $$
BEGIN
    RETURN QUERY (
        SELECT
            array_agg(t.column_name::text),
            array_agg(t.data_type::text),
            array_agg(t.character_maximum_length::text)
        FROM information_schema.columns AS t
        WHERE t.table_schema = 'public'
        AND t.table_name = tablename
    );
END;
$$ LANGUAGE plpgsql; 

-- Optionally:

-- CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- GRANT USAGE ON SCHEMA information_schema TO postgres, anon, authenticated, service_role;
-- GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO postgres, anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA "public" TO postgres, authenticated, anon, service_role;

-- NOTIFY pgrst, 'reload schema';
