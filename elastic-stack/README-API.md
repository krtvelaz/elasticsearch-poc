# Elasticsearch API – Comandos básicos (curl)

Esta guía reúne comandos útiles para consultar y operar el clúster con `curl`.

Notas importantes
- Seguridad y TLS están habilitados. Debes autenticarte con el usuario `elastic` y usar la CA generada por `setup`.
- Ruta de la CA (en el HOST): `/mnt/elasticsearch/certs/ca/ca.crt`
- Usuario/password: `elastic` y el valor de `ELASTIC_PASSWORD` en `elastic-stack/.env`.
- Puerto HTTP expuesto: `https://localhost:9200`

Puedes ejecutar los comandos:
- Desde el HOST (recomendado): agregar `--cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}"`
- O dentro del contenedor `es01` (la CA está montada en `config/certs/ca/ca.crt`):
  ```bash
  sudo docker compose --env-file elastic-stack/.env exec es01 bash -lc 'curl -s --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200' 
  ```

## Cluster y nodos

- Salud del clúster
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cluster/health?pretty
```

- Listar nodos (vista tabular)
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cat/nodes?v
```

- Información general del clúster
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200
```

- Listar índices
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cat/indices?v
```

## Indexación de documentos

- Crear/actualizar un documento (index API)
```bash
curl -s -X POST --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  https://localhost:9200/people/_doc/1 \
  -d '{
    "name": "Alice",
    "city": "Bogotá",
    "age": 30,
    "created_at": "2025-09-18T02:00:00Z"
  }'
```

- Obtener un documento
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/people/_doc/1?pretty
```

- Actualizar parcialmente un documento
```bash
curl -s -X POST --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  https://localhost:9200/people/_update/1 \
  -d '{ "doc": { "age": 31 } }'
```

- Eliminación de documento
```bash
curl -s -X DELETE --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/people/_doc/1
```

- Bulk (carga masiva) – NDJSON
```bash
curl -s -X POST --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/x-ndjson' \
  https://localhost:9200/people/_bulk \
  --data-binary $'{"index":{}}
{"name":"Bob","city":"Medellín","age":25}
{"index":{}}
{"name":"Carla","city":"Cali","age":40}\n'
```

## Búsquedas (Search API)

- Búsqueda por palabra clave (query_string)
```bash
curl -s -X GET --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  'https://localhost:9200/people/_search?pretty' \
  -d '{
    "query": {
      "query_string": {
        "query": "city:Bogotá OR city:Medellín"
      }
    }
  }'
```

- Búsqueda por coincidencia (match)
```bash
curl -s -X GET --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  'https://localhost:9200/people/_search?pretty' \
  -d '{
    "query": {
      "match": { "name": "alice" }
    }
  }'
```

- Filtros por rango (edad >= 30)
```bash
curl -s -X GET --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  'https://localhost:9200/people/_search?pretty' \
  -d '{
    "query": {
      "range": { "age": { "gte": 30 } }
    }
  }'
```

- Agregaciones (conteo por ciudad)
```bash
curl -s -X GET --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  'https://localhost:9200/people/_search?pretty' \
  -d '{
    "size": 0,
    "aggs": {
      "por_ciudad": {
        "terms": { "field": "city.keyword" }
      }
    }
  }'
```

## Gestión de índices

- Crear índice con mappings básicos
```bash
curl -s -X PUT --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  https://localhost:9200/people \
  -d '{
    "settings": { "number_of_shards": 1, "number_of_replicas": 1 },
    "mappings": {
      "properties": {
        "name":   { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
        "city":   { "type": "keyword" },
        "age":    { "type": "integer" },
        "created_at": { "type": "date" }
      }
    }
  }'
```

- Ver mappings
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/people/_mapping?pretty
```

- Eliminar índice
```bash
curl -s -X DELETE --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/people
```

## Cat APIs útiles

- Índices:
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cat/indices?v&s=index
```

- Shards:
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cat/shards?v
```

- Asignación de shards:
```bash
curl -s --cacert /mnt/elasticsearch/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9200/_cat/allocation?v
```

## Consejos
- Para pruebas rápidas dentro del clúster, usa `docker compose exec es01 ...` y la CA en `config/certs/ca/ca.crt`.
- En Kibana (Dev Tools) puedes ejecutar los mismos cuerpos JSON sin headers ni auth manual.
- Ajusta consultas a tus índices reales; en los ejemplos se usa `people` como índice de muestra.
