-- Script: create_mysql_initial_tables.sql
-- This script creates the initial tables for the MySQL database.

-------------------
-- Create tables --
-------------------

-- Table: users

CREATE TABLE IF NOT EXISTS users (firstname LONGTEXT, lastname LONGTEXT, email VARCHAR(255), status VARCHAR(100), plan VARCHAR(100), superuser VARCHAR(100), birthday FLOAT(20, 10), gender VARCHAR(100), language VARCHAR(100), openai_api_key LONGTEXT, openai_model LONGTEXT, creation_date FLOAT(20, 10), update_date FLOAT(20, 10), passcode VARCHAR(255), _id CHAR(30), users_config JSON);

ALTER TABLE users ADD PRIMARY KEY (_id);

-- Table: ai_chatbot_conversations

CREATE TABLE IF NOT EXISTS ai_chatbot_conversations (user_id LONGTEXT, title LONGTEXT, creation_date FLOAT(20, 10), update_date FLOAT(20, 10), messages JSON, _id CHAR(30));

ALTER TABLE ai_chatbot_conversations ADD PRIMARY KEY (_id);

-- Table: general_config

CREATE TABLE IF NOT EXISTS general_config (config_name LONGTEXT, active VARCHAR(100), config_value LONGTEXT, notes LONGTEXT, creation_date VARCHAR(255), update_date VARCHAR(255), _id CHAR(30));

ALTER TABLE general_config ADD PRIMARY KEY (_id);


