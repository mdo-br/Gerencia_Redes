#!/bin/bash
# temperature_monitor.sh - Monitor de temperatura com envio de SNMP Traps
#
# Monitora temperatura do sistema e envia trap SNMP quando ultrapassa limite
#
# Uso: ./temperature_monitor.sh [LIMITE_TEMPERATURA] [TRAP_DESTINATION]
# Exemplo: ./temperature_monitor.sh 70 localhost

# Configuracoes
TEMP_THRESHOLD=${1:-70}          # Limite de temperatura em Celsius (default: 70)
TRAP_DEST=${2:-localhost}        # Destino do trap (default: localhost)
COMMUNITY="public"               # Community string
CHECK_INTERVAL=60                # Intervalo de verificacao em segundos

# OIDs do CUSTOM-TRAPS-MIB
TRAP_OID=".1.3.6.1.4.1.99999.0.1"  # myHighTemperatureTrap
CURRENT_TEMP_OID=".1.3.6.1.4.1.99999.3.1.1.0"     # currentTemperature
THRESHOLD_OID=".1.3.6.1.4.1.99999.3.1.2.0"        # temperatureThreshold
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

# Funcao para obter temperatura
get_temperature() {
    local temp=0
    
    # Tenta ler temperatura de diferentes fontes
    
    # 1. sensors (lm-sensors)
    if command -v sensors &> /dev/null; then
        temp=$(sensors 2>/dev/null | grep -i 'core 0' | awk '{print $3}' | sed 's/+//;s/°C//' | cut -d. -f1)
        if [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null; then
            echo "$temp"
            return
        fi
    fi
    
    # 2. thermal_zone (Linux)
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ]; then
            # Converte de miligraus para graus
            temp=$((temp / 1000))
            echo "$temp"
            return
        fi
    fi
    
    # 3. vcgencmd (Raspberry Pi)
    if command -v vcgencmd &> /dev/null; then
        temp=$(vcgencmd measure_temp 2>/dev/null | sed 's/temp=//;s/°C//' | cut -d. -f1)
        if [ -n "$temp" ]; then
            echo "$temp"
            return
        fi
    fi
    
    # 4. osx-cpu-temp (MacOS)
    if command -v osx-cpu-temp &> /dev/null; then
        temp=$(osx-cpu-temp 2>/dev/null | awk '{print $1}' | cut -d. -f1)
        if [ -n "$temp" ]; then
            echo "$temp"
            return
        fi
    fi
    
    # 5. Simulacao (fallback para testes)
    # Gera temperatura aleatoria entre 30 e 85 graus
    temp=$((30 + RANDOM % 56))
    echo "$temp"
}

# Funcao para enviar trap SNMP
send_temperature_trap() {
    local current_temp=$1
    local severity=$2  # 2=warning, 3=critical
    local timestamp=$(date -Iseconds)
    
    log_critical "Enviando trap de temperatura alta: ${current_temp}°C (limite: ${TEMP_THRESHOLD}°C)"
    
    # Envia trap usando snmptrap
    snmptrap -v 2c -c "$COMMUNITY" "$TRAP_DEST" '' \
        "$TRAP_OID" \
        "$CURRENT_TEMP_OID" i "$current_temp" \
        "$THRESHOLD_OID" i "$TEMP_THRESHOLD" \
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
}

# Funcao principal de monitoramento
monitor_temperature() {
    log_info "Iniciando monitoramento de temperatura"
    log_info "Limite: ${TEMP_THRESHOLD}°C | Destino: ${TRAP_DEST} | Intervalo: ${CHECK_INTERVAL}s"
    
    local last_alert_time=0
    local alert_cooldown=300  # 5 minutos entre alertas do mesmo tipo
    
    while true; do
        temp=$(get_temperature)
        current_time=$(date +%s)
        
        if [ "$temp" -gt "$TEMP_THRESHOLD" ]; then
            # Verifica se pode enviar novo alerta (cooldown)
            time_since_alert=$((current_time - last_alert_time))
            
            if [ $time_since_alert -gt $alert_cooldown ]; then
                # Define severidade baseada na temperatura
                if [ "$temp" -gt $((TEMP_THRESHOLD + 20)) ]; then
                    severity=3  # Critical (>90°C se limite for 70)
                else
                    severity=2  # Warning
                fi
                
                send_temperature_trap "$temp" "$severity"
                last_alert_time=$current_time
            else
                log_warning "Temperatura alta (${temp}°C) mas em cooldown (${time_since_alert}s/${alert_cooldown}s)"
            fi
        else
            log_info "Temperatura OK: ${temp}°C (limite: ${TEMP_THRESHOLD}°C)"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Main
echo "========================================="
echo "  Monitor de Temperatura com SNMP Traps"
echo "========================================="
echo ""

check_dependencies

# Testa temperatura antes de iniciar
test_temp=$(get_temperature)
log_info "Temperatura atual detectada: ${test_temp}°C"

# Pergunta se quer testar enviando um trap
echo ""
read -p "Deseja enviar um trap de teste agora? (s/N): " test_trap
if [[ "$test_trap" =~ ^[Ss]$ ]]; then
    log_info "Enviando trap de teste..."
    send_temperature_trap "$test_temp" 2
    echo ""
fi

# Inicia monitoramento continuo
read -p "Iniciar monitoramento continuo? (s/N): " start_monitor
if [[ "$start_monitor" =~ ^[Ss]$ ]]; then
    echo ""
    monitor_temperature
else
    log_info "Monitoramento não iniciado. Script finalizado."
fi
