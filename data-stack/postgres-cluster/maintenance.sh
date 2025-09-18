#!/bin/bash

# Script de mantenimiento para el cluster PostgreSQL

set -e


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar variables de entorno desde .env y exportarlas
load_env() {
    local ENV_FILE="$SCRIPT_DIR/.env"
    if [ -f "$ENV_FILE" ]; then
        echo "🔧 Cargando variables desde $ENV_FILE"
        set -o allexport
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +o allexport
    else
        echo "⚠️  No se encontró $ENV_FILE; se continuará sin variables personalizadas"
    fi
}

# Desinstalar carga persistente de .env en ~/.bashrc (idempotente)
env_uninstall() {
    local BASHRC="$HOME/.bashrc"
    local LOADER_PATH="$SCRIPT_DIR/load-env.sh"
    local LINE_TO_ADD="source $LOADER_PATH"

    if [ ! -f "$BASHRC" ]; then
        echo "ℹ️  $BASHRC no existe; nada que quitar"
        return 0
    fi

    if grep -Fqx "$LINE_TO_ADD" "$BASHRC"; then
        # Eliminar la línea exacta de forma segura
        sed -i "\|$LINE_TO_ADD|d" "$BASHRC"
        echo "✅ Removido del $BASHRC"
    else
        echo "ℹ️  No se encontró la línea en $BASHRC; nada que hacer"
    fi
}

# Imprimir variables relevantes para verificación
print_env() {
    echo "📦 Variables cargadas (echo $VAR):"
    # imprimir todas las variables del sistema
    env | grep -E 'POSTGRES_|PG_'
}

# Asegurar que trabajamos desde el directorio del script
cd "$SCRIPT_DIR"

show_help() {
    echo "Script de mantenimiento para cluster PostgreSQL"
    echo ""
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos disponibles:"
    echo "  start           - Iniciar el cluster"
    echo "  stop            - Detener el cluster"
    echo "  restart         - Reiniciar el cluster"
    echo "  status          - Mostrar estado del cluster"
    echo "  logs            - Mostrar logs en tiempo real"
    echo "  backup          - Crear backup del master"
    echo "  restore         - Restaurar desde backup"
    echo "  test            - Ejecutar pruebas de replicación"
    echo "  cleanup         - Limpiar datos y reiniciar"
    echo "  monitor         - Mostrar métricas de monitoreo"
    echo "  failover        - Promover réplica a master (CUIDADO!)"
    echo "  help            - Mostrar esta ayuda"
    echo "  env             - Mostrar variables cargadas desde .env"
    echo "  env-install     - Cargar .env automáticamente en cada sesión del usuario"
    echo "  env-uninstall   - Quitar la carga automática desde ~/.bashrc"
}

start_cluster() {
    echo "🚀 Iniciando cluster PostgreSQL..."
    # Mostrar variables antes de iniciar para verificar
    print_env
    docker-compose up -d
    echo "✅ Cluster iniciado"
    
    echo "⏳ Esperando a que los servicios estén listos..."
    sleep 10
    
    status_cluster
}

stop_cluster() {
    echo "🛑 Deteniendo cluster PostgreSQL..."
    docker-compose down
    echo "✅ Cluster detenido"
}

restart_cluster() {
    echo "🔄 Reiniciando cluster PostgreSQL..."
    docker-compose restart
    echo "✅ Cluster reiniciado"
}

status_cluster() {
    echo "📊 Estado del cluster PostgreSQL:"
    echo ""
    docker-compose ps
    
    echo ""
    echo "🏥 Salud de los servicios:"
    for service in postgres-master postgres-replica; do
        if docker-compose exec -T $service pg_isready -U postgres >/dev/null 2>&1; then
            echo "✅ $service - OK"
        else
            echo "❌ $service - ERROR"
        fi
    done
    
    echo ""
    echo "📈 Estado de replicación:"
    docker-compose exec -T postgres-master psql -U postgres -tA -c "
        SELECT 
            application_name,
            client_addr,
            state,
            sent_lsn,
            write_lsn,
            flush_lsn,
            replay_lsn,
            sync_state
        FROM pg_stat_replication;
    " 2>/dev/null | while IFS='|' read app addr state sent write flush replay sync; do
        if [ ! -z "$app" ]; then
            echo "  📍 App: $app, Estado: $state, Sync: $sync"
        fi
    done
}

show_logs() {
    echo "📋 Mostrando logs del cluster (Ctrl+C para salir)..."
    docker-compose logs -f
}

create_backup() {
    BACKUP_DIR="/mnt/postgres/backups"
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    
    echo "💾 Creando backup del master..."
    
    sudo mkdir -p "$BACKUP_DIR"
    
    docker-compose exec -T postgres-master pg_dumpall -U postgres > "${BACKUP_DIR}/${BACKUP_FILE}"
    
    echo "✅ Backup creado: ${BACKUP_DIR}/${BACKUP_FILE}"
    
    # Comprimir backup
    gzip "${BACKUP_DIR}/${BACKUP_FILE}"
    echo "📦 Backup comprimido: ${BACKUP_DIR}/${BACKUP_FILE}.gz"
}

restore_backup() {
    BACKUP_DIR="/mnt/postgres/backups"
    
    echo "📂 Backups disponibles:"
    ls -la "$BACKUP_DIR"/*.gz 2>/dev/null || echo "No hay backups disponibles"
    
    echo ""
    read -p "Ingresa el nombre del archivo de backup (sin .gz): " BACKUP_FILE
    
    if [ -f "${BACKUP_DIR}/${BACKUP_FILE}.gz" ]; then
        echo "🔄 Restaurando backup..."
        gunzip -c "${BACKUP_DIR}/${BACKUP_FILE}.gz" | docker-compose exec -T postgres-master psql -U postgres
        echo "✅ Backup restaurado"
    else
        echo "❌ Archivo de backup no encontrado"
    fi
}

run_tests() {
    echo "🧪 Ejecutando pruebas de replicación..."
    bash test-replication.sh
}

cleanup_data() {
    echo "⚠️  ADVERTENCIA: Esto eliminará todos los datos del cluster"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Limpiando datos del cluster..."
        
        stop_cluster
        
        sudo rm -rf /mnt/postgres/master/*
        sudo rm -rf /mnt/postgres/replica/*
        sudo rm -rf /mnt/postgres/archive/*
        
        sudo chown -R 999:999 /mnt/postgres
        sudo chmod -R 755 /mnt/postgres
        
        echo "✅ Datos eliminados"
        echo "Para reiniciar: $0 start"
    else
        echo "❌ Operación cancelada"
    fi
}

show_monitoring() {
    echo "📈 Métricas de monitoreo:"
    echo ""
    
    echo "🔗 Conexiones activas:"
    docker-compose exec -T postgres-master psql -U postgres -tA -c "
        SELECT count(*) as active_connections 
        FROM pg_stat_activity 
        WHERE state = 'active';
    " 2>/dev/null || echo "Error al obtener conexiones"
    
    echo ""
    echo "💾 Uso de base de datos:"
    docker-compose exec -T postgres-master psql -U postgres -tA -c "
        SELECT 
            datname,
            pg_size_pretty(pg_database_size(datname)) as size
        FROM pg_database 
        WHERE datistemplate = false;
    " 2>/dev/null || echo "Error al obtener tamaños de BD"
    
    echo ""
    echo "📊 URL del monitor Prometheus: http://localhost:9187/metrics"
}

promote_replica() {
    echo "⚠️  ADVERTENCIA: Esto promoverá la réplica a master"
    echo "⚠️  Solo usar en caso de falla del master principal"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Promoviendo réplica a master..."
        
        # Promover la réplica
        docker-compose exec postgres-replica pg_promote
        
        # Esperar a que la promoción se complete
        sleep 5
        
        # Verificar que ya no está en recovery
        IS_RECOVERY=$(docker-compose exec -T postgres-replica psql -U postgres -tA -c "SELECT pg_is_in_recovery();" 2>/dev/null)
        
        if [ "$IS_RECOVERY" = "f" ]; then
            echo "✅ Réplica promovida exitosamente a master"
            echo "📍 La réplica ahora está funcionando como master en el puerto 5433"
            echo "⚠️  Recuerda actualizar tu aplicación para apuntar al nuevo master"
        else
            echo "❌ Error al promover la réplica"
        fi
    else
        echo "❌ Promoción cancelada"
    fi
}

# Instalar carga persistente de .env en ~/.bashrc (idempotente)
env_install() {
    local BASHRC="$HOME/.bashrc"
    local LOADER_PATH="$SCRIPT_DIR/load-env.sh"
    local LINE_TO_ADD="source $LOADER_PATH"

    if [ ! -f "$LOADER_PATH" ]; then
        echo "❌ No se encontró $LOADER_PATH"
        echo "   Crea el loader o ejecuta manualmente: echo 'set -a; . $SCRIPT_DIR/.env; set +a' >> $BASHRC"
        return 1
    fi

    # Crear .bashrc si no existe
    touch "$BASHRC"

    if grep -Fqx "$LINE_TO_ADD" "$BASHRC"; then
        echo "✅ Ya estaba instalado en $BASHRC"
    else
        echo "$LINE_TO_ADD" >> "$BASHRC"
        echo "✅ Instalado en $BASHRC"
    fi

    # Cargar de inmediato en esta sesión actual
    # shellcheck disable=SC1090
    source "$LOADER_PATH"
    echo "ℹ️  Recarga tu shell con: source $BASHRC (o abre una nueva terminal)"
}

# Función principal
main() {
    # Cargar variables siempre antes de cualquier operación
    load_env
    case "${1:-help}" in
        start)
            start_cluster
            ;;
        stop)
            stop_cluster
            ;;
        restart)
            restart_cluster
            ;;
        status)
            status_cluster
            ;;
        logs)
            show_logs
            ;;
        backup)
            create_backup
            ;;
        restore)
            restore_backup
            ;;
        test)
            run_tests
            ;;
        cleanup)
            cleanup_data
            ;;
        monitor)
            show_monitoring
            ;;
        failover)
            promote_replica
            ;;
        env-install)
            env_install
            ;;
        env-uninstall)
            env_uninstall
            ;;
        env)
            print_env
            ;;
        help)
            show_help
            ;;
        *)
            echo "❌ Comando desconocido: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"