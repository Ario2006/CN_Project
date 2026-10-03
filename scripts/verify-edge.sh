#!/usr/bin/env bash
# Tasks D/E/F evidence via the edge, by NAME, with full certificate validation (no -k, no --resolve)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
CURL=/usr/bin/curl
SUFFIX=""; [ "$HTTPS_PORT" != "443" ] && SUFFIX=":$HTTPS_PORT"
URL="https://app.${DOMAIN}${SUFFIX}"

echo "== Load balancing: 8 requests to $URL/api/status =="
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
