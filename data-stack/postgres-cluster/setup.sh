#!/bin/bash

# Script de configuración inicial para el cluster PostgreSQL

set -e

echo "=== Configuración inicial del Cluster PostgreSQL ==="

# Verificar si Docker y Docker Compose están instalados
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Por favor, instálalo primero."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose no está instalado. Por favor, instálalo primero."
    exit 1
fi

# Crear directorios necesarios
echo "📁 Creando estructura de directorios..."

sudo mkdir -p /mnt/postgres/{master,replica}/{data,config,logs}
sudo mkdir -p /mnt/postgres/archive

echo "📁 Configurando permisos de directorios..."
sudo chown -R 999:999 /mnt/postgres
sudo chmod -R 755 /mnt/postgres

# Hacer ejecutables los scripts
echo "🔧 Configurando permisos de scripts..."
chmod +x ./config/init-replica.sh
chmod +x ./config/entrypoint-init-master.sh

# Crear archivo de variables de entorno si no existe
if [ ! -f .env ]; then
    echo "📝 Creando archivo .env..."
    cat > .env << EOF
# Configuración de la base de datos
POSTGRES_DB=myapp
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SecurePassword123!

# Usuario de replicación
POSTGRES_REPLICATION_USER=replicator
POSTGRES_REPLICATION_PASSWORD=ReplicatorPass456!

# Configuraciones adicionales
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_MAINTENANCE_WORK_MEM=64MB
POSTGRES_CHECKPOINT_COMPLETION_TARGET=0.9
POSTGRES_WAL_BUFFERS=16MB
POSTGRES_DEFAULT_STATISTICS_TARGET=100
EOF
fi

echo "✅ Configuración inicial completada"
echo ""
echo "🚀 Para iniciar el cluster ejecuta:"
echo "   docker-compose up -d"
echo ""
echo "📊 Para verificar el estado:"
echo "   docker-compose ps"
echo "   docker-compose logs -f"
echo ""
echo "🔍 Para probar la conexión:"
echo "   Master:  psql -h localhost -p 5432 -U postgres -d myapp"
echo "   Replica: psql -h localhost -p 5433 -U postgres -d myapp"
echo ""
echo "📈 Monitor (Prometheus exporter): http://localhost:9187/metrics"