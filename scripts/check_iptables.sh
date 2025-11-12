#!/bin/bash
MINUTES=5
WARN=10
CRIT=50
COUNT=$(journalctl --since="${MINUTES} minutes ago" -k | grep -E "IN=.*(DROP|REJECT)" | wc -l 2>/dev/null || true)
if [ -z "$COUNT" ]; then COUNT=0; fi
if [ "$COUNT" -ge "$CRIT" ]; then
  echo "FIREWALL CRITICAL - $COUNT DROP/REJECT events in last ${MINUTES}m"
  exit 2
elif [ "$COUNT" -ge "$WARN" ]; then
  echo "FIREWALL WARNING - $COUNT DROP/REJECT events in last ${MINUTES}m"
  exit 1
else
  echo "FIREWALL OK - $COUNT DROP/REJECT events in last ${MINUTES}m"
  exit 0
fi
