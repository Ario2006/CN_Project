#!/usr/bin/env bash
# Ext B (extra, very visual): run a tiny CACHING resolver on this Mac (127.0.0.1:5300,
# no sudo) that forwards to Mac 1, then query it every 2 s. dig shows the TTL COUNTING
# DOWN 30..0 and the old IP being served until it hits 0 - exactly what an ISP/campus
# recursive resolver does. Needs dnsmasq installed on this Mac.
#   usage: scripts/ttl-cache-probe.sh [name]      (Ctrl+C stops the probe AND the cache)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
NAME="${1:-app.$DOMAIN}"
DNSMASQ="$(command -v dnsmasq || echo /opt/homebrew/sbin/dnsmasq)"
"$DNSMASQ" -k --port=5300 --listen-address=127.0.0.1 --bind-interfaces --no-resolv --no-hosts \
  --server="$MAC1_IP" --server="$BACKUP_DNS_IP" --cache-size=150 --log-queries --log-facility=/tmp/cn-ttl-cache.log &
CPID=$!; trap 'kill $CPID 2>/dev/null; echo; echo "cache stopped"' EXIT
sleep 1
echo "caching resolver 127.0.0.1:5300 -> upstream $MAC1_IP   (log /tmp/cn-ttl-cache.log)"
printf '%-8s %-6s %s\n' TIME TTL ANSWER
while true; do
  L="$(dig @127.0.0.1 -p 5300 "$NAME" A +noall +answer +time=1 +tries=1 | awk '/IN[[:space:]]+A/{print $2, $5; exit}')"
  printf '%-8s %-6s %s\n' "$(date +%T)" "${L%% *}" "${L#* }"
  sleep 2
done
