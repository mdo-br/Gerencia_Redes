#!/bin/bash
# check_mem.sh - realistic memory usage check using /proc/meminfo (Linux)
# Usage: check_mem.sh -w <warn_percent> -c <crit_percent>
WARN=80
CRIT=90
while getopts "w:c:" opt; do
  case "$opt" in
    w) WARN=$OPTARG ;;
    c) CRIT=$OPTARG ;;
  esac
done
# Read MemTotal and MemAvailable
MT=$(grep -i '^MemTotal:' /proc/meminfo | awk '{print $2}')
MA=$(grep -i '^MemAvailable:' /proc/meminfo | awk '{print $2}')
if [ -z "$MT" ] || [ -z "$MA" ]; then
  echo "MEM UNKNOWN - cannot read /proc/meminfo"
  exit 3
fi
USED_KB=$(( MT - MA ))
PCT=$(( 100 * USED_KB / MT ))
if [ "$PCT" -ge "$CRIT" ]; then
  echo "MEM CRITICAL - ${PCT}% used | mem_used_pct=${PCT}"
  exit 2
elif [ "$PCT" -ge "$WARN" ]; then
  echo "MEM WARNING - ${PCT}% used | mem_used_pct=${PCT}"
  exit 1
else
  echo "MEM OK - ${PCT}% used | mem_used_pct=${PCT}"
  exit 0
fi
