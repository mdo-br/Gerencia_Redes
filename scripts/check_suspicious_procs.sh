#!/bin/bash
PATTERN="nmap|nc|netcat|socat|metasploit|msfconsole|python -m http.server"
FOUND=$(ps aux | egrep -i "$PATTERN" | egrep -v "egrep|check_suspicious_procs" || true)
if [ -n "$FOUND" ]; then
  echo "SUSPICIOUS_PROCS CRITICAL - found suspicious processes"
  echo "$FOUND"
  exit 2
else
  echo "SUSPICIOUS_PROCS OK - no suspicious processes found"
  exit 0
fi
