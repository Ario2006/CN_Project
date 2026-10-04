#!/usr/bin/env bash
# Backend A runner - runs on Mac 3 (Abhijeet, 10.7.2.73, port 3001)
# Hostname: Abhijeets-MacBook-Pro-3 | Interface: en0
# Subnet: 10.7.0.0/19 | Netmask: 255.255.224.0 (0xffffe000) | Gateway: 10.7.0.1
# MAC (on-the-air): 8e:c9:23:39:6e:c1 | MAC (hardware): 10:9f:41:c0:b2:b1
cd "$(dirname "$0")" || exit 1
BACKEND_ID=A PORT=3001 exec python3 server.py
