#!/usr/bin/env bash
# Ext A: run on a CLIENT Mac. Shows which resolvers are configured, whether each one
# answers, and which one the system actually used.
#   usage: scripts/dns-failover-check.sh [--flush]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
NAME="app.$DOMAIN"
[ "${1:-}" = "--flush" ] && { sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; echo "[$(date +%T)] cache flushed (forces a real query)"; }
echo "== Configured resolvers (order matters) =="
echo "networksetup: $(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ')"
grep nameserver /etc/resolv.conf | sed 's/^/resolv.conf : /'
echo
echo "== Each DNS server queried directly (2 s timeout) =="
for s in "$MAC1_IP:PRIMARY Mac1" "$BACKUP_DNS_IP:BACKUP $BACKUP_DNS_LABEL"; do
  ip="${s%%:*}"; lbl="${s#*:}"
  R="$(dig +time=2 +tries=1 @"$ip" "$NAME" A +short 2>&1 | head -1)"
  case "$R" in [0-9]*) echo "UP    $lbl ($ip) -> $R";; *) echo "DOWN  $lbl ($ip) -> ${R:-no answer}";; esac
done
echo
echo "== What the client actually used (dig walks resolv.conf in order) =="
dig "$NAME" +time=2 +tries=1 | grep -E 'status:|^app|SERVER:|Query time'
echo
echo "== System resolver (what curl/Safari use) =="
dscacheutil -q host -a name "$NAME" | grep ip_address || echo "NOT RESOLVED"
echo
/usr/bin/curl -sS -m 4 -o /dev/null -w "curl https://$NAME -> HTTP %{http_code} via %{remote_ip}\n" "https://$NAME/api/status"
