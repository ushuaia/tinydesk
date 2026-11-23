#!/bin/bash
# Soak check: watch TinyDesk's memory and its WebContent processes while you
# manually open/close tabs and hosts. A healthy app returns to a plateau when
# tabs are closed; an unbounded climb is a leak.
#
# Usage:  ./tool/soak_check.sh            (30s samples, until Ctrl-C)
#         INTERVAL=5 ./tool/soak_check.sh (faster sampling)

INTERVAL=${INTERVAL:-30}

echo "time       main(RSS MB)  webcontent(procs)  flutter(threads)"
while true; do
  PID=$(pgrep -f "TinyDesk.app/Contents/MacOS/TinyDesk" | head -1)
  if [ -z "$PID" ]; then
    echo "$(date +%H:%M:%S)  TinyDesk not running"
    sleep "$INTERVAL"
    continue
  fi
  RSS_KB=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
  RSS_MB=$(( ${RSS_KB:-0} / 1024 ))
  WEB=$(pgrep -f "com.apple.WebKit.WebContent" 2>/dev/null | wc -l | tr -d ' ')
  THREADS=$(ps -M -p "$PID" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  printf "%-10s %-13s %-18s %s\n" "$(date +%H:%M:%S)" "$RSS_MB" "$WEB" "$THREADS"
  sleep "$INTERVAL"
done
