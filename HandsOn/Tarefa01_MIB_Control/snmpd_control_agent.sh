#!/bin/bash

OID_BASE=".1.3.6.1.4.1.99999.1.1"

if [ "$1" = "-g" ]; then
    case "$2" in
        "${OID_BASE}.1.0")
            echo "${OID_BASE}.1.0"
            echo "integer"
            systemctl is-active --quiet snmpd && echo "1" || echo "2"
            ;;
        "${OID_BASE}.2.0")
            echo "${OID_BASE}.2.0"
            echo "integer"
            echo "0"
            ;;
        "${OID_BASE}.3.0")
            echo "${OID_BASE}.3.0"
            echo "string"
            systemctl show snmpd --property=ActiveEnterTimestamp --value 2>/dev/null | head -1
            ;;
        "${OID_BASE}.4.0")
            echo "${OID_BASE}.4.0"
            echo "string"
            snmpd -v 2>&1 | grep "NET-SNMP version" | awk '{print $3}'
            ;;
    esac
elif [ "$1" = "-n" ]; then
    case "$2" in
        ".1.3.6.1.4.1.99999"|".1.3.6.1.4.1.99999.1"|"${OID_BASE}"|"${OID_BASE}.0")
            echo "${OID_BASE}.1.0"
            echo "integer"
            systemctl is-active --quiet snmpd && echo "1" || echo "2"
            ;;
        "${OID_BASE}.1.0")
            echo "${OID_BASE}.2.0"
            echo "integer"
            echo "0"
            ;;
        "${OID_BASE}.2.0")
            echo "${OID_BASE}.3.0"
            echo "string"
            systemctl show snmpd --property=ActiveEnterTimestamp --value 2>/dev/null | head -1
            ;;
        "${OID_BASE}.3.0")
            echo "${OID_BASE}.4.0"
            echo "string"
            snmpd -v 2>&1 | grep "NET-SNMP version" | awk '{print $3}'
            ;;
    esac
elif [ "$1" = "-s" ]; then
    # SET operation
    OID="$2"
    TYPE="$3"
    VALUE="$4"
    
    echo "$(date): SET OID=$OID VALUE=$VALUE" >> /tmp/snmp_set.log
    
    if [ "$OID" = "${OID_BASE}.2.0" ]; then
        # Ação executada em background para não interromper o snmpd
        case "$VALUE" in
            1) echo "$(date): Executing STOP" >> /tmp/snmp_set.log; (sleep 1; sudo systemctl stop snmpd) >/dev/null 2>&1 & ;;
            2) echo "$(date): Executing RESTART" >> /tmp/snmp_set.log; (sleep 1; sudo systemctl restart snmpd) >/dev/null 2>&1 & ;;
            3) echo "$(date): Executing START" >> /tmp/snmp_set.log; (sleep 1; sudo systemctl start snmpd) >/dev/null 2>&1 & ;;
        esac
    fi
fi
