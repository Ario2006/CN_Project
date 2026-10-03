#!/usr/bin/env bash
# Task C evidence: hit each backend DIRECTLY (allowed for diagnosis only, not the final demo)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
for t in "A:$MAC3_IP:$BACKEND_A_PORT" "B:$MAC4_IP:$BACKEND_B_PORT"; do
  IFS=: read -r id ip port <<<"$t"
  echo "=============== Backend $id  $ip:$port ==============="
  nc -vz -G 2 "$ip" "$port" 2>&1 | tail -1
  for p in / /api/status /api/cache; do
    echo "--- GET $p"
    curl -si -m 3 "http://$ip:$port$p" | tr -d '\r'
    echo
  done
done
