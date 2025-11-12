#!/bin/bash
HOST=${1:-localhost}
DAYS=$(echo | openssl s_client -servername $HOST -connect $HOST:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | sed 's/.*=//' | xargs -I{} date -d {} +%s)
NOW=$(date +%s)
DIFF=$(( ($DAYS - $NOW) / 86400 ))
if [ "$DIFF" -gt 30 ]; then
  echo "CERT OK - $DIFF days until expiry"
  exit 0
elif [ "$DIFF" -gt 10 ]; then
  echo "CERT WARNING - $DIFF days until expiry"
  exit 1
else
  echo "CERT CRITICAL - $DIFF days until expiry"
  exit 2
fi
