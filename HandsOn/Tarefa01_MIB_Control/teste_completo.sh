#!/bin/bash

echo "=========================================="
echo "TESTE COMPLETO - CUSTOM-CONTROL-MIB"
echo "=========================================="
echo

# Teste 1: GET todos os objetos
echo "1. GET - Leitura de todos os objetos:"
echo "--------------------------------------"
snmpget -v2c -c public localhost \
  .1.3.6.1.4.1.99999.1.1.1.0 \
  .1.3.6.1.4.1.99999.1.1.2.0 \
  .1.3.6.1.4.1.99999.1.1.3.0 \
  .1.3.6.1.4.1.99999.1.1.4.0
echo

# Teste 2: WALK da árvore
echo "2. WALK - Navegação da árvore OID:"
echo "--------------------------------------"
snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.1
echo

# Teste 3: SET com validação
echo "3. SET - Controle do serviço (restart):"
echo "--------------------------------------"
echo "Uptime ANTES:"
UPTIME_ANTES=$(snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.3.0 -Oqv)
echo "  $UPTIME_ANTES"
echo

echo "Executando SET restart (valor 2)..."
snmpset -v2c -c private localhost .1.3.6.1.4.1.99999.1.1.2.0 i 2
echo

echo "Aguardando 5 segundos..."
sleep 5
echo

echo "Uptime DEPOIS:"
UPTIME_DEPOIS=$(snmpget -v2c -c public localhost .1.3.6.1.4.1.99999.1.1.3.0 -Oqv)
echo "  $UPTIME_DEPOIS"
echo

# Validação
if [ "$UPTIME_ANTES" != "$UPTIME_DEPOIS" ]; then
    echo "✅ SUCESSO: Uptime mudou, restart confirmado!"
else
    echo "❌ FALHA: Uptime não mudou"
fi
echo

echo "=========================================="
echo "Log do SET (se disponível):"
echo "=========================================="
if [ -f /tmp/snmp_set.log ]; then
    cat /tmp/snmp_set.log
else
    echo "Nenhum log encontrado"
fi
