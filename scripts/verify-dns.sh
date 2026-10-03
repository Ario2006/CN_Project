#!/usr/bin/env bash
# Task B evidence (run on a CLIENT Mac whose DNS is set to Mac 1)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
echo "== Resolver this Mac is using =="
scutil --dns | grep -m2 nameserver
echo
for h in app api; do
  name="$h.$DOMAIN"
  ans="$(dig +short "$name" | head -1)"
  if [ "$ans" = "$MAC2_IP" ]; then echo "PASS  $name -> $ans (Mac 2)"; else echo "FAIL  $name -> '${ans}' (expected $MAC2_IP)"; fi
done
echo
dig "app.$DOMAIN"
echo "== System resolver path (what curl/browsers use) =="
dscacheutil -q host -a name "app.$DOMAIN"
