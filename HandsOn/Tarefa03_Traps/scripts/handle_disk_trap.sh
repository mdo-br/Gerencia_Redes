#!/bin/bash
# handle_disk_trap.sh
# Handler para processar myDiskFullTrap
# Recebe trap via STDIN e processa as variáveis

# Arquivo de log
LOG_FILE="/var/log/disk_traps.log"

# Criar diretório de logs se não existir
sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
sudo touch "$LOG_FILE" 2>/dev/null
sudo chmod 666 "$LOG_FILE" 2>/dev/null

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Cabeçalho do log
echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] DISK FULL TRAP RECEIVED" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Variáveis para armazenar dados do trap
PARTITION=""
USAGE_PERCENT=""
TOTAL_MB=""
USED_MB=""
ALERT_TIME=""
SEVERITY=""

# Ler dados do trap via STDIN
while read -r line; do
    echo "$line" >> "$LOG_FILE"
    
    # Parsear variáveis do trap
    # Formato: iso.3.6.1.4.1.99999.3.1.X.0 valor
    if [[ "$line" =~ 99999\.3\.1\.3\.0[[:space:]]+\"?([^\"]+)\"?$ ]]; then
        PARTITION="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.4\.0[[:space:]]+(.+)$ ]]; then
        USAGE_PERCENT="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.5\.0[[:space:]]+(.+)$ ]]; then
        TOTAL_MB="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.6\.0[[:space:]]+(.+)$ ]]; then
        USED_MB="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.7\.0[[:space:]]+\"?([^\"]+)\"?$ ]]; then
        ALERT_TIME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ 99999\.3\.1\.8\.0[[:space:]]+(.+)$ ]]; then
        SEVERITY="${BASH_REMATCH[1]}"
    fi
done

# Calcular espaço livre
if [[ -n "$TOTAL_MB" && -n "$USED_MB" ]]; then
    FREE_MB=$((TOTAL_MB - USED_MB))
else
    FREE_MB="N/A"
fi

# Processar dados
echo "----------------------------------------" >> "$LOG_FILE"
echo "PARSED DATA:" >> "$LOG_FILE"
echo "  Partition: $PARTITION" >> "$LOG_FILE"
echo "  Usage: $USAGE_PERCENT%" >> "$LOG_FILE"
echo "  Total Space: ${TOTAL_MB}MB" >> "$LOG_FILE"
echo "  Used Space: ${USED_MB}MB" >> "$LOG_FILE"
echo "  Free Space: ${FREE_MB}MB" >> "$LOG_FILE"
echo "  Alert Time: $ALERT_TIME" >> "$LOG_FILE"
echo "  Severity: $SEVERITY (1=warning, 2=critical, 3=emergency)" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Ações baseadas na severidade
case "$SEVERITY" in
    1)
        echo "ACTION: Warning level - Logging only" >> "$LOG_FILE"
        ;;
    2)
        echo "ACTION: Critical level - Send email alert" >> "$LOG_FILE"
        # echo "Disk usage alert on $PARTITION: ${USAGE_PERCENT}%" | mail -s "Disk Alert" admin@example.com
        ;;
    3)
        echo "ACTION: Emergency level - Immediate action required!" >> "$LOG_FILE"
        # Aqui você pode adicionar ações críticas como:
        # - Cleanup de arquivos temporários
        # - Compressão de logs antigos
        # - Notificações via API (Slack, Discord, etc.)
        # - Trigger de scripts de manutenção
        ;;
    *)
        echo "ACTION: Unknown severity level" >> "$LOG_FILE"
        ;;
esac

# Sugestões de limpeza
if [[ "$USAGE_PERCENT" -gt 90 ]]; then
    echo "SUGGESTIONS:" >> "$LOG_FILE"
    echo "  1. Clean package cache: sudo apt-get clean" >> "$LOG_FILE"
    echo "  2. Remove old logs: sudo journalctl --vacuum-time=7d" >> "$LOG_FILE"
    echo "  3. Check large files: sudo du -h $PARTITION | sort -rh | head -20" >> "$LOG_FILE"
    echo "  4. Clean temp files: sudo rm -rf /tmp/*" >> "$LOG_FILE"
fi

# Log de conclusão
echo "[$TIMESTAMP] Trap processed successfully" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Retornar sucesso
exit 0
