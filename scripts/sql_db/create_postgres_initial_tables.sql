-- Script: create_postgres_initial_tables.sql
-- This script creates the initial tables for the Postgres database.

-------------------
-- Create tables --
-------------------

-- Table: users

CREATE TABLE IF NOT EXISTS users (firstname character varying, lastname character varying, email character varying, status character varying, plan character varying, superuser character varying, birthday numeric, gender character varying, language character varying, openai_api_key character varying, openai_model character varying, creation_date numeric, update_date numeric, passcode character varying, _id character(30), users_config json);

ALTER TABLE users ADD PRIMARY KEY (_id);

-- Table: ai_chatbot_conversations

CREATE TABLE IF NOT EXISTS ai_chatbot_conversations (user_id character varying, title character varying, creation_date numeric, update_date numeric, messages json, _id character varying);

ALTER TABLE ai_chatbot_conversations ADD PRIMARY KEY (_id);

-- Table: general_config

CREATE TABLE IF NOT EXISTS general_config (config_name character varying, active character varying, config_value character varying, notes character varying, creation_date numeric, update_date numeric, _id character varying);

ALTER TABLE general_config ADD PRIMARY KEY (_id);

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
