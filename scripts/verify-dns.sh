#!/usr/bin/env bash
# Task B evidence (run on a CLIENT Mac whose DNS is set to Mac 1)
# Mac 1 DNS: 10.7.30.82 | Mask: 255.255.224.0 (/19) | Air MAC: de:ee:5b:31:fc:1a
# Mac 2 Target: 10.7.7.179 | Mask: 255.255.224.0 (/19) | Air MAC: 06:a4:46:65:eb:bd
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
echo "== Resolver this Mac is using (Expected: $MAC1_IP, Mac 1 DNS) =="
scutil --dns | grep -m2 nameserver
echo
for h in app api; do
  name="$h.$DOMAIN"
  ans="$(dig +short "$name" | head -1)"
  if [ "$ans" = "$MAC2_IP" ]; then
    echo "PASS  $name -> $ans (Mac 2 Edge, Air MAC: $MAC2_AIR_MAC)"
  else
    echo "FAIL  $name -> '${ans}' (expected $MAC2_IP)"
  fi
done
echo
dig "app.$DOMAIN"
echo "== System resolver path (what curl/browsers use) =="
dscacheutil -q host -a name "app.$DOMAIN"
