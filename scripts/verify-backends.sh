#!/usr/bin/env bash
# Task C evidence: hit each backend DIRECTLY (allowed for diagnosis only, not the final demo)
# Subnet: 10.7.0.0/19 | Netmask: 255.255.224.0 (0xffffe000) | Gateway: 10.7.0.1
# Backend A: Mac 3 (Abhijeet, 10.7.2.73:3001) | Air MAC: 8e:c9:23:39:6e:c1 | HW MAC: 10:9f:41:c0:b2:b1
# Backend B: Mac 4 (Ankita, 10.7.5.46:3002)   | Air MAC: da:8e:64:df:05:3f | HW MAC: 10:9f:41:c6:2a:38
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"

for t in "A:$MAC3_IP:$BACKEND_A_PORT:$MAC3_AIR_MAC:Abhijeet" "B:$MAC4_IP:$BACKEND_B_PORT:$MAC4_AIR_MAC:Ankita"; do
  IFS=: read -r id ip port air_mac owner <<<"$t"
  echo "=============== Backend $id ($owner) $ip:$port (MAC: $air_mac) ==============="
  nc -vz -G 2 "$ip" "$port" 2>&1 | tail -1
  for p in / /api/status /api/cache; do
    echo "--- GET $p"
    curl -si -m 3 "http://$ip:$port$p" | tr -d '\r'
    echo
  done
done
