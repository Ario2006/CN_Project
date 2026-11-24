#!/usr/bin/env bash
# Ext D / E (and B): fire a request every INTERVAL s and print one line per request:
#   time | HTTP status | X-Backend | X-Edge | edge IP actually connected to | DNS cache answer
#   usage: scripts/watch-requests.sh [count|0=forever] [interval_s] [path]
#   e.g.   scripts/watch-requests.sh 0 1            (Ctrl+C to stop)
# Uses the SYSTEM resolver (mDNSResponder cache) -> shows what a real client/browser would hit.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
N="${1:-0}"; INT="${2:-1}"; P="${3:-/api/status}"
SUFFIX=""; [ "$HTTPS_PORT" != "443" ] && SUFFIX=":$HTTPS_PORT"
URL="https://app.${DOMAIN}${SUFFIX}${P}"
label() { case "$1" in "$MAC2_IP") echo "Mac2-primary";; "$STANDBY_EDGE_IP") echo "standby";; "") echo "-";; *) echo "?";; esac; }
echo "Watching $URL   (primary edge $MAC2_IP, standby $STANDBY_EDGE_IP)"
printf '%-8s %-4s %-7s %-8s %s\n' TIME HTTP BACKEND X-EDGE CONNECTED-TO
i=0
while [ "$N" -eq 0 ] || [ "$i" -lt "$N" ]; do
  i=$((i+1))
  OUT="$(/usr/bin/curl -sS -m 4 -o /dev/null -D - -w 'CODE=%{http_code} RIP=%{remote_ip}\n' "$URL" 2>&1 | tr -d '\r')"
  CODE="$(echo "$OUT" | sed -n 's/.*CODE=\([0-9]*\).*/\1/p')"
  RIP="$(echo "$OUT" | sed -n 's/.*RIP=\([0-9.]*\).*/\1/p')"
  BE="$(echo "$OUT" | awk -F': ' 'tolower($1)=="x-backend"{print $2}')"
  ED="$(echo "$OUT" | awk -F': ' 'tolower($1)=="x-edge"{print $2}')"
  ERR="$(echo "$OUT" | grep -m1 '^curl:' | cut -c1-60)"
  printf '%-8s %-4s %-7s %-8s %s %s\n' "$(date +%T)" "${CODE:-ERR}" "${BE:--}" "${ED:--}" "${RIP:--} ($(label "$RIP"))" "$ERR"
  sleep "$INT"
done
