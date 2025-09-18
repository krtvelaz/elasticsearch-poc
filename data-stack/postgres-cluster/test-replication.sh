#!/bin/bash

# Script para probar la replicación PostgreSQL

set -e

echo "=== Prueba de Replicación PostgreSQL ==="

# Configuración
MASTER_HOST="localhost"
MASTER_PORT="5432"
REPLICA_HOST="localhost"
REPLICA_PORT="5433"
DB_USER="postgres"
DB_NAME="myapp"

echo "🔍 Verificando estado de los contenedores..."
docker-compose ps

echo ""
echo "📊 Verificando estado de replicación en el master..."
docker-compose exec postgres-master psql -U postgres -c "SELECT * FROM pg_stat_replication;" || true

echo ""
echo "🧪 Insertando datos de prueba en el master..."
docker-compose exec postgres-master psql -U postgres -d myapp -c "
INSERT INTO test_replication (message) VALUES ('Prueba de replicación - $(date)');
SELECT COUNT(*) as total_records FROM test_replication;
SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;
"

echo ""
echo "⏳ Esperando a que se repliquen los datos (5 segundos)..."
sleep 5

echo ""
echo "🔍 Verificando datos en la réplica..."
docker-compose exec postgres-replica psql -U postgres -d myapp -c "
SELECT COUNT(*) as total_records FROM test_replication;
SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;
" || echo "❌ Error al consultar la réplica"

echo ""
echo "📈 Verificando estado de recovery en la réplica..."
docker-compose exec postgres-replica psql -U postgres -c "SELECT pg_is_in_recovery();" || true

echo ""
echo "🏥 Verificando salud de los servicios..."
for service in postgres-master postgres-replica; do
    echo "Verificando $service..."
    if docker-compose exec $service pg_isready -U postgres; then
        echo "✅ $service está funcionando correctamente"
    else
        echo "❌ $service no responde"
    fi
done

echo ""
echo "📊 Información adicional del cluster:"
echo "Master - Puerto: 5432"
echo "Replica - Puerto: 5433"
echo "Monitor - Puerto: 9187"
echo ""
echo "Para conectar:"
echo "Master:  docker-compose exec postgres-master psql -U postgres -d myapp"
echo "Replica: docker-compose exec postgres-replica psql -U postgres -d myapp"

echo ""
echo "✅ Prueba de replicación completada"