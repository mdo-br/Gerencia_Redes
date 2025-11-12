#!/bin/bash
URL="${1:-http://localhost/}"
TMP=$(mktemp)
curl -s -D "$TMP" "$URL" -o /dev/null
H1=$(grep -i "^X-Frame-Options:" "$TMP" || true)
H2=$(grep -i "^Content-Security-Policy:" "$TMP" || true)
H3=$(grep -i "^X-Content-Type-Options:" "$TMP" || true)
H4=$(grep -i "^Strict-Transport-Security:" "$TMP" || true)
rm -f "$TMP"
MISSING=0
[ -z "$H1" ] && MISSING=$((MISSING+1))
[ -z "$H2" ] && MISSING=$((MISSING+1))
[ -z "$H3" ] && MISSING=$((MISSING+1))
if [ -n "$H4" ]; then :
fi
if [ "$MISSING" -eq 0 ]; then
  echo "APACHE OK - security headers present"
  exit 0
elif [ "$MISSING" -le 2 ]; then
  echo "APACHE WARNING - $MISSING security headers missing"
  exit 1
else
  echo "APACHE CRITICAL - $MISSING security headers missing"
  exit 2
fi
