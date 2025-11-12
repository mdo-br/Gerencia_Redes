#!/bin/bash
WARN=1000
CRIT=2000
if command -v conntrack >/dev/null 2>&1; then
  CNT=$(conntrack -C 2>/dev/null || ss -s 2>/dev/null | grep 'connections' -m1 | awk '{print $1}' || true)
else
  CNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
fi
CNT=${CNT:-0}
if [ "$CNT" -ge "$CRIT" ]; then
  echo "CONNTRACK CRITICAL - $CNT entries"
  exit 2
elif [ "$CNT" -ge "$WARN" ]; then
  echo "CONNTRACK WARNING - $CNT entries"
  exit 1
else
  echo "CONNTRACK OK - $CNT entries"
  exit 0
fi
