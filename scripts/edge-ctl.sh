#!/usr/bin/env bash
# nginx edge control (nginx daemonizes itself).
#   scripts/edge-ctl.sh primary|standby start|stop|reload|test|status|log
#   primary = Mac 2, nginx/nginx.conf      standby = Mac 4, nginx/nginx-standby.conf
source "$(dirname "$0")/lib.sh"
ROLE="${1:?usage: edge-ctl.sh primary|standby start|stop|reload|test|status|log}"; ACTION="${2:-status}"
case "$ROLE" in primary) CONF="$ROOT/nginx/nginx.conf" ;; standby) CONF="$ROOT/nginx/nginx-standby.conf" ;; *) echo "role: primary|standby"; exit 1 ;; esac
certs_ok() { for f in edge.pem edge-key.pem; do [ -f "$CERT_DIR/$f" ] || { bad "missing $CERT_DIR/$f"; return 1; }; done; }
running() { [ -s /tmp/nginx-cn.pid ] && ps -p "$(cat /tmp/nginx-cn.pid)" >/dev/null 2>&1; }
status() {
  running && ok "nginx $ROLE RUNNING (master pid $(cat /tmp/nginx-cn.pid))" || bad "nginx $ROLE STOPPED"
  run "$CURL -sS -m 3 --resolve $APP:$HTTPS_PORT:127.0.0.1 https://$APP$PORTSUFFIX/edge-health"
}
case "$ACTION" in
  test)   certs_ok; run "sudo $NGINX -t -c $CONF" ;;
  start)  certs_ok || exit 1; running && { status; exit 0; }
          run "sudo $NGINX -t -c $CONF" && run "sudo $NGINX -c $CONF" && echo "[$(date +%T)] started $ROLE edge"; sleep 1; status ;;
  stop)   run "sudo $NGINX -c $CONF -s stop" && echo "[$(date +%T)] stopped $ROLE edge" ;;
  reload) run "sudo $NGINX -t -c $CONF" && run "sudo $NGINX -c $CONF -s reload" && echo "[$(date +%T)] reloaded $ROLE edge" ;;
  status) status ;;
  log)    tail -n 20 -f /tmp/nginx-cn-access.log /tmp/nginx-cn-error.log ;;
  *) echo "action: start|stop|reload|test|status|log"; exit 1 ;;
esac
