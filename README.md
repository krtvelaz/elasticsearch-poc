# Elasticsearch POC - Arquitectura Separada

## 🏗️ Arquitectura

- **data-stack/**: PostgreSQL + Logstash
- **elastic-stack/**: Elasticsearch + Kibana
- **scripts/**: Scripts de gestión

## 🚀 Inicio Rápido
```bash
# 1. Setup inicial
./scripts/setup.sh

# 2. Iniciar todos los servicios
./scripts/start-all.sh

# 3. Verificar estado
./scripts/check-status.sh
```

## 📍 URLs

Elasticsearch: http://localhost:9200
Kibana: http://localhost:5601
PgAdmin: http://localhost:8080

## 🛠️ Comandos Útiles
```bash
# Iniciar con herramientas adicionales
cd data-stack && docker-compose --profile tools up -d

# Ver logs
docker-compose logs -f logstash

# Detener todo
./scripts/stop-all.sh
```

## 🔧 Comandos de Verificación
```bash

# Verificar red compartida
docker network ls | grep elasticsearch

# Ver todos los contenedores
docker ps -a

# Logs específicos
docker logs elasticsearch-cluster
docker logs logstash-pipeline
docker logs postgres-data

# Entrar a PostgreSQL
docker exec -it postgres-data psql -U postgres -d testdb

```
