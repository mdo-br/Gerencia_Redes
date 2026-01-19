#!/bin/bash
# Script de agente SNMP para tabela de processos
# Implementa a PROCESS-TABLE-MIB
# OID Base: .1.3.6.1.4.1.99999.2.1
#
# NOTA: Usa indices sequenciais (1-20) mapeados para os PIDs reais
#       dos processos com maior uso de CPU

OID_BASE=".1.3.6.1.4.1.99999.2.1"
OID_TABLE="${OID_BASE}.1.1"
OID_COUNT="${OID_BASE}.2"

# Funcao para obter lista de processos ordenados por CPU
# Retorna: PID %CPU %MEM ETIME COMMAND
get_process_list() {
    ps -eo pid,%cpu,%mem,etime,comm --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=21'
}

# Funcao para obter PID real a partir do indice (1-20)
# Parametro: indice (1-20)
# Retorna: PID real
get_pid_by_index() {
    local INDEX=$1
    get_process_list | awk -v idx=$INDEX 'NR==idx {print $1}'
}

# Funcao para obter dados completos do processo pelo indice
# Parametro: indice (1-20)
# Retorna: linha completa "PID %CPU %MEM ETIME COMMAND"
get_process_by_index() {
    local INDEX=$1
    get_process_list | awk -v idx=$INDEX 'NR==idx'
}

# Funcao para converter memoria de % para MB
calc_memory_mb() {
    MEM_PERCENT=$1
    # Obter memoria total em MB
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    # Calcular MB usado
    echo "$MEM_PERCENT $TOTAL_MEM" | awk '{printf "%.0f", ($1/100)*$2}'
}

# Funcao para formatar uptime
format_uptime() {
    ETIME=$1
    # Ja vem formatado do ps (HH:MM:SS ou DD-HH:MM:SS)
    echo "$ETIME"
}

# Funcao para processar requisicao GET
process_get() {
    REQUEST_OID=$1
    
    # Extrair componentes do OID
    # OID formato: .1.3.6.1.4.1.99999.2.1.1.1.COLUNA.INDEX (INDEX = 1-20)
    
    if [[ $REQUEST_OID == ${OID_COUNT} ]]; then
        # Total de processos
        TOTAL=$(ps -e | wc -l)
        echo "$OID_COUNT"
        echo "gauge"
        echo "$TOTAL"
        return
    fi
    
    # Verificar se eh requisicao da tabela
    if [[ $REQUEST_OID =~ ^${OID_TABLE}\.([0-9]+)\.([0-9]+)$ ]]; then
        COLUMN="${BASH_REMATCH[1]}"
        INDEX="${BASH_REMATCH[2]}"
        
        # Validar indice (1-20)
        if [ "$INDEX" -lt 1 ] || [ "$INDEX" -gt 20 ]; then
            return
        fi
        
        # Obter dados completos do processo pelo indice (UMA UNICA CHAMADA)
        PROC_DATA=$(get_process_by_index $INDEX)
        
        if [ -z "$PROC_DATA" ]; then
            # Indice nao existe (menos de 20 processos)
            return
        fi
        
        # Parsear dados: PID %CPU %MEM ETIME COMMAND
        read -r P_PID P_CPU P_MEM P_TIME P_NAME <<< "$PROC_DATA"
        
        case $COLUMN in
            2)  # Process PID (real PID)
                echo "${OID_TABLE}.2.${INDEX}"
                echo "integer"
                echo "$P_PID"
                ;;
            3)  # Process Name
                echo "${OID_TABLE}.3.${INDEX}"
                echo "string"
                echo "$P_NAME"
                ;;
            4)  # CPU Percent
                echo "${OID_TABLE}.4.${INDEX}"
                echo "gauge"
                echo "${P_CPU%.*}"
                ;;
            5)  # Memory MB
                MEM_MB=$(calc_memory_mb "$P_MEM")
                echo "${OID_TABLE}.5.${INDEX}"
                echo "gauge"
                echo "$MEM_MB"
                ;;
            6)  # Uptime
                echo "${OID_TABLE}.6.${INDEX}"
                echo "string"
                echo "$P_TIME"
                ;;
        esac
    fi
}

# Funcao para processar requisicao GETNEXT
process_getnext() {
    REQUEST_OID=$1
    
    # Se requisicao eh do OID base da tabela ou antes
    if [[ $REQUEST_OID == $OID_TABLE ]] || [[ $REQUEST_OID == ${OID_TABLE%.1} ]] || [[ $REQUEST_OID < ${OID_TABLE} ]]; then
        # Retornar primeira coluna acessivel (processPID = coluna 2) do indice 1
        REAL_PID=$(get_pid_by_index 1)
        if [ -n "$REAL_PID" ]; then
            echo "${OID_TABLE}.2.1"
            echo "integer"
            echo "$REAL_PID"
        fi
        return
    fi
    
    # Se requisicao eh para uma coluna sem indice (ex: .1.1.1.2 ou .1.1.1.3)
    if [[ $REQUEST_OID =~ ^${OID_TABLE}\.([0-9]+)$ ]]; then
        COLUMN="${BASH_REMATCH[1]}"
        # Retornar indice 1 dessa coluna
        INDEX=1
        
        # Obter dados completos do processo pelo indice (UMA UNICA CHAMADA)
        PROC_DATA=$(get_process_by_index $INDEX)
        
        if [ -n "$PROC_DATA" ]; then
            # Parsear dados: PID %CPU %MEM ETIME COMMAND
            read -r P_PID P_CPU P_MEM P_TIME P_NAME <<< "$PROC_DATA"
                
                case $COLUMN in
                    2)  # Process PID
                        echo "${OID_TABLE}.2.1"
                        echo "integer"
                        echo "$P_PID"
                        ;;
                    3)  # Process Name
                        echo "${OID_TABLE}.3.1"
                        echo "string"
                        echo "$P_NAME"
                        ;;
                    4)  # CPU Percent
                        echo "${OID_TABLE}.4.1"
                        echo "gauge"
                        echo "${P_CPU%.*}"
                        ;;
                    5)  # Memory MB
                        MEM_MB=$(calc_memory_mb "$P_MEM")
                        echo "${OID_TABLE}.5.1"
                        echo "gauge"
                        echo "$MEM_MB"
                        ;;
                    6)  # Uptime
                        echo "${OID_TABLE}.6.1"
                        echo "string"
                        echo "$P_TIME"
                        ;;
                    *)
                        # Coluna invalida, retornar primeira coluna valida (PID)
                        echo "${OID_TABLE}.2.1"
                        echo "integer"
                        echo "$P_PID"
                        ;;
                esac
        fi
        return
    fi
    
    # Extrair componentes do OID atual (coluna.indice)
    if [[ $REQUEST_OID =~ ^${OID_TABLE}\.([0-9]+)\.([0-9]+)$ ]]; then
        CURRENT_COLUMN="${BASH_REMATCH[1]}"
        CURRENT_INDEX="${BASH_REMATCH[2]}"
        
        # Primeiro tentar avancar para proximo indice na mesma coluna
        NEXT_COLUMN=$CURRENT_COLUMN
        NEXT_INDEX=$((CURRENT_INDEX + 1))
        
        if [ $NEXT_INDEX -gt 20 ]; then
            # Esgotamos os indices desta coluna, ir para proxima coluna
            NEXT_COLUMN=$((CURRENT_COLUMN + 1))
            NEXT_INDEX=1
            
            if [ $NEXT_COLUMN -gt 6 ]; then
                # Fim da tabela, retornar contador
                TOTAL=$(ps -e | wc -l)
                echo "$OID_COUNT"
                echo "gauge"
                echo "$TOTAL"
                return
            fi
        fi
        
        # Obter PID real do proximo indice
        REAL_PID=$(get_pid_by_index $NEXT_INDEX)
        
        if [ -z "$REAL_PID" ]; then
            # Indice invalido, tentar proxima coluna
            NEXT_COLUMN=$((CURRENT_COLUMN + 1))
            NEXT_INDEX=1
            
            if [ $NEXT_COLUMN -gt 6 ]; then
                # Fim da tabela
                TOTAL=$(ps -e | wc -l)
                echo "$OID_COUNT"
                echo "gauge"
                echo "$TOTAL"
                return
            fi
            
            REAL_PID=$(get_pid_by_index $NEXT_INDEX)
        fi
        
        if [ -z "$REAL_PID" ]; then
            return
        fi
        
        # Obter dados completos do proximo processo (UMA UNICA CHAMADA)
        PROC_DATA=$(get_process_by_index $NEXT_INDEX)
        if [ -z "$PROC_DATA" ]; then
            return
        fi
        
        # Parsear dados: PID %CPU %MEM ETIME COMMAND
        read -r P_PID P_CPU P_MEM P_TIME P_NAME <<< "$PROC_DATA"
        
        case $NEXT_COLUMN in
            2)  # Process PID
                echo "${OID_TABLE}.2.${NEXT_INDEX}"
                echo "integer"
                echo "$P_PID"
                ;;
            3)  # Process Name
                echo "${OID_TABLE}.3.${NEXT_INDEX}"
                echo "string"
                echo "$P_NAME"
                ;;
            4)  # CPU Percent
                echo "${OID_TABLE}.4.${NEXT_INDEX}"
                echo "gauge"
                echo "${P_CPU%.*}"
                ;;
            5)  # Memory MB
                MEM_MB=$(calc_memory_mb "$P_MEM")
                echo "${OID_TABLE}.5.${NEXT_INDEX}"
                echo "gauge"
                echo "$MEM_MB"
                ;;
            6)  # Uptime
                echo "${OID_TABLE}.6.${NEXT_INDEX}"
                echo "string"
                echo "$P_TIME"
                ;;
        esac
        return
    fi
}

# Processar requisicao
case "$1" in
    -g)  # GET
        process_get "$2"
        ;;
    -n)  # GETNEXT
        process_getnext "$2"
        ;;
esac

exit 0
