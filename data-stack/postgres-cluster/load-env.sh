#!/usr/bin/env bash
# Cargar todas las variables de /home/pcc/installation/postgres-cluster/v2/.env al entorno actual
# Uso:
#   source /home/pcc/installation/postgres-cluster/v2/load-env.sh

# Importante: este archivo puede ser "sourceado" desde ~/.bashrc.
# Evitar "set -e" aquí para no cerrar la terminal ante cualquier error menor.

ENV_FILE="/home/pcc/installation/postgres-cluster/v2/.env"

if [ ! -f "$ENV_FILE" ]; then
  # Silencioso si falta el archivo para no romper la experiencia de login
  # Puedes descomentar la siguiente línea si deseas ver un aviso:
  # echo "[load-env] Aviso: no se encontró $ENV_FILE" >&2
  return 0 2>/dev/null || exit 0
fi

# Exportar todo lo definido en el .env respetando comentarios y líneas vacías
set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

# Mensaje amigable pero no intrusivo
echo "[load-env] Variables del .env cargadas en el entorno actual."
