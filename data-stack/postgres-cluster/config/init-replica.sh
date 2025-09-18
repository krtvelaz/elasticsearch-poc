#!/bin/bash
set -e

# Script para inicializar la réplica PostgreSQL

echo "Iniciando configuración de la réplica PostgreSQL..."

# Esperar a que el master esté disponible
echo "Esperando a que el master esté disponible..."
until pg_isready -h postgres-master -p 5432 -U postgres; do
    echo "Master no disponible aún, esperando..."
    sleep 5
done

echo "Master disponible, continuando con la configuración..."

# Verificar si ya existe data en el directorio
if [ "$(ls -A /var/lib/postgresql/data)" ]; then
    echo "Directorio de datos no vacío, verificando si es una réplica válida..."
    
    # Verificar si existe recovery.conf o standby.signal
    if [ -f "/var/lib/postgresql/data/standby.signal" ] || [ -f "/var/lib/postgresql/data/recovery.conf" ]; then
        echo "Configuración de réplica existente encontrada, saltando pg_basebackup..."
        exit 0
    else
        echo "Limpiando directorio de datos para nueva réplica..."
        rm -rf /var/lib/postgresql/data/*
    fi
fi

echo "Ejecutando pg_basebackup desde el master..."

# Tomar credenciales del entorno (con valores por defecto para backward compatibility)
: "${POSTGRES_REPLICATION_USER:=replicator}"
: "${POSTGRES_REPLICATION_PASSWORD:=replicator123}"
: "${POSTGRES_REPLICATION_SLOT:=replica_slot}"

# Realizar backup base desde el master
PGPASSWORD="$POSTGRES_REPLICATION_PASSWORD" pg_basebackup \
    -h postgres-master \
    -p 5432 \
    -U "$POSTGRES_REPLICATION_USER" \
    -D /var/lib/postgresql/data \
    -W \
    -v \
    -P \
    -R \
    -X stream \
    -S "$POSTGRES_REPLICATION_SLOT"

echo "pg_basebackup completado exitosamente"

# Crear archivo standby.signal para indicar que es una réplica
touch /var/lib/postgresql/data/standby.signal

# Configurar postgresql.auto.conf con parámetros específicos de la réplica
cat >> /var/lib/postgresql/data/postgresql.auto.conf << EOF

# Configuración específica de la réplica
primary_conninfo = 'host=postgres-master port=5432 user=$POSTGRES_REPLICATION_USER password=$POSTGRES_REPLICATION_PASSWORD application_name=replica1'
primary_slot_name = '$POSTGRES_REPLICATION_SLOT'
hot_standby = on
max_standby_streaming_delay = 30s
hot_standby_feedback = on
restore_command = 'cp /var/lib/postgresql/archive/%f %p'
recovery_target_timeline = 'latest'

EOF

# Asegurar permisos correctos
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

echo "Configuración de réplica completada exitosamente"

# Crear directorio para logs si no existe
mkdir -p /var/log/postgresql
chown postgres:postgres /var/log/postgresql

echo "Réplica lista para iniciar"