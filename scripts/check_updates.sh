#!/bin/bash
sudo apt update -qq >/dev/null 2>&1
PKG_COUNT=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l || true)
CRIT=10
WARN=2
if [ "$PKG_COUNT" -ge "$CRIT" ]; then
  echo "UPDATES CRITICAL - $PKG_COUNT packages upgradable"
  exit 2
elif [ "$PKG_COUNT" -ge "$WARN" ]; then
  echo "UPDATES WARNING - $PKG_COUNT packages upgradable"
  exit 1
else
  echo "UPDATES OK - $PKG_COUNT packages upgradable"
  exit 0
fi
