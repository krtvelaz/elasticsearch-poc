-- Script de inicialización para el servidor PostgreSQL Master

-- Crear usuario de replicación
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '#{POSTGRES_REPLICATION_USER}#') THEN
        CREATE ROLE "#{POSTGRES_REPLICATION_USER}#" WITH REPLICATION PASSWORD '#{POSTGRES_REPLICATION_PASSWORD}#' LOGIN;
    END IF;
END
$$;
-- Create usuario de la aplicacion
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '#{POSTGRES_USER}#') THEN
        CREATE ROLE "#{POSTGRES_USER}#" WITH PASSWORD '#{POSTGRES_PASSWORD}#' LOGIN;
    END IF;
END
$$;


-- Otorgar permisos necesarios al usuario de replicación
GRANT CONNECT ON DATABASE postgres TO "#{POSTGRES_REPLICATION_USER}#";

-- Otorgar permisos necesarios al usuario de la aplicacion
GRANT CONNECT ON DATABASE postgres TO "#{POSTGRES_USER}#";

-- Crear slot de replicación
SELECT pg_create_physical_replication_slot('#{POSTGRES_REPLICATION_SLOT}#');

-- Crear directorio de archivos WAL si no existe
\! mkdir -p /var/lib/postgresql/archive

-- Configurar parámetros dinámicos
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET max_wal_senders = 3;
ALTER SYSTEM SET max_replication_slots = 3;
ALTER SYSTEM SET wal_keep_size = '64MB';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/archive/%f && cp %p /var/lib/postgresql/archive/%f';

-- Aplicar configuración
SELECT pg_reload_conf();

-- Crear base de datos de aplicación si no existe (sin usar transacciones ni extensiones)
SELECT format('CREATE DATABASE "%s"', '#{POSTGRES_DB}#')
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '#{POSTGRES_DB}#'
) \gexec

-- Crear tabla de ejemplo para probar la replicación
\c #{POSTGRES_DB}#;

CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insertar datos de prueba
INSERT INTO test_replication (message) VALUES 
    ('Mensaje de prueba desde el master'),
    ('Replicación funcionando correctamente'),
    ('Cluster PostgreSQL iniciado');

-- Mostrar información del estado de replicación
SELECT * FROM pg_stat_replication;