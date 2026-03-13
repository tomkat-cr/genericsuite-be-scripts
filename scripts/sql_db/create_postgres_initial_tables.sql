-- Script: create_postgres_initial_tables.sql
-- This script creates the initial tables for the Postgres database.

-------------------
-- Create tables --
-------------------

-- Table: users_api_keys;

CREATE TABLE IF NOT EXISTS users_api_keys (access_token character varying NOT NULL, active character varying NOT NULL DEFAULT '1' , user_id character varying, creation_date numeric NOT NULL, update_date numeric NOT NULL, _id character(30) NOT NULL);

ALTER TABLE users_api_keys ADD PRIMARY KEY (_id);

-- Table: users;

CREATE TABLE IF NOT EXISTS users (firstname character varying NOT NULL, lastname character varying NOT NULL, email character varying NOT NULL, status character varying NOT NULL DEFAULT '1' , plan character varying NOT NULL DEFAULT 'free' , superuser character varying NOT NULL DEFAULT '0' , birthday numeric NOT NULL, gender character varying NOT NULL, openai_api_key character varying, openai_model character varying, creation_date numeric NOT NULL DEFAULT 0 , update_date numeric NOT NULL DEFAULT 0 , passcode character varying, _id character(30) NOT NULL, users_config jsonb NOT NULL DEFAULT '[]', user_history jsonb NOT NULL DEFAULT '[]');

ALTER TABLE users ADD PRIMARY KEY (_id);

-- Table: ai_chatbot_conversations;

CREATE TABLE IF NOT EXISTS ai_chatbot_conversations (user_id character varying NOT NULL, title character varying NOT NULL, creation_date numeric NOT NULL DEFAULT 0 , update_date numeric NOT NULL DEFAULT 0 , messages jsonb NOT NULL, _id character(30) NOT NULL);

ALTER TABLE ai_chatbot_conversations ADD PRIMARY KEY (_id);

-- Table: general_config;

CREATE TABLE IF NOT EXISTS general_config (config_name character varying NOT NULL, active character varying NOT NULL DEFAULT '1' , config_value character varying NOT NULL, notes character varying NOT NULL, creation_date numeric NOT NULL, update_date numeric NOT NULL, _id character(30) NOT NULL);

ALTER TABLE general_config ADD PRIMARY KEY (_id);
