-- Script: create_mysql_initial_tables.sql
-- This script creates the initial tables for the MySQL database.

-------------------
-- Create tables --
-------------------
-- Table: users_api_keys

CREATE TABLE IF NOT EXISTS users_api_keys (access_token TEXT NOT NULL, active VARCHAR(100) NOT NULL DEFAULT "1" , user_id TEXT, creation_date VARCHAR(255) NOT NULL, update_date VARCHAR(255) NOT NULL, _id CHAR(30) NOT NULL)

ALTER TABLE users_api_keys ADD PRIMARY KEY (_id)

-- Table: users

CREATE TABLE IF NOT EXISTS users (firstname TEXT NOT NULL, lastname TEXT NOT NULL, email VARCHAR(255) NOT NULL, status VARCHAR(100) NOT NULL DEFAULT "1" , plan VARCHAR(100) NOT NULL DEFAULT "free" , superuser VARCHAR(100) NOT NULL DEFAULT "0" , birthday FLOAT(20, 10) NOT NULL, gender VARCHAR(100) NOT NULL, openai_api_key TEXT, openai_model TEXT, creation_date FLOAT(20, 10) NOT NULL DEFAULT 0 , update_date FLOAT(20, 10) NOT NULL DEFAULT 0 , passcode VARCHAR(255), _id CHAR(30) NOT NULL, users_config JSON NOT NULL DEFAULT (JSON_ARRAY()) , user_history JSON NOT NULL DEFAULT (JSON_ARRAY()) )

ALTER TABLE users ADD PRIMARY KEY (_id)

-- Table: ai_chatbot_conversations

CREATE TABLE IF NOT EXISTS ai_chatbot_conversations (user_id TEXT NOT NULL, title TEXT NOT NULL, creation_date FLOAT(20, 10) NOT NULL DEFAULT 0 , update_date FLOAT(20, 10) NOT NULL DEFAULT 0 , messages JSON NOT NULL, _id CHAR(30) NOT NULL)

ALTER TABLE ai_chatbot_conversations ADD PRIMARY KEY (_id)

-- Table: general_config

CREATE TABLE IF NOT EXISTS general_config (config_name TEXT NOT NULL, active VARCHAR(100) NOT NULL DEFAULT "1" , config_value TEXT NOT NULL, notes TEXT NOT NULL, creation_date VARCHAR(255) NOT NULL, update_date VARCHAR(255) NOT NULL, _id CHAR(30) NOT NULL)

ALTER TABLE general_config ADD PRIMARY KEY (_id)


