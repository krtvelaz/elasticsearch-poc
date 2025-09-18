# Elasticsearch 3 nodos + Kibana (Compose v2)

Este stack despliega un clúster de Elasticsearch de 3 nodos (es01, es02, es03) con seguridad y TLS habilitados, más Kibana. Usa Docker Compose v2 y bind mounts en `/mnt/elasticsearch/*` para persistencia.

## Documentación oficial
- Guía de despliegue self-managed de Elastic: https://www.elastic.co/docs/deploy-manage/deploy/self-managed

## Requisitos previos
- Docker y Docker Compose v2 instalados
  - Verifica:
    - `docker version`
    - `docker compose version`
- Linux con permisos de sudo.
- Ajustar vm.max_map_count (requerido por Elasticsearch):
  - Temporal (hasta reinicio):
    ```bash
    sudo sysctl -w vm.max_map_count=262144
    ```
  - Persistente:
    ```bash
    echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
    sudo sysctl --system
    ```

## Estructura
- Directorio del proyecto: `elastic-stack/`
- Configuración de variables: `elastic-stack/.env`
- Compose file: `elastic-stack/docker-compose.yml`
- Persistencia en host:
  - Certificados: `/mnt/elasticsearch/certs`
  - Datos ES: `/mnt/elasticsearch/esdata01`, `/mnt/elasticsearch/esdata02`, `/mnt/elasticsearch/esdata03`
  - Datos Kibana: `/mnt/elasticsearch/kibanadata`

## Variables de entorno (.env)
- `STACK_VERSION=8.11.0`
- `ELASTIC_PASSWORD` (usuario UI: `elastic`)
- `KIBANA_PASSWORD` (usuario interno `kibana_system`)
- `CLUSTER_NAME=pcardinal-cluster`
- Puertos: `ES_PORT=9200`, `KIBANA_PORT=5601`
- Memoria (host ~30GB):
  - `ES_HEAP=8g`
  - `MEM_LIMIT_ES=10g` por nodo (heap ≤ 50% del límite del contenedor)
  - `MEM_LIMIT_KIBANA=1g`

## Preparación de directorios y permisos
Crea los directorios para bind mounts y aplica permisos adecuados:
```bash
sudo mkdir -p /mnt/elasticsearch/{certs,esdata01,esdata02,esdata03,kibanadata}
# Propietario uid 1000 (usuario del contenedor) para datos
sudo chown -R 1000:0 /mnt/elasticsearch/esdata01 /mnt/elasticsearch/esdata02 /mnt/elasticsearch/esdata03 /mnt/elasticsearch/kibanadata
sudo chmod -R 750 /mnt/elasticsearch/esdata01 /mnt/elasticsearch/esdata02 /mnt/elasticsearch/esdata03 /mnt/elasticsearch/kibanadata
```
Los certificados serán generados por el servicio `setup` dentro del contenedor y montados en `/mnt/elasticsearch/certs`.

## Despliegue
Ubícate en `elastic-stack/`:
```bash
cd /home/pcc/installation/elasticsearch/elastic-stack
```

1) Descargar imágenes
```bash
sudo docker compose --env-file .env pull
```

2) Generar certificados y establecer contraseña interna de `kibana_system`
```bash
sudo docker compose --env-file .env up -d setup
sudo docker compose --env-file .env logs -f setup   # espera "All done!"
```

3) Arrancar Elasticsearch (3 nodos)
```bash
sudo docker compose --env-file .env up -d es01
sudo docker compose --env-file .env up -d es02 es03
```

4) Validar el clúster
```bash
# Nodos (deberían ser 3)
sudo docker compose --env-file .env exec es01 bash -lc 'curl -s --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cat/nodes?v'
# Salud
sudo docker compose --env-file .env exec es01 bash -lc 'curl -s --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cluster/health?pretty'
```

5) Arrancar Kibana
```bash
sudo docker compose --env-file .env up -d kibana
```

6) Acceder a Kibana
- URL: `http://localhost:5601`
- Usuario: `elastic`
- Contraseña: valor de `ELASTIC_PASSWORD` en `.env`

## Operación sin sudo (opcional)
Para usar Docker sin sudo:
```bash
sudo usermod -aG docker $USER
newgrp docker
# reabre la sesión si es necesario
```

## Comandos útiles
```bash
# Estado de servicios
sudo docker compose --env-file .env ps
# Logs
sudo docker compose --env-file .env logs -f es01
sudo docker compose --env-file .env logs -f kibana
# Parar
sudo docker compose --env-file .env down
```

## Solución de problemas
- Permiso denegado al socket Docker:
  - Usa `sudo ...` o añade tu usuario al grupo docker (ver sección "Operación sin sudo").
- Errores de permisos en data path:
  - Asegura `chown -R 1000:0` y `chmod -R 750` en `/mnt/elasticsearch/esdata0*` y `/mnt/elasticsearch/kibanadata`.
- Certificados no generados:
  - Revisa logs de `setup`: `sudo docker compose --env-file .env logs -f setup`
  - Verifica presencia de archivos en `/mnt/elasticsearch/certs`.
- Puertos en uso (9200/5601):
  - Cambia `ES_PORT` o `KIBANA_PORT` en `.env` y vuelve a levantar.
- vm.max_map_count insuficiente:
  - Aplica el ajuste indicado en Requisitos previos y reinicia servicios.

## Notas
- No subas `.env` con contraseñas a repositorios públicos.
- Mantén el heap (`ES_HEAP`) ≤ 50% del límite del contenedor.
- Para monitoreo gráfico de nodos, habilita Stack Monitoring desde Kibana.
