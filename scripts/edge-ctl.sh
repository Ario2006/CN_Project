#!/usr/bin/env bash
# Start/stop the nginx edge (safe over SSH; nginx daemonizes itself).
#   usage: scripts/edge-ctl.sh primary|standby start|stop|reload|test|status|log
#   primary = Mac 2 (nginx/nginx.conf)   standby = STANDBY_EDGE_IP Mac (nginx/nginx-standby.conf)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
ROLE="${1:?usage: edge-ctl.sh primary|standby start|stop|reload|test|status|log}"; ACTION="${2:-status}"
case "$ROLE" in
  primary) CONF="$ROOT/nginx/nginx.conf" ;;
  standby) CONF="$ROOT/nginx/nginx-standby.conf" ;;
  *) echo "role must be primary or standby"; exit 1 ;;
esac
NGINX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/nginx"
[ -x "$NGINX" ] || { echo "nginx not found at $NGINX -> brew install nginx"; exit 1; }

certs_ok() {
  for f in edge.pem edge-key.pem; do
    [ -f "$CERT_DIR/$f" ] || { echo "MISSING $CERT_DIR/$f  (copy from Mac 2: see docs/PHASE2_RUNBOOK.md, Ext E prep)"; return 1; }
  done
}
status() {
  if [ -s /tmp/nginx-cn.pid ] && ps -p "$(cat /tmp/nginx-cn.pid)" >/dev/null 2>&1; then
    echo "nginx ($ROLE) RUNNING  master pid $(cat /tmp/nginx-cn.pid 2>/dev/null)"
  else echo "nginx ($ROLE) STOPPED"; fi
  lsof -nP -iTCP:"$HTTPS_PORT" -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -3
  /usr/bin/curl -sS -m 3 --resolve "app.$DOMAIN:$HTTPS_PORT:127.0.0.1" "https://app.$DOMAIN:$HTTPS_PORT/edge-health" 2>&1 | sed 's/^/  edge-health: /'
}
case "$ACTION" in
  test)   certs_ok; sudo "$NGINX" -t -c "$CONF" ;;
  start)  certs_ok || exit 1; sudo "$NGINX" -t -c "$CONF" && sudo "$NGINX" -c "$CONF" && echo "started $ROLE edge at $(date '+%T')"; sleep 1; status ;;
  stop)   sudo "$NGINX" -c "$CONF" -s stop && echo "stopped $ROLE edge at $(date '+%T')" ;;
  reload) sudo "$NGINX" -t -c "$CONF" && sudo "$NGINX" -c "$CONF" -s reload && echo "reloaded $ROLE edge at $(date '+%T')" ;;
  status) status ;;
  log)    tail -n 30 -f /tmp/nginx-cn-access.log /tmp/nginx-cn-error.log ;;
  *) echo "action: start|stop|reload|test|status|log"; exit 1 ;;
esac
