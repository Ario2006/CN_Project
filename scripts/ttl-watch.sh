#!/usr/bin/env bash
# Ext B / E: compare what the CLIENT CACHE says vs what the DNS SERVER says, every 2 s.
#   usage: scripts/ttl-watch.sh [name] [count]  (default app.$DOMAIN, forever; Ctrl+C to stop)
# CACHED   = macOS system resolver (mDNSResponder) = what curl/Safari will use
# SERVER   = fresh query straight to Mac 1 (dig never caches)
# STALE    = client still using the old answer because its TTL has not expired yet
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
NAME="${1:-app.$DOMAIN}"; COUNT="${2:-0}"; i=0
printf '%-8s %-16s %-16s %-5s %s\n' TIME CACHED\(client\) SERVER\(Mac1\) TTL STATE
while [ "$COUNT" -eq 0 ] || [ "$i" -lt "$COUNT" ]; do
  i=$((i+1))
  C="$(dscacheutil -q host -a name "$NAME" 2>/dev/null | awk '/ip_address/{print $2; exit}')"
  read -r S T <<<"$(dig +time=1 +tries=1 @"$MAC1_IP" "$NAME" A +noall +answer 2>/dev/null | awk '/IN[[:space:]]+A/{print $5, $2; exit}')"
  if [ -z "$C" ]; then ST="NO-ANSWER"; elif [ "$C" = "$S" ]; then ST="in sync"; else ST="STALE (cached old record)"; fi
  printf '%-8s %-16s %-16s %-5s %s\n' "$(date +%T)" "${C:--}" "${S:--}" "${T:--}" "$ST"
  sleep 2
done
