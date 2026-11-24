#!/usr/bin/env bash
# Ext F - run ON the edge Mac (Mac 2, or the standby). Checks nginx itself and each upstream.
#   usage: scripts/diagnose-edge.sh [primary|standby]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
ROLE="${1:-primary}"; CONF="$ROOT/nginx/nginx.conf"; [ "$ROLE" = standby ] && CONF="$ROOT/nginx/nginx-standby.conf"
NGINX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/nginx"
echo "== this Mac: $(ipconfig getifaddr "$IFACE")  (primary edge $MAC2_IP, standby $STANDBY_EDGE_IP)"
echo "== nginx process / config test"
pgrep -fl "nginx: master" || echo "nginx master NOT running"
sudo "$NGINX" -t -c "$CONF" 2>&1 | tail -2
echo "== listening sockets on $HTTPS_PORT"
sudo lsof -nP -iTCP:"$HTTPS_PORT" -sTCP:LISTEN | tail -n +2 || echo "NOTHING listening on $HTTPS_PORT"
echo "== cert files"
ls -l "$CERT_DIR"/edge.pem "$CERT_DIR"/edge-key.pem 2>&1
openssl x509 -in "$CERT_DIR/edge.pem" -noout -subject -enddate -ext subjectAltName 2>/dev/null
echo "== upstreams in the RUNNING config"
grep -E '^\s*server [0-9]' "$CONF"
for u in $(grep -E '^\s*server [0-9]' "$CONF" | awk '{print $2}'); do
  ip="${u%:*}"; port="${u#*:}"
  printf '%-22s TCP: %s\n' "$u" "$(nc -vz -G 2 "$ip" "$port" 2>&1 | tail -1 | grep -oE 'succeeded|refused|timed out|Operation timed out' || echo 'no answer')"
  printf '%-22s HTTP: %s\n' "$u" "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://$u/api/status")"
done
echo "== last errors"; tail -n 8 /tmp/nginx-cn-error.log 2>/dev/null
echo "== last requests"; tail -n 6 /tmp/nginx-cn-access.log 2>/dev/null
