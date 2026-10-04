#!/usr/bin/env bash
# Tasks D/E/F evidence via the edge, by NAME, with full certificate validation (no -k, no --resolve)
# Edge node: Mac 2 (Ranajeet, 10.7.7.179:443) | Subnet: 10.7.0.0/19 | Netmask: 255.255.224.0
# Edge MAC: 06:a4:46:65:eb:bd (air) | 10:9f:41:bb:a2:9f (hardware)
# Upstreams: Backend A (10.7.2.73:3001, MAC: 8e:c9:23:39:6e:c1) & Backend B (10.7.5.46:3002, MAC: da:8e:64:df:05:3f)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
CURL=/usr/bin/curl
SUFFIX=""; [ "$HTTPS_PORT" != "443" ] && SUFFIX=":$HTTPS_PORT"
URL="https://app.${DOMAIN}${SUFFIX}"

echo "== Load balancing: 8 requests to $URL/api/status (Edge: $MAC2_IP, Air MAC: $MAC2_AIR_MAC) =="
for i in 1 2 3 4 5 6 7 8; do
  hdr="$($CURL -sS -m 5 -o /dev/null -D - "$URL/api/status" | tr -d '\r' | grep -i '^x-backend')"
  echo "request $i: ${hdr:-NO X-Backend (failed?)}"
done
echo
echo "== Caching headers (HEAD) =="
$CURL -sSI -m 5 "$URL/api/cache" | tr -d '\r' | egrep -i 'HTTP/|cache-control|etag|x-backend'
echo
echo "== Conditional request =="
$CURL -sS -m 5 -o /dev/null -w 'If-None-Match -> HTTP %{http_code}\n' -H 'If-None-Match: "phase1-cache-v1"' "$URL/api/cache"
