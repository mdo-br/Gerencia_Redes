#!/bin/bash
# handle_temperature_trap.sh
# Handler para processar myHighTemperatureTrap
# Recebe trap via STDIN e processa as variáveis

# Arquivo de log
LOG_FILE="/var/log/temperature_traps.log"

# Criar diretório de logs se não existir
sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
sudo touch "$LOG_FILE" 2>/dev/null
sudo chmod 666 "$LOG_FILE" 2>/dev/null

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Cabeçalho do log
echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] HIGH TEMPERATURE TRAP RECEIVED" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Variáveis para armazenar dados do trap
CURRENT_TEMP=""
THRESHOLD=""
ALERT_TIME=""
SEVERITY=""

# Ler dados do trap via STDIN
while read -r line; do
    echo "$line" >> "$LOG_FILE"
    
    # Parsear variáveis do trap
    # Formato: iso.3.6.1.4.1.99999.3.1.X.0 valor
    if [[ "$line" =~ 99999\.3\.1\.1\.0[[:space:]]+(.+)$ ]]; then
        CURRENT_TEMP="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.2\.0[[:space:]]+(.+)$ ]]; then
        THRESHOLD="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.7\.0[[:space:]]+\"?([^\"]+)\"?$ ]]; then
        ALERT_TIME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.8\.0[[:space:]]+(.+)$ ]]; then
        SEVERITY="${BASH_REMATCH[1]}"
    fi
done

# Processar dados
echo "----------------------------------------" >> "$LOG_FILE"
echo "PARSED DATA:" >> "$LOG_FILE"
echo "  Current Temperature: $CURRENT_TEMP°C" >> "$LOG_FILE"
echo "  Threshold: $THRESHOLD°C" >> "$LOG_FILE"
echo "  Alert Time: $ALERT_TIME" >> "$LOG_FILE"
echo "  Severity: $SEVERITY (1=warning, 2=critical, 3=emergency)" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Ações baseadas na severidade
case "$SEVERITY" in
    1)
        echo "ACTION: Warning level - Logging only" >> "$LOG_FILE"
        # Alerta sonoro leve (1 beep)
        beep -f 800 -l 200 2>/dev/null || (speaker-test -t sine -f 800 -l 1 2>/dev/null &)
        ;;
    2)
        echo "ACTION: Critical level - Send email alert" >> "$LOG_FILE"
        # echo "High temperature alert: ${CURRENT_TEMP}°C" | mail -s "Temperature Alert" admin@example.com
        # Alerta sonoro moderado (2 beeps)
        beep -f 1000 -l 300 -n -f 1000 -l 300 2>/dev/null || \
        (speaker-test -t sine -f 1000 -l 1 2>/dev/null & sleep 0.5; speaker-test -t sine -f 1000 -l 1 2>/dev/null &)
        ;;
    3)
        echo "ACTION: Emergency level - Immediate action required!" >> "$LOG_FILE"
        # Aqui você pode adicionar ações críticas como:
        # - Enviar SMS
        # - Trigger de scripts de shutdown
        # - Notificações via API (Slack, Discord, etc.)
        # Alerta sonoro de emergência (3 beeps rápidos e intensos)
        beep -f 1500 -l 400 -n -f 1500 -l 400 -n -f 1500 -l 400 2>/dev/null || \
        (for i in {1..3}; do speaker-test -t sine -f 1500 -l 1 2>/dev/null & sleep 0.5; done)
        ;;
    *)
        echo "ACTION: Unknown severity level" >> "$LOG_FILE"
        ;;
esac

# Log de conclusão
echo "[$TIMESTAMP] Trap processed successfully" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Retornar sucesso
exit 0
