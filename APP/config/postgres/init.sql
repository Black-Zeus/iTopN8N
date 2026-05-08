-- Extensiones usadas por n8n
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Base de datos para NocoDB (separada de n8n)
CREATE DATABASE nocodb_db;
