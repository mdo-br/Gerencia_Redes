#!/bin/bash
# disk_monitor.sh - Monitor de uso de disco com envio de SNMP Traps
#
# Monitora uso de disco e envia trap SNMP quando ultrapassa limite
#
# Uso: ./disk_monitor.sh [LIMITE_PERCENTUAL] [TRAP_DESTINATION]
# Exemplo: ./disk_monitor.sh 95 localhost

# Configuracoes
DISK_THRESHOLD=${1:-95}          # Limite de uso em percentual (default: 95%)
TRAP_DEST=${2:-localhost}        # Destino do trap (default: localhost)
COMMUNITY="public"               # Community string
CHECK_INTERVAL=300               # Intervalo de verificacao em segundos (5 min)

# OIDs do CUSTOM-TRAPS-MIB
TRAP_OID=".1.3.6.1.4.1.99999.3.0.2"  # myDiskFullTrap
PARTITION_OID=".1.3.6.1.4.1.99999.3.1.3.0"        # diskPartition
USAGE_PERCENT_OID=".1.3.6.1.4.1.99999.3.1.4.0"    # diskUsagePercent
TOTAL_MB_OID=".1.3.6.1.4.1.99999.3.1.5.0"         # diskTotalMB
USED_MB_OID=".1.3.6.1.4.1.99999.3.1.6.0"          # diskUsedMB
TIMESTAMP_OID=".1.3.6.1.4.1.99999.3.1.7.0"        # alertTimestamp
SEVERITY_OID=".1.3.6.1.4.1.99999.3.1.8.0"         # alertSeverity

# Cores para output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_critical() {
    echo -e "${RED}[CRIT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Funcao para obter informacoes de disco
get_disk_info() {
    # Usa df com formato portavel
    # Filtra sistemas de arquivo reais (exclui tmpfs, devtmpfs, etc)
    df -BM | grep -vE '^(tmpfs|devtmpfs|udev|none|overlay)' | \
    awk 'NR>1 {
        # Remove "M" de tamanhos
        total = $2; gsub(/M/, "", total);
        used = $3; gsub(/M/, "", used);
        avail = $4; gsub(/M/, "", avail);
        percent = $5; gsub(/%/, "", percent);
        mount = $6;
        
        # Imprime: mountpoint|total_MB|used_MB|usage_percent
        print mount "|" total "|" used "|" percent
    }'
}

# Funcao para enviar trap SNMP
send_disk_trap() {
    local partition=$1
    local usage_percent=$2
    local total_mb=$3
    local used_mb=$4
    local severity=$5  # 2=warning, 3=critical
    local timestamp=$(date -Iseconds)
    
    log_critical "Enviando trap de disco cheio: $partition ${usage_percent}% (limite: ${DISK_THRESHOLD}%)"
    
    # Envia trap usando snmptrap
    snmptrap -v 2c -c "$COMMUNITY" "$TRAP_DEST" '' \
        "$TRAP_OID" \
        "$PARTITION_OID" s "$partition" \
        "$USAGE_PERCENT_OID" i "$usage_percent" \
        "$TOTAL_MB_OID" i "$total_mb" \
        "$USED_MB_OID" i "$used_mb" \
        "$TIMESTAMP_OID" s "$timestamp" \
        "$SEVERITY_OID" i "$severity"
    
    if [ $? -eq 0 ]; then
        log_info "Trap enviado com sucesso para $TRAP_DEST"
    else
        log_warning "Falha ao enviar trap"
    fi
}

# Verificacao de dependencias
check_dependencies() {
    if ! command -v snmptrap &> /dev/null; then
        echo "ERRO: snmptrap não encontrado. Instale net-snmp-utils"
        echo ""
        echo "Ubuntu/Debian: sudo apt-get install snmp"
        echo "RedHat/CentOS: sudo yum install net-snmp-utils"
        echo "MacOS: brew install net-snmp"
        exit 1
    fi
    
    if ! command -v df &> /dev/null; then
        echo "ERRO: comando df não encontrado"
        exit 1
    fi
}

# Funcao principal de monitoramento
monitor_disk() {
    log_info "Iniciando monitoramento de disco"
    log_info "Limite: ${DISK_THRESHOLD}% | Destino: ${TRAP_DEST} | Intervalo: ${CHECK_INTERVAL}s"
    
    # Array associativo para controlar cooldown por particao
    declare -A last_alert_times
    local alert_cooldown=600  # 10 minutos entre alertas da mesma particao
    
    while true; do
        current_time=$(date +%s)
        
        # Le informacoes de disco
        while IFS='|' read -r partition total_mb used_mb usage_percent; do
            # Ignora linhas vazias
            [ -z "$partition" ] && continue
            
            if [ "$usage_percent" -ge "$DISK_THRESHOLD" ]; then
                # Verifica cooldown desta particao
                last_alert="${last_alert_times[$partition]:-0}"
                time_since_alert=$((current_time - last_alert))
                
                if [ $time_since_alert -gt $alert_cooldown ]; then
                    # Define severidade baseada no uso
                    if [ "$usage_percent" -ge 98 ]; then
                        severity=3  # Critical (>=98%)
                    else
                        severity=2  # Warning
                    fi
                    
                    send_disk_trap "$partition" "$usage_percent" "$total_mb" "$used_mb" "$severity"
                    last_alert_times[$partition]=$current_time
                else
                    log_warning "Disco $partition cheio (${usage_percent}%) mas em cooldown (${time_since_alert}s/${alert_cooldown}s)"
                fi
            else
                log_info "Disco $partition OK: ${usage_percent}% de ${total_mb}MB (limite: ${DISK_THRESHOLD}%)"
            fi
        done < <(get_disk_info)
        
        sleep "$CHECK_INTERVAL"
    done
}

# Funcao para exibir status atual
show_disk_status() {
    echo ""
    echo "========================================="
    echo "  Status Atual dos Discos"
    echo "========================================="
    printf "%-20s %10s %10s %10s\n" "PARTICAO" "TOTAL(MB)" "USADO(MB)" "USO(%)"
    echo "-----------------------------------------"
    
    while IFS='|' read -r partition total_mb used_mb usage_percent; do
        [ -z "$partition" ] && continue
        
        # Coloriza baseado no uso
        if [ "$usage_percent" -ge "$DISK_THRESHOLD" ]; then
            color=$RED
        elif [ "$usage_percent" -ge $((DISK_THRESHOLD - 10)) ]; then
            color=$YELLOW
        else
            color=$GREEN
        fi
        
        printf "${color}%-20s %10s %10s %9s%%${NC}\n" \
            "$partition" "$total_mb" "$used_mb" "$usage_percent"
    done < <(get_disk_info)
    
    echo ""
}

# Main
echo "========================================="
echo "  Monitor de Disco com SNMP Traps"
echo "========================================="
echo ""

check_dependencies

# Mostra status atual
show_disk_status

# Pergunta se quer testar enviando um trap
echo ""
read -p "Deseja enviar um trap de teste agora? (s/N): " test_trap
if [[ "$test_trap" =~ ^[Ss]$ ]]; then
    log_info "Enviando trap de teste para a particao /"
    
    # Pega info da raiz
    root_info=$(get_disk_info | grep "^/|")
    if [ -n "$root_info" ]; then
        IFS='|' read -r partition total_mb used_mb usage_percent <<< "$root_info"
        send_disk_trap "$partition" "$usage_percent" "$total_mb" "$used_mb" 2
    else
        log_warning "Nao foi possivel obter informacoes da particao /"
    fi
    echo ""
fi

# Inicia monitoramento continuo
read -p "Iniciar monitoramento continuo? (s/N): " start_monitor
if [[ "$start_monitor" =~ ^[Ss]$ ]]; then
    echo ""
    monitor_disk
else
    log_info "Monitoramento não iniciado. Script finalizado."
fi
